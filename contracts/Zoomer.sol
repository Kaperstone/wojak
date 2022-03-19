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

contract Zoomer is ERC20, AccessControlEnumerable {
    using SafeERC20 for IWojak;
    using SafeERC20 for IERC20;

    event Stake(uint zoomerAmount);
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

    constructor() ERC20("Zoomer Staking", "ZOOMER") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }

    // ------- Actions -------

    function stakeAdmin(uint wjkAmount) public onlyRole(CONTRACT_ROLE) returns (uint) {
        require(!disabled, "ZMR:Stake is disabled, withdraw only");
        
        // We transfer his tokens to the smart contract, its now in its posession
        wjk.safeTransferFrom(msg.sender, address(this), wjkAmount);
        
        if(balanceOf(msg.sender) == 0) _grantRole(STAKERS, msg.sender);
        
        uint zoomerAmount = zoomersForMe(wjkAmount);
        wjkBalance += wjkAmount;

        // We can now mint, a dangerous function to our economy :o
        _mint(msg.sender, zoomerAmount); // Mint Zoomer tokens to his account

        emit Stake(zoomerAmount);

        return zoomerAmount;
    }

    function unstake(uint bAmount) public onlyRole(STAKERS) returns(uint) {
        // He requests back more than he can
        require(balanceOf(msg.sender) >= bAmount, "ZMR:Not enough to unstake");

        // We burn his Zoomers
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

    function zoomersForMe(uint amount) public view returns (uint) {
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

    // Distribute once per 24 hours
    // Can only launched by [Keeper], to keep everything in order
    uint private lastDist = block.timestamp;
    uint private blockNum = block.number;
    function distributeRewards() public onlyRole(CONTRACT_ROLE) {
        if(wjkBalance > 1e18 && (block.timestamp - lastDist) > 86400 && blockNum != block.number) {
            // We just raise the amount of wjk contract holds
            uint totalRewards = wjkBalance / 400;

            // Mint to the contract
            
            wjk.mint(address(this), totalRewards);
            wjkBalance += totalRewards;

            index = (wjkBalance * 1e18) / totalSupply();


            if(wjk.balanceOf(address(chad)) < (wjk.totalSupply() / 10)) {
                uint tenPercent = totalRewards / 10; // + 10% to be sold at the market
                wjk.mint(address(chad), tenPercent);
            }

            emit RewardsDistributed(totalRewards);
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