// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./../IPancakeswap.sol";

contract BooSoy is ERC20, AccessControlEnumerable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IStaking;

    uint8 private constant _ldecimals = 18;
    uint8 private constant _decimals = 18;

    event Deposit(uint soyAmount);
    event Withdraw(uint booAmount);

    bytes32 private constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    bytes32 private constant FARMERS = keccak256("FARMERS");

    IERC20 public wjk = IERC20(address(0)); // When buying new wjk
    IStaking public zwjk = IStaking(address(0)); // We transfer new wjk to swjk

    ILending public constant LTOKEN = ILending(0xa48d959AE2E88f1dAA7D5F611E01908106dE7598); // The token from the lending platform we interact with
    IERC20 public constant ITOKEN = IERC20(0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE); // The token we are investing with, like boo
    IUniswapV2Router02 public constant SWAP_ROUTER = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    address constant public USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant public WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    ILocker public locker = ILocker(address(0));
    address public keeper = address(0);

    bool public disabled = false; // For emergency or farm deprecation
    bool public lock = false; // Protect investment & order

    uint public booBalance = 0;
    uint public epochIndex = 0;
    uint public booOverflow = 0;
    mapping(address => uint) private epochs; // Each account epoch entered
    mapping(uint => uint) private zwjkHistory; // Will keep a track of each wjk total reward
    mapping(uint => uint) private booHistory; // Will keep a track of his share of the pool

    address ownerAddress = address(0);

    constructor() ERC20("Boo Bean", "booSOY") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
        ownerAddress = msg.sender;
    }

    // ------- Actions -------

    function depositAdmin(uint booAmount) public onlyRole(CONTRACT_ROLE) {
        _deposit(booAmount);
    }

    function deposit(uint booAmount) public {
        require(!lock, "BooSoy:Distribution is going on");
        require(booAmount >= 10**(_decimals-2), "BooSoy:Minimum 0.01 BOO");
        _deposit(booAmount);
    }

    function _deposit(uint booAmount) private {
        require(!disabled, "BooSoy:Farm disabled,withdraw only");
        
        // We transfer his tokens to the smart contract, its now in its posession
        ITOKEN.safeTransferFrom(msg.sender, address(this), booAmount);
        
        if(balanceOf(msg.sender) == 0) {
            _grantRole(FARMERS, msg.sender);
            epochs[msg.sender] = epochIndex;
        }else{
            _withdrawRewards(balanceOf(msg.sender));
        }

        booBalance += booAmount; // Global track
        booOverflow += booAmount;

        // Deposit to lending
        ITOKEN.approve(address(LTOKEN), booAmount);
        LTOKEN.enter(booAmount); // Put into work
        
        _mint(msg.sender, booAmount); // Mint 1:1 $SOY tokens with boo

        emit Deposit(booAmount);
        IKeeper(keeper).distributeRewards();
    }
    
    function withdraw(uint soyAmount) public returns (uint) {
        // 7 epochs
        require(epochIndex > (epochs[msg.sender] + 7), "BooSoy:You cannot withdraw yet.");
        require(!lock, "BooSoy:Distribution is going on");
        return _withdraw(soyAmount);
    }

    function withdrawAdmin(uint soyAmount) public onlyRole(CONTRACT_ROLE) returns (uint) {
        return _withdraw(soyAmount);
    }
    
    function _withdraw(uint soyAmount) private onlyRole(FARMERS) returns (uint) {
        // He requests back more than he can
        require(balanceOf(msg.sender) >= soyAmount, "BooSoy:Insufficient amount");
        
        // Burn his sauce
        _burn(msg.sender, soyAmount);
        // Decrease global supply
        booBalance -= soyAmount;

        uint xbooAmount = LTOKEN.BOOForxBOO(soyAmount);
        LTOKEN.approve(address(LTOKEN), xbooAmount);
        LTOKEN.leave(xbooAmount); // SOY = BOO => xBOO => BOO back

        // Give him his tokens from this contract
        uint wjkAmount = _withdrawRewards(soyAmount);
        ITOKEN.safeTransfer(msg.sender, soyAmount -1); // Boo accuracy

        // Not one of us anymore
        if(balanceOf(msg.sender) == 0) _revokeRole(FARMERS, msg.sender);

        emit Withdraw(soyAmount);
        IKeeper(keeper).distributeRewards();

        return wjkAmount;
    }

    // public function, accounts can withdraw rewards without withdrawing boo
    function withdrawRewards() public returns (uint) {
        return _withdrawRewards(balanceOf(msg.sender));
    }

    function _withdrawRewards(uint soyAmount) private returns (uint) {
        uint wjkAmount = 0;
        uint zwjkAmount = 0;
        uint cEpoch = epochs[msg.sender];

        // Avoid reentrancy;
        epochs[msg.sender] = epochIndex; // Reset his epoch count

        if(cEpoch < epochIndex) {
            // Loop from the epoch he entered to the current epoch and collect all rewards
            for(uint x = cEpoch; x <= epochIndex; x++) {
                if(zwjkHistory[x] > 0 && booHistory[x] > 0) {
                    zwjkAmount += (zwjkHistory[x]*10**_decimals) / ((booHistory[x]*10**_decimals) / soyAmount); // We multiply by 10^_decimals because I hate my life.
                }
            }
        }

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
        uint wjkAmount = 0;
        if(hasRole(FARMERS, _farmer) && epochs[_farmer] < epochIndex) {
            for(uint x = epochs[_farmer]; x <= epochIndex; x++) {
                if(zwjkHistory[x] > 0 && booHistory[x] > 0) {
                    wjkAmount += (zwjkHistory[x]*10**_decimals) / ((booHistory[x]*10**_decimals) / balanceOf(_farmer));
                }
            }
        }
        return wjkAmount;
    }

    // ------- Routine -------

    function distributeRewards() public onlyRole(CONTRACT_ROLE) {
        if(booBalance > 0) {
            lock = true;

            uint booWorth = LTOKEN.BOOBalance(address(this));
            uint booProfit = 0;
            if(booWorth > booBalance) booProfit = booWorth - booBalance;

            if(booProfit > 10**(_decimals-2)) { // 0.01
                // Perform a buyback and then put into staking all the tokens
                // Extract precise amount of revenue


                // Get accrued revenue
                LTOKEN.leave(LTOKEN.BOOForxBOO(booProfit) -2);
                uint boo = ITOKEN.balanceOf(address(this));

                // 5% to locker
                uint lockerShare = boo / 20;
                ITOKEN.approve(address(locker), lockerShare);
                locker.depositToBank(address(ITOKEN), lockerShare);
                boo -= lockerShare;

                // 1% to dev
                uint devShare = boo / 100;
                ITOKEN.transfer(address(ownerAddress), devShare);
                boo -= devShare;

                // The rest is sent to buy WJK
                uint wftmAmount = swap(address(ITOKEN), WFTM, boo, address(this));
                uint usdcAmount = swap(WFTM, USDC, wftmAmount, address(this));
                uint wjkAmount = swap(USDC, address(wjk), usdcAmount, address(this));
                // Put into leveraged staking
                wjk.approve(address(zwjk), wjkAmount);
                uint wjkRewards = zwjk.stakeAdmin(wjkAmount);

                // We now go through the "actual distribution"
                zwjkHistory[epochIndex] = wjkRewards;
            }else{
                zwjkHistory[epochIndex] = 0;
            }

            booHistory[epochIndex] = booBalance - booOverflow;
            booOverflow = 0;
            epochIndex++;

            lock = false;
        }
    }

    // ------- Functions -------

    // Restrict transfers of the token
    function _beforeTokenTransfer(
        address from,
        address to,
        uint /* amount */
    ) internal virtual override {
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
    function enter(uint) external;
    function leave(uint) external;
    function BOOBalance(address) external view returns (uint);
    function BOOForxBOO(uint) external view returns (uint);
}

interface ILocker {
    function depositToBank(address addr, uint amount) external;
}

interface IStaking is IERC20 {
    function stakeAdmin(uint) external returns(uint);
    function unstake(uint) external returns(uint);
}

interface IKeeper {
    function distributeRewards() external;
}