// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./Interfaces/IStrategy.sol";

contract TStrategy is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");

    // Testnet
    IERC20 public constant BUSD = IERC20(address(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7));
    // Mainnet
    // IERC20 public constant BUSD = IERC20(address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56));

    event Deposit(uint busdIn, uint soyOut);
    event Withdraw(uint soyIn, uint busdOut);
    event Burn(uint wjkAmount, uint swjkAmount);

    IWojak public WJK = IWojak(address(0));
    IStaking public sWJK = IStaking(address(0));
    ISoyFarms public SOY = ISoyFarms(address(0));

    address public Treasury = address(0);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }
    
    function deposit() public {
        // We don't use transferFrom, because we rely that the treasury will send on its own behalf the funds

        uint busdIn = BUSD.balanceOf(address(this));
        // We approve the farm to take our BUSD
        BUSD.safeApprove(address(SOY), busdIn);
        uint soyOut = SOY.deposit(busdIn);
        // In exchange, we receive SOY tokens and the rest is being held by the farm

        emit Deposit(busdIn, soyOut);
    }

    function withdraw() public {
        // SOY -> BUSD
        uint soyIn = SOY.balanceOf(address(this));
        SOY.approve(address(SOY), soyIn);
        SOY.withdraw(soyIn);

        // BUSD -> Treasury
        uint busdOut = BUSD.balanceOf(address(this));
        BUSD.safeTransfer(address(Treasury), busdOut);

        // Burn all WJK & sWJK tokens this contract holds.
        burn();

        emit Withdraw(soyIn, busdOut);
    }

    function burn() public {
        uint wjkAmount = WJK.balanceOf(address(this));
        uint swjkAmount = sWJK.balanceOf(address(this)); 

        WJK.burn(wjkAmount);
        sWJK.burn(swjkAmount);
        
        emit Burn(wjkAmount, swjkAmount);
    }

    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        WJK = IWojak(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressStaking(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        sWJK = IStaking(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressTreasury(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        Treasury = newAddress;
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressSoyFarm(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        SOY = ISoyFarms(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }
}

interface IWojak is IERC20 {
    function burn(uint amount) external;
}

interface IStaking is IERC20 {
    function burn(uint amount) external;
}

interface ISoyFarms is IERC20 {
    function deposit(uint busdAmount) external returns (uint256);
    function withdraw(uint soyAmount) external returns (uint256);
}