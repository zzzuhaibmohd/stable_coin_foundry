// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DepolyDSC.s.sol";
import {dStableCoin} from "../../src/dStableCoin.sol";
import {dscEngine} from "../../src/dscEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract dscEngineTest is Test {
    DeployDSC public deployer;
    dStableCoin public usdc;
    dscEngine public dscCore;
    HelperConfig public config;

    address WETH;
    ERC20Mock public weth;
    address WETH_USD_PRICE_FEED;

    address user = makeAddr("user");

    function setUp() public {
        deployer = new DeployDSC();
        (usdc, dscCore, config) = deployer.run();
        (WETH, WETH_USD_PRICE_FEED,) = config.activeNetworkConfig();

        weth = ERC20Mock(WETH);

        //Mint some WETH to the user
        weth.mint(address(this), 1000 ether);
        weth.mint(user, 1000 ether);
    }

    /////////////////////////////////////////
    // Deposit Collateral depositCollateral()
    /////////////////////////////////////////

    function test_depositCollateral_RevertsIfAmountIsZero() public {
        vm.expectRevert(dscEngine.dscEngine_MustBeMoreThanZero.selector);
        dscCore.depositCollateral(0);
    }

    function testFuzz_depositCollateral_success(uint256 collateralAmount) public returns (uint256) {
        collateralAmount = bound(collateralAmount, 1, type(uint128).max);
        weth.mint(user, collateralAmount);
        vm.startPrank(user);
        weth.approve(address(dscCore), collateralAmount);
        dscCore.depositCollateral(collateralAmount);
        assertEq(dscCore.getAccountCollateralValue(user), dscCore.getUsdValue(collateralAmount));
        vm.stopPrank();
        return collateralAmount;
    }

    /////////////////////////////////////////
    // Mint Dsc mintDsc()
    /////////////////////////////////////////

    function test_mintDsc_RevertsIfAmountIsZero() public {
        vm.expectRevert(dscEngine.dscEngine_MustBeMoreThanZero.selector);
        dscCore.mintDsc(0);
    }

    function testFuzz_mintDsc_success(uint256 collateralAmount, uint256 dscAmount) public {
        uint256 depositedCollateral = testFuzz_depositCollateral_success(collateralAmount);

        uint256 collateralValueInUsd = dscCore.getAccountCollateralValue(user);
        uint256 maxSafeDscAmount =
            (collateralValueInUsd * dscCore.LIQUIDATION_THRESHOLD()) / dscCore.LIQUIDATION_PRECISION(); // 50% of collateral value

        // Bound dscAmount to be between 1 and maxSafeDscAmount
        dscAmount = bound(dscAmount, 1, maxSafeDscAmount);

        vm.startPrank(user);
        dscCore.mintDsc(dscAmount);
        vm.stopPrank();

        // Verify the mint was successful
        (uint256 totalDscMinted,) = dscCore.getAccountInfo(user);
        assertEq(totalDscMinted, dscAmount);

        // Verify health factor is still >= 1
        uint256 healthFactor = dscCore.getHealthFactor(user);
        assertGe(healthFactor, dscCore.MIN_HEALTH_FACTOR());
    }
}
