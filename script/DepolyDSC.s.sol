// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {dscEngine} from "../src/dscEngine.sol";
import {dStableCoin} from "../src/dStableCoin.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    function run() public returns (dStableCoin, dscEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address weth, address wethUsdPriceFeed, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        dStableCoin dsc = new dStableCoin();
        dscEngine engine = new dscEngine(weth, wethUsdPriceFeed, address(dsc));

        dsc.transferOwnership(address(engine));

        vm.stopBroadcast();
        return (dsc, engine, helperConfig);
    }
}
