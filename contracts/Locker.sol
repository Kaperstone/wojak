// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Locker is ERC20, AccessControlEnumerable {
    using SafeERC20 for IERC20;

    // Configuarition
    uint private constant LOCK_TIME = 2628000;

    event Deposit(uint swjkAmount);
    event Withdraw(uint lockAmount);

    bytes32 private constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    bytes32 private constant LOCKERS = keccak256("LOCKERS");
    bytes32 private constant TOKENS = keccak256("TOKENS");
    
    IERC public wjk = IERC(address(0));
    IERC20 public swjk = IERC20(address(0));

    bool public disabled = false;
    bool public lock = false;

    uint public epochIndex = 0;
    uint private swjkBalance = 0;
    uint private swjkOverflow = 0;
    mapping(address => uint) private epochs; // Each account epoch entered
    mapping(uint => uint) private swjkHistory; // Will keep a track of each wjk total reward
    mapping(address => uint) public timeleft;

    struct SToken {
        address strategy;
        uint balance;
        uint record;
        mapping(uint => uint) history;
    }

    mapping(address => SToken) public token;

    uint public statsBurntWJK = 0;

    constructor() ERC20("Boomer Locks", "LOCK") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }

    /*

        @caution: when used, it will reset all current profit

    */
    function addStrategy(address tokenAddress, address strategy) public onlyRole(DEFAULT_ADMIN_ROLE) {
        token[tokenAddress].strategy = strategy;
        uint balance = IERC20(tokenAddress).balanceOf(address(this));
        token[tokenAddress].balance = balance;
        token[tokenAddress].record = balance;
        grantRole(TOKENS, tokenAddress);
    }

    function disableStrategy(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(TOKENS, tokenAddress);

        uint balance = IStrategy(token[tokenAddress].strategy).balanceOf(address(this));
        if(token[tokenAddress].strategy != address(0) && balance > 0) {
            IStrategy(token[tokenAddress].strategy).withdrawAdmin(balance);
            wjk.burn(wjk.balanceOf(address(this)));
        }
    }

    function enableStrategy(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(TOKENS, tokenAddress);

        uint balance = IERC20(tokenAddress).balanceOf(address(this));
        uint _decimals = IERC(tokenAddress).decimals();

        token[tokenAddress].balance = balance;
        if(token[tokenAddress].strategy != address(0) && balance >= 10**(_decimals-2)) {
            IERC20(tokenAddress).approve(token[tokenAddress].strategy, balance);
            IStrategy(token[tokenAddress].strategy).depositAdmin(balance);
        }
    }

    function changeStrategy(address tokenAddress, address strategy) public onlyRole(DEFAULT_ADMIN_ROLE) {
        disableStrategy(tokenAddress);
        token[tokenAddress].strategy = strategy;
        enableStrategy(tokenAddress);
    }

    function depositToBank(address tokenAddress, uint amount) public {
        // This is a must
        require(hasRole(TOKENS, tokenAddress), "Disallowed token");
        // At first, transfer it to us
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        // Record it to history
        token[tokenAddress].balance += amount;

        // If strategy is set, then put it to work
        if(token[tokenAddress].strategy != address(0)) {
            uint _decimals = IERC(tokenAddress).decimals();
            uint balance = IERC20(tokenAddress).balanceOf(address(this));
            if(balance >= 10**(_decimals-2)) {
                IERC20(tokenAddress).approve(token[tokenAddress].strategy, balance);
                IStrategy(token[tokenAddress].strategy).depositAdmin(balance);
            }
        }
    }

    function enter(uint swjkAmount) public returns (address[] memory tokens, uint[] memory amounts, uint8[] memory decimals) {
        require(!disabled, "Withrawl only mode");
        require(!lock, "Distribution is going on");

        swjk.safeTransferFrom(msg.sender, address(this), swjkAmount);
                
        if(balanceOf(msg.sender) == 0) {
            _grantRole(LOCKERS, msg.sender);
            epochs[msg.sender] = epochIndex;
        }else{
            // Account is already registered, he has an epoch recorded
            // To keep math correct, we withdraw all of his rewards
            // This will also reset the lockup.
            _withdrawRewards(balanceOf(msg.sender));
        }

        swjkBalance += swjkAmount;
        swjkOverflow += swjkAmount;

        _mint(msg.sender, swjkAmount); // Mint 1:1 $SOY tokens with USDC
        timeleft[msg.sender] = block.timestamp;

        emit Deposit(swjkAmount);

        return (tokens, amounts, decimals);
    }

    function leave(uint lockAmount) public {
        // 30 epochs
        require((block.timestamp - timeleft[msg.sender]) > LOCK_TIME, "You cannot withdraw yet.");
        _leave(lockAmount);
    }

    function leaveAdmin(uint lockAmount) public onlyRole(CONTRACT_ROLE) {
        _leave(lockAmount);
    }
    
    function _leave(uint lockAmount) private onlyRole(LOCKERS) {
        require(!lock, "Distribution is going on");
        require(balanceOf(msg.sender) >= lockAmount, "Insufficient amount");
        
        _burn(msg.sender, lockAmount);
        swjkBalance -= lockAmount;
        if(epochIndex == epochs[msg.sender]) swjkOverflow -= lockAmount; // only useful in dev. mode

        _withdrawRewards(lockAmount);
        uint wjkAmount = wjk.balanceOf(address(this));
        statsBurntWJK += wjkAmount;
        wjk.burn(wjkAmount);

        if(balanceOf(msg.sender) == 0) _revokeRole(LOCKERS, msg.sender);

        swjk.safeTransfer(msg.sender, lockAmount);

        emit Withdraw(lockAmount);
    }

    // public function, accounts can withdraw rewards without withdrawing usdc
    function withdrawRewards() public {
        _withdrawRewards(balanceOf(msg.sender));
    }

    function _withdrawRewards(uint lockAmount) private {
        uint cEpoch = epochs[msg.sender] + 1;

        if(hasRole(LOCKERS, msg.sender) && cEpoch < epochIndex) {
            // Avoid reentrancy;
            epochs[msg.sender] = epochIndex; // Reset his epoch count

            uint stop = getRoleMemberCount(TOKENS);

            address tokenAddress;
            uint tokenAmount;
            uint8 tokenDecimals;
            for(uint y = 0; y < stop; y++) {
                tokenAddress = getRoleMember(TOKENS, y);
                tokenAmount = 0;
                tokenDecimals = IERC(tokenAddress).decimals();

                // Loop from the epoch he entered to the current epoch and collect all rewards
                for(uint x = cEpoch; x <= epochIndex; x++) 
                    if(swjkHistory[x] > 0 && token[tokenAddress].history[x] > 0) 
                        tokenAmount += (token[tokenAddress].history[x]*10**(18 - tokenDecimals + 18)) / ((swjkHistory[x]*10**(36 - tokenDecimals)) / lockAmount);

                if(tokenAmount > 0) {
                    if(token[tokenAddress].strategy != address(0)) 
                        IStrategy(token[tokenAddress].strategy).withdrawAdmin(tokenAmount);
                    require(token[tokenAddress].balance >= tokenAmount, "Not enough in the balance to send");
                    require(token[tokenAddress].record >= tokenAmount, "Not enough in the record decrease");
                    token[tokenAddress].balance -= tokenAmount;
                    token[tokenAddress].record -= tokenAmount;
                    IERC20(tokenAddress).safeTransfer(msg.sender, tokenAmount -2);
                }
            }
        }
    }

    // ------- Helpers -------

    function timeDifference(address _locker) public view returns (uint) {
        if(hasRole(LOCKERS, _locker)) return timeleft[_locker];
        else return 0;
    }
    
    function checkRewards(address _locker, address rewardToken) public view returns (uint) {
        uint cEpoch = epochs[_locker] + 1;
        uint amount = 0;

        if(hasRole(LOCKERS, _locker) && cEpoch < epochIndex) {
            uint8 decimals = IERC(rewardToken).decimals();
            uint lockAmount = balanceOf(_locker);

            // Loop from the epoch he entered to the current epoch and collect all rewards
            for(uint x = cEpoch; x <= epochIndex; x++) {
                if(swjkHistory[x] > 0 && token[rewardToken].history[x] > 0) {
                    amount += (token[rewardToken].history[x]*10**(18 - decimals + 18)) / ((swjkHistory[x]*10**(36 - decimals)) / lockAmount);
                    // To avoid USDC inaccuracy
                    if(amount > 10**decimals) amount -= 10**decimals;
                }
            }
        }

        return amount;
    }

    // ------- Routine -------

    function distributeRewards() public onlyRole(CONTRACT_ROLE) {
        lock = true;

        uint stop = getRoleMemberCount(TOKENS);
        for(uint x = 0; x < stop; x++) {
            address memberAddress = getRoleMember(TOKENS, x);
            token[memberAddress].history[epochIndex] = token[memberAddress].balance - token[memberAddress].record;
            token[memberAddress].record += token[memberAddress].history[epochIndex];
        }

        swjkHistory[epochIndex] = swjkBalance - swjkOverflow;
        swjkOverflow = 0;
        epochIndex++;

        lock = false;
    }

    // ------- Administration -------

    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        wjk = IERC(newAddress);
    }

    function setAddressStaking(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        swjk = IERC20(newAddress);
    }
    
    function triggerLocker() public onlyRole(DEFAULT_ADMIN_ROLE) {
        disabled = !disabled;
    }
}

interface IERC is IERC20 {
    function burn(uint) external;
    function decimals() external view returns (uint8);
}

interface IStrategy {
    function balanceOf(address account) external view returns (uint);
    function depositAdmin(uint amount) external;
    function withdrawAdmin(uint amount) external;
    // function withdrawUnderlying(uint amount) external;
}