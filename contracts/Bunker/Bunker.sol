// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 *
 *  Bunker
 *  The function of this contract is very simple, it only holds the treasury - and it puts in "GoldenRog" smart contract which used as a bridge for investment.
 *      AddToTreasury: Done
 *
 *
**/

import "./@openzeppelin/contracts/access/AccessControl.sol";
import "./@openzeppelin/contracts/utils/Pancakeswap.sol";
import "./@openzeppelin/contracts/utils/SafeERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./iBunker.sol";

contract Bunker is AccessControl, IERC20 {

    bool public StayHome = true;
    uint public BUSDinTreasury = 0;

    IERC20 public BUSD = IERC20(address(0));
    GoldenRog public Bridge = GoldenRog(address(0));

    bool lock = false;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function addPennies() public {
        if(!lock) {
             addToTreasury();
        }
        // Postpone the function if burning is going on
    }

    function addToTreasury() private {
        // Increase balance
        BUSDinTreasury += BUSDinTreasury - BUSD.balanceOf(address(this)); 

        if(!StayHome) {
            putInInvestment();
        }
    }

    function putBackInBunker() public onlyRole(DEFAULT_ADMIN_ROLE) {
        StayHome = true;
        bridge.transformIncomeGeneratingTokensBackToTokens(address(this));
    }

    // Exposing to the public the function, but with admin restrictions
    function admin_putInInvestment() public onlyRole(DEFAULT_ADMIN_ROLE) {
        putInInvestment();
    }

    function putInInvestment() private {
        StayHome = false;
        BUSD.safeTransfer(address(bridge), BUSD.balanceOf(address(this)));
        Bridge.transformTokensToIncomeGeneratingTokens();
    }

    function setBUSDAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        BUSD = IERC20(newAddress);
    }

    function setBridgeAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        Bridge = GoldenRog(newAddress);
    }

    // When you send cash to the contract, you donate those tokens to treasury as a charity.
    // Your mistake, take responsibility.
    function convertDonations(address token) public {
        // Make a deal with Pancakeswap for some BUSD
    }

    function heatOven(uint randNum) public onlyRole(KEEPER_ROLE) {
        lock = true;

        // Take out the revenue, its not a part of the treasury anyway.
        uint revenue = Bridge.calculateRevenue();
        Bridge.takeIncome();

        // Check if we have minimum 10k to spend on burn
        // That should amount about 25mil in locked value in order for this to work with 5% return
        if(revenue > (10000 * 10**18)) {
            bool boughtLink = false;

            // Check if the keeper has at least 10 $LINK or more
            if(keeper.linkAmount() <= (10 * 10**18)) {
                boughtLink = true;

                // Buy LINK for 100 BUSD
                buyLink(100 * 10**18);

                // Send them to keeper
                LINK.transfer(address(keeper), LINK.balanceOf(address(this)));
            }

            // 
            if(block.timestamp > 172800 && randNum == 5) {
                // initiate a burn

                // We have 100 busd less
                if(boughtLink) revenue -= 100 * 10**18;

                // Buy WJK
                buyWJK(revenue);

                // Burn all tokens
                Token.burnEverything();
            }
        }else{ // Less than 10k, we re-add it back to the pool
            addToTreasury();
        }
        // Release lock
        lock = false;
    }

    function buyLink(uint busdAmount) private {
        // 
    }

    function buyWJK(uint busdAmount) private {
        // 
    }
}

interface GoldenRog {
    function transformIncomeGeneratingTokensBackToTokens() external;
    function transformTokensToIncomeGeneratingTokens() external;
    function calculateRevenue() external returns(uint256);
    function takeIncome() external;
}

