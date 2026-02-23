// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {ETHStablecoin} from "../src/Defi-stablecoin.sol";

contract DeployScript is Script {
    function run() public {
        vm.startBroadcast();
        new ETHStablecoin();
        vm.stopBroadcast();
    }
}
