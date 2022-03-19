// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./../IPancakeswap.sol";

contract CrvSoy is ERC20, AccessControlEnumerable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IStaking;

    // uint8 private constant _ldecimals = 8;
    uint8 private constant _decimals = 18;

    event Deposit(uint soyAmount);
    event Withdraw(uint crvAmount);

    bytes32 private constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    bytes32 private constant FARMERS = keccak256("FARMERS");

    IERC20 public wjk = IERC20(address(0)); // When buying new wjk
    IStaking public zwjk = IStaking(address(0)); // We transfer new wjk to swjk

    ILending public constant LTOKEN = ILending(0x820BdA1786AFA19DA6B92d6AC603574962337326); // The token from the lending platform we interact with
    IERC20 public constant ITOKEN = IERC20(0x1E4F97b9f9F913c46F1632781732927B9019C68b); // The token we are investing with, like CRV
    IUniswapV2Router02 public constant SWAP_ROUTER = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    IERC20 public constant SCREAM = IERC20(0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475);
    IComptroller public constant Comptroller = IComptroller(0x37517C5D880c5c282437a3Da4d627B4457C10BEB);
    
    address constant public USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant public WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    ILocker public locker = ILocker(address(0));
    address public keeper = address(0);

    bool public disabled = false; // For emergency or farm deprecation
    bool public lock = false; // Protect investment & order

    uint public crvBalance = 0;
    uint public epochIndex = 0;
    uint public crvOverflow = 0;
    mapping(address => uint) private epochs; // Each account epoch entered
    mapping(uint => uint) private zwjkHistory; // Will keep a track of each wjk total reward
    mapping(uint => uint) private crvHistory; // Will keep a track of his share of the pool

    address ownerAddress = address(0);

    constructor() ERC20("CRV Bean", "crvSOY") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
        ownerAddress = msg.sender;
    }

    // ------- Actions -------

    function depositAdmin(uint crvAmount) public onlyRole(CONTRACT_ROLE) {
        _deposit(crvAmount);
    }

    function deposit(uint crvAmount) public {
        require(!lock, "CrvSoy:Distribution is going on");
        require(crvAmount >= 10**(_decimals-2), "CrvSoy:Minimum 0.01 CRV");
        _deposit(crvAmount);
    }

    function _deposit(uint crvAmount) private {
        require(!disabled, "CrvSoy:Farm disabled,withdraw only");
        
        // We transfer his tokens to the smart contract, its now in its posession
        ITOKEN.safeTransferFrom(msg.sender, address(this), crvAmount);
        
        if(balanceOf(msg.sender) == 0) {
            _grantRole(FARMERS, msg.sender);
            epochs[msg.sender] = epochIndex;
        }else{
            _withdrawRewards(balanceOf(msg.sender));
        }

        crvBalance += crvAmount; // Global track
        crvOverflow += crvAmount;

        // Deposit to lending
        ITOKEN.approve(address(LTOKEN), crvAmount);
        LTOKEN.mint(crvAmount); // Put into work
        
        _mint(msg.sender, crvAmount); // Mint 1:1 $SOY tokens with CRV

        emit Deposit(crvAmount);
        IKeeper(keeper).distributeRewards();
    }
    
    function withdraw(uint soyAmount) public returns (uint) {
        // 7 epochs
        require(epochIndex > (epochs[msg.sender] + 7), "CrvSoy:You cannot withdraw yet.");
        require(!lock, "CrvSoy:Distribution is going on");
        return _withdraw(soyAmount);
    }

    function withdrawAdmin(uint soyAmount) public onlyRole(CONTRACT_ROLE) returns (uint) {
        return _withdraw(soyAmount);
    }
    
    function _withdraw(uint soyAmount) private onlyRole(FARMERS) returns (uint) {
        // He requests back more than he can
        require(balanceOf(msg.sender) >= soyAmount, "CrvSoy:Insufficient amount");
        
        // Burn his sauce
        _burn(msg.sender, soyAmount);
        // Decrease global supply
        crvBalance -= soyAmount;

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

    // public function, accounts can withdraw rewards without withdrawing crv
    function withdrawRewards() public returns (uint) {
        return _withdrawRewards(balanceOf(msg.sender));
    }

    function _withdrawRewards(uint soyAmount) private returns (uint) {
        uint zwjkAmount = 0;
        uint wjkAmount = 0;
        uint cEpoch = epochs[msg.sender];

        // Avoid reentrancy;
        epochs[msg.sender] = epochIndex; // Reset his epoch count

        if(cEpoch < epochIndex)
            // Loop from the epoch he entered to the current epoch and collect all rewards
            for(uint x = cEpoch; x <= epochIndex; x++) 
                if(zwjkHistory[x] > 0 && crvHistory[x] > 0) 
                    zwjkAmount += (zwjkHistory[x]*10**(18 - _decimals + 18)) / ((crvHistory[x]*10**(36 - _decimals)) / soyAmount);

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
        if(hasRole(FARMERS, _farmer) && epochs[_farmer] < epochIndex)
            for(uint x = epochs[_farmer]; x <= epochIndex; x++)
                if(zwjkHistory[x] > 0 && crvHistory[x] > 0)
                    zwjkAmount += (zwjkHistory[x]*10**(18 - _decimals + 18)) / ((crvHistory[x]*10**(36 - _decimals)) / soyAmount);

        return zwjkAmount;
    }

    // ------- Routine -------

    function distributeRewards() public onlyRole(CONTRACT_ROLE) {
        if(crvBalance > 0) {
            lock = true;

            uint underlyingBalance = LTOKEN.balanceOfUnderlying(address(this));
            uint crvProfit = 0;
            if(underlyingBalance > crvBalance) crvProfit = underlyingBalance - crvBalance;

            // First rounds are rough.
            if(crvProfit > 10**(_decimals-2)) { // 0.01
                // Perform a buyback and then put into staking all the tokens
                // Extract precise amount of revenue


                // Get accrued revenue
                LTOKEN.redeemUnderlying(crvProfit);
                Comptroller.claimComp(address(this));
                uint screamBalance = SCREAM.balanceOf(address(this));
                if(screamBalance > 1e17) { // 0.1 scream
                    uint ftmAmount = swap(address(SCREAM), WFTM, screamBalance, address(this));
                    swap(WFTM, address(ITOKEN), ftmAmount, address(this));
                }
                uint crv = ITOKEN.balanceOf(address(this));

                // 5% to locker
                uint lockerShare = crv / 20;
                ITOKEN.approve(address(locker), lockerShare);
                locker.depositToBank(address(ITOKEN), lockerShare);
                crv -= lockerShare;

                // 1% to dev
                uint devShare = crv / 100;
                ITOKEN.transfer(address(ownerAddress), devShare);
                crv -= devShare;

                uint wftmAmount = swap(address(ITOKEN), WFTM, crv, address(this)); // CRV => WFTM
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

            crvHistory[epochIndex] = crvBalance - crvOverflow;
            crvOverflow = 0;
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
    
    function disableFarm() public onlyRole(DEFAULT_ADMIN_ROLE) {
        disabled = !disabled;
    }

    function setAddressKeeper(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        keeper = newAddress;
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