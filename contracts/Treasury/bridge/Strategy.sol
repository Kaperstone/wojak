// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../../_lib/Common.sol";

abstract contract TStrategy is Common {
    using SafeERC20 for IERC20;

    constructor(bool testnet) Common(testnet) {}

    function Get() public {
        farm.withdraw(SOY.balanceOf(address(this)));
        BUSD.safeTransfer(address(treasury), BUSD.balanceOf(address(this)));
    }
    
    function Invest() public {
        farm.deposit(BUSD.balanceOf(address(this)));
    }
}