// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Architecturev2.sol";

contract SCREAMSoy is Architecturev2 {

    ILending private constant Strategy = ILending(0xe3D17C7e840ec140a7A51ACA351a482231760824); // IB token
    IERC20 private constant Token = IERC20(0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475); // Token to invest

    constructor() Architecturev2(false, address(Token)) ERC20("SCREAM Bean", "soySCREAM") {}

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