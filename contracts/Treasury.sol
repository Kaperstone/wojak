// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// When in treasury, busd is in the treasury
// When in investment, ib tokens in the strategy

contract Treasury is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");

    IWojak public WJK = IWojak(address(0));
    IStaking public sWJK = IStaking(address(0));
    ITStrategy public TStrategy = ITStrategy(address(0));
    // Testnet
    IERC20 public constant BUSD = IERC20(address(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7));
    // Mainnet
    // IERC20 public constant BUSD = IERC20(address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56));

    event TreasuryAdded(uint busd);
    event ToWork(uint busdBalance);
    event FromWork(uint busdBalance);
    event Burn(uint wjkAmount, uint swjkAmount);

    bool public stayHome = false;
    // Treasury only holds BUSD
    uint public busdInTreasury = 0;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }

    function addToTreasury() public {
        // Instead of using a function to transfer and dealing with "approve" and wasting on it gas
        // Contracts will "willingly" transfer busd to this contract

        uint added = 0;

        // Its either the money is in the hands of the treasury
        // Or its in the investment bridge i.e. "Strategy"
        if(!stayHome) {
            added = BUSD.balanceOf(address(this));
            invest();
        }else{
            added = BUSD.balanceOf(address(this)) - busdInTreasury;
        }
        
        busdInTreasury += added;

        emit TreasuryAdded(added);
    }

    // When we want to upgrade the strategy, we withdraw the cash into the treasury.
    function get() public onlyRole(DEFAULT_ADMIN_ROLE) {
        stayHome = true;
        // Constant function to interact with
        TStrategy.withdraw();

        emit FromWork(BUSD.balanceOf(address(this)));
    }

    // Exposing as public function
    function put() public onlyRole(DEFAULT_ADMIN_ROLE) {
        stayHome = false;
        invest();

        emit ToWork(BUSD.balanceOf(address(this)));
    }

    function invest() private {
        // Without approve, just send to the strategy
        BUSD.safeTransfer(address(TStrategy), BUSD.balanceOf(address(this)));
        // Constant function to interact with
        TStrategy.deposit();
    }

    function changeTreasuryContract(address newContract) public onlyRole(DEFAULT_ADMIN_ROLE) {
        BUSD.safeTransfer(address(newContract), BUSD.balanceOf(address(this)));
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

    function setAddressTreasuryStrategy(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        TStrategy = ITStrategy(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }
}

interface IWojak {
    function balanceOf(address account) external view returns (uint256);
    function burn(uint amount) external;
}

interface IStaking {
    function balanceOf(address account) external view returns (uint256);
    function burn(uint amount) external;
}

interface ITStrategy {
    function deposit() external;
    function withdraw() external;
}