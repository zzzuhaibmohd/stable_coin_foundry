// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address weth;
        address wethUsdPriceFeed;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 4000e8;
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getLocalConfig();
        }
    }

    function getSepoliaConfig() public returns (NetworkConfig memory) {
        return NetworkConfig({
            weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getLocalConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        return NetworkConfig({
            weth: address(new ERC20Mock()),
            wethUsdPriceFeed: address(new MockV3Aggregator(DECIMALS, ETH_USD_PRICE)),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
