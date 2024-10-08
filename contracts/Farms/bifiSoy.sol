// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Architecturev2.sol";

contract BIFISoy is Architecturev2 {

    ILending private constant Strategy = ILending(0x0467c22fB5aF07eBb14C851C75bFf4180674Ed64); // IB token
    IERC20 private constant Token = IERC20(0xd6070ae98b8069de6B494332d1A1a81B6179D960); // Token to invest

    constructor() Architecturev2(true, address(Token)) ERC20("BIFI Bean", "soyBIFI") {}

    function igs_deposit(uint amount) internal virtual override {
        Token.approve(address(Strategy), amount);
        Strategy.mint(amount);
    }

    function igs_underlyingBalance() public virtual override returns (uint) {
        return Strategy.balanceOfUnderlying(address(this));
    }

    function igs_withdraw(uint amount) internal virtual override {
        Strategy.approve(address(Strategy), type(uint256).max);
        Strategy.redeemUnderlying(amount);
    }
}

interface ILending is IERC20 {
    function mint(uint) external returns (uint);
    function redeemUnderlying(uint) external returns (uint);
    function balanceOfUnderlying(address) external returns (uint);
}