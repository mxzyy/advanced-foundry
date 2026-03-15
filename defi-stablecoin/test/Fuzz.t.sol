// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DeployScript} from "../script/Deploy.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ETHStablecoin} from "../src/Coin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract FuzzTest is Test {
    DeployScript deployer;
    ETHStablecoin dsc;
    DSCEngine engine;
    HelperConfig config;

    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("fuzzUser");
    address public LIQUIDATOR = makeAddr("fuzzLiquidator");

    function setUp() public {
        deployer = new DeployScript();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
    }

    ///////////////////////////
    // Deposit Fuzz Tests    //
    ///////////////////////////

    /// @notice Any valid deposit amount should succeed and update collateral balance
    function testFuzz_depositCollateral(uint256 amountCollateral) public {
        amountCollateral = bound(amountCollateral, 1, type(uint96).max);

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, amountCollateral);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateral(weth, amountCollateral);
        vm.stopPrank();

        uint256 balance = engine.getCollateralBalanceOfUser(USER, weth);
        assertEq(balance, amountCollateral);
    }

    /// @notice Depositing zero should always revert
    function testFuzz_depositCollateralRevertsOnZero(uint8 collateralSeed) public {
        address collateral = collateralSeed % 2 == 0 ? weth : wbtc;

        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(collateral, 0);
        vm.stopPrank();
    }

    ///////////////////////////
    // Mint Fuzz Tests       //
    ///////////////////////////

    /// @notice Minting within health factor limits should succeed
    function testFuzz_mintDscWithinHealthFactor(uint256 amountCollateral, uint256 amountDscToMint) public {
        amountCollateral = bound(amountCollateral, 1 ether, type(uint96).max);

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, amountCollateral);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateral(weth, amountCollateral);
        vm.stopPrank();

        uint256 collateralValueInUsd = engine.getUsdValue(weth, amountCollateral);
        // Max DSC = collateral * 50 / 100 (200% overcollateralization)
        uint256 maxDsc = collateralValueInUsd / 2;
        if (maxDsc == 0) return;

        amountDscToMint = bound(amountDscToMint, 1, maxDsc);

        vm.startPrank(USER);
        engine.mintDsc(amountDscToMint);
        vm.stopPrank();

        uint256 dscBalance = dsc.balanceOf(USER);
        assertEq(dscBalance, amountDscToMint);
    }

    /// @notice Minting more than allowed by health factor should revert
    function testFuzz_mintDscRevertsWhenBreakingHealthFactor(uint256 amountCollateral) public {
        amountCollateral = bound(amountCollateral, 1 ether, 100 ether);

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, amountCollateral);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateral(weth, amountCollateral);
        vm.stopPrank();

        uint256 collateralValueInUsd = engine.getUsdValue(weth, amountCollateral);
        uint256 maxDsc = collateralValueInUsd / 2;
        uint256 tooMuchDsc = maxDsc + 1;

        vm.startPrank(USER);
        vm.expectRevert();
        engine.mintDsc(tooMuchDsc);
        vm.stopPrank();
    }

    ///////////////////////////
    // Burn Fuzz Tests       //
    ///////////////////////////

    /// @notice Burning minted DSC should decrease balance proportionally
    function testFuzz_burnDsc(uint256 amountCollateral, uint256 amountToMint, uint256 amountToBurn) public {
        amountCollateral = bound(amountCollateral, 1 ether, type(uint96).max);

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, amountCollateral);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateral(weth, amountCollateral);
        vm.stopPrank();

        uint256 collateralValueInUsd = engine.getUsdValue(weth, amountCollateral);
        uint256 maxDsc = collateralValueInUsd / 2;
        if (maxDsc == 0) return;

        amountToMint = bound(amountToMint, 1, maxDsc);

        vm.startPrank(USER);
        engine.mintDsc(amountToMint);
        vm.stopPrank();

        amountToBurn = bound(amountToBurn, 1, amountToMint);

        vm.startPrank(USER);
        dsc.approve(address(engine), amountToBurn);
        engine.burnDsc(amountToBurn);
        vm.stopPrank();

        uint256 remainingDsc = dsc.balanceOf(USER);
        assertEq(remainingDsc, amountToMint - amountToBurn);
    }

    ///////////////////////////
    // Redeem Fuzz Tests     //
    ///////////////////////////

    /// @notice Redeeming collateral without debt should always succeed
    function testFuzz_redeemCollateralNoDsc(uint256 depositAmount, uint256 redeemAmount) public {
        depositAmount = bound(depositAmount, 1, type(uint96).max);

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, depositAmount);
        ERC20Mock(weth).approve(address(engine), depositAmount);
        engine.depositCollateral(weth, depositAmount);
        vm.stopPrank();

        redeemAmount = bound(redeemAmount, 1, depositAmount);

        vm.startPrank(USER);
        engine.redeemCollateral(weth, redeemAmount);
        vm.stopPrank();

        uint256 remaining = engine.getCollateralBalanceOfUser(USER, weth);
        assertEq(remaining, depositAmount - redeemAmount);
    }

    ///////////////////////////
    // Price Feed Fuzz Tests //
    ///////////////////////////

    /// @notice USD value calculation should be consistent with token amount conversion
    function testFuzz_usdValueAndTokenAmountAreInverse(uint256 ethAmount) public view {
        ethAmount = bound(ethAmount, 1, type(uint96).max);

        uint256 usdValue = engine.getUsdValue(weth, ethAmount);
        if (usdValue == 0) return;

        uint256 tokenAmount = engine.getTokenAmountFromUsd(weth, usdValue);
        // Should get back the original amount (may lose precision by 1 wei due to rounding)
        assertApproxEqAbs(tokenAmount, ethAmount, 1);
    }

    /// @notice getUsdValue should scale linearly with amount
    function testFuzz_usdValueScalesLinearly(uint256 amount) public view {
        amount = bound(amount, 1, type(uint80).max);

        uint256 singleValue = engine.getUsdValue(weth, amount);
        uint256 doubleValue = engine.getUsdValue(weth, amount * 2);

        assertEq(doubleValue, singleValue * 2);
    }

    ///////////////////////////
    // Health Factor Fuzz    //
    ///////////////////////////

    /// @notice Health factor should be max (type(uint256).max) when no DSC is minted
    function testFuzz_healthFactorMaxWithNoDsc(uint256 amountCollateral) public {
        amountCollateral = bound(amountCollateral, 1, type(uint96).max);

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, amountCollateral);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateral(weth, amountCollateral);
        vm.stopPrank();

        uint256 healthFactor = engine.getHealthFactor(USER);
        assertEq(healthFactor, type(uint256).max);
    }

    /// @notice Health factor should decrease when more DSC is minted
    function testFuzz_healthFactorDecreasesWithMoreDsc(uint256 amountCollateral, uint256 mint1, uint256 mint2) public {
        amountCollateral = bound(amountCollateral, 10 ether, type(uint96).max);

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, amountCollateral);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateral(weth, amountCollateral);
        vm.stopPrank();

        uint256 collateralValueInUsd = engine.getUsdValue(weth, amountCollateral);
        uint256 maxDsc = collateralValueInUsd / 2;
        if (maxDsc < 3) return;

        mint1 = bound(mint1, 1, maxDsc / 2);
        mint2 = bound(mint2, 1, maxDsc - mint1);

        vm.startPrank(USER);
        engine.mintDsc(mint1);
        uint256 healthFactor1 = engine.getHealthFactor(USER);

        engine.mintDsc(mint2);
        uint256 healthFactor2 = engine.getHealthFactor(USER);
        vm.stopPrank();

        assert(healthFactor2 <= healthFactor1);
    }

    ///////////////////////////
    // Liquidation Fuzz      //
    ///////////////////////////

    /// @notice Cannot liquidate a user with a good health factor
    function testFuzz_cantLiquidateHealthyUser(uint256 amountCollateral, uint256 amountDsc) public {
        amountCollateral = bound(amountCollateral, 1 ether, 100 ether);

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, amountCollateral);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateral(weth, amountCollateral);
        vm.stopPrank();

        uint256 collateralValueInUsd = engine.getUsdValue(weth, amountCollateral);
        uint256 maxDsc = collateralValueInUsd / 2;
        if (maxDsc == 0) return;

        amountDsc = bound(amountDsc, 1, maxDsc);

        vm.startPrank(USER);
        engine.mintDsc(amountDsc);
        vm.stopPrank();

        // Liquidator tries to liquidate
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, USER, amountDsc);
        vm.stopPrank();
    }

    ///////////////////////////////////
    // Deposit + Mint Combo Fuzz     //
    ///////////////////////////////////

    /// @notice depositCollateralAndMintDsc should work atomically
    function testFuzz_depositAndMintDsc(uint256 amountCollateral, uint256 amountDsc) public {
        amountCollateral = bound(amountCollateral, 1 ether, type(uint96).max);

        uint256 collateralValueInUsd = engine.getUsdValue(weth, amountCollateral);
        uint256 maxDsc = collateralValueInUsd / 2;
        if (maxDsc == 0) return;

        amountDsc = bound(amountDsc, 1, maxDsc);

        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, amountCollateral);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateralAndMintDsc(weth, amountCollateral, amountDsc);
        vm.stopPrank();

        uint256 dscBalance = dsc.balanceOf(USER);
        uint256 collateralBalance = engine.getCollateralBalanceOfUser(USER, weth);

        assertEq(dscBalance, amountDsc);
        assertEq(collateralBalance, amountCollateral);
    }

    //////////////////////////////////
    // Redeem + Burn Combo Fuzz     //
    //////////////////////////////////

    /// @notice redeemCollateralForDsc should burn DSC and return collateral atomically
    function testFuzz_redeemCollateralForDsc(uint256 amountCollateral, uint256 amountDsc) public {
        amountCollateral = bound(amountCollateral, 1 ether, type(uint96).max);

        uint256 collateralValueInUsd = engine.getUsdValue(weth, amountCollateral);
        uint256 maxDsc = collateralValueInUsd / 2;
        if (maxDsc == 0) return;

        amountDsc = bound(amountDsc, 1, maxDsc);

        // Deposit and mint
        vm.startPrank(USER);
        ERC20Mock(weth).mint(USER, amountCollateral);
        ERC20Mock(weth).approve(address(engine), amountCollateral);
        engine.depositCollateralAndMintDsc(weth, amountCollateral, amountDsc);

        // Redeem and burn all
        dsc.approve(address(engine), amountDsc);
        engine.redeemCollateralForDsc(weth, amountCollateral, amountDsc);
        vm.stopPrank();

        assertEq(dsc.balanceOf(USER), 0);
        assertEq(engine.getCollateralBalanceOfUser(USER, weth), 0);
    }

    ///////////////////////////////
    // ETHStablecoin Fuzz Tests  //
    ///////////////////////////////

    /// @notice Only the owner (DSCEngine) should be able to mint
    function testFuzz_coinMintRevertsIfNotOwner(address caller, uint256 amount) public {
        vm.assume(caller != address(engine));
        vm.assume(caller != address(0));
        amount = bound(amount, 1, type(uint96).max);

        vm.startPrank(caller);
        vm.expectRevert();
        dsc.mint(caller, amount);
        vm.stopPrank();
    }

    /// @notice Only the owner (DSCEngine) should be able to burn
    function testFuzz_coinBurnRevertsIfNotOwner(address caller, uint256 amount) public {
        vm.assume(caller != address(engine));
        amount = bound(amount, 1, type(uint96).max);

        vm.startPrank(caller);
        vm.expectRevert();
        dsc.burn(amount);
        vm.stopPrank();
    }
}
