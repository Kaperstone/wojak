// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Common.sol";

// When in treasury, busd is in the treasury
// When in investment, ib tokens in the strategy

contract Treasury is Common {
    using SafeERC20 for IERC20;

    event TreasuryAdded(uint busd);
    event ToWork(uint busdBalance);
    event FromWork(uint busdBalance);
    event Burn(uint wjkAmount, uint swjkAmount);

    bool public stayHome = false;
    // Treasury only holds BUSD
    uint public busdInTreasury = 0;

    constructor() Common() {}

    function addToTreasury() public {
        // Instead of using a function to transfer and dealing with "approve" and wasting on it gas
        // Contracts will "willingly" transfer busd to this contract

        uint added = 0;

        // Its either the money is in the hands of the treasury
        // Or its in the investment bridge i.e. "Strategy"
        if(!stayHome) {
            added = BUSD.balanceOf(address(this));
            invest();
        }else{
            added = BUSD.balanceOf(address(this)) - busdInTreasury;
        }
        
        busdInTreasury += added;

        emit TreasuryAdded(added);
    }

    // When we want to upgrade the strategy, we withdraw the cash into the treasury.
    function get() public onlyRole(DEFAULT_ADMIN_ROLE) {
        stayHome = true;
        // Constant function to interact with
        tstrat.withdraw();

        emit FromWork(BUSD.balanceOf(address(this)));
    }

    // Exposing as public function
    function put() public onlyRole(DEFAULT_ADMIN_ROLE) {
        stayHome = false;
        invest();

        emit ToWork(BUSD.balanceOf(address(this)));
    }

    function invest() private {
        // Without approve, just send to the strategy
        BUSD.safeTransfer(address(tstrat), BUSD.balanceOf(address(this)));
        // Constant function to interact with
        tstrat.deposit();
    }

    function changeTreasuryContract(address newContract) public onlyRole(DEFAULT_ADMIN_ROLE) {
        BUSD.safeTransfer(address(newContract), BUSD.balanceOf(address(this)));
    }

    function burn() public {
        uint wjkAmount = WJK.balanceOf(address(this));
        uint swjkAmount = sWJK.balanceOf(address(this)); 

        wojak.burn(wjkAmount);
        staking.burn(swjkAmount);
        
        emit Burn(wjkAmount, swjkAmount);
    }
}