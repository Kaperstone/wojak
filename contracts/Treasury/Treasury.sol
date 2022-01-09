// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Common.sol";

contract Treasury is Common {
    using SafeERC20 for IERC20;

    bool public stayHome = false;
    // Treasury only holds BUSD
    uint public busdInTreasury = 0;

    constructor() Common() {}

    function addToTreasury() public {
        // Increase balance
        busdInTreasury += BUSD.balanceOf(address(this)); 

        if(!stayHome) {
            invest();
        }
    }

    // When we want to upgrade the strategy, we withdraw the cash into the treasury.
    function get() public onlyRole(DEFAULT_ADMIN_ROLE) {
        stayHome = true;
        // Constant function to interact with
        tstrat.withdraw();
    }

    // Exposing as public function
    function put() public onlyRole(DEFAULT_ADMIN_ROLE) {
        invest();
    }

    function invest() private {
        stayHome = false;
        BUSD.safeTransfer(address(tstrat), BUSD.balanceOf(address(this)));
        // Constant function to interact with
        tstrat.deposit();
    }

    function changeTreasuryContract(address newContract) public onlyRole(DEFAULT_ADMIN_ROLE) {
        BUSD.safeTransfer(address(newContract), BUSD.balanceOf(address(this)));
    }
}