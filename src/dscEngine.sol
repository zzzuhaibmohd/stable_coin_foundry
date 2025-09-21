// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {dStableCoin} from "./dStableCoin.sol";

contract dscEngine {
    error dscEngine_MustBeMoreThanZero();
    error dscEngine_InvalidAddress();

    mapping(address => address) public s_CollateralToPriceFeed;
    dStableCoin public dsc;

    modifier moreThanZero(uint256 value) {
        if (value <= 0) {
            revert dscEngine_MustBeMoreThanZero();
        }
        _;
    }

    constructor(address collateral, address priceFeed, address dscAddress) {
        if (collateral == address(0) || priceFeed == address(0) || dscAddress == address(0)) {
            revert dscEngine_InvalidAddress();
        }

        s_CollateralToPriceFeed[collateral] = priceFeed;
        dsc = dStableCoin(dscAddress);
    }

    function depositCollateral(address asset, uint256 amount) public moreThanZero(amount) {}
}
