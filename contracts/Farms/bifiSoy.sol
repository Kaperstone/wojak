// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./../IPancakeswap.sol";

contract BifiSoy is ERC20, AccessControlEnumerable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IStaking;

    // uint8 private constant _ldecimals = 8;
    uint8 private constant _decimals = 18;

    event Deposit(uint soyAmount);
    event Withdraw(uint bifiAmount);

    bytes32 private constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    bytes32 private constant FARMERS = keccak256("FARMERS");

    IERC20 public wjk = IERC20(address(0)); // When buying new wjk
    IStaking public zwjk = IStaking(address(0)); // We transfer new wjk to swjk

    ILending public constant LTOKEN = ILending(0x0467c22fB5aF07eBb14C851C75bFf4180674Ed64); // The token from the lending platform we interact with
    IERC20 public constant ITOKEN = IERC20(0xd6070ae98b8069de6B494332d1A1a81B6179D960); // The token we are investing with, like BIFI
    IUniswapV2Router02 public constant SWAP_ROUTER = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    IERC20 public constant SCREAM = IERC20(0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475);
    IComptroller public constant Comptroller = IComptroller(0x37517C5D880c5c282437a3Da4d627B4457C10BEB);
    
    address constant public USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant public WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    ILocker public locker = ILocker(address(0));
    address public keeper = address(0);

    bool public disabled = false; // For emergency or farm deprecation
    bool public lock = false; // Protect investment & order

    uint public bifiBalance = 0;
    uint public epochIndex = 0;
    uint public bifiOverflow = 0;
    mapping(address => uint) private epochs; // Each account epoch entered
    mapping(uint => uint) private zwjkHistory; // Will keep a track of each wjk total reward
    mapping(uint => uint) private bifiHistory; // Will keep a track of his share of the pool

    address ownerAddress = address(0);

    constructor() ERC20("BIFI Bean", "bifiSOY") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
        ownerAddress = msg.sender;
    }

    // ------- Actions -------

    function depositAdmin(uint bifiAmount) public onlyRole(CONTRACT_ROLE) {
        _deposit(bifiAmount);
    }

    function deposit(uint bifiAmount) public {
        require(!lock, "BifSoy:Distribution is going on");
        require(bifiAmount >= 10**(_decimals-2), "BifSoy:Minimum 0.01 BIFI");
        _deposit(bifiAmount);
    }

    function _deposit(uint bifiAmount) private {
        require(!disabled, "BifSoy:Farm disabled,withdraw only");
        
        // We transfer his tokens to the smart contract, its now in its posession
        ITOKEN.safeTransferFrom(msg.sender, address(this), bifiAmount);
        
        if(balanceOf(msg.sender) == 0) {
            _grantRole(FARMERS, msg.sender);
            epochs[msg.sender] = epochIndex;
        }else{
            _withdrawRewards(balanceOf(msg.sender));
        }

        bifiBalance += bifiAmount; // Global track
        bifiOverflow += bifiAmount;

        // Deposit to lending
        ITOKEN.approve(address(LTOKEN), bifiAmount);
        LTOKEN.mint(bifiAmount); // Put into work
        
        _mint(msg.sender, bifiAmount); // Mint 1:1 $SOY tokens with BIFI

        emit Deposit(bifiAmount);
        IKeeper(keeper).distributeRewards();
    }
    
    function withdraw(uint soyAmount) public returns (uint) {
        // 7 epochs
        require(epochIndex > (epochs[msg.sender] + 7), "BifSoy:You cannot withdraw yet.");
        require(!lock, "BifSoy:Distribution is going on");
        return _withdraw(soyAmount);
    }

    function withdrawAdmin(uint soyAmount) public onlyRole(CONTRACT_ROLE) returns (uint) {
        return _withdraw(soyAmount);
    }
    
    function _withdraw(uint soyAmount) private onlyRole(FARMERS) returns (uint) {
        // He requests back more than he can
        require(balanceOf(msg.sender) >= soyAmount, "BifSoy:Insufficient amount");
        
        // Burn his sauce
        _burn(msg.sender, soyAmount);
        // Decrease global supply
        bifiBalance -= soyAmount;

        LTOKEN.approve(address(LTOKEN), soyAmount);
        LTOKEN.redeemUnderlying(soyAmount);

        // Give him his tokens from this contract
        uint wjkAmount = _withdrawRewards(soyAmount);
        ITOKEN.safeTransfer(msg.sender, soyAmount -1);

        // Not one of us anymore
        if(balanceOf(msg.sender) == 0) _revokeRole(FARMERS, msg.sender);

        emit Withdraw(soyAmount);
        IKeeper(keeper).distributeRewards();

        return wjkAmount;
    }

    // public function, accounts can withdraw rewards without withdrawing bifi
    function withdrawRewards() public returns (uint) {
        return _withdrawRewards(balanceOf(msg.sender));
    }

    function _withdrawRewards(uint soyAmount) private returns (uint) {
        uint zwjkAmount = 0;
        uint wjkAmount = 0;
        uint cEpoch = epochs[msg.sender] + 1;

        // Avoid reentrancy;
        epochs[msg.sender] = epochIndex; // Reset his epoch count

        if(cEpoch < epochIndex)
            // Loop from the epoch he entered to the current epoch and collect all rewards
            for(uint x = cEpoch; x <= epochIndex; x++) 
                if(zwjkHistory[x] > 0 && bifiHistory[x] > 0) 
                    zwjkAmount += (zwjkHistory[x]*10**(18 - _decimals + 18)) / ((bifiHistory[x]*10**(36 - _decimals)) / soyAmount);

        if(zwjkAmount > 0) {
            wjkAmount = zwjk.unstake(zwjkAmount);
            wjk.safeTransfer(msg.sender, wjkAmount);
        }
        return wjkAmount;
    }

    // ------- Helpers -------

    function timeDifference(address _farmer) public view returns (uint) {
        if(hasRole(FARMERS, _farmer)) return epochIndex - epochs[_farmer];
        else return 0;
    }
    
    function checkRewards(address _farmer) public view returns (uint) {
        uint zwjkAmount = 0;
        uint soyAmount = balanceOf(_farmer);
        uint cEpoch = epochs[_farmer] + 1;
        if(hasRole(FARMERS, _farmer) && cEpoch < epochIndex)
            for(uint x = cEpoch; x <= epochIndex; x++)
                if(zwjkHistory[x] > 0 && bifiHistory[x] > 0)
                    zwjkAmount += (zwjkHistory[x]*10**(18 - _decimals + 18)) / ((bifiHistory[x]*10**(36 - _decimals)) / soyAmount);

        return zwjkAmount;
    }

    // ------- Routine -------

    function distributeRewards() public onlyRole(CONTRACT_ROLE) {
        if(bifiBalance > 0) {
            lock = true;

            uint underlyingBalance = LTOKEN.balanceOfUnderlying(address(this));
            uint bifiProfit = 0;
            if(underlyingBalance > bifiBalance) bifiProfit = underlyingBalance - bifiBalance;

            // First rounds are rough.
            if(bifiProfit > 10**(_decimals-2)) { // 0.01
                // Perform a buyback and then put into staking all the tokens
                // Extract precise amount of revenue


                // Get accrued revenue
                LTOKEN.redeemUnderlying(bifiProfit);
                Comptroller.claimComp(address(this));
                uint screamBalance = SCREAM.balanceOf(address(this));
                if(screamBalance > 1e15) { // 0.001 scream
                    uint ftmAmount = swap(address(SCREAM), WFTM, screamBalance, address(this));
                    swap(WFTM, address(ITOKEN), ftmAmount, address(this));
                }
                uint bifi = ITOKEN.balanceOf(address(this));

                // 5% to locker
                uint lockerShare = bifi / 20;
                ITOKEN.approve(address(locker), lockerShare);
                locker.depositToBank(address(ITOKEN), lockerShare);
                bifi -= lockerShare;

                // 1% to dev
                uint devShare = bifi / 100;
                ITOKEN.transfer(address(ownerAddress), devShare);
                bifi -= devShare;

                uint wftmAmount = swap(address(ITOKEN), WFTM, bifi, address(this)); // CRV => WFTM
                uint usdcAmount = swap(WFTM, USDC, wftmAmount, address(this)); // WFTM => USDC
                uint wjkAmount = swap(USDC, address(wjk), usdcAmount, address(this)); // USDC => WJK
                // Put into leveraged staking
                wjk.approve(address(zwjk), wjkAmount);
                uint zwjkAmount = zwjk.stakeAdmin(wjkAmount);

                // We now go through the "actual distribution"
                zwjkHistory[epochIndex] = zwjkAmount;
            }else{
                zwjkHistory[epochIndex] = 0;
            }

            bifiHistory[epochIndex] = bifiBalance - bifiOverflow;
            bifiOverflow = 0;
            epochIndex++;

            lock = false;
        }
    }

    // ------- Functions -------

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

    function setAddressLocker(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        locker = ILocker(newAddress);
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

interface ILending is IERC20 {
    function mint(uint) external returns (uint);
    function redeemUnderlying(uint) external returns (uint);
    function balanceOfUnderlying(address) external returns (uint);
}

interface ILocker {
    function depositToBank(address addr, uint amount) external;
}

interface IComptroller {
    function claimComp(address holder) external;
    function balanceOf(address) external view returns(uint);
}

interface IStaking is IERC20 {
    function stakeAdmin(uint) external returns(uint);
    function unstake(uint) external returns(uint);
}

interface IKeeper {
    function distributeRewards() external;
}