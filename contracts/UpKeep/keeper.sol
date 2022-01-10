// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// This is the upkeep contract, it ensures that everything in every contract is running smoothly, including launching timers
// This contract is executed at least once per block (15sec)

import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

import "../Common.sol";

contract Counter is Common, IKeeper, KeeperCompatibleInterface {
    using SafeERC20 for IERC20;

    uint private constant INTERVAL = 2 * 3600; // 2 hours
    uint private lastUpkeep = block.timestamp;
    uint public counter = 0;

    event LaunchedRewards(uint8 RewardsType);

    constructor() Common() {}

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        // Restrict the call to the UpKeeper contract only.
        if(address(keeper) == msg.sender) {
            // Once per hour
            upkeepNeeded = (block.timestamp - lastUpkeep) > INTERVAL && LINK.balanceOf(address(this)) > 1000000000000000000; // At least 1 LINK
            // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
            return (upkeepNeeded, bytes(""));
        }
        return (false, bytes(""));
    }

    function adminCheckUp() public view override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool upkeepNeeded) {
        // Once per hour
        upkeepNeeded = (block.timestamp - lastUpkeep) > INTERVAL;
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
        return upkeepNeeded;
    }
    
    uint public nextStaking = block.timestamp;
    uint public nextFarming = block.timestamp + 2 * 3600; // Delay by 2 hours
    uint public nextSelfKeep = block.timestamp + 4 * 3600; // Delay by 4 hours

    function performUpkeep(bytes calldata /* performData */) external override onlyRole(KEEPER_ROLE) {
        lastUpkeep = block.timestamp;

        // For fun.
        counter = counter + 1;
        
        if(block.timestamp > nextStaking) {
            nextStaking += (INTERVAL * 3);
            
            staking.distributeRewards();
            bonds.updateTokenPriceAtStaking();

            emit LaunchedRewards(0);
            // 0 = Staking
        }

        if(block.timestamp > nextFarming) {
            nextFarming += (INTERVAL * 3);

            farm.distributeRewards();
            bonds.updateTokenPriceAtFarming();

            emit LaunchedRewards(1);
            // 1 = Farming
        }

        if(block.timestamp > nextSelfKeep) {
            nextSelfKeep += (INTERVAL * 3);

            uint busd = BUSD.balanceOf(address(this));

            // Contract receives BUSD from WJK transfer fees
            // Make sure the contract has enough LINK (at least 100 LINK, dunno why, just to make sure)
            if(LINK.balanceOf(address(this)) < (100 * 10**18)) {
                uint busdForLINK = 0;

                // If BUSD revenue is more than 100$
                if(busd > (100 * 10**18)) {
                    busdForLINK = 100 * 10**18;
                }else{ // If less, then we use everything to buy more LINK
                    busdForLINK = 100 * 10**18 - busd;
                }

                if(busdForLINK != 0) swap(address(BUSD), address(LINK), busdForLINK, address(this));
            }

            busd = BUSD.balanceOf(address(this));

            // If revenue more than 1000
            if(busd > (10 * 10**18)) {
                // Sent to use from 
                // cut the BUSD left in half
                uint halfBUSD = BUSD.balanceOf(address(this)) / 2;
                // 1 half for Liquidity
                swapAndLiquify(halfBUSD);
                // 1 half for Treasury
                BUSD.transfer(address(treasury), halfBUSD);

                // Make sure everything is added properly to the treasury.
                treasury.addToTreasury();

                // Update bond price
                bonds.updateTokenPriceAtSelfKeep();

                // 2 = Self keep
            }

            emit LaunchedRewards(1);
        }

        // Future:
        //  * Rebase
        //  * Liquidations for loans
    }
}