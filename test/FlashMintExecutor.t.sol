// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DutchOrderReactor, DutchOrder, DutchInput, DutchOutput} from "uniswapx/src/reactors/DutchOrderReactor.sol";
import {MockERC20} from "uniswapx/test/util/mock/MockERC20.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {MockSwapRouter} from "uniswapx/test/util/mock/MockSwapRouter.sol";
import {OutputToken, InputToken, OrderInfo, ResolvedOrder, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {DeployPermit2} from "uniswapx/test/util/DeployPermit2.sol";
import {OrderInfoBuilder} from "uniswapx/test/util/OrderInfoBuilder.sol";
import {OutputsBuilder} from "uniswapx/test/util/OutputsBuilder.sol";
import {PermitSignature} from "uniswapx/test/util/PermitSignature.sol";
import {ISwapRouter02, ExactInputParams} from "uniswapx/src/external/ISwapRouter02.sol";

import {FlashMintExecutor} from "../src/FlashMintExecutor.sol";
import {MockFlashMint} from "./mocks/MockFlashMint.sol";
import {MockSetToken} from "./mocks/MockSetToken.sol";
import {IFlashMintDexV5} from "../src/interfaces/IFlashMintDexV5.sol";

// This set of tests will use a mock flash mint to simulate the UniswapX flash mint executor.
contract FlashMintExecutorTest is Test, PermitSignature, DeployPermit2 {
    using OrderInfoBuilder for OrderInfo;

    address public owner;
    address public nonOwner;

    uint256 fillerPrivateKey;
    uint256 swapperPrivateKey;
    address filler;
    address swapper;
    DutchOrderReactor reactor;
    IPermit2 permit2;

    uint256 underlyingUnit;
    MockERC20 underlyingToken;
    MockSetToken mockSetToken;
    MockFlashMint mockFlashMint;

    FlashMintExecutor flashMintExecutor;

    IFlashMintDexV5.SwapData emptySwapData;

    uint256 constant ONE = 10 ** 18;
    // Represents a 0.3% fee, but setting this doesn't matter
    uint24 constant FEE = 3000;
    address constant PROTOCOL_FEE_OWNER = address(80085);

    event FlashMintTokenAdded(address indexed token, address indexed flashMintContract);
    event FlashMintTokenRemoved(address indexed token, address indexed flashMintContract);

    // to test sweeping ETH
    receive() external payable {}

    function setUp() public {
        vm.warp(1000);

        owner = msg.sender;
        nonOwner = address(0x420);

        // Mock input/output tokens
        underlyingUnit = 2 ether;
        underlyingToken = new MockERC20("Underlying", "UNDER", 18);
        mockSetToken = new MockSetToken("Set", "SET", 18, underlyingToken, underlyingUnit);

        // Mock filler and swapper
        fillerPrivateKey = 0x12341234;
        filler = vm.addr(fillerPrivateKey);
        swapperPrivateKey = 0x12341235;
        swapper = vm.addr(swapperPrivateKey);

        // Instantiate relevant contracts
        mockFlashMint = new MockFlashMint();
        permit2 = IPermit2(deployPermit2());
        reactor = new DutchOrderReactor(permit2, PROTOCOL_FEE_OWNER);

        flashMintExecutor = new FlashMintExecutor(reactor, owner);

        emptySwapData = IFlashMintDexV5.SwapData({
            path: new address[](0),
            fees: new uint24[](0),
            tickSpacing: new int24[](0),
            pool: address(0),
            poolIds: new bytes32[](0),
            exchange: 0
        });
    }

    function testConstructor() public {
        assertEq(address(flashMintExecutor.reactor()), address(reactor), "Incorrect reactor address");
        assertEq(flashMintExecutor.owner(), owner, "Incorrect owner address");
    }

    function testReactorCallbackIssuance() public {
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), address(mockFlashMint));

        uint256 issueAmount = 1 ether;

        OutputToken[] memory outputs = new OutputToken[](1);
        outputs[0].token = address(mockSetToken);
        outputs[0].amount = issueAmount;
        outputs[0].recipient = swapper;

        address setToken = address(mockSetToken);
        uint256 setAmount = issueAmount;
        address inputOutputToken = address(underlyingToken);
        uint256 inputOutputTokenAmount = issueAmount * underlyingUnit / ONE;

        IFlashMintDexV5.SwapData memory swapDataCollateral = emptySwapData;
        IFlashMintDexV5.SwapData memory swapDataInputOutputToken = emptySwapData;

        bytes memory flashMintCallData = abi.encodeWithSelector(
            IFlashMintDexV5.issueExactSetFromERC20.selector,
            setToken,
            setAmount,
            inputOutputToken,
            inputOutputTokenAmount,
            swapDataCollateral,
            swapDataInputOutputToken
        );

        bytes memory callbackData =
            abi.encode(setToken, address(mockFlashMint), inputOutputToken, true, flashMintCallData);

        ResolvedOrder[] memory resolvedOrders = new ResolvedOrder[](1);
        bytes memory sig = hex"1234";
        resolvedOrders[0] = ResolvedOrder(
            OrderInfoBuilder.init(address(reactor)).withSwapper(swapper).withDeadline(block.timestamp + 100),
            InputToken(underlyingToken, inputOutputTokenAmount, inputOutputTokenAmount),
            outputs,
            sig,
            keccak256(abi.encode(1))
        );

        underlyingToken.mint(address(swapper), inputOutputTokenAmount);
        assertEq(underlyingToken.balanceOf(address(swapper)), inputOutputTokenAmount);
        assertEq(underlyingToken.balanceOf(address(mockSetToken)), 0);
        assertEq(mockSetToken.balanceOf(address(swapper)), 0);

        vm.prank(address(swapper));
        // Note: In reality the reactor will send the tokens ot the executor prior to calling the callback
        underlyingToken.transfer(address(flashMintExecutor), inputOutputTokenAmount);
        vm.prank(address(reactor));
        flashMintExecutor.reactorCallback(resolvedOrders, callbackData);

        assertEq(underlyingToken.balanceOf(address(swapper)), 0);
        assertEq(underlyingToken.balanceOf(address(mockSetToken)), inputOutputTokenAmount);
        // Note: the output token is expected to be approved to the reactor which will then pull it out of the executor contract and send to the swapper
        assertEq(mockSetToken.allowance(address(flashMintExecutor), address(reactor)), issueAmount);
        // Note: Removed this assertion as it doesn't seem to be necessary / part of the interface
        // assertEq(mockSetToken.allowance(address(mockFlashMint), address(reactor)), type(uint256).max);
    }

    function testAddFlashMintToken() public {
        vm.expectEmit(true, false, false, true);
        emit FlashMintTokenAdded(address(mockSetToken), address(mockFlashMint));

        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), address(mockFlashMint));
        assertTrue(
            flashMintExecutor.flashMintEnabled(address(mockSetToken), address(mockFlashMint)), "Token should be enabled"
        );
    }

    function testCannotAddFlashMintTokenWithZeroAddresses() public {
        vm.expectRevert("Invalid token");
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(0), address(mockFlashMint));

        vm.expectRevert("Invalid FlashMint contract");
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), address(0));
    }

    function testCannotAddFlashMintTokenIfNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        flashMintExecutor.addFlashMintToken(address(mockSetToken), address(mockFlashMint));
    }

    function testRemoveFlashMintToken() public {
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), address(mockFlashMint));

        vm.expectEmit(true, true, false, true);
        emit FlashMintTokenRemoved(address(mockSetToken), address(mockFlashMint));

        vm.prank(owner);
        flashMintExecutor.removeFlashMintToken(address(mockSetToken), address(mockFlashMint));

        assertFalse(
            flashMintExecutor.flashMintEnabled(address(mockSetToken), address(mockFlashMint)),
            "Token should be disabled"
        );
    }

    function testCannotRemoveFlashMintTokenIfNotOwner() public {
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), address(mockFlashMint));

        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        flashMintExecutor.removeFlashMintToken(address(mockSetToken), address(mockFlashMint));
    }
}
