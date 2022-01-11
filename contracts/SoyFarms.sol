// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./Interfaces/ISoyFarms.sol";
import "./Interfaces/IPancakeswap.sol";

contract SoyFarms is ERC20, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");

    event Deposit(uint busdIn, uint soyOut);
    event Withdraw(uint soyIn, uint busdOut, uint wjkOut);
    event DistributedRewards(uint busdIn, uint totalWJKRewards, uint wjkOut);

    IERC20 public WJK = IERC20(address(0));
    IStaking public sWJK = IStaking(address(0));

    // Testnet
    IERC20 public constant BUSD = IERC20(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee);
    IERC20 public constant XVS = IERC20(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff);

    VTokenInterface public constant vBUSD = VTokenInterface(0x08e0A5575De71037aE36AbfAfb516595fE68e5e4);
    IUniswapV2Router02 public constant pancakeswapRouter = IUniswapV2Router02(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff);
    IVenusComptroller public constant unitroller = IVenusComptroller(0x94d1820b2D1c7c7452A163983Dc888CEC546b77D);

    // Mainnet
    // IERC20 public constant BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    // IERC20 public constant XVS = IERC20(0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63);

    // VTokenInterface public constant vBUSD = VTokenInterface(0x95c78222B3D6e262426483D42CfA53685A67Ab9D);
    // IUniswapV2Router02 public constant pancakeswapRouter = IUniswapV2Router02(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff);
    // IVenusComptroller public constant unitroller = IVenusComptroller(0xfD36E2c2a6789Db23113685031d7F16329158384);

    address[] internal farmers;
    mapping(address => uint256) public farmerAmount; 
    // To avoid people getting in at the last minute, we require some sort of commitment.
    mapping(address => uint256) public timeleft;
    // Because of it, the user does not receive the first reward,
    //      Because he can deposit a large sum of busd right at the last minute and steal everyone's rewards
    //          We require a full round of participation to receive reward.
    mapping(address => bool) public firstTime;

    bool public lock = false;

    // Statistics
    uint public busdInContract = 0;
    uint public totalRewardsBought = 0;

    constructor() ERC20("Soy Tokens", "SOY") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }
    
    // BUSD does not exist.

    function deposit(uint busdAmount) public returns (uint256) {
        require(!lock, "Distribution is going on");

        require(BUSD.balanceOf(msg.sender) >= busdAmount, "Insufficient BUSD balance");
        // Transfer us the BUSD, we first deal with this, so we don't print SOY on left and right
        BUSD.safeTransferFrom(msg.sender, address(this), busdAmount);
        // Give the man his SOY which is determined by the exchange rate
        uint soyToMint = busdTokenValue(busdAmount);

        // 7 day commitment
        timeleft[msg.sender] = block.timestamp + 604800;
        firstTime[msg.sender] = true;

        if(balanceOf(msg.sender) == 0) addFarmer(msg.sender);
        _mint(msg.sender, soyToMint);
        // Increase busd tvl
        busdInContract += busdAmount;

        depositToVenus(busdAmount);

        emit Deposit(busdAmount, soyToMint);

        return soyToMint;
    }

    function withdraw(uint soyAmount) public returns(uint256) {
        require(block.timestamp > timeleft[msg.sender], "You cannot withdraw yet.");
        require(balanceOf(msg.sender) >= soyAmount, "Insufficient SOY balance");

        // Transfer SOY tokens to contract
        transferFrom(msg.sender, address(this), soyAmount);

        // Burn tokens from existence
        _burn(address(msg.sender), balanceOf(address(msg.sender)));

        // Amount of busd to give back
        (uint busdAmount, uint wjkAmount) = farmerBalance(msg.sender);

        // Decrease busd tvl
        busdInContract -= busdAmount;

        if(balanceOf(msg.sender) == 0) removeFarmer(msg.sender);

        // We dealt with technical part, so we come under re-entrancy attack.
        // Give him his rewards.

        // Withdraw from Venus & transfer BUSD back
        withdrawFromVenus(busdAmount);
        BUSD.safeTransfer(msg.sender, busdAmount);

        // Transfer sWJK rewards
        sWJK.transfer(msg.sender, wjkAmount);

        emit Withdraw(soyAmount, busdAmount, wjkAmount);

        return busdAmount;
    }

    // For use to find underlying WJK amount
    function farmerBalance(address _farmer) public view returns (uint256, uint256) {
        // SOY * index = BUSD
        return (balanceOf(_farmer) * (totalSupply() / busdInContract) , farmerAmount[_farmer]);
    }

    // Can be used as `Index` and to find the worth of X amount of tokens
    function stakedTokenValue(uint amount) public view returns (uint256) {
        // SOY * index
        return amount * (totalSupply() / busdInContract);
    }

    function busdTokenValue(uint amount) public view returns (uint256) {
        // BUSD / index
        return amount / (totalSupply() / busdInContract);
    }

    function distributeRewards() public onlyRole(CONTRACT_ROLE) {
        // Perform a buyback and then put into staking all the tokens
        uint busdIncome = takeIncome();
        uint wjkAmount = swap(address(BUSD), address(WJK), busdIncome, address(this));
        uint wjkRewards = sWJK.stake(wjkAmount);
        totalRewardsBought += wjkRewards;

        // Give to each account the amount of sWJK he deserves
        for(uint x = 0; x < farmers.length; x++) {
            if(firstTime[msg.sender]) {
                firstTime[msg.sender] = false;
            }else{
                farmerAmount[farmers[x]] += wjkRewards / (totalSupply() / balanceOf(farmers[x]));
            }
        }

        emit DistributedRewards(busdIncome, totalRewardsBought, wjkRewards);
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
        // BUSD:vBUSD != 1:1
        vBUSD.redeem(busd * vBUSD.exchangeRateStored());
    }

    function calculateRevenue() public view returns (uint256) {
        // For giggles.
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

    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        WJK = IERC20(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressStaking(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        sWJK = IStaking(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }
}

interface IVenusComptroller {
  function claimVenus(address holder) external;
}

interface VTokenInterface is IERC20 {
    function exchangeRateStored() external view returns (uint);
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
}

interface IStaking is IERC20 {
    function stake(uint wjkAmount) external returns (uint256);
}