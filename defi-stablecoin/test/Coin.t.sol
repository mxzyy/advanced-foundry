// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ETHStablecoin} from "../src/Coin.sol";

contract ETHStablecoinTest is Test {
    ETHStablecoin public eths;

    function setUp() public {
        eths = new ETHStablecoin();
    }

    function testMint() public {
        eths.mint(address(this), 1000);
        assertEq(eths.balanceOf(address(this)), 1000);
    }

    function testBurn() public {
        eths.mint(address(this), 1000);
        eths.burn(1000);
        assertEq(eths.balanceOf(address(this)), 0);
    }


    function testMintRevertsIfAmountZero() public {                                                    
      vm.expectRevert(ETHStablecoin.ETHStablecoin__MustBeMoreThanZero.selector);                     
      eths.mint(address(this), 0);                                                                   
    }  
}
