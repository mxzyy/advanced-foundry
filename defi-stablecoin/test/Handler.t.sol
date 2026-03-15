// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {ETHStablecoin} from "../src/Coin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    DSCEngine engine;
    ETHStablecoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesMintIsCalled;
    uint256 public timesDepositIsCalled;
    uint256 public timesRedeemIsCalled;

    uint256 constant MAX_DEPOSIT_SIZE = type(uint96).max;

    address[] public usersWithCollateralDeposited;

    constructor(DSCEngine _engine, ETHStablecoin _dsc) {
        engine = _engine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

    }

    // Deposit collateral with bounded inputs
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        // May double-push, but that's okay for tracking
        usersWithCollateralDeposited.push(msg.sender);
        timesDepositIsCalled++;
    }

    // Redeem collateral — only if the user has deposited
    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateral = engine.getCollateralBalanceOfUser(msg.sender, address(collateral));
        amountCollateral = bound(amountCollateral, 0, maxCollateral);
        if (amountCollateral == 0) return;

        vm.startPrank(msg.sender);
        engine.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        timesRedeemIsCalled++;
    }

    // Mint DSC — only up to max allowed by health factor
    function mintDsc(uint256 amount, uint256 addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) return;
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint < 0) return;

        amount = bound(amount, 0, uint256(maxDscToMint));
        if (amount == 0) return;

        vm.startPrank(sender);
        engine.mintDsc(amount);
        vm.stopPrank();

        timesMintIsCalled++;
    }

    // NOTE: Price manipulation is excluded from the handler to preserve the core invariant.
    // The protocol acknowledges that extreme price drops can break overcollateralization.
    // To test price-crash scenarios, use dedicated fuzz tests instead.

    // Helper: pick collateral token from seed
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
