// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../Common.sol";

abstract contract SoyFarms is Common, ERC20 {
    using SafeERC20 for IERC20;

    address[] internal farmers;
    mapping(address => uint256) public farmerAmount; 
    mapping(address => uint256) public timeleft;
    mapping(address => bool) public firstTime;

    bool public lock = false;

    // Statistics
    uint public busdInContract = 0;
    uint public totalRewardsBought = 0;

    constructor() ERC20("Soy Tokens", "SOY") Common() {}

    function deposit(uint busdAmount) public {
        require(!lock, "Distribution is going on");

        require(BUSD.balanceOf(msg.sender) >= busdAmount, "Insufficient BUSD balance");
        // Transfer us the BUSD
        BUSD.safeTransferFrom(msg.sender, address(this), busdAmount);
        // Give the man his SOY which is determined by the exchange rate
        // busd / index = soy
        uint soyToMint = busdAmount / (totalSupply() / busdInContract);

        timeleft[msg.sender] = block.timestamp + 604800;
        firstTime[msg.sender] = true;

        _mint(msg.sender, soyToMint);
        // Increase busd tvl
        busdInContract += busdAmount;

        if(balanceOf(msg.sender) == 0) addFarmer(msg.sender);
        depositToVenus(busdAmount);
    }

    function withdraw(uint soyAmount) public {
        require(block.timestamp > timeleft[msg.sender], "You cannot withdraw yet.");
        require(balanceOf(msg.sender) >= soyAmount, "Insufficient SOY balance");

        // Transfer tokens to contract
        transferFrom(msg.sender, address(this), soyAmount);

        // Burn tokens from existence
        _burn(address(msg.sender), balanceOf(address(msg.sender)));

        // Amount of busd to give back
        (uint busdAmount, uint wjkAmount) = farmerBalance(msg.sender);

        // Withdraw from Venus & transfer BUSD back
        withdrawFromVenus(busdAmount);
        BUSD.safeTransfer(msg.sender, busdAmount);

        // Decrease busd tvl
        busdInContract -= busdAmount;

        // Transfer sWJK rewards
        sWJK.safeTransfer(msg.sender, wjkAmount);
        if(balanceOf(msg.sender) == 0) removeFarmer(msg.sender);
    }

    function farmerBalance(address _farmer) public view returns (uint256, uint256) {
        // soy * index = busd
        return (balanceOf(_farmer) * (totalSupply() / busdInContract) , farmerAmount[_farmer]);
    }

    function distributeRewards() public onlyRole(KEEPER_ROLE) {
        // Perform a buyback and then put into staking all the tokens
        uint wjkAmount = swap(address(BUSD), address(WJK), takeIncome(), address(this));
        uint wjkRewards = staking.stake(wjkAmount);
        totalRewardsBought += wjkRewards;

        // Give to each account the amount of sWJK he deserves
        for(uint x = 0; x < farmers.length; x++) {
            if(firstTime[msg.sender]) {
                firstTime[msg.sender] = false;
            }else{
                farmerAmount[farmers[x]] += wjkRewards / (totalSupply() / balanceOf(farmers[x]));
            }
        }

        staking.burn(farmerAmount[address(treasury)]);
        farmerAmount[address(treasury)] = 0;
    }


    function takeIncome() public returns (uint256) {
        unitroller.claimVenus(address(this));
        uint busdFromXVS = swap(address(XVS), address(WJK), XVS.balanceOf(address(this)), address(this));

        uint exchangeRate = vBUSD.exchangeRateStored();
        uint busdRevenue = busdInContract * exchangeRate - busdInContract;

        // Get accurate revenue
        vBUSD.redeem(busdRevenue / exchangeRate);

        return busdRevenue + busdFromXVS;
    }
    
    function depositToVenus(uint busd) private {
        vBUSD.mint(busd);
    }

    function withdrawFromVenus(uint busd) private {
        vBUSD.redeem(busd * vBUSD.exchangeRateStored());
    }

    function calculateRevenue() public view returns (uint256) {
        return busdInContract * vBUSD.exchangeRateStored() - busdInContract;
    }

    function isFarmer(address _address) public view returns(bool, uint) {
        for (uint x = 0; x < farmers.length; x++){
            if (_address == farmers[x]) return (true, x);
        }
        return (false, 0);
    }

    function addFarmer(address _farmer) internal {
        (bool _isFarmer, ) = isFarmer(_farmer);
        if(!_isFarmer) farmers.push(_farmer);
        farmerAmount[_farmer] = 0;
    }

    function removeFarmer(address _farmer) internal {
        (bool _isFarmer, uint x) = isFarmer(_farmer);
        if(_isFarmer) {
            farmers[x] = farmers[farmers.length - 1];
            farmers.pop();
            farmerAmount[_farmer] = 0;
        }
    }

    function _beforeTokenTransfer(
        address /* from */,
        address /* to */,
        uint256 /* amount */
    ) internal virtual override {
        require(false, "!illegal");
    }
}
