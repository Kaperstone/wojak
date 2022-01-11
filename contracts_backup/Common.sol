// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


import "./Interfaces/IPancakeswap.sol";
import "./Interfaces/IChad.sol";
import "./Interfaces/ISoyFarms.sol";
import "./Interfaces/IBoomer.sol";
import "./Interfaces/IWojak.sol";
import "./Interfaces/ITreasury.sol";
import "./Interfaces/IStrategy.sol";
import "./Interfaces/IKeeper.sol";

abstract contract Common is AccessControl {
    // AccessControl, IWojak, IBoomer, IChad, IStrategy, ITreasury, IKeeper, ISoyFarms, IERC20
    using SafeERC20 for IERC20;
    
    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");

    event SwapAndLiquify(uint256 wjk, uint256 busd);
    event Donated(uint bnbDonated, uint busdDonated);

    // Testnet
    IERC20 public constant BUSD = IERC20(address(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee));
    IERC20 public constant LINK = IERC20(address(0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06));
    IERC20 public constant XVS = IERC20(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));

    VTokenInterface public constant vBUSD = VTokenInterface(address(0x08e0A5575De71037aE36AbfAfb516595fE68e5e4));
    IUniswapV2Router02 public constant pancakeswapRouter = IUniswapV2Router02(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));
    IVenusComptroller public constant unitroller = IVenusComptroller(address(0x94d1820b2D1c7c7452A163983Dc888CEC546b77D));

    // Mainnet
    // IERC20 public constant BUSD = IERC20(address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56));
    // IERC20 public constant LINK = IERC20(address(0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD));
    // IERC20 public constant XVS = IERC20(address(0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63));

    // VTokenInterface public constant vBUSD = VTokenInterface(address(0x95c78222B3D6e262426483D42CfA53685A67Ab9D));
    // IUniswapV2Router02 public constant pancakeswapRouter = IUniswapV2Router02(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));
    // IVenusComptroller public constant unitroller = IVenusComptroller(address(0xfD36E2c2a6789Db23113685031d7F16329158384));


    IUniswapV2Pair public pairAddress = IUniswapV2Pair(address(0));


    IERC20 public WJK = IERC20(address(0));
    IERC20 public sWJK = IERC20(address(0));
    IERC20 public CHAD = IERC20(address(0));
    IERC20 public SOY = IERC20(address(0));


    IWojak public wojak = IWojak(address(0));
    IBoomer public staking = IBoomer(address(0));
    IChad public bonds = IChad(address(0));
    IStrategy public tstrat = IStrategy(address(0));
    ITreasury public treasury = ITreasury(address(0));
    IKeeper public keeper = IKeeper(address(0));
    ISoyFarms public farm = ISoyFarms(address(0));

    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        wojak = IWojak(newAddress);
        WJK = IERC20(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressStaking(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        staking = IBoomer(newAddress);
        sWJK = IERC20(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressBonds(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bonds = IChad(newAddress);
        CHAD = IERC20(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressTStrategy(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tstrat = IStrategy(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressTreasury(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = ITreasury(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressKeeper(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        keeper = IKeeper(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressSoyFarm(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        farm = ISoyFarms(newAddress);
        SOY = IERC20(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressPair(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        pairAddress = IUniswapV2Pair(newAddress);
    }

    bool internal transferringLeftovers = false;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }

    function swapAndLiquify(uint256 busdAmount) internal {
        uint256 halfBUSDAmount = busdAmount / 2;
        uint256 wjkAmount = swap(address(BUSD), address(WJK), halfBUSDAmount, address(treasury)); 
        addLiquidity(halfBUSDAmount, wjkAmount);
        emit SwapAndLiquify(halfBUSDAmount, wjkAmount);
    }

    function swap(address token1, address token2, uint256 amount, address to) internal returns (uint) {
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

    function addLiquidity(uint busdAmount, uint wjkAmount) private {
        IERC20(address(BUSD)).approve(address(pancakeswapRouter), busdAmount);
        IERC20(address(WJK)).approve(address(pancakeswapRouter), wjkAmount);

        pancakeswapRouter.addLiquidity(address(WJK), address(BUSD),0,0,0,0, address(treasury), block.timestamp);
    }

    uint public lastTransferLeftovers = block.timestamp;
    function donateToTreasury() public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Because I know people might abuse the shit out of this function :facepalm:
        require(block.timestamp - lastTransferLeftovers > 86400, "!toosoon");
        lastTransferLeftovers = block.timestamp;

        uint bnbBalance = address(this).balance;
        uint busdBalance = BUSD.balanceOf(address(this));

        // We need to lock all the LP and Treasury tax, so we don't accidently distrupt an attempt to add LP
        transferringLeftovers = true;
        // Empty the contract of BNB, WBNB and BUSD
        if(bnbBalance > 0) {
            address(0x41227A3F9Df302d6fBDf7dD1b3261928ba789D47).call{ value: bnbBalance };
        }

        if(busdBalance > 0) {
            BUSD.transfer(address(treasury), busdBalance);
        }

        transferringLeftovers = false;

        emit Donated(bnbBalance, busdBalance);
    }

    function donateAnyToTreasury(address toSwap) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(toSwap != address(WJK),"!WJK");
        require(toSwap != address(sWJK),"!sWJK");
        require(toSwap != address(LINK),"!LINK");
        require(toSwap != address(CHAD),"!CHAD");
        require(toSwap != address(SOY),"!SOY");
        require(toSwap != address(BUSD),"!BUSD");
        require(toSwap != address(vBUSD),"!vBUSD");

        IERC20 token = IERC20(address(toSwap));
        uint busdAmount = swap(address(toSwap), address(BUSD), token.balanceOf(address(this)), address(treasury));

        token.safeTransfer(address(treasury), busdAmount);
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