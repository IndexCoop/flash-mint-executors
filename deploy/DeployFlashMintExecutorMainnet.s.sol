// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {FlashMintExecutor} from "../src/FlashMintExecutor.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {console} from "forge-std/console.sol";

contract DeployFlashMintExcecutorMainnet is Script {
    IReactor v2DutchOrderReactor = IReactor(0x00000011F84B9aa48e5f8aA8B9897600006289Be);
    address flashMintLeveraged = 0x45c00508C14601fd1C1e296eB3C0e3eEEdCa45D0;
    address eth2x = 0x65c4C0517025Ec0843C9146aF266A2C5a2D148A2;
    address btc2x = 0xD2AC55cA3Bbd2Dd1e9936eC640dCb4b745fDe759;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address owner = vm.addr(deployerPrivateKey);
        console.log("owner", owner);
        vm.startBroadcast(deployerPrivateKey);
        FlashMintExecutor flashMintExecutor = new FlashMintExecutor(v2DutchOrderReactor, owner);
        flashMintExecutor.addFlashMintToken(eth2x, flashMintLeveraged);
        flashMintExecutor.addFlashMintToken(btc2x, flashMintLeveraged);
    }
}
