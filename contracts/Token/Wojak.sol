// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";

contract Wojak is ERC20, ERC20Burnable, AccessControl {
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
        
        lastInflation = block.timestamp;
    }

    // We have no use :)
    // function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    //     _mint(to, amount);
    // }

    function evaluateInflation() internal {
        // Allow also an early 10sec execution, to ensure the other contract executes this function properly
        require((block.timestamp - lastInflation - 10) > 43200);
        // In case the function was executed late.
        lastInflation += 43200;

        // Total 12%
        uint mintForStaking = totalSupply() / 10 * 10 ** decimals(); // 10%
        uint mintForBonds = totalSupply() / 100 * 10 ** decimals(); // 1%
        uint mintForVaults = totalSupply() / 100 * 10 ** decimals(); // 1%


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

    function requestMintedForStaking() public onlyRole(STAKING_ROLE) {
        evaluateInflation();
        // 10%
        // Send all the staking funds to the contract
        _transfer(address(this), address(stakingAddress), readyForStaking);
    }

    function requestMintedForBonds() public onlyRole(BONDS_ROLE) {
        evaluateInflation();
        // 1%
        _transfer(address(this), address(bondsAddress), readyForBonds);
    }

    function requestMintedForVaults() public onlyRole(VAULT_ROLE) {
        evaluateInflation();
        // 1%
        _transfer(address(this), address(vaultAddress), readyForVaults);
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
}
