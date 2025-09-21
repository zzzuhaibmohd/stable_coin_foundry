// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract dStableCoin is ERC20Burnable, Ownable {
    error dStableCoin_MustBeMoreThanZero();
    error dStableCoin_BurnAmountExceedsBalance(uint256 balance, uint256 amount);
    error dStableCoin_InvalidReceiver();

    constructor() ERC20("dStableCoin", "dSC") Ownable(msg.sender) {}

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (amount <= 0) {
            revert dStableCoin_MustBeMoreThanZero();
        }

        if (amount > balance) {
            revert dStableCoin_BurnAmountExceedsBalance(balance, amount);
        }

        super.burn(amount);
    }

    function mint(address to, uint256 amount) public onlyOwner returns (bool) {
        if (to == address(0)) {
            revert dStableCoin_InvalidReceiver();
        }

        if (amount <= 0) {
            revert dStableCoin_MustBeMoreThanZero();
        }

        _mint(to, amount);
        return true;
    }
}
