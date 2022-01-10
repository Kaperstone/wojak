// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../Common.sol";

abstract contract TStrategy is Common {
    using SafeERC20 for IERC20;

    event Deposit(uint busdIn, uint soyOut);
    event Withdraw(uint soyIn, uint busdOut);
    event Burn(uint wjkAmount, uint swjkAmount);

    constructor() Common() {}
    
    function deposit() public {
        // We don't use transferFrom, because we rely that the treasury will send on its own behalf the funds

        uint busdIn = BUSD.balanceOf(address(this));
        // We approve the farm to take our BUSD
        BUSD.approve(address(farm), busdIn);
        uint soyOut = farm.deposit(busdIn);
        // In exchange, we receive SOY tokens and the rest is being held by the farm

        emit Deposit(busdIn, soyOut);
    }

    function withdraw() public {
        // SOY -> BUSD
        uint soyIn = SOY.balanceOf(address(this));
        SOY.approve(address(farm), soyIn);
        farm.withdraw(soyIn);

        // BUSD -> Treasury
        uint busdOut = BUSD.balanceOf(address(this));
        BUSD.safeTransfer(address(treasury), busdOut);

        // Burn all WJK & sWJK tokens this contract holds.
        burn();

        emit Withdraw(soyIn, busdOut);
    }

    function burn() public {
        uint wjkAmount = WJK.balanceOf(address(this));
        uint swjkAmount = sWJK.balanceOf(address(this)); 

        wojak.burn(wjkAmount);
        staking.burn(swjkAmount);
        
        emit Burn(wjkAmount, swjkAmount);
    }
}