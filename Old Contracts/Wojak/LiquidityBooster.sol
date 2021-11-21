// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/** 
 *
 *  KADET smart contract - Liquidity Booster
 *  Becuase I'm poor and need some help.
 *
**/

contract LiquidityBooster {
    bool activeLiquidityBooster = false;
    
    constructor () {}

    function startLiquidityBooster(uint256 amount, bool byTime) external {
        /*

            the smart contract must hold some $kdt

        */
        require(!activeLiquidityBooster, "There is already an active Liquidity Booster event going on");


    }


    function depositLiquidityBooster(uint256 amount) external {
        require(activeLiquidityBooster, "There is no active liquidity booster event");
    }
}