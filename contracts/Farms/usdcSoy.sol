// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Architecturev2.sol";

contract USDCSoy is Architecturev2 {

    ILending private constant Strategy = ILending(0xE45Ac34E528907d0A0239ab5Db507688070B20bf); // IB token
    IERC20 private constant Token = IERC20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75); // Token to invest

    constructor() Architecturev2(true, address(Token)) ERC20("USDC Bean", "soyUSDC") {}

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