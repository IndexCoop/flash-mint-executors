// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {OutputToken, InputToken, OrderInfo, SignedOrder} from "uniswapx/src/base/ReactorStructs.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {DeployPermit2} from "uniswapx/test/util/DeployPermit2.sol";
import {OrderInfoBuilder} from "uniswapx/test/util/OrderInfoBuilder.sol";
import {OutputsBuilder} from "uniswapx/test/util/OutputsBuilder.sol";
import {PermitSignature} from "uniswapx/test/util/PermitSignature.sol";
import {ISwapRouter02, ExactInputParams} from "uniswapx/src/external/ISwapRouter02.sol";
import {V2DutchOrder, V2DutchOrderLib} from "uniswapx/src/lib/V2DutchOrderLib.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";

import {IFlashMintDexV5} from "../src/interfaces/IFlashMintDexV5.sol";
import {FlashMintExecutor} from "../src/FlashMintExecutor.sol";
import {IFlashMintLeveraged, DEXAdapter} from "../src/interfaces/IFlashMintLeveraged.sol";
import {ISetToken} from "../src/interfaces/ISetToken.sol";
import {console} from "forge-std/console.sol";

// This set of tests will use a mock flash mint to simulate the UniswapX flash mint executor.
contract FlashMintExecutorIntegrationTest is Test, PermitSignature, DeployPermit2 {
    using OrderInfoBuilder for OrderInfo;
    using V2DutchOrderLib for V2DutchOrder;

    uint256 testBlock = 19994792;
    address public owner;
    address public nonOwner;

    address underlyingTokenWhale = 0x8EB8a3b98659Cce290402893d0123abb75E3ab28;
    uint256  underlyingUnit;
    Vm.Wallet fillerWallet;
    address filler;
    uint256 fillerPrivateKey;
    uint256 swapperPrivateKey;
    address swapper;
    IReactor v2DutchOrderReactor = IReactor(0x00000011F84B9aa48e5f8aA8B9897600006289Be);
    IPermit2 permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IFlashMintLeveraged flashMintLeveraged = IFlashMintLeveraged(payable(0x45c00508C14601fd1C1e296eB3C0e3eEEdCa45D0));
    ISetToken eth2x = ISetToken(0x65c4C0517025Ec0843C9146aF266A2C5a2D148A2);
    ERC20 underlyingToken = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH

    FlashMintExecutor flashMintExecutor;
    
    DEXAdapter.SwapData emptySwapData;

    uint256 constant ONE = 10 ** 18;
    // Represents a 0.3% fee, but setting this doesn't matter
    uint24 constant FEE = 3000;
    address constant PROTOCOL_FEE_OWNER = address(80085);

    // to test sweeping ETH
    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("mainnet", testBlock);

        fillerWallet = vm.createWallet("filler");

        owner = msg.sender;
        underlyingUnit = 2 ether;

        vm.startPrank(underlyingTokenWhale);
        underlyingToken.transfer(address(this), 100 ether);
        vm.stopPrank();

        filler = fillerWallet.addr;
        fillerPrivateKey = fillerWallet.privateKey;
        swapperPrivateKey = 0x12341235;
        swapper = vm.addr(swapperPrivateKey);


        flashMintExecutor = new FlashMintExecutor(v2DutchOrderReactor, owner);
        
        emptySwapData = DEXAdapter.SwapData({
            path: new address[](0),
            fees: new uint24[](0),
            pool: address(0),
            exchange: 0
        });
    }

    function createAndSignOrder(V2DutchOrder memory request)
        public
        virtual
        returns (SignedOrder memory signedOrder, bytes32 orderHash)
    {

        request.cosigner = filler;
        request.info.reactor = v2DutchOrderReactor;
        bytes32 signatureData = keccak256(abi.encodePacked(request.hash(), abi.encode(request.cosignerData)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fillerWallet, signatureData);
        bytes memory signature = abi.encodePacked(abi.encode(r, s), v);
        request.cosignature = signature;
        _validateOrder(request.hash(), request);
        return (SignedOrder({
            order: abi.encode(request),
            sig: signature
        }), request.hash());
    }

    /// @dev Create many signed orders and return
    /// @param requests Array of orders to sign
    function createAndSignBatchOrders(V2DutchOrder[] memory requests)
        public
        returns (SignedOrder[] memory signedOrders, bytes32[] memory orderHashes)
    {
        signedOrders = new SignedOrder[](requests.length);
        orderHashes = new bytes32[](requests.length);
        for (uint256 i = 0; i < requests.length; i++) {
            (SignedOrder memory signed, bytes32 hash) = createAndSignOrder(requests[i]);
            signedOrders[i] = signed;
            orderHashes[i] = hash;
        }
        return (signedOrders, orderHashes);
    }

    function testReactorCallbackIssuance() public {
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(eth2x), IFlashMintDexV5(address(flashMintLeveraged)));

        uint256 issueAmount = 1 ether;

        OutputToken[] memory outputs = new OutputToken[](1);
        outputs[0].token = address(eth2x);
        outputs[0].amount = issueAmount;
        outputs[0].recipient = swapper;

        address setToken = address(eth2x);
        uint256 setAmount = issueAmount;
        address inputOutputToken = address(underlyingToken);
        uint256 inputOutputTokenAmount = issueAmount * underlyingUnit / ONE;

        DEXAdapter.SwapData memory swapDataCollateral = emptySwapData;
        DEXAdapter.SwapData memory swapDataInputOutputToken = emptySwapData;

        bytes memory callbackData = abi.encode(
            setToken,
            setAmount,
            inputOutputToken,
            inputOutputTokenAmount,
            swapDataCollateral,
            swapDataInputOutputToken,
            true
        );

        V2DutchOrder[] memory resolvedOrders = new V2DutchOrder[](1);
        // resolvedOrders[0] = V2DutchOrder(
        //     OrderInfoBuilder.init(address(v2DutchOrderReactor)).withSwapper(swapper).withDeadline(block.timestamp + 100),
        //     InputToken(underlyingToken, inputOutputTokenAmount, inputOutputTokenAmount),
        //     outputs,
        //     sig,
        //     keccak256(abi.encode(1))
        // );


        //vm.prank(address(swapper));
        // Note: In reality the reactor will send the tokens ot the executor prior to calling the callback
        underlyingToken.transfer(address(flashMintExecutor), inputOutputTokenAmount);

        (SignedOrder[] memory signedOrders, bytes32[] memory orderHashes) = createAndSignBatchOrders(resolvedOrders);

        flashMintExecutor.executeBatch(signedOrders, callbackData);

    }

    /// @notice validate the dutch order fields
    /// - deadline must be greater than or equal to decayEndTime
    /// - decayEndTime must be greater than decayStartTime
    /// - if there's input decay, outputs must not decay
    /// @dev Throws if the order is invalid
    function _validateOrder(bytes32 orderHash, V2DutchOrder memory order) internal pure {
        (bytes32 r, bytes32 s) = abi.decode(order.cosignature, (bytes32, bytes32));
        uint8 v = uint8(order.cosignature[64]);
        // cosigner signs over (orderHash || cosignerData)
        address signer = ecrecover(keccak256(abi.encodePacked(orderHash, abi.encode(order.cosignerData))), v, r, s);
    }


}
