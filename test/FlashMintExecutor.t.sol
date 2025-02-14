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

    uint256 constant ONE = 10 ** 18;
    // Represents a 0.3% fee, but setting this doesn't matter
    uint24 constant FEE = 3000;
    address constant PROTOCOL_FEE_OWNER = address(80085);

    event FlashMintTokenAdded(address indexed token, address indexed flashMintContract);
    event FlashMintTokenRemoved(address indexed token);

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
    }

    function testConstructor() public {
        assertEq(address(flashMintExecutor.reactor()), address(reactor), "Incorrect reactor address");
        assertEq(flashMintExecutor.owner(), owner, "Incorrect owner address");
    }

    function testAddFlashMintToken() public {
        vm.expectEmit(true, false, false, true);
        emit FlashMintTokenAdded(address(mockSetToken), address(mockFlashMint));

        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), mockFlashMint);

        assertTrue(flashMintExecutor.flashMintEnabled(address(mockSetToken)), "Token should be enabled");
        assertEq(
            address(flashMintExecutor.flashMintForToken(address(mockSetToken))), 
            address(mockFlashMint), 
            "Incorrect flash mint contract"
        );
    }

    function testCannotAddFlashMintTokenWithZeroAddresses() public {
        vm.expectRevert("Invalid token");
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(0), IFlashMintDexV5(mockFlashMint));

        vm.expectRevert("Invalid FlashMint contract");
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), IFlashMintDexV5(address(0)));
    }

    function testCannotAddFlashMintTokenIfNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        flashMintExecutor.addFlashMintToken(address(mockSetToken), mockFlashMint);
    }

    function testRemoveFlashMintToken() public {
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), mockFlashMint);

        vm.expectEmit(true, false, false, true);
        emit FlashMintTokenRemoved(address(mockSetToken));

        vm.prank(owner);
        flashMintExecutor.removeFlashMintToken(address(mockSetToken));

        assertFalse(flashMintExecutor.flashMintEnabled(address(mockSetToken)), "Token should be disabled");
        assertEq(
            address(flashMintExecutor.flashMintForToken(address(mockSetToken))), 
            address(0), 
            "Flash mint contract should be removed"
        );
    }

    function testCannotRemoveFlashMintTokenIfNotOwner() public {
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), mockFlashMint);

        vm.prank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        flashMintExecutor.removeFlashMintToken(address(mockSetToken));
    }

    function testUpdateFlashMintToken() public {
        address newMockFlashMint = address(0x99);

        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), mockFlashMint);

        vm.expectEmit(true, true, false, false);
        emit FlashMintTokenAdded(address(mockSetToken), newMockFlashMint);

        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(mockSetToken), IFlashMintDexV5(newMockFlashMint));

        assertTrue(flashMintExecutor.flashMintEnabled(address(mockSetToken)), "Token should still be enabled");
        assertEq(
            address(flashMintExecutor.flashMintForToken(address(mockSetToken))), 
            newMockFlashMint, 
            "Flash mint contract should be updated"
        );
    }

}
