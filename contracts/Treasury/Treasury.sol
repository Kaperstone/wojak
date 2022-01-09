// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../_lib/Common.sol";

contract Treasury is Common {
    using SafeERC20 for IERC20;

    bool public StayHome = false;
    // Treasury only holds BUSD
    uint public BUSDinTreasury = 0;

    constructor(bool testnet) Common(testnet) {}

    function addToTreasury() public {
        // Increase balance
        BUSDinTreasury += BUSD.balanceOf(address(this)); 

        if(!StayHome) {
            Invest();
        }
    }

    // When we want to upgrade the strategy, we withdraw the cash into the treasury.
    function get() public onlyRole(DEFAULT_ADMIN_ROLE) {
        StayHome = true;
        // Constant function to interact with
        tstrat.Get();
    }

    // Exposing as public function
    function put() public onlyRole(DEFAULT_ADMIN_ROLE) {
        Invest();
    }

    function Invest() private {
        StayHome = false;
        BUSD.safeTransfer(address(tstrat), BUSD.balanceOf(address(this)));
        // Constant function to interact with
        tstrat.Invest();
    }

    function changeTreasuryContract(address newContract) public onlyRole(DEFAULT_ADMIN_ROLE) {
        BUSD.safeTransfer(address(newContract), BUSD.balanceOf(address(this)));
    }
}