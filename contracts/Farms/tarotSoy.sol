// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Architecturev2.sol";

contract TAROTSoy is Architecturev2 {

    ILending private constant Strategy = ILending(0x74D1D2A851e339B8cB953716445Be7E8aBdf92F4); // IB token
    IERC20 private constant Token = IERC20(0xC5e2B037D30a390e62180970B3aa4E91868764cD); // Token to invest

    constructor() Architecturev2(false, address(Token)) ERC20("TAROT Bean", "soyTAROT") {}

    function igs_deposit(uint amount) internal virtual override {
        Token.approve(address(Strategy), amount);
        Strategy.enter(amount);
    }

    function igs_underlyingBalance() public virtual override returns (uint) {
        return Strategy.underlyingBalanceForAccount(address(this));
    }

    function igs_withdraw(uint amount) internal virtual override {
        uint xAmount = Strategy.underlyingValuedAsShare(amount);
        Strategy.approve(address(Strategy), type(uint256).max);
        Strategy.leave(xAmount);
    }
}

interface ILending is IERC20 {
    function enter(uint) external;
    function leave(uint) external;
    function underlyingBalanceForAccount(address) external returns (uint);
    function underlyingValuedAsShare(uint) external returns (uint);
}