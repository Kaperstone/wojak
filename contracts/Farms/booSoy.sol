// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Architecturev2.sol";

contract BOOSoy is Architecturev2 {

    ILending private constant Strategy = ILending(0xa48d959AE2E88f1dAA7D5F611E01908106dE7598); // IB token
    IERC20 private constant Token = IERC20(0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE); // Token to invest

    constructor() Architecturev2(false, address(Token)) ERC20("BOO Bean", "soyBOO") {}

    function igs_deposit(uint amount) internal virtual override {
        Token.approve(address(Strategy), amount);
        Strategy.enter(amount);
    }

    function igs_underlyingBalance() public virtual override returns (uint) {
        return Strategy.BOOBalance(address(this));
    }

    function igs_withdraw(uint amount) internal virtual override {
        uint xbooAmount = Strategy.BOOForxBOO(amount);
        Strategy.approve(address(Strategy), type(uint256).max);
        Strategy.leave(xbooAmount);
    }
}

interface ILending is IERC20 {
    function enter(uint) external;
    function leave(uint) external;
    function BOOBalance(address) external view returns (uint);
    function BOOForxBOO(uint) external view returns (uint);
}