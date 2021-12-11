// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";

import "./iWojak.sol";

contract Wojak is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant STAKING_ROLE = keccak256("STAKING_ROLE");
    bytes32 public constant BONDS_ROLE = keccak256("BONDS_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    Treasury treasury = Treasury(address(0));

    uint readyForStaking = 0;
    uint readyForBonds = 0;
    uint readyForTreasury = 0;
    uint stakeExecuteReward = 0;
    
    bool treasuryMint = false;

    uint lastInflation = 0;

    constructor() ERC20("Wojak", "WJK") {
        _mint(msg.sender, 500 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(STAKING_ROLE, msg.sender);
        _setupRole(BONDS_ROLE, msg.sender);
        _setupRole(TREASURY_ROLE, msg.sender);
        
        lastInflation = block.timestamp;
    }

    // We have no use :)
    // function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    //     _mint(to, amount);
    // }

    uint booster = 4;

    function requestQuarterIncreaseInInflation() public onlyRole(STAKING_ROLE) {
        // Maximum 3.0%
        if(booster + 1 < 8) booster++;
    }

    function requestQuarterDecreaseInInflation() public onlyRole(STAKING_ROLE) {
        // Minimum 1.5%
        if(booster - 1 > 4) booster--;
    }

    function evaluateInflation() private {
        // Allow also an early 10sec execution, to ensure the other contract executes this function properly
        require((block.timestamp - lastInflation - 10) > 21600);
        // In case the function was executed late.
        lastInflation += 86400;

        uint quarterForStaking = totalSupply() / 100 / 8; // 4 for partial of a quarter, and another four for quarter of a day.
        uint quarterForBonds = totalSupply() / 1000 / 8;

        // Total 1.5% of the supply per day
        // (+1000 is to fix in case there are roundings in the calculation)
        uint mintForStaking = (quarterForStaking * booster) * 10 ** decimals() + 1000 + (stakeExecuteReward*10**18/4); // 1% of the supply (highest) + reward
        uint mintForBonds = (quarterForBonds * booster * 3) * 10 ** decimals() + 1000; // 0.3% * Booster
        uint mintForSell = (totalSupply() / 1000) * 10 ** decimals(); // 0.1% always go to sell to fill the treasury


        _mint(address(this), mintForStaking);
        readyForStaking += mintForStaking;

        _mint(address(this), mintForBonds);
        readyForBonds += mintForBonds;

        // We start to create tokens and sell to increase the treasury supply
        // When the treasury size is too small to cope with the inflation
        if(treasuryMint) {
            _mint(address(this), mintForSell);
            readyForTreasury += mintForSell;
        }

        if((treasury.treasurySize() / 50) < totalSupply()) {
            _setBurningFee(100); // Activate the burning mechnanism
        }else{
            _setBurningFee(0);
        }
    }

    // Even if the contracts are hacked, someday, somehow
    // They can only mint limited amount of tokens
    // designated to that contract

    function requestMintedForStaking() public onlyRole(STAKING_ROLE) returns (uint256) {
        evaluateInflation();
        // 10%
        // Send all the staking funds to the contract
        _transfer(address(this), address(stakingAddress), readyForStaking);
        readyForStaking = 0;

        // request for bonds as well
        requestMintedForBonds();
        requestMintedForTreasury();

        return readyForStaking;
    }

    function requestMintedForBonds() public onlyRole(BONDS_ROLE) returns (uint256) {
        evaluateInflation();
        // 1%
        _transfer(address(this), address(bondsAddress), readyForBonds);
        readyForBonds = 0;
        return readyForBonds;
    }

    function requestMintedForTreasury() public onlyRole(TREASURY_ROLE) returns (uint256) {
        evaluateInflation();
        // 1%
        _transfer(address(this), address(treasuryAddress), readyForTreasury);
        readyForTreasury = 0;
        return readyForTreasury;
    }

    // Addresses
    function updateTreasuryAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateTreasuryAddress(newAddress);
        treasury = Treasury(newAddress);
    }
    function updateBondsAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateBondsAddress(newAddress);
    }
    function updateOvenAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateOvenAddress(newAddress);
    }
    function updateStakingAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateStakingAddress(newAddress);
    }

    // Taxs
    function setLiquidityFee(uint256 fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setLiquidityFee(fee);
    }
    function setTreasuryFee(uint256 fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTreasuryFee(fee);
    }
    function setBurningFee(uint256 fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBurningFee(fee);
    }

    function burnForMeEverything() public {
        _burn(msg.sender, balanceOf(msg.sender));
    }

    function burnForMe(uint amount) public {
        _burn(msg.sender, amount);
    }

    function activateTreasurySellMinting() public onlyRole(TREASURY_ROLE) {
        treasuryMint = true;
    }

    function deactivateTreasurySellMinting() public onlyRole(TREASURY_ROLE) {
        treasuryMint = false;
    }

    function setStakingExecuterReward(uint newReward) public onlyRole(DEFAULT_ADMIN_ROLE) {
        stakeExecuteReward = newReward;
    }
}

interface Treasury {
    function treasurySize() view external returns (uint256);
}