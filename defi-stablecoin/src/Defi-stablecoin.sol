// SPDX-License-Identifier: MIT

// Layout of Contract:
//      version
//      imports
//      errors
//      interfaces, libraries, contracts
//      Type declarations
//      State variables
//      Events
//      Modifiers
//      Functions

// Layout of Functions:
//      constructor
//      receive function (if exists)
//      fallback function (if exists)
//      external
//      public
//      internal
//      private
//      view & pure functions

pragma solidity ^0.8.26;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ETHStablecoin
 * @author mxzyy
 * @notice This contract is the ERC-20 implementation of a decentralized stablecoin.
 *
 * - Relative Stability: Pegged to USD (1 token == $1)
 * - Stability Method: Algorithmic (minting & burning controlled by the protocol)
 * - Collateral Type: Exogenous (backed by ETH)
 *
 * This contract is meant to be governed by an external engine contract (e.g. DSCEngine).
 * This contract is just the ERC-20 token implementation. All stablecoin logic
 * (minting, redeeming, liquidating) should be handled by the governing contract.
 */
contract ETHStablecoin is ERC20Burnable, Ownable {
    ///////////////////
    // Errors        //
    ///////////////////
    error ETHStablecoin__MustBeMoreThanZero();
    error ETHStablecoin__BurnAmountExceedsBalance();
    error ETHStablecoin__NotZeroAddress();

    ///////////////////
    // Functions     //
    ///////////////////
    constructor() ERC20("ETH Stablecoin", "ETHS") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert ETHStablecoin__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert ETHStablecoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert ETHStablecoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert ETHStablecoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
