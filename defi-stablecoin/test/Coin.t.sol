// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {ETHStablecoin} from "../src/Coin.sol";

contract ETHStablecoinTest is Test {
    ETHStablecoin public eths;
    address public USER = makeAddr("user");

    function setUp() public {
        eths = new ETHStablecoin();
    }

    //////////////////////
    // Metadata Tests   //
    //////////////////////

    /// @notice Check that the token name is correct
    function testTokenName() public view {
        assertEq(eths.name(), "ETH Stablecoin");
    }

    /// @notice Check that the token symbol is correct
    function testTokenSymbol() public view {
        assertEq(eths.symbol(), "ETHS");
    }

    //////////////////////
    // Mint Tests       //
    //////////////////////

    /// @notice Minting should increase the balance of the recipient
    function testMint() public {
        eths.mint(address(this), 1000);
        assertEq(eths.balanceOf(address(this)), 1000);
    }

    /// @notice Minting should return true on success
    function testMintReturnsTrue() public {
        bool success = eths.mint(address(this), 1000);
        assertTrue(success);
    }

    /// @notice Minting with amount zero should revert
    function testMintRevertsIfAmountZero() public {
        vm.expectRevert(ETHStablecoin.ETHStablecoin__MustBeMoreThanZero.selector);
        eths.mint(address(this), 0);
    }

    /// @notice Minting to zero address should revert
    function testMintRevertsToZeroAddress() public {
        vm.expectRevert(ETHStablecoin.ETHStablecoin__NotZeroAddress.selector);
        eths.mint(address(0), 10);
    }

    /// @notice Minting from non-owner should revert
    function testMintRevertsIfNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        eths.mint(USER, 1000);
    }

    //////////////////////
    // Burn Tests       //
    //////////////////////

    /// @notice Burning should decrease the balance of the caller
    function testBurn() public {
        eths.mint(address(this), 1000);
        eths.burn(1000);
        assertEq(eths.balanceOf(address(this)), 0);
    }

    /// @notice Burning with amount zero should revert
    function testBurnRevertsAmountZero() public {
        vm.expectRevert(ETHStablecoin.ETHStablecoin__MustBeMoreThanZero.selector);
        eths.burn(0);
    }

    /// @notice Burning more than balance should revert
    function testBurnAmountExceedsBalance() public {
        eths.mint(address(this), 10);
        vm.expectRevert(ETHStablecoin.ETHStablecoin__BurnAmountExceedsBalance.selector);
        eths.burn(11111);
    }

    /// @notice Burning from non-owner should revert
    function testBurnRevertsIfNotOwner() public {
        eths.mint(USER, 1000);
        vm.prank(USER);
        vm.expectRevert();
        eths.burn(1000);
    }
}
