// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../_lib/contracts/token/ERC20/ERC20.sol";
import "../_lib/contracts/utils/SafeERC20.sol";

import "../_lib/Common.sol";

abstract contract SoyFarms is Common, ERC20 {
    using SafeERC20 for IERC20;

    address[] internal farmers;
    mapping(address => uint256) public farmerAmount; 

    bool public lock = false;

    // Statistics
    uint public BUSDinContract = 0;
    uint public totalRewardsBought = 0;

    constructor(bool testnet) ERC20("Soy Tokens", "SOY") Common(testnet) {}

    function deposit(uint busdAmount) public {
        require(!lock, "Distribution is going on");

        require(BUSD.balanceOf(msg.sender) >= busdAmount, "Insufficient BUSD balance");
        // Transfer us the BUSD
        BUSD.safeTransferFrom(msg.sender, address(this), busdAmount);
        // Give the man his SOY which is determined by the exchange rate
        // busd / index = soy
        uint SOYtoMint = busdAmount / (_totalSupply / BUSDinContract);


        _mint(msg.sender, SOYtoMint);
        // Increase busd tvl
        BUSDinContract += busdAmount;

        if(balanceOf(msg.sender) == 0) addFarmer(msg.sender);
        depositToVenus(busdAmount);
    }

    function withdraw(uint soyAmount) public {
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
        BUSDinContract -= busdAmount;

        // Transfer sWJK rewards
        sWJK.safeTransfer(msg.sender, wjkAmount);
        if(balanceOf(msg.sender) == 0) removeFarmer(msg.sender);
    }

    function farmerBalance(address _farmer) public view returns (uint256, uint256) {
        // soy * index = busd
        return (balanceOf(_farmer) * (_totalSupply / BUSDinContract) , farmerAmount[_farmer]);
    }

    function distributeRewards() public onlyRole(KEEPER_ROLE) {
        // Perform a buyback and then put into staking all the tokens
        uint wjkAmount = swap(address(BUSD), address(WJK), takeIncome(), address(this));
        uint wjkRewards = staking.Stake(wjkAmount);
        totalRewardsBought += wjkRewards;

        // Give to each account the amount of sWJK he deserves
        for(uint x = 0; x < farmers.length; x++) {
            farmerAmount[farmers[x]] += wjkRewards / (_totalSupply / _balances[farmers[x]]);
        }

        staking.burn(farmerAmount[address(treasury)]);
        farmerAmount[address(treasury)] = 0;
    }


    function takeIncome() public returns (uint256) {
        Unitroller.claimVenus(address(this));
        uint busdFromXVS = swap(address(XVS), address(WJK), XVS.balanceOf(address(this)), address(this));

        uint exchangeRate = vBUSD.exchangeRateStored();
        uint BUSDRevenue = BUSDinContract * exchangeRate - BUSDinContract;

        // Get accurate revenue
        vBUSD.redeem(BUSDRevenue / exchangeRate);

        return BUSDRevenue + busdFromXVS;
    }
    
    function depositToVenus(uint busd) private {
        vBUSD.mint(busd);
    }

    function withdrawFromVenus(uint busd) private {
        vBUSD.redeem(busd * vBUSD.exchangeRateStored());
    }

    function calculateRevenue() public view returns (uint256) {
        return BUSDinContract * vBUSD.exchangeRateStored() - BUSDinContract;
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

    function _transfer(
        address /* sender */,
        address /* recipient */,
        uint256 /* brutto */
    ) internal virtual override {
        require(false, "!illegal");
    }
}
