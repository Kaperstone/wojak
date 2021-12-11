// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 *
 * Staking
 * _mint here should be removed here permenanetly
 * The function takes rewards from the [token] contract and splits it among stakers proportionally
 *
**/

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";
import "./@openzeppelin/contracts/utils/SafeERC20.sol";

import "./iBoomer";

abstract contract Boomer is ERC20, ERC20Burnable, AccessControl {
    uint8 internal days_passed = 0;
    uint internal lastSupply = 10000;

    address[] internal stakeholders;

    Wojak internal tokenAddress = Wojak(address(0));
    Wojak internal bondAddress = Wojak(address(0));

    uint internal TotalStaked = 0;
    uint internal lastTotalRewardsFetchAmount = 0;
    uint internal lastStakingRewardsTimestamp = block.timestamp;
    uint internal lastStakingRewards = 0;
    uint private lastBlockNum = 0;

    bool lock = false;

    constructor(address WojakTokenAddress) ERC20("Boomer", "BMR") {
        _mint(msg.sender, 500 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // Connect the original staking token
        tokenAddress = Wojak(address(WojakTokenAddress));
    }

    // ---------- STAKES ----------

    function Stake(uint amount) public {
        require(lock == false, "Try again later");
        lastBlockNum = block.number;

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
        // Flash loan
        require(lastBlockNum != block.number, "!");
        lock = true;
        lastBlockNum = block.number;

        require((lastStakingRewardsTimestamp - block.timestamp) > 21600, "Staking rewards are distributed only once per 24 hours");
        // Set immediately the new timestamp
        lastStakingRewardsTimestamp = lastStakingRewardsTimestamp + 21600;

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
        lastTotalRewardsFetchAmount = tokenAddress.requestMintedForStaking();

        // Once per 30 days, check if we achieved a target of 50% inflation
        // If not, increase the number of tokens being printed
        // If yes, then check if we inflated more than 60% of the intended supply
        //      If again yes, then decrease the number of tokens being printed

        // The first happens when the burning mechanism burns more tokens than is being printed
        // We can then print more $WJK
        // The second happens when we achieved our goals and are now over-printing 
        days_passed++;
        if(days_passed >= 30) {
            uint newSupply = tokenAddress.totalSupply();
            if((100000 / (newSupply / lastSupply)) > 1563) {
                // We achieved our goal, but we check if its too high now
                if((100000 / (newSupply / lastSupply)) > 1609) {
                    // Inflation above 60%
                    // Request decrease
                    tokenAddress.requestQuarterDecreaseInInflation();
                }
            }else{
                // Not at the target, increase by 25%
                tokenAddress.requestQuarterIncreaseInInflation();
            }

            lastSupply = newSupply;
            days_passed = 0;
        }
        
        bondAddress.updateTokenPriceAtStaking();

        // Reward the one who launched this function with 1 WJK
        tokenAddress.transfer(msg.sender, 1*10**18);

        treasuryAddress.heatOven();

        lock = false;
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

    function updateTokenAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenAddress = Wojak(newAddress);
    }

    function updateBondAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bondAddress = Wojak(newAddress);
    }
}

interface Wojak {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function requestQuarterIncreaseInInflation() external;
    function requestQuarterDecreaseInInflation() external;

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

    function updateTokenPriceAtStaking() external;
}