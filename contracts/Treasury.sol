// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "./IPancakeswap.sol";

contract Treasury is AccessControlEnumerable {
    using SafeERC20 for IERC20;
    using SafeERC20 for ITWojak;

    bytes32 private constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    bytes32 private constant TOKENS = keccak256("TOKENS");

    ITWojak public wjk = ITWojak(address(0));
    address public chad = address(0);
    IAccessControl public keeper = IAccessControl(address(0));

    address constant public USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant public WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    IUniswapV2Router02 public constant SWAP_ROUTER = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    struct SToken {
        address strategy;
        uint balance;
    }
    mapping(address => SToken) public token;
    
    uint public statsSentToChad = 0;
    uint public statsBurntWJK = 0;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }
    /*

        @dev: New strategy
        @note: left without a condition to check if enabled for easier development, not critical
        @caution: when used in production twice, it will leave the treasury cash in the unset strategy

    */
    function addStrategy(address tokenAddress, address strategy) public onlyRole(DEFAULT_ADMIN_ROLE)  {
        token[tokenAddress].strategy = strategy;
        token[tokenAddress].balance = IERC20(tokenAddress).balanceOf(address(this));
        grantRole(TOKENS, tokenAddress);
    }

    /*

        @dev: When we want to change, redeploy or emergenchy stop use of a strategy.
        @note: left public, so the developer can disable/enable for longer periods of time
        @reuse: There is a check that prevents reuse of this function

    */
    function disableStrategy(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(TOKENS, tokenAddress), "Farm not enabled");
        keeper.revokeRole(TOKENS, tokenAddress); // Stop buying new tokens
        revokeRole(TOKENS, tokenAddress);

        uint balance = ITStrategy(token[tokenAddress].strategy).balanceOf(address(this));
        if(token[tokenAddress].strategy != address(0) && balance > 0) {
            ITStrategy(token[tokenAddress].strategy).withdrawAdmin(balance);
            wjk.burn(wjk.balanceOf(address(this))); // Burn to decrease supply
        }
    }

    /*

        @dev: in case `disableStrategy` didn't withdraw all the money (illogical, but in case)

    */
    function forceWithdraw(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint balance = ITStrategy(token[tokenAddress].strategy).balanceOf(address(this));
        if(token[tokenAddress].strategy != address(0) && balance > 0) {
            ITStrategy(token[tokenAddress].strategy).withdrawAdmin(balance);
            wjk.burn(wjk.balanceOf(address(this))); // Burn to decrease supply
        }
    }

    /*

        @dev: When want to re-enable the strategy and put it work
        @note: left public, so the developer can disable/enable for longer periods of time
        @reuse: There is a check that prevents reuse of this function

    */
    function enableStrategy(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!hasRole(TOKENS, tokenAddress), "Farm is already enabled");
        keeper.grantRole(TOKENS, tokenAddress); // Make keeper start buying the token
        grantRole(TOKENS, tokenAddress);

        uint balance = IERC20(tokenAddress).balanceOf(address(this));
        uint _decimals = ITWojak(tokenAddress).decimals();

        token[tokenAddress].balance = balance;
        if(token[tokenAddress].strategy != address(0) && balance >= 10**(_decimals-2))
            IERC20(tokenAddress).approve(token[tokenAddress].strategy, balance);
            ITStrategy(token[tokenAddress].strategy).depositAdmin(balance);
    }

    /*

        @dev: Seemless strategy change

    */
    function changeStrategy(address tokenAddress, address strategy) public onlyRole(DEFAULT_ADMIN_ROLE) {
        disableStrategy(tokenAddress); // So we safely withdraw from the strategy
        token[tokenAddress].strategy = strategy;
        enableStrategy(tokenAddress); // Deposit to new strategy
    }

    /*

        @dev: This is where we receive the money from `keeper` and we put it to work

    */
    function deposit(address tokenAddress, uint amount, bool transfer) public {
        // token = token address
        // amount = token amount
        if(transfer) IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);

        if(hasRole(TOKENS, tokenAddress) && token[tokenAddress].strategy != address(0)) {
            uint _decimals = ITWojak(tokenAddress).decimals();
            uint balance = IERC20(tokenAddress).balanceOf(address(this));
            if(balance >= 10**(_decimals-2)) {
                IERC20(tokenAddress).approve(token[tokenAddress].strategy, balance);
                ITStrategy(token[tokenAddress].strategy).depositAdmin(balance);
                token[tokenAddress].balance += balance;
            }
        }else token[tokenAddress].balance = IERC20(tokenAddress).balanceOf(address(this));
    }

    /*

        @dev: the main function we all gathered here, this is the function that withdraws WJK on a daily basis
              and then either sends it to `bonds` or burns WJK from the supply.

    */
    function fillBonds() public onlyRole(CONTRACT_ROLE) {
        // Money is withdrawn on deposit
        for(uint x = 0; x < getRoleMemberCount(TOKENS); x++) {
            address memberAddress = getRoleMember(TOKENS, x);
            if(token[memberAddress].balance > 0)
                ITStrategy(token[memberAddress].strategy).withdrawRewards(address(this));
        }
        
        uint chadBalance = wjk.balanceOf(address(chad));
        // We fill only 10% of the `bonds` contract
        uint wjkSupply = (wjk.totalSupply() / 10);
        // If `bonds` contract has 10% of the supply
        if(chadBalance < wjkSupply) {
            // It doesn't
            uint wjkAmount = wjk.balanceOf(address(this));

            // Check how much we need to fill `bonds` contract
            if((wjkSupply - chadBalance) < wjkAmount) {
                wjk.safeTransfer(address(chad), (wjkSupply - chadBalance)); // Complete
                statsSentToChad += (wjkSupply - chadBalance);
            }else{
                wjk.safeTransfer(address(chad), wjkAmount); // Transfer all we got
                statsSentToChad += wjkAmount;
            }
        }

        // burn leftovers
        uint leftWJK = wjk.balanceOf(address(this));
        statsBurntWJK += leftWJK;
        wjk.burn(leftWJK);
    }

    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        wjk = ITWojak(newAddress);
    }

    function setAddressBonds(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        chad = newAddress;
    }

    function setAddressKeeper(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        keeper = IAccessControl(newAddress);
    }

    /*

        @dev: Will enter a new market and use all USDC
        @purpose: in case we abandoned or we entering a new DeFi platform

    */
    function enterMarket(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint usdcBalance = IERC20(USDC).balanceOf(address(this));
        require(usdcBalance > 1e6, "Insufficient USDC amount");

        // At all times, we hold stable coin namely `usdc` after we exit any market (if not used `exitAndBalanceMarkets`)
        // But most DeFi platforms pair with wftm
        uint wftmAmount = swap(USDC, WFTM, IERC20(USDC).balanceOf(address(this)), address(this));
        // Buy the max amount of the target token
        uint tokenAmount = swap(WFTM, tokenAddress, wftmAmount, address(this));
        // If there is a strategy existing for this token, it will put it to work
        deposit(tokenAddress, tokenAmount, false);
    }

    /*

        @dev: Shorthand exitMarket and instead of keeping the newly obtained tokens in the form of USDC
              it will balance the newly obtained WFTM to buy more of the other tokens we already own
        @purpose: if we abandoned the platform completely and we want to utilize better the newly obtained cash

    */
    function exitAndBalanceMarkets(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint usdcAmount = exitMarket(tokenAddress); // We are left with WFTM
        // How many tokens we want to distribute amongst
        uint totalTokens = getRoleMemberCount(TOKENS);

        uint wftmAmount = swap(USDC, WFTM, usdcAmount, address(this));
        uint share = wftmAmount / totalTokens;

        for(uint x = 0; x < totalTokens; x++) {
            address memberAddress = getRoleMember(TOKENS, x);
            // Buy token
            uint tokenAmount = swap(WFTM, memberAddress, share, address(this));
            // Put to work (if can)
            deposit(memberAddress, tokenAmount, false);
        }
    }

    /*

        @dev: This function will exit a DeFi market and exchange the tokens for USDC
        @purpose: In case the DeFi platform migrated contracts, platform closed, switch strategy or decided to exit the platform.

    */
    function exitMarket(address tokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) returns (uint) {
        // Disable strategy, we exited the 
        disableStrategy(tokenAddress);

        // We can proceed to actually exiting the market
        // We don't need to use `withdraw` because disableStrategy does just about this.
        uint wftmAmount = 0;
        if(tokenAddress != address(WFTM))
            wftmAmount = swap(tokenAddress, address(WFTM), IERC20(tokenAddress).balanceOf(address(this)), address(this));
        else
            wftmAmount = IERC20(WFTM).balanceOf(address(this));
        return swap(address(WFTM), address(USDC), wftmAmount, address(this));
    }

    function swap(address token0, address token1, uint amount, address to) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = token0;  
        path[1] = token1;

        IERC20(token0).approve(address(SWAP_ROUTER), amount);
        uint[] memory amounts = SWAP_ROUTER.swapExactTokensForTokens(amount, 0, path, to, block.timestamp);
        return amounts[amounts.length - 1];
    }
}

interface ITWojak is IERC20 {
    function burn(uint amount) external;
    function decimals() external returns (uint8);
}

interface ITStrategy {
    function balanceOf(address) external view returns (uint);
    function depositAdmin(uint) external;
    function withdrawAdmin(uint) external returns (uint);
    function withdrawRewards(address) external;
}