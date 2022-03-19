// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Architecturev1.sol";

contract GEISTSoy is Architecturev1 {

    ILending private constant Strategy = ILending(0xB259d75fF80e3069bcf6Cb28aa5B2191FCd6a13C); // IB token
    IERC20 private constant Token = IERC20(0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE); // Token to invest

    constructor() Architecturev1(false, address(Token)) ERC20("GEIST Bean", "soyGEIST") {}

    function igs_deposit(uint amount) internal virtual override {
        Token.approve(address(Strategy), amount);
        Strategy.deposit(amount);
    }

    function igs_underlyingBalance() public virtual override returns (uint) {
        return Strategy.balanceOf(address(this)) * Strategy.totalSupply() / Strategy.balance();
    }

    function igs_withdraw(uint amount) internal virtual override {
        uint xAmount = Strategy.balance() * amount / Strategy.totalSupply();
        Strategy.approve(address(Strategy), type(uint256).max);
        Strategy.withdraw(xAmount);
    }
}

interface ILending is IERC20 {
    function deposit(uint) external;
    function withdraw(uint) external;

    function balance() external view returns (uint);
}