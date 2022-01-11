// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./Interfaces/IPancakeswap.sol";

contract Wojak is ERC20, AccessControl {
    event Tax(uint busdRevenue, uint taxSize);
    event Mint(address to, uint amount);

    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");    

    address public keeper = address(0);
    // Testnet
    IERC20 public constant BUSD = IERC20(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee);
    IUniswapV2Router02 public constant pancakeswapRouter = IUniswapV2Router02(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));
    // Mainnet
    // IERC20 public constant BUSD = IERC20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7);
    // IUniswapV2Router02 public constant pancakeswapRouter = IUniswapV2Router02(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));

    // Excluded list
    address[] internal excluded;

    constructor() ERC20("Wojak", "WJK") {
        // Developer tokens
        _mint(msg.sender, 1200 * 10 ** decimals());

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(CONTRACT_ROLE) {
        _mint(to, amount);
        emit Mint(to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override virtual {

        // Check if its not one of our contracts that is trying to transfer
        (bool senderExcluded, ) = isExcluded(from);
        (bool recipientExcluded, ) = isExcluded(to);
        if(!senderExcluded && !recipientExcluded) {
            uint onePercent = amount / 100;

            // Burn 3% off his account
            _burn(address(to), onePercent * 3);

            // Mint 2% to this contract and then sell it
            _mint(address(this), onePercent * 2);
            uint busd = swap(address(this), address(BUSD), onePercent*2, address(keeper));
            emit Tax(busd, onePercent);
        }
    }


    function isExcluded(address _address) public view returns(bool, uint) {
        for (uint x = 0; x < excluded.length; x++){
            if (_address == excluded[x]) return (true, x);
        }
        return (false, 0);
    }

    function addExcluded(address excludeAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool _isExcluded, ) = isExcluded(excludeAddress);
        if(!_isExcluded) excluded.push(excludeAddress);
    }

    function removeExcluded(address excludeAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool _isExcluded, uint x) = isExcluded(excludeAddress);
        if(_isExcluded) {
            excluded[x] = excluded[excluded.length - 1];
            excluded.pop();
        } 
    }

    function swap(address token1, address token2, uint256 amount, address to) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = address(token1);  
        path[1] = address(token2);

        IERC20(address(token1)).approve(address(pancakeswapRouter), amount);

        uint[] memory amounts = pancakeswapRouter.swapExactTokensForTokens(
            amount,
            0, // Accept any amount of tokens back
            path,
            to, // Give the LP tokens to the treasury
            block.timestamp
        );
        return amounts[amounts.length - 1];
    }

    function setAddressKeeper(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        keeper = newAddress;
        grantRole(CONTRACT_ROLE, newAddress);
    }
}
