// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Architecturev2.sol";

contract WFTMSoy is Architecturev2 {
    ILending private constant Strategy = ILending(0x5AA53f03197E08C4851CAD8C92c7922DA5857E5d); // IB token
    IERC20 private constant Token = IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83); // Token to invest

    constructor() Architecturev2(true, address(Token)) ERC20("WFTM Bean", "soyWFTM") {}

    function igs_deposit(uint amount) internal virtual override {
        Token.approve(address(Strategy), amount);
        Strategy.mint(amount); // Put to work
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