// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./contracts/access/AccessControl.sol";
import "./contracts/utils/SafeERC20.sol";
import "./Pancakeswap.sol";

import "../Bonds/IChad.sol";
import "../SoyFarms/ISoyFarms.sol";
import "../Staking/IBoomer.sol";
import "../Token/IWojak.sol";
import "../Treasury/ITreasury.sol";
import "../Treasury/bridge/IStrategy.sol";
import "../UpKeep/IKeeper.sol";

contract Common is AccessControl {
    // AccessControl, IWojak, IBoomer, IChad, IStrategy, ITreasury, IKeeper, ISoyFarms, IERC20
    using SafeERC20 for IERC20;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant TOKEN_ROLE = keccak256("TOKEN_ROLE");
    bytes32 public constant STAKING_ROLE = keccak256("STAKING_ROLE");
    bytes32 public constant BONDS_ROLE = keccak256("BONDS_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant SOYFARMS_ROLE = keccak256("SOYFARMS_ROLE");

    event SwapAndLiquify(uint256 WJK, uint256 BUSD);

    IERC20 public BUSD = IERC20(address(0));
    VTokenInterface public vBUSD = VTokenInterface(address(0));
    IERC20 public WBNB = IERC20(address(0));
    IERC20 public WJK = IERC20(address(0));
    IERC20 public sWJK = IERC20(address(0));
    IERC20 public CHAD = IERC20(address(0));
    IERC20 public SOY = IERC20(address(0));
    IERC20 public LINK = IERC20(address(0));
    IERC20 public XVS = IERC20(address(0));

    // Pancakeswap v2
    IUniswapV2Router02 public pancakeswapRouter = IUniswapV2Router02(address(0));
    IUniswapV2Pair public pairAddress = IUniswapV2Pair(address(0));
    IVenusComptroller public Unitroller = IVenusComptroller(address(0));

    IWojak public wojak = IWojak(address(0));
    IBoomer public staking = IBoomer(address(0));
    IChad public bonds = IChad(address(0));
    IStrategy public tstrat = IStrategy(address(0));
    ITreasury public treasury = ITreasury(address(0));
    IKeeper public keeper = IKeeper(address(0));
    ISoyFarms public farm = ISoyFarms(address(0));

    bool transferringLeftovers = false;

    constructor(bool testnet) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TOKEN_ROLE, msg.sender);
        _setupRole(STAKING_ROLE, msg.sender);
        _setupRole(BONDS_ROLE, msg.sender);
        _setupRole(TREASURY_ROLE, msg.sender);
        _setupRole(KEEPER_ROLE, msg.sender);
        _setupRole(SOYFARMS_ROLE, msg.sender);

        if(testnet) {
            BUSD = IERC20(address(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee));
            WBNB = IERC20(address(0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd));
            LINK = IERC20(address(0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06));
            XVS = IERC20(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));

            vBUSD = VTokenInterface(address(0x08e0A5575De71037aE36AbfAfb516595fE68e5e4));
            pancakeswapRouter = IUniswapV2Router02(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));
            Unitroller = IVenusComptroller(address(0x94d1820b2D1c7c7452A163983Dc888CEC546b77D));
        }else{
            BUSD = IERC20(address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56));
            WBNB = IERC20(address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
            LINK = IERC20(address(0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD));
            XVS = IERC20(address(0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63));

            vBUSD = VTokenInterface(address(0x95c78222B3D6e262426483D42CfA53685A67Ab9D));
            pancakeswapRouter = IUniswapV2Router02(address(0xB9e0E753630434d7863528cc73CB7AC638a7c8ff));
            Unitroller = IVenusComptroller(address(0xfD36E2c2a6789Db23113685031d7F16329158384));
        }
    }

    function swapAndLiquify(uint256 busdAmount) internal {
        uint256 half_busdAmount = busdAmount / 2;
        uint256 wjkAmount = swap(address(BUSD), address(WJK), half_busdAmount, address(this)); 
        addLiquidity(half_busdAmount, wjkAmount);
        emit SwapAndLiquify(half_busdAmount, wjkAmount);
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

    uint lastTransferLeftovers = block.timestamp;
    function donateToTreasury() public {
        // Because I know people might abuse the shit out of this function :facepalm:
        require(block.timestamp - lastTransferLeftovers > 86400, "!toosoon");
        lastTransferLeftovers = block.timestamp;
        // We need to lock all the LP and Treasury tax, so we don't accidently distrupt an attempt to add LP
        transferringLeftovers = true;
        // Empty the contract of BNB, WBNB and BUSD
        if(address(this).balance > 0) {
            address(treasury).call{ value: address(this).balance };
        }

        if(BUSD.balanceOf(address(this)) > 0) {
            BUSD.transfer(address(treasury), BUSD.balanceOf(address(this)));
        }

        if(WBNB.balanceOf(address(this)) > 0) {
            WBNB.transfer(address(treasury), WBNB.balanceOf(address(this)));
        }
        transferringLeftovers = false;
    }

    function donateAnyToTreasury(address toSwap) public {
        IERC20 token = IERC20(address(toSwap));
        swap(address(toSwap), address(BUSD), token.balanceOf(address(this)), address(treasury));

        token.safeTransfer(address(treasury), BUSD.balanceOf(address(this)));
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