// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";

contract Wojak is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant STAKING_ROLE = keccak256("STAKING_ROLE");
    bytes32 public constant BONDS_ROLE = keccak256("BONDS_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    uint readyForStaking = 0;
    uint readyForBonds = 0;
    uint readyForVaults = 0;

    uint lastInflation = 0;

    constructor() ERC20("Wojak", "WJK") {
        _mint(msg.sender, 500 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(STAKING_ROLE, msg.sender);
        _setupRole(BONDS_ROLE, msg.sender);
        _setupRole(VAULT_ROLE, msg.sender);
        
        lastInflation = block.timestamp;
    }

    // We have no use :)
    // function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    //     _mint(to, amount);
    // }

    uint boo = 4;

    function requestQuarterIncreaseInInflation() public onlyRole(STAKING_ROLE) {
        // Maximum 3.0%
        if(boo + 1 < 8) boo++;
    }

    function requestQuarterDecreaseInInflation() public onlyRole(STAKING_ROLE) {
        // Minimum 1.5%
        if(boo - 1 > 4) boo--;
    }

    function evaluateInflation() private {
        // Allow also an early 10sec execution, to ensure the other contract executes this function properly
        require((block.timestamp - lastInflation - 10) > 86400);
        // In case the function was executed late.
        lastInflation += 86400;

        uint quarterForStaking = totalSupply() / 100 / 4;
        uint quarterForBonds = totalSupply() / 1000 / 4;
        uint quarterForVaults = totalSupply() / 250 / 4;

        // Total 1.5% of the supply per day
        // (+1000 is to fix in case there are roundings in the calculation)
        uint mintForStaking = (quarterForStaking * boo + 1) * 10 ** decimals() + 1000; // 1% of the supply (highest)
        uint mintForBonds = (quarterForBonds * boo) * 10 ** decimals() + 1000; // 0.1% (lowest)
        uint mintForVaults = (quarterForVaults * boo) * 10 ** decimals() + 1000; // 0.4% of the supply (medium)


        _mint(address(this), mintForStaking);
        readyForStaking += mintForStaking;

        _mint(address(this), mintForBonds);
        readyForBonds += mintForBonds;

        _mint(address(this), mintForVaults);
        readyForVaults += mintForVaults;
    }

    // Even if the contracts are hacked, someday, somehow
    // They can only mint limited amount of tokens
    // designated to that contract

    function requestMintedForStaking() public onlyRole(STAKING_ROLE) returns (uint256) {
        evaluateInflation();
        // 10%
        // Send all the staking funds to the contract
        _transfer(address(this), address(stakingAddress), readyForStaking);

        // request for bonds as well
        requestMintedForBonds();
        requestMintedForVaults();

        return readyForStaking;
    }

    function requestMintedForBonds() public onlyRole(BONDS_ROLE) returns (uint256) {
        evaluateInflation();
        // 1%
        _transfer(address(this), address(bondsAddress), readyForBonds);
        return readyForBonds;
    }

    function requestMintedForVaults() public onlyRole(VAULT_ROLE) returns (uint256) {
        evaluateInflation();
        // 1%
        _transfer(address(this), address(vaultAddress), readyForVaults);
        return readyForVaults;
    }

    // Addresses
    function updateTreasuryAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateTreasuryAddress(newAddress);
    }
    function updateBondsAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateBondsAddress(newAddress);
    }
    function updateVaultAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateVaultAddress(newAddress);
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
}
