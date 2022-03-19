// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Architecturev2.sol";

contract SPELLSoy is Architecturev2 {

    ILending private constant Strategy = ILending(0xB19b33fFf3A9B21F120B6aC585b8ce21635BEb96); // IB token
    IERC20 private constant Token = IERC20(0x468003B688943977e6130F4F68F23aad939a1040); // Token to invest

    constructor() Architecturev2(true, address(Token)) ERC20("SPELL Bean", "soySPELL") {}

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