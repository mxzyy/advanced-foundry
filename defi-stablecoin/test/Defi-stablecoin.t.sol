// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ETHStablecoin} from "../src/Defi-stablecoin.sol";

contract ETHStablecoinTest is Test {
    ETHStablecoin public eths;

    function setUp() public {
        eths = new ETHStablecoin();
    }
}
