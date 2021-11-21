// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";

abstract contract Boomer is ERC20, ERC20Burnable, AccessControl {
    /*
    address[] internal stakeholders;
    mapping(address => uint) internal stakes;
    mapping(address => uint) internal rewards;
    mapping(address => bool) internal lock;

    uint internal lastStakingRewards = 0;
    address public father = address(0);

    // Analytics
    uint TotalStaked = 0;
    uint TotalReward = 0;
    uint UnclaimedRewards = 0;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(address WojakTokenAddress) ERC20("Boomer", "BMR") {
        _mint(msg.sender, 500 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        // Connect the original staking token
        fatherAddress = WojakTokenAddress;
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // ---------- STAKES ----------

    function Stake(uint amount) public {
        // Check if the account holds the amount he wants to stake
        require(address(fatherAddress).balanceOf(msg.sender) >= amount, "You don't hold that amount to stake");
        // We attempt to burn his tokens
        require(address(fatherAddress)._burn(msg.sender, amount), "You cannot stake balance that you don't have"); // Burn his `Wojak` tokens
        // We can now mint, a dangerous function to our economy :o
        _mint(msg.sender, amount); // Mint stakedWJK tokens to his account
        // IF its a new address, welcome to the staking pool
        if(stakes[msg.sender] == 0) addStakeholder(msg.sender); // New unique staker account
        // Whether new or not, we took care of
        // Now the variable exists and we can add his staked amount to the pool
        stakes[msg.sender] = stakes[msg.sender].add(amount); // Save how much the account staked
        TotalStaked = TotalStaked.add(amount);
    }

    function Unstake(uint amount) public {
        require(balanceOf(msg.sender) >= amount, "You don't hold that amount to unstake");
        _burn(msg.sender, amount);
        address(fatherAddress)._mint(msg.sender, amount);
        stakes[msg.sender] = stakes[msg.sender].sub(amount);
        if(stakes[msg.sender] == 0) removeStakeholder(msg.sender);
        TotalStaked = TotalStaked.sub(amount);
    }

    function stakeOf(address _stakeholder) public view returns(uint) {
        return stakes[_stakeholder];
    }

    function totalStakes() public view returns(uint) {
        uint _totalStakes = 0;
        for (uint s = 0; s < stakeholders.length; s++){
            _totalStakes = _totalStakes.add(stakes[stakeholders[s]]);
        }
        return _totalStakes;
    }

    // ---------- STAKEHOLDERS ----------

    function isStakeholder(address _address) public view returns(bool, uint) {
        for (uint s = 0; s < stakeholders.length; s++){
            if (_address == stakeholders[s]) return (true, s);
        }
        // The above return stops the function and returns the value, thus,
        // if _address is a stakeholder, it will never reach the line below.
        return (false, 0);
    }

    function addStakeholder(address _stakeholder) internal {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(_stakeholder);
    }

    function removeStakeholder(address _stakeholder) internal {
        (bool _isStakeholder, uint s) = isStakeholder(_stakeholder);
        if(_isStakeholder) {
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        } 
    }

    // ---------- REWARDS ----------
    
    function rewardOf(address _stakeholder) public view returns(uint) {
        return rewards[_stakeholder];
    }

    function totalRewards() public view returns(uint) {
        uint _totalRewards = 0;
        for(uint s = 0; s < stakeholders.length; s++){
            _totalRewards = _totalRewards.add(rewards[stakeholders[s]]);
        }
        return _totalRewards;
    }

    // Internally it is used for `distributeRewards`
    // Externally it can be used for `Next reward yield`
    function calculateReward(address _stakeholder) public view returns(uint) {
        // stakes[_stakeholder] // Amount staked
        uint Staked = stakes[_stakeholder];
        uint Reward = 0;
        // Add all the supply we have.
        uint TotalTokenSupply = address(fatherAddress).totalSupply().add(totalSupply()).add(UnclaimedRewards);

        // Oh shit, here we go again.

        // uint treasurySize = address(fatherAddress).getTreasuryTotalStable();
        
        // reward+(reward/2*(TotalStaked/TotalTokenSupply))
        uint RewardRatio = TotalTokenSupply.div(100);
        // (RewardRatio*(Staked/TotalStaked))
        uint reward = RewardRatio.mul(Staked.div(TotalStaked));
        // reward/(reward/2*(Staked/TotalStaked))
        return reward.add(reward.div(2).mul(TotalStaked.div(TotalTokenSupply)));
    }

    function distributeRewards() public oncePer(21600, "Staking rewards are distributed only once per 6 hours") {
        for(uint s = 0; s < stakeholders.length; s++){
            uint reward = calculateReward(stakeholder);
            rewards[stakeholders[s]] = rewards[stakeholder].add(reward);
            UnclaimedRewards = UnclaimedRewards.add(reward);
        }
    }

    function withdrawReward() public {
        require(balanceOf(msg.sender) > 0, "You have nothing to withdraw");
        _burn(msg.sender, rewards[msg.sender]);
        UnclaimedRewards = UnclaimedRewards.sub(rewards[msg.sender]);
        address(fatherAddress)._mint(msg.sender, rewards[msg.sender]);
        rewards[msg.sender] = 0;
    }
    
    function getLastStakingRewards() public view returns (uint) {
        return lastStakingRewards;
    }

    // To make everything prettier :)
    modifier oncePer(uint time, string memory errorMessage) {
        require((lastStakingRewards - block.timestamp) > time, errorMessage);
        // Set immediately the new timestamp
        lastStakingRewards = block.timestamp;
        _;
    }
    */
}
