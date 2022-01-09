// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../Common.sol";

abstract contract TStrategy is Common {
    using SafeERC20 for IERC20;

    constructor() Common() {}
    
    function deposit() public {
        BUSD.approve(address(farm), BUSD.balanceOf(address(this)));
        farm.deposit(BUSD.balanceOf(address(this)));
    }

    function withdraw() public {
        SOY.approve(address(farm), SOY.balanceOf(address(this)));
        farm.withdraw(SOY.balanceOf(address(this)));
        BUSD.safeTransfer(address(treasury), BUSD.balanceOf(address(this)));
    }
}