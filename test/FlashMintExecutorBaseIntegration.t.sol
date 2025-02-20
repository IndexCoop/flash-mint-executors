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
import {
    PriorityOrder,
    PriorityOrderLib,
    PriorityInput,
    PriorityOutput,
    PriorityCosignerData
} from "uniswapx/src/lib/PriorityOrderLib.sol";
import {PriorityFeeLib} from "uniswapx/src/lib/PriorityFeeLib.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {ArrayBuilder} from "uniswapx/test/util/ArrayBuilder.sol";

import {FlashMintExecutor} from "../src/FlashMintExecutor.sol";
import {IFlashMintLeveraged, DEXAdapter} from "../src/interfaces/IFlashMintLeveraged.sol";
import {ISetToken} from "../src/interfaces/ISetToken.sol";
import {console} from "forge-std/console.sol";

// This set of tests will use a mock flash mint to simulate the UniswapX flash mint executor.
contract FlashMintExecutorBaseIntegrationTest is Test, PermitSignature, DeployPermit2 {
    using OrderInfoBuilder for OrderInfo;
    using PriorityOrderLib for PriorityOrder;
    using PriorityFeeLib for PriorityInput;
    using PriorityFeeLib for PriorityOutput;
    using PriorityFeeLib for PriorityOutput[];

    address public owner;
    address public nonOwner;

    uint256  underlyingUnit;
    Vm.Wallet cosignerWallet;
    address cosigner;
    uint256 cosignerPrivateKey;
    uint256 swapperPrivateKey;
    address swapper;
    FlashMintExecutor flashMintExecutor;
    DEXAdapter.SwapData emptySwapData;

    // Base test setup
    uint256 testBlock = 26614000;
    IReactor priorityOrderReactor = IReactor(0x000000001Ec5656dcdB24D90DFa42742738De729);
    IPermit2 permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    ISetToken eth2x = ISetToken(0xC884646E6C88d9b172a23051b38B0732Cc3E35a6);
    IFlashMintLeveraged flashMintLeveraged = IFlashMintLeveraged(payable(0xE6c18c4C9FC6909EDa546649EBE33A8159256CBE));
    address underlyingTokenWhale = 0x86D888C3fA8A7F67452eF2Eccc1C5EE9751Ec8d6;
    ERC20 underlyingToken = ERC20(0x4200000000000000000000000000000000000006); // WETH
    ERC20 usdc = ERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    address dai = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;

    // Max input amount to spent in issuance
    uint256 inputTokenAmount = 0.5 ether;

    uint256 setAmount = 1 ether;

    address setToken = address(eth2x);

    uint256 constant ONE = 10 ** 18;
    // Represents a 0.3% fee, but setting this doesn't matter
    uint24 constant FEE = 3000;
    address constant PROTOCOL_FEE_OWNER = address(80085);

    // to test sweeping ETH
    receive() external payable {}

    function setUp() public {
        vm.createSelectFork("base", testBlock);

        cosignerWallet = vm.createWallet("cosigner");

        owner = msg.sender;
        underlyingUnit = 2 ether;


        cosigner = cosignerWallet.addr;
        cosignerPrivateKey = cosignerWallet.privateKey;

        swapperPrivateKey = 0x12341235;
        swapper = vm.addr(swapperPrivateKey);
        vm.startPrank(swapper);
        underlyingToken.approve(address(permit2), 100 ether);
        eth2x.approve(address(permit2), 100 ether);
        vm.stopPrank();

        vm.startPrank(underlyingTokenWhale);
        underlyingToken.transfer(swapper, 100 ether);
        vm.stopPrank();

        flashMintExecutor = new FlashMintExecutor(priorityOrderReactor, owner);
        
        emptySwapData = DEXAdapter.SwapData({
            path: new address[](0),
            fees: new uint24[](0),
            pool: address(0),
            exchange: 0
        });
    }

    function cosignOrder(bytes32 orderHash, PriorityCosignerData memory cosignerData) private view returns (bytes memory sig) {
        bytes32 msgHash = keccak256(abi.encodePacked(orderHash, abi.encode(cosignerData)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(cosignerPrivateKey, msgHash);
        sig = bytes.concat(r, s, bytes1(v));
    }



    function testExecuteIssuance() public {
        vm.prank(owner);
        flashMintExecutor.addFlashMintToken(address(eth2x), address(flashMintLeveraged));

        ERC20 tokenIn = underlyingToken;
        address tokenOut = address(eth2x);

        console.log("block.basefee: %d", block.basefee);
        uint256 priorityFee = block.basefee + 1000;
        console.log("priorityFee: %d", priorityFee);
        vm.txGasPrice(priorityFee);

        uint256 inputMpsPerPriorityFeeWei = 1;
        uint256 outputMpsPerPriorityFeeWei = 0; // exact input
        uint256 deadline = block.timestamp + 1000;

        PriorityOutput[] memory outputs =
            OutputsBuilder.singlePriority(tokenOut, setAmount, outputMpsPerPriorityFeeWei, address(swapper));

        PriorityInput memory input = PriorityInput({token: tokenIn, amount: inputTokenAmount, mpsPerPriorityFeeWei: inputMpsPerPriorityFeeWei});
        uint256 scaledInputAmount = input.scale(priorityFee).amount;
        console.log("scaledInputAmount: %d", scaledInputAmount);

        bytes memory callbackData = generateIssuanceCallbackData(scaledInputAmount);

        PriorityCosignerData memory cosignerData = PriorityCosignerData({auctionTargetBlock: block.number});

        PriorityOrder memory order = PriorityOrder({
            info: OrderInfoBuilder.init(address(priorityOrderReactor)).withSwapper(swapper).withDeadline(deadline),
            cosigner: vm.addr(cosignerPrivateKey),
            auctionStartBlock: block.number,
            baselinePriorityFeeWei: 0,
            input: input,
            outputs: outputs,
            cosignerData: cosignerData,
            cosignature: bytes("")
        });
        order.cosignature = cosignOrder(order.hash(), cosignerData);

        _checkPermit2Nonce(swapper, order.info.nonce);

        SignedOrder memory signedOrder =
            SignedOrder(abi.encode(order), signOrder(swapperPrivateKey, address(permit2), order));
        flashMintExecutor.execute(signedOrder, callbackData);
    }

    function generateIssuanceCallbackData(uint256 scaledInputAmount) internal view returns(bytes memory callbackData){
        // Swapdata copied from this tx: https://basescan.org/tx/0xc9becf9480aba0753a7e9af6c59a12ad73b4c7159e7165b05368c2bb28dc5383
        address[] memory path = new address[](3);
        path[0] = address(usdc);
        path[1] = dai;
        path[2] = address(underlyingToken);

        uint24[] memory fees = new uint24[](2);
        fees[0] = 100;
        fees[1] = 500;

        DEXAdapter.SwapData memory swapDataDebtToCollateral = DEXAdapter.SwapData({ 
            path: path,
            fees: fees,
            pool: address(0),
            exchange: 3
        });
        DEXAdapter.SwapData memory swapDataInputOutputToken = emptySwapData;

        bytes memory flashMintCallData = abi.encodeWithSelector(
            IFlashMintLeveraged.issueExactSetFromERC20.selector,
            setToken,
            setAmount,
            underlyingToken,
            scaledInputAmount,
            swapDataDebtToCollateral,
            swapDataInputOutputToken
        );

        return abi.encode(
            setToken,
            address(flashMintLeveraged),
            underlyingToken,
            true,
            flashMintCallData
        );

    }

    function _checkPermit2Nonce(address swapper, uint256 nonce) internal view {
        uint256 wordPos = uint248(nonce >> 8);
        uint256 bit = 1 << uint8(nonce); // bitPos
        uint256 bitmap = permit2.nonceBitmap(swapper, wordPos);
        uint256 flipped = bitmap ^ bit;
        console.log("bitmap: %d", bitmap);
        console.log("flipped: %d", flipped);
        console.log("bit: %d", bit);
    }

}
