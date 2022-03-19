// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Architecturev2.sol";

contract CRVSoy is Architecturev2 {

    ILending private constant Strategy = ILending(0x820BdA1786AFA19DA6B92d6AC603574962337326); // IB token
    IERC20 private constant Token = IERC20(0x1E4F97b9f9F913c46F1632781732927B9019C68b); // Token to invest

    constructor() Architecturev2(true, address(Token)) ERC20("CRV Bean", "soyCRV") {}

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