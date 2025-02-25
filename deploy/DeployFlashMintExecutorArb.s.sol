// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {FlashMintExecutor} from "../src/FlashMintExecutor.sol";
import {IReactor} from "uniswapx/src/interfaces/IReactor.sol";
import {console} from "forge-std/console.sol";

contract DeployFlashMintExcecutorMainnet is Script {
    IReactor v2DutchOrderReactor = IReactor(0x1bd1aAdc9E230626C44a139d7E70d842749351eb);
    address flashMintLeveraged = 0xc6b3B4624941287bB7BdD8255302c1b337e42194;
    address eth2x = 0x26d7D3728C6bb762a5043a1d0CeF660988Bca43C;
    address eth3x = 0xA0A17b2a015c14BE846C5d309D076379cCDfa543;
    address ieth = 0x749654601a286833aD30357246400D2933b1C89b;
    address btc2x = 0xeb5bE62e6770137beaA0cC712741165C594F59D7;
    address btc3x = 0x3bDd0d5c0C795b2Bf076F5C8F177c58e42beC0E6;
    address ibtc = 0x80e58AEA88BCCaAE19bCa7f0e420C1387Cc087fC;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address owner = vm.addr(deployerPrivateKey);
        console.log("owner", owner);
        vm.startBroadcast(deployerPrivateKey);
        FlashMintExecutor flashMintExecutor = new FlashMintExecutor(v2DutchOrderReactor, owner);
        flashMintExecutor.addFlashMintToken(eth2x, flashMintLeveraged);
        flashMintExecutor.addFlashMintToken(eth3x, flashMintLeveraged);
        flashMintExecutor.addFlashMintToken(ieth, flashMintLeveraged);
        flashMintExecutor.addFlashMintToken(btc2x, flashMintLeveraged);
        flashMintExecutor.addFlashMintToken(btc3x, flashMintLeveraged);
        flashMintExecutor.addFlashMintToken(ibtc, flashMintLeveraged);
    }
}
