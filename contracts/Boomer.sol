// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
CREAM Goerli crUSDC = 0xD9b8c80d7fe4391B583916F1bFAa972446F72a1B
      Goerli USDC   = 0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C

*/

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IPancakeswap.sol";

contract Boomer is ERC20, AccessControlEnumerable {
    using SafeERC20 for IWojak;
    using SafeERC20 for IERC20;

    event Stake(uint boomerAmount);
    event Unstake(uint wjkAmount);
    event RewardsDistributed(uint rewards);

    bytes32 private constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    bytes32 private constant STAKERS = keccak256("STAKERS");

    bool public disabled = false;
    bool public lock = false;

    // Can be changed.
    IWojak public wjk = IWojak(address(0));
    address public chad = address(0);
    address public keeper = address(0);

    // wjk balance as a variable
    uint private wjkBalance = 0;

    uint public index = 1e18;

    IERC20 public constant USDC = IERC20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
    IUniswapV2Router02 public constant SWAP_ROUTER = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    constructor() ERC20("Boomer Staking", "BOOMER") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }

    // ------- Actions -------

    function stakeAdmin(uint wjkAmount) public onlyRole(CONTRACT_ROLE) returns(uint) {
        return _stake(wjkAmount);
    }

    function stake(uint wjkAmount) public returns (uint) {
        require(!lock, "BMR:Distribution is going on");
        return _stake(wjkAmount);
    }

    function _stake(uint wjkAmount) private returns (uint) {
        require(!disabled, "BMR:Stake is disabled, withdraw only");
        
        // We transfer his tokens to the smart contract, its now in its posession
        wjk.safeTransferFrom(msg.sender, address(this), wjkAmount);

        uint fivePercent = wjkAmount / 50;
        uint usdc = swap(fivePercent);
        USDC.safeTransfer(keeper, usdc);
        wjkAmount -= fivePercent;
        
        if(balanceOf(msg.sender) == 0) _grantRole(STAKERS, msg.sender);
        
        uint boomerAmount = boomersForMe(wjkAmount);
        wjkBalance += wjkAmount;

        // We can now mint, a dangerous function to our economy :o
        _mint(msg.sender, boomerAmount); // Mint Boomer tokens to his account

        emit Stake(boomerAmount);
        return boomerAmount;
    }

    function unstake(uint bAmount) public onlyRole(STAKERS) returns(uint) {
        require(!lock, "BMR:Distribution is going on");
        // He requests back more than he can
        require(balanceOf(msg.sender) >= bAmount, "BMR:No tokens to unstake");

        // We burn his Boomers
        uint wjkAmount = balanceOfUnderlying(bAmount);
        wjkBalance -= wjkAmount;
        // We don't need his BOOMER tokens
        _burn(msg.sender, bAmount);
        if(balanceOf(msg.sender) == 0) _revokeRole(STAKERS, msg.sender);

        // Give him his tokens from this contract
        wjk.safeTransfer(msg.sender, wjkAmount);

        emit Unstake(wjkAmount);

        return wjkAmount;
    }

    // ------- Helpers

    function boomersForMe(uint amount) public view returns (uint) {
        // swjk * index = wjk
        return (amount * 1e18) / index;
    }

    function balanceOfUnderlying(uint amount) public view returns (uint) {
        // wjk * index = swjk
        return (amount * index) / 1e18;
    }

    function balanceOfUnderlyingForAccount(address _staker) public view returns (uint) {
        // wjk * index = swjk
        return (balanceOf(_staker) * index) / 1e18;
    }


    // ------- Routine -------

    // Can only launched by [Keeper], to keep everything in order
    function distributeRewards() public onlyRole(CONTRACT_ROLE) {
        if(wjkBalance > 1e18) { // Has more than 1 WJK staked
            lock = true;
            // We just raise the amount of wjk contract holds
            uint totalRewards = wjkBalance / 400;

            // Mint to the contract
            wjk.mint(address(this), totalRewards);
            wjkBalance += totalRewards;

            index = wjkBalance * 1e18 / totalSupply();


            if(wjk.balanceOf(address(chad)) < (wjk.totalSupply() / 10)) {
                wjk.mint(address(chad), totalRewards / 10); // + 10% to be transferred to bonds
            }

            emit RewardsDistributed(totalRewards);
            lock = false;
        }
    }

    // ------- Administration -------
    
    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        wjk = IWojak(newAddress);
    }

    function setAddressBonds(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        chad = newAddress;
    }

    function setAddressKeeper(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        keeper = newAddress;
    }
    
    function triggerStaking() public onlyRole(DEFAULT_ADMIN_ROLE) {
        disabled = !disabled;
    }

    function swap(uint amount) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = address(wjk);  
        path[1] = address(USDC);

        wjk.safeApprove(address(SWAP_ROUTER), amount);

        uint[] memory amounts = SWAP_ROUTER.swapExactTokensForTokens(
            amount,
            0, // Accept any amount of tokens back
            path,
            address(this), // Give the LP tokens to the treasury
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }
}

interface IWojak is IERC20 {
    function mint(address, uint) external;
    function burn(uint) external;
}