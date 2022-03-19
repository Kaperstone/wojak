// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./../IPancakeswap.sol";

abstract contract Architecturev2 is ERC20, AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IStaking;

    uint8 private _decimals = 18;

    event Deposit(uint soyAmount);
    event Withdraw(uint tokenAmount);

    bytes32 private constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    bytes32 private constant FARMERS = keccak256("FARMERS");

    IERC20 public wjk = IERC20(address(0)); // When buying new wjk
    IStaking public zwjk = IStaking(address(0)); // We transfer new wjk to swjk

    // Configurable addresses
    address public immutable ITOKEN; // Token investing with

    // Constant addresses
    IUniswapV2Router02 public constant SWAP_ROUTER = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    IERC20 public constant SCREAM = IERC20(0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475);
    IComptroller public constant Comptroller = IComptroller(0x37517C5D880c5c282437a3Da4d627B4457C10BEB);
    address constant public USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    IERC20 constant public WFTM = IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);

    address public keeper = address(0);

    bool public disabled = false; // For emergency or farm deprecation
    bool public lock = false; // Protect investment & order
    bool public immutable isScream;

    uint public bLastHarvest = 0;
    uint public lastHarvest = 0;
    uint public bLastHarvestTime = 0;
    uint public harvestTimeDifference = 0;

    uint public cBalance = 0;
    uint public epochIndex = 0;
    uint public newlyDeposited = 0;
    mapping(uint => uint) private zwjkHistory; // Will keep a track of each wjk total reward
    mapping(uint => uint) private tokenHistory; // Will keep a track of his share of the pool

    struct Depositor {
        uint lastDeposit; // 
        uint lastReceive; // = Epoch when he used last withdrawRewards
        uint justDeposited;
        mapping(uint => uint) myBalance;
    }
    mapping(address => Depositor) private depositor;

    constructor(
        bool _isScream, 
        address _itoken
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);

        isScream = _isScream;
        ITOKEN = _itoken;

        _decimals = IERC(_itoken).decimals();
    }

    // ------- Actions -------

    function depositAdmin(uint tokenAmount) public onlyRole(CONTRACT_ROLE) {
        if(tokenAmount > 0) {
            // Locker & Treasury function
            _deposit(tokenAmount);
        }
    }

    function deposit(uint tokenAmount) public nonReentrant {
        require(!lock, "SOY:Distribution is going on");
        require(tokenAmount >= 10**(_decimals-2), "SOY:Minimum 0.01");
        _deposit(tokenAmount);
    }

    function _deposit(uint tokenAmount) private {
        require(!disabled, "SOY:Farm disabled,withdraw only");
        
        // We transfer his tokens to the smart contract, its now in its posession
        IERC20(ITOKEN).safeTransferFrom(msg.sender, address(this), tokenAmount);

        // Is he a new depositor?
        if(balanceOf(msg.sender) == 0) {
            // Grant him the FARMER title, useful for checks to see if he is a farmer later on
            _grantRole(FARMERS, msg.sender);
            depositor[msg.sender].lastReceive = epochIndex;
            depositor[msg.sender].justDeposited = tokenAmount;
            depositor[msg.sender].myBalance[epochIndex] = tokenAmount;

            _mint(msg.sender, tokenAmount); // Mint 1:1 $SOY
        }else{

            // If he is not a new depositor
            // If he already deposited in this epoch
            if(depositor[msg.sender].lastDeposit == epochIndex) {
                // He did deposit this epoch, so we use the same
                depositor[msg.sender].justDeposited += tokenAmount;
            }else{
                // He didn't deposit in this epoch, we set everything
                depositor[msg.sender].justDeposited = tokenAmount;
            }

            _mint(msg.sender, tokenAmount);
            depositor[msg.sender].myBalance[epochIndex +1] = balanceOf(msg.sender); // balance of the future
        }

        newlyDeposited += tokenAmount;
        depositor[msg.sender].lastDeposit = epochIndex; // This is his sole purpose.

        emit Deposit(tokenAmount);
    }

    function withdraw(uint soyAmount) public nonReentrant {
        require(!lock, "SOY:Distribution is going on");
        require((epochIndex - depositor[msg.sender].lastDeposit) > 4, "SOY:Cannot withdraw yet");
        _withdraw(soyAmount);
    }

    function withdrawAdmin(uint soyAmount) public onlyRole(CONTRACT_ROLE)  {
        _withdraw(soyAmount);
    }
    
    function _withdraw(uint soyAmount) private onlyRole(FARMERS) {
        // He requests back more than he can
        require(balanceOf(msg.sender) >= soyAmount, "SOY:Insufficient amount");
        require(soyAmount > 0, "SOY:non-zero");
        
        // Burn his sauce
        _burn(msg.sender, soyAmount);
        withdrawRewards(msg.sender);

        // If his last deposit was the current epoch
        if(depositor[msg.sender].lastDeposit == epochIndex) {

            // We have balance in the future
            depositor[msg.sender].myBalance[epochIndex + 1] = 0; // We set it to zero

            // If he withdraws more than he deposited this epoch
            if(soyAmount > depositor[msg.sender].justDeposited) {
                // He withdraws all that he just deposited
                newlyDeposited -= depositor[msg.sender].justDeposited; // It doesn't require a condition because newlyDeposited >= depositor.justDeposited (always)
                // So part of it is in IGS
                uint inIGS = soyAmount - depositor[msg.sender].justDeposited;
                igs_withdraw(inIGS);
                cBalance -= inIGS;

            }else{
                // He withdraws less than he deposited
                newlyDeposited -= soyAmount;
            }

            // We send him his tokens later on
        }else{ 
            /*
                Its not his first epoch
                He deposited before the current epoch
            
                As he is not a new depositor, then all of his soyAmount is already working
                so we withdraw everything from IGS and we attempt to withraw all of his rewards
                (in any case)

            */

            // Decrease the participation amount
            cBalance -= soyAmount;

            // Because this is not the same epoch, his tokens should be in IGS
            // Withdraw his tokens from the IGS (interest generating strategy)
            igs_withdraw(soyAmount);
        }

        depositor[msg.sender].myBalance[epochIndex -1] = balanceOf(msg.sender); // We set the past balance to the current balance
        depositor[msg.sender].myBalance[epochIndex] = 0; // We set the current epoch balance to zero

        // Give him his tokens back, 1:1
        IERC20(ITOKEN).safeTransfer(msg.sender, soyAmount -1); // -1 for percision cautiousness

        // Is he still one of us?
        if(balanceOf(msg.sender) == 0) _revokeRole(FARMERS, msg.sender);

        emit Withdraw(soyAmount);
    }

    /*

        @params:
        @returns:

    */
    function withdrawRewards(address _holder) public nonReentrant returns (uint) {  // Error: revert
        uint wjkAmount = 0;

        if(hasRole(FARMERS, _holder)) {
            uint zwjkRewards = checkRewards(_holder);

            depositor[_holder].lastReceive = epochIndex;

            // Transfer
            // Check if we found any rewards to send
            if(zwjkRewards > 0) {
                // Its always in staking mode
                wjkAmount = zwjk.unstake(zwjkRewards); // No tokens to unstake (trying to unstake more than holding)
                // Transfer his WJK
                wjk.safeTransfer(_holder, wjkAmount);
            }
        }

        return wjkAmount;
    }

    /*

        @params:
        @returns:

    */
    function checkRewards(address _holder) public view returns (uint) {
        uint lastReceive = depositor[_holder].lastReceive;
        if(hasRole(FARMERS, _holder) && lastReceive < epochIndex) { // Always excluding current epoch
            uint zwjkRewards = 0;
            uint balance = 0;

            // Last interaction happened after receive
            for(uint x = lastReceive; x >= 0; x--) {
                if(depositor[_holder].myBalance[x] > 0) {
                    balance = depositor[_holder].myBalance[x];
                    break;
                }
            }

            for(uint x = lastReceive; x < epochIndex; x++) {
                if(zwjkHistory[x] > 0 && tokenHistory[x] > 0 && balance > 0) {
                    zwjkRewards += ( zwjkHistory[x]*10**(36 - _decimals) ) / ( (tokenHistory[x]*10**(36 - _decimals)) / balance);
                }
                    
                // If spokenEpoch equals to the new change
                // then we move to the next index and use the new balance
                if(depositor[_holder].myBalance[x] > 0) {
                    balance = depositor[_holder].myBalance[x];
                }   
            }
            return zwjkRewards;
        }

        return 0;
    }

    // ------- Routine -------

    function distributeRewards() public onlyRole(CONTRACT_ROLE) {
        lock = true;
        if(cBalance > 0) {

            // Variables
            uint underlyingBalance = igs_underlyingBalance();
            uint profit = 0;

            // Check if we made a profit
            if(underlyingBalance > cBalance) profit = underlyingBalance - cBalance -2;

            // First rounds are rough.
            uint fraction = 0;
            if(address(ITOKEN) == address(USDC)) {
                fraction = 1e5; // 0.1 USDC
            }else if(address(ITOKEN) == address(WFTM)) {
                fraction = 1e17; // 0.1 FTM
            }else{
                // This is done because different tokens have different supply
                // Tokens like SPELL, 0.1 equals to cents, while 0.1 YFI equals to ~1800$ at the time of writing
                // Compare by price will require additional measures with YFI-ETH awful pairing.
                fraction = IERC20(ITOKEN).totalSupply() / 1e8;
            }

            if(profit > fraction) {
                // Perform a buyback and then put into staking all the tokens

                // Get accrued revenue
                igs_withdraw(profit);

                uint wftmAmount = 0;

                // Is WFTM farm
                if(address(ITOKEN) == address(WFTM)) {
                    wftmAmount = WFTM.balanceOf(address(this)) - newlyDeposited;

                    Comptroller.claimComp(address(this));
                    uint screamBalance = SCREAM.balanceOf(address(this));
                    if(screamBalance > 1e15)
                        wftmAmount += swap(address(SCREAM), address(WFTM), screamBalance, address(this));
                }else{
                    profit = IERC20(ITOKEN).balanceOf(address(this)) - newlyDeposited;
                    // Only applicable to tokens that deposited into SCREAM
                    if(isScream) {
                        Comptroller.claimComp(address(this));
                        uint screamBalance = SCREAM.balanceOf(address(this));
                        if(screamBalance > 1e15) { // 0.001 scream
                            uint ftmAmount = swap(address(SCREAM), address(WFTM), screamBalance, address(this));
                            profit += swap(address(WFTM), ITOKEN, ftmAmount, address(this));
                        }
                    }

                    wftmAmount += swap(address(ITOKEN), address(WFTM), profit, address(this));
                }

                // 10% to keeper
                uint keeperShare = wftmAmount / 100;
                WFTM.safeTransfer(keeper, keeperShare);
                wftmAmount -= keeperShare;

                uint usdcAmount = swap(address(WFTM), address(USDC), wftmAmount, address(this)); // WFTM => USDC
                uint wjkAmount = swap(address(USDC), address(wjk), usdcAmount, address(this)); // USDC => WJK

                // Put into leveraged staking
                wjk.approve(address(zwjk), wjkAmount);
                uint zwjkAmount = zwjk.stakeAdmin(wjkAmount);

                // We make a record of this epoch
                zwjkHistory[epochIndex] = zwjkAmount;
                bLastHarvest = lastHarvest;
                lastHarvest = zwjkAmount;

                harvestTimeDifference = block.timestamp - bLastHarvestTime;
                bLastHarvestTime = block.timestamp;

            // No buyback was made
            }else zwjkHistory[epochIndex] = 0;
        }else zwjkHistory[epochIndex] = 0;
        // We make a record of how many tokens were staked
        tokenHistory[epochIndex] = cBalance;

        // New epoch
        epochIndex++;

        // Deposit newly added tokens to contract
        /*

            This late deposit to revenue generating strategy eliminates loses on first deposit

        */
        if(newlyDeposited > 0) {
            igs_deposit(newlyDeposited);

            cBalance += newlyDeposited;
            newlyDeposited = 0;
        }

        lock = false;
    }

    function hipoYearlyOutput() public view returns (uint) {
        uint diff = 0;

        if(bLastHarvest < lastHarvest) {
            diff = lastHarvest - bLastHarvest;
        }else{
            diff = bLastHarvest - lastHarvest;
        }

        return diff * (31622400 / harvestTimeDifference);
        /*

            Calculate afterwards:
                100 / (marketValue(totalDeposited) / marketValue(hipoYearlyOutput()))

                4 WJK a day

                10,000 * (31622400 / 86400) = 3,660,000 WJK
                100 / (600000 / 366000) = 61%

        */
    }

    // ------- Functions -------
    function igs_deposit(uint) internal virtual {}
    function igs_underlyingBalance() public virtual returns (uint) {}
    function igs_withdraw(uint) internal virtual {}

    // Restrict transfers of the token
    function _beforeTokenTransfer(address from, address to, uint /* amount */) internal virtual override {
        if(from != address(0) && to != address(0) && from != address(this) && to != address(this)) require(false, "!illegal");
    }

    function swap(address token0, address token1, uint amount, address to) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = token0;  
        path[1] = token1;

        IERC20(token0).approve(address(SWAP_ROUTER), amount);
        uint[] memory amounts = SWAP_ROUTER.swapExactTokensForTokens(amount, 0, path, to, block.timestamp);
        return amounts[amounts.length - 1];
    }

    // ------- Administration -------

    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        wjk = IERC20(newAddress);
    }

    function setAddressStaking(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        zwjk = IStaking(newAddress);
    }

    function setAddressKeeper(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        keeper = newAddress;
    }
    
    function disableFarm() public onlyRole(DEFAULT_ADMIN_ROLE) {
        disabled = !disabled;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}

interface IERC {
    function decimals() external returns (uint8);
}

interface IComptroller {
    function claimComp(address holder) external;
    function balanceOf(address) external view returns(uint);
}

interface IStaking is IERC20 {
    function stakeAdmin(uint) external returns(uint);
    function unstake(uint) external returns(uint);
}