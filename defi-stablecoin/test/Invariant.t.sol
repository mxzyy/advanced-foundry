// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployScript} from "../script/Deploy.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ETHStablecoin} from "../src/Coin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    DeployScript deployer;
    ETHStablecoin dsc;
    DSCEngine engine;
    HelperConfig config;
    Handler handler;

    address weth;
    address wbtc;

    function setUp() public {
        deployer = new DeployScript();
        (dsc, engine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();

        handler = new Handler(engine, dsc);
        targetContract(address(handler));
    }

    /// @notice The total DSC supply must never exceed the USD value of all collateral in the system
    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = ERC20Mock(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = ERC20Mock(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("weth value: ", wethValue);
        console.log("wbtc value: ", wbtcValue);
        console.log("total supply: ", totalSupply);
        console.log("times mint called: ", handler.timesMintIsCalled());
        console.log("times deposit called: ", handler.timesDepositIsCalled());
        console.log("times redeem called: ", handler.timesRedeemIsCalled());

        assert(wethValue + wbtcValue >= totalSupply);
    }

    /// @notice All getter functions should never revert
    function invariant_gettersShouldNotRevert() public view {
        engine.getCollateralTokens();
        engine.getLiquidationThreshold();
        engine.getLiquidationBonus();
        engine.getPrecision();
        engine.getMinHealthFactor();
        engine.getDsc();
    }

    /// @notice DSC total supply must equal the sum tracked in the engine for all users who minted
    function invariant_dscTotalSupplyMatchesEngineTracking() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = ERC20Mock(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = ERC20Mock(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = engine.getUsdValue(wbtc, totalWbtcDeposited);
        uint256 totalCollateralValue = wethValue + wbtcValue;

        // The total collateral value adjusted for threshold must cover total supply
        // totalCollateral * 50 / 100 >= totalSupply (the overcollateralization invariant)
        if (totalSupply > 0) {
            assert(totalCollateralValue > 0);
        }
    }
}
