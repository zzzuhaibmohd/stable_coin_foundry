// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {dStableCoin} from "./dStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract dscEngine is ReentrancyGuard {
    // ========================================
    // Custom Errors
    // ========================================
    error dscEngine_MustBeMoreThanZero();
    error dscEngine_InvalidAddress();
    error dscEngine_TransferFailed();
    error dscEngine_HealthFactorIsBroken(uint256 healthFactor);
    error dscEngine_MintFailed();

    // ========================================
    // Events
    // ========================================
    event CollateralDeposited(address indexed collateral, uint256 indexed amount);
    event DscMinted(address indexed user, uint256 indexed amount);

    // ========================================
    // State Variables
    // ========================================

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    uint256 public constant LIQUIDATION_THRESHOLD = 50; // 200 % over collateral value
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address => address) private s_CollateralToPriceFeed;
    address private immutable i_collateral;
    dStableCoin private immutable i_dsc;
    mapping(address => uint256) private s_CollateralDeposited;
    mapping(address => uint256) private s_DscMinted;

    // ========================================
    // Modifiers
    // ========================================
    modifier moreThanZero(uint256 value) {
        if (value <= 0) {
            revert dscEngine_MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowed(address asset) {
        if (s_CollateralToPriceFeed[asset] == address(0)) {
            revert dscEngine_InvalidAddress();
        }
        _;
    }

    // ========================================
    // Constructor
    // ========================================
    constructor(address collateral, address priceFeed, address dscAddress) {
        if (collateral == address(0) || priceFeed == address(0) || dscAddress == address(0)) {
            revert dscEngine_InvalidAddress();
        }

        s_CollateralToPriceFeed[collateral] = priceFeed;
        i_dsc = dStableCoin(dscAddress);
        i_collateral = collateral;
    }

    // ========================================
    // External Functions
    // ========================================

    /// @notice Deposits collateral tokens into the engine
    /// @param amount The amount of collateral tokens to deposit
    function depositCollateral(uint256 amount) public moreThanZero(amount) isAllowed(i_collateral) nonReentrant {
        s_CollateralDeposited[msg.sender] += amount;
        bool success = IERC20(i_collateral).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert dscEngine_TransferFailed();
        }
        emit CollateralDeposited(i_collateral, amount);
    }

    function mintDsc(uint256 amount) public moreThanZero(amount) nonReentrant {
        s_DscMinted[msg.sender] += amount;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool success = i_dsc.mint(msg.sender, amount);
        if (!success) {
            revert dscEngine_MintFailed();
        }
        emit DscMinted(msg.sender, amount);
    }

    // ========================================
    // Private And Internal Functions
    // ========================================

    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = getAccountInfo(user);

        // If no DSC is minted, health factor is infinite (or very high)
        if (totalDscMinted == 0) {
            return type(uint256).max;
        }

        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert dscEngine_HealthFactorIsBroken(healthFactor);
        }
    }

    // ========================================
    // Public And External View Functions
    // ========================================

    function getAccountInfo(address user) public view returns (uint256 totalDscMinted, uint256 collateralValueInUsd) {
        totalDscMinted = s_DscMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function getAccountCollateralValue(address user) public view returns (uint256) {
        return getUsdValue(s_CollateralDeposited[user]);
    }

    function getUsdValue(uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_CollateralToPriceFeed[i_collateral]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION;
    }

    function getHealthFactor(address user) public view returns (uint256) {
        return _healthFactor(user);
    }
}
