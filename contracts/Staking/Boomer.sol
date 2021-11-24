// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 *
 * Staking
 * _mint here should be removed here permenanetly
 * The function takes rewards from the [token] contract and splits it among stakers proportionally
 *
 *
 *
 *
 *
**/

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";

abstract contract Boomer is ERC20, ERC20Burnable, AccessControl {

    address[] internal stakeholders;

    IERC20 internal tokenAddress = IERC20(address(0));
    Wojak internal wojak = Wojak(address(0));

    uint internal TotalStaked = 0;
    uint internal lastTotalRewardsFetchAmount = 0;
    uint internal lastStakingRewardsTimestamp = block.timestamp;
    uint internal lastStakingRewards = 0;

    constructor(address WojakTokenAddress) ERC20("Boomer", "BMR") {
        _mint(msg.sender, 500 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // Connect the original staking token
        tokenAddress = IERC20(address(WojakTokenAddress));
        wojak = Wojak(address(WojakTokenAddress));
    }

    // ---------- STAKES ----------

    function Stake(uint amount) public {
        // We transfer his tokens to the smart contract, its now in its posession
        require(tokenAddress.transferFrom(msg.sender, address(this), amount), "Unable to stake");
        // We can now mint, a dangerous function to our economy :o
        _mint(msg.sender, amount); // Mint Boomer tokens to his account
        // If its a new address, welcome to the staking pool
        if(balanceOf(msg.sender) == 0) addStakeholder(msg.sender); // New unique staker account
        TotalStaked += amount; // We add to the total staked.
    }

    function Unstake(uint amount) public {
        uint amountHave = balanceOf(msg.sender);
        // He requests back more than he can
        require(amount > amountHave, "No tokens to unstake");

        // We burn his Boomers
        _burn(msg.sender, amountHave);

        // Give him his tokens
        tokenAddress.transfer(msg.sender, amountHave);
        
        // Remove him from the array if he holds 0 tokens
        if(balanceOf(msg.sender) == 0) removeStakeholder(msg.sender);
        TotalStaked -= amount; // Decrease total staked
    }

    // ---------- STAKEHOLDERS ----------

    function isStakeholder(address _address) public view returns(bool, uint) {
        for (uint x = 0; x < stakeholders.length; x++){
            if (_address == stakeholders[x]) return (true, x);
        }
        return (false, 0);
    }

    function addStakeholder(address _stakeholder) internal {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(_stakeholder);
    }

    function removeStakeholder(address _stakeholder) internal {
        (bool _isStakeholder, uint x) = isStakeholder(_stakeholder);
        if(_isStakeholder) {
            stakeholders[x] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        } 
    }

    // ---------- REWARDS ----------

    // We need this, because when we are using `distributeRewards`
    // the TotalStaked amount grows each time it distributes, it means the last gets the least.
    // and its not necessarily the last one that staked.
    // So in order to keep things in order, we supply the TotalStaked
    function calculateRewardCustomSupply(address _stakeholder, uint stakeSupply) private view returns (uint) {
        // auto-compounding function ;)
        uint Staked = balanceOf(_stakeholder);
        
        return (lastTotalRewardsFetchAmount / (stakeSupply / Staked));
    }

    // Externally it can be used for `Next reward yield`
    function calculateReward(address _stakeholder) public view returns (uint) {
        // auto-compounding function ;)
        uint Staked = balanceOf(_stakeholder);
        
        return (lastTotalRewardsFetchAmount / (TotalStaked / Staked));
    }

    // Distribute once per 24 hours
    function distributeRewards() public {
        require((lastStakingRewardsTimestamp - block.timestamp) > 86400, "Staking rewards are distributed only once per 24 hours");
        // Set immediately the new timestamp
        lastStakingRewardsTimestamp = lastStakingRewardsTimestamp + 86400;

        uint initialStakedSupply = TotalStaked;

        // First stake is empty
        if(lastTotalRewardsFetchAmount != 0) {
            for(uint x = 0; x < stakeholders.length; x++) {
                uint Reward = calculateRewardCustomSupply(stakeholders[x], initialStakedSupply);
                _mint(msg.sender, Reward);
                TotalStaked += Reward; // because we are auto-compounding
            }
        }

        lastStakingRewards = lastTotalRewardsFetchAmount;
        lastTotalRewardsFetchAmount = wojak.requestMintedForStaking();
        tokenAddress.transfer(msg.sender, 1 ** 18);
    }
    
    function getLastStakingRewardsTimestamp() public view returns (uint) {
        return lastStakingRewardsTimestamp;
    }

    function getLastStakingRewards() public view returns (uint) {
        return lastStakingRewards;
    }

    function getTotalStaked() public view returns (uint256) {
        return TotalStaked;
    }

    function setWojakTokenAddress(address newWojakTokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenAddress = IERC20(address(newWojakTokenAddress));
        wojak = Wojak(address(newWojakTokenAddress));
    }
}

interface Wojak {
    function requestMintedForStaking() external returns (uint256);
    function requestMintedForBonds() external returns (uint256);
    function requestMintedForVaults() external returns (uint256);
    function updateTreasuryAddress(address newAddress) external;
    function updateBondsAddress(address newAddress) external;
    function updateVaultAddress(address newAddress) external;
    function updateOvenAddress(address newAddress) external;
    function updateStakingAddress(address newAddress) external;
    function setLiquidityFee(uint256 fee) external;
    function setTreasuryFee(uint256 fee) external;
    function setBurningFee(uint256 fee) external;
}