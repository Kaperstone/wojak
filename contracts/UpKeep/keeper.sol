// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// This is the upkeep contract, it ensures that everything in every contract is running smoothly, including launching timers
// This contract is executed at least once per block (15sec)

import "./@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "./@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract Counter is KeeperCompatibleInterface {

    uint public counter = 0;

    /**
    * Use an interval in seconds and a timestamp to slow execution of Upkeep
    */
    uint public immutable interval;
    uint public lastTimeStamp;

    bytes32 internal keyHash;
    uint256 internal fee;
    
    uint256 public randomResult = 10;
    
    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Kovan
     * Chainlink VRF Coordinator address: 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9
     * LINK token address:                0xa36085F69e2889c224210F603D836748e7dC0088
     * Key Hash: 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4
     */
    constructor(uint updateInterval) VRFConsumerBase(
        0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
        0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
    ) {
        interval = updateInterval;
        lastTimeStamp = block.timestamp;
        keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
    }
    
    /** 
     * Requests randomness 
     */
    function getRandomNumber() private returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness + 1;
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        // Restrict the call to the UpKeeper contract only.
        if(UpKeepAddress == msg.sender) {
            upkeepNeeded = (block.timestamp - lastTimeStamp) > 21590;
            // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
            return (upkeepNeeded, bytes(""));
        }
    }
    
    uint lastBurn = block.timestamp;

    function performUpkeep(bytes calldata /* performData */) external override {
        lastTimeStamp = block.timestamp;
        counter = counter + 1;
        
        // Staking distribution every 6 hours
        Staking.distributeRewards();

        // Burning (random number) - every 72 hours
        if((lastBurn - block.timestamp) > 172750) {
            // Request for the next burn
            getRandomNumber();
            // Get the most random number we can get
            Bunker.heatOven(((block.number % 10) - (randomResult % 10)));
            // Renew timer
            lastBurn = block.timestamp;
        }

        // Take into effect all the bonds that should be released, but did not release yet.
        Bonds.relase();

        // Future:
        //  * Rebase
        //  * Liquidations for loans
    }
}