// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// This is the upkeep contract, it ensures that everything in every contract is running smoothly, including launching timers
// This contract is executed at least once per block (15sec)

import "./@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "./@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

import "../_lib/Common.sol";

contract Counter is Common, IKeeper, KeeperCompatibleInterface {
    using SafeERC20 for IERC20;

    uint private immutable interval = 2 * 3600; // 2 hours
    uint private lastUpkeep = block.timestamp;
    uint public counter = 0;

    constructor(bool testnet) Common(testnet) {}

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        // Restrict the call to the UpKeeper contract only.
        if(address(keeper) == msg.sender) {
            // Once per hour
            upkeepNeeded = (block.timestamp - lastUpkeep) > interval && LINK.balanceOf(address(this)) > 1000000000000000000; // At least 1 LINK
            // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
            return (upkeepNeeded, bytes(""));
        }
    }

    function simpleUpKeepCheck() external view onlyRole(DEFAULT_ADMIN_ROLE) returns (bool upkeepNeeded) {
        // Once per hour
        upkeepNeeded = (block.timestamp - lastUpkeep) > interval;
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
        return upkeepNeeded;
    }
    
    uint lastStaking = block.timestamp;
    uint lastFarming = block.timestamp + 2 * 3600; // Delay by 2 hours
    uint lastSelfKeep = block.timestamp + 4 * 3600; // Delay by 4 hours

    function performUpkeep(bytes calldata /* performData */) external override onlyRole(KEEPER_ROLE) {
        lastUpkeep = block.timestamp;

        // For fun.
        counter = counter + 1;
        
        if((block.timestamp - lastStaking) > (interval * 3)) {
            staking.distributeRewards();
            bonds.updateTokenPriceAtStaking();
            lastStaking = block.timestamp;
        }

        if((block.timestamp - lastFarming) > (interval * 3)) {
            farm.distributeRewards();
            bonds.updateTokenPriceAtFarming();
            lastFarming = block.timestamp;
        }

        if((block.timestamp - lastSelfKeep) > (interval * 3)) {
            // Contract receives BUSD from WJK transfer fees
            // Make sure the contract has enough LINK (at least 100 LINK, dunno why, just to make sure)
            if(LINK.balanceOf(address(this)) < (100 * 10**18)) {
                swap(address(BUSD), address(LINK), (100 * 10**18), address(this));
            }
            // cut the BUSD left in half
            uint halfBUSD = BUSD.balanceOf(address(this)) / 2;
            // 1 half for Liquidity
            swapAndLiquify(halfBUSD);
            // 1 half for Treasury
            BUSD.transfer(address(treasury), halfBUSD);

            treasury.addToTreasury();

            bonds.updateTokenPriceAtSelfKeep();

            lastSelfKeep = block.timestamp;
        }

        // Future:
        //  * Rebase
        //  * Liquidations for loans
    }
}