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
    // Constructor constructor()
    /////////////////////////////////////////

    function test_constructor_RevertsIfInvalidAddress() public {
        vm.expectRevert(dscEngine.dscEngine_InvalidAddress.selector);
        new dscEngine(address(0), address(0), address(0));
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

    /////////////////////////////////////////
    // Deposit Collateral And Mint Dsc depositCollateralAndMintDsc()
    /////////////////////////////////////////

    function testFuzz_depositCollateralAndMintDsc_revertsIfHealthFactorIsBroken(
        uint256 collateralAmount,
        uint256 dscAmount
    ) public {
        collateralAmount = bound(collateralAmount, 1, type(uint128).max);
        weth.mint(user, collateralAmount);
        uint256 maxSafeDscAmount =
            (dscCore.getUsdValue(collateralAmount) * dscCore.LIQUIDATION_THRESHOLD()) / dscCore.LIQUIDATION_PRECISION(); // 50% of collateral value
        dscAmount = bound(dscAmount, maxSafeDscAmount + 1 wei, type(uint160).max);
        vm.startPrank(user);
        weth.approve(address(dscCore), collateralAmount);
        vm.expectRevert(dscEngine.dscEngine_HealthFactorIsBroken.selector);
        dscCore.depositCollateralAndMintDsc(collateralAmount, dscAmount);
        vm.stopPrank();
    }

    function testFuzz_depositCollateralAndMintDsc_success(uint256 collateralAmount, uint256 dscAmount) public {
        collateralAmount = bound(collateralAmount, 1, type(uint128).max);
        weth.mint(user, collateralAmount);
        uint256 maxSafeDscAmount =
            (dscCore.getUsdValue(collateralAmount) * dscCore.LIQUIDATION_THRESHOLD()) / dscCore.LIQUIDATION_PRECISION(); // 50% of collateral value
        dscAmount = bound(dscAmount, 1, maxSafeDscAmount);

        vm.startPrank(user);
        weth.approve(address(dscCore), collateralAmount);
        dscCore.depositCollateralAndMintDsc(collateralAmount, dscAmount);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscCore.getAccountInfo(user);
        assertEq(collateralValueInUsd, dscCore.getUsdValue(collateralAmount));
        assertEq(totalDscMinted, dscAmount);
    }

    /////////////////////////////////////////
    // Redeem Collateral redeemCollateral()
    /////////////////////////////////////////

    function testFuzz_redeemCollateral_revertsIfHealthFactorIsBroken(uint256 collateralAmount, uint256 dscAmountToMint)
        public
    {
        collateralAmount = bound(collateralAmount, 1, type(uint128).max);
        weth.mint(user, collateralAmount);
        uint256 maxSafeDscAmount =
            (dscCore.getUsdValue(collateralAmount) * dscCore.LIQUIDATION_THRESHOLD()) / dscCore.LIQUIDATION_PRECISION(); // 50% of collateral value
        dscAmountToMint = bound(dscAmountToMint, 1, maxSafeDscAmount);

        testFuzz_depositCollateralAndMintDsc_success(collateralAmount, dscAmountToMint);

        vm.startPrank(user);
        vm.expectRevert(dscEngine.dscEngine_HealthFactorIsBroken.selector);
        dscCore.redeemCollateral(collateralAmount);
        vm.stopPrank();
    }

    function testFuzz_redeemCollateral_success(uint256 collateralAmount, uint256 amountToRedeem) public {
        collateralAmount = bound(collateralAmount, 1, type(uint128).max);
        weth.mint(user, collateralAmount);
        testFuzz_depositCollateral_success(collateralAmount);

        amountToRedeem = bound(amountToRedeem, 1, collateralAmount);

        vm.startPrank(user);
        dscCore.redeemCollateral(amountToRedeem);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscCore.getAccountInfo(user);
        assertLt(collateralValueInUsd, dscCore.getUsdValue(collateralAmount));
    }

    /////////////////////////////////////////
    // Burn Dsc burnDsc()
    /////////////////////////////////////////

    function testFuzz_burnDsc_success(uint256 collateralAmount, uint256 dscAmountToMint, uint256 dscAmountToBurn)
        public
    {
        collateralAmount = bound(collateralAmount, 1, type(uint128).max);
        weth.mint(user, collateralAmount);
        uint256 maxSafeDscAmount =
            (dscCore.getUsdValue(collateralAmount) * dscCore.LIQUIDATION_THRESHOLD()) / dscCore.LIQUIDATION_PRECISION(); // 50% of collateral value
        dscAmountToMint = bound(dscAmountToMint, 1, maxSafeDscAmount);
        testFuzz_depositCollateralAndMintDsc_success(collateralAmount, dscAmountToMint);

        dscAmountToBurn = bound(dscAmountToBurn, 1, dscAmountToMint);

        vm.startPrank(user);
        usdc.approve(address(dscCore), dscAmountToBurn);
        dscCore.burnDsc(dscAmountToBurn);
        vm.stopPrank();

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscCore.getAccountInfo(user);
        assertEq(totalDscMinted, dscAmountToMint - dscAmountToBurn);
        assertEq(collateralValueInUsd, dscCore.getUsdValue(collateralAmount));
    }

    /////////////////////////////////////////
    // Redeem Collateral For Dsc redeemCollateralForDsc()
    /////////////////////////////////////////

    function testFuzz_redeemCollateralForDsc_success(
        uint256 collateralAmount,
        uint256 dscAmountToMint,
        uint256 amountToRedeem
    ) public {
        collateralAmount = bound(collateralAmount, 1, type(uint128).max);
        weth.mint(user, collateralAmount);
        uint256 maxSafeDscAmount =
            (dscCore.getUsdValue(collateralAmount) * dscCore.LIQUIDATION_THRESHOLD()) / dscCore.LIQUIDATION_PRECISION(); // 50% of collateral value
        dscAmountToMint = bound(dscAmountToMint, 1, maxSafeDscAmount);
        testFuzz_depositCollateralAndMintDsc_success(collateralAmount, dscAmountToMint);

        uint256 dscAmountToBurn = dscAmountToMint;
        amountToRedeem = bound(amountToRedeem, 1, collateralAmount);

        vm.startPrank(user);
        usdc.approve(address(dscCore), dscAmountToBurn);
        dscCore.redeemCollateralForDsc(dscAmountToBurn, amountToRedeem);
        vm.stopPrank();
    } //@note: Fix this test to calcualte the correct amount to burn and redeem
}
