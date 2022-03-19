// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Architecturev2.sol";

contract CREDITSoy is Architecturev2 {

    ILending private constant Strategy = ILending(0xd9e28749e80D867d5d14217416BFf0e668C10645); // IB token
    IERC20 private constant Token = IERC20(0x77128DFdD0ac859B33F44050c6fa272F34872B5E); // Token to invest

    constructor() Architecturev2(false, address(Token)) ERC20("CREDIT Bean", "soyCREDIT") {}

    function igs_deposit(uint amount) internal virtual override {
        Token.approve(address(Strategy), amount);
        Strategy.deposit(amount);
    }

    function igs_underlyingBalance() public virtual override returns (uint) {
        return Strategy.balanceOf(address(this)) * Token.balanceOf(address(Strategy)) / Strategy.totalSupply();
    }

    function igs_withdraw(uint amount) internal virtual override {
        uint xAmount = amount * Strategy.totalSupply() / Token.balanceOf(address(Strategy));
        Strategy.approve(address(Strategy), type(uint256).max);
        Strategy.withdraw(xAmount);
    }
}

interface ILending is IERC20 {
    function deposit(uint) external;
    function withdraw(uint) external;
}