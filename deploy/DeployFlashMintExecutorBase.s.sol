// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {FlashMintExecutor} from "../src/FlashMintExecutor.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {console} from "forge-std/console.sol";

contract DeployFlashMintExcecutorBase is Script {
    IReactor priorityOrderReactor = IReactor(0x000000001Ec5656dcdB24D90DFa42742738De729);
    address flashMintLeveraged = 0xE6c18c4C9FC6909EDa546649EBE33A8159256CBE;
    address eth2x = 0xC884646E6C88d9b172a23051b38B0732Cc3E35a6;
    address eth3x = 0x329f6656792c7d34D0fBB9762FA9A8F852272acb;
    address btc2x = 0x329f6656792c7d34D0fBB9762FA9A8F852272acb;
    address btc3x = 0x1F4609133b6dAcc88f2fa85c2d26635554685699;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address owner = vm.addr(deployerPrivateKey);
        console.log("owner", owner);
        vm.startBroadcast(deployerPrivateKey);
        FlashMintExecutor flashMintExecutor = new FlashMintExecutor(priorityOrderReactor, owner);
        flashMintExecutor.addFlashMintToken(eth2x, flashMintLeveraged);
        flashMintExecutor.addFlashMintToken(eth3x, flashMintLeveraged);
        flashMintExecutor.addFlashMintToken(btc2x, flashMintLeveraged);
        flashMintExecutor.addFlashMintToken(btc3x, flashMintLeveraged);
    }
}
