// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// This is the upkeep contract, it ensures that everything in every contract is running smoothly, including launching timers
// This contract is executed at least once per block (15sec)

import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IPancakeswap.sol";

contract Keeper is KeeperCompatibleInterface, AccessControlEnumerable {
    using SafeERC20 for IERC20;

    // Configuration
    // Testing: 120 seconds = 2 minutes
    uint private constant INTERVAL = 86400; // Every 24 hours (86400)
    uint private constant DIST_INTERVAL = 3600; // Every 1 hour (3600)

    uint public lastKeep = block.timestamp;
    uint public totalUpkeeps = 0;

    uint public constant _decimals = 6; // USDC decimals

    bytes32 private constant TARGETS = keccak256("TARGETS");
    bytes32 private constant TOKENS = keccak256("TOKENS");

    event SelfKeep();

    IERC public wjk = IERC(address(0));
    address public swjk = address(0);
    IChad public chad = IChad(address(0));
    ITreasury public treasury = ITreasury(address(0));

    IERC20 public constant USDC = IERC20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
    IERC20 public constant WFTM = IERC20(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    IUniswapV2Router02 public constant SWAP_ROUTER = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);

    uint public forLiquidity = 0;
    mapping(address => uint) public forTokens;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = (block.timestamp - lastKeep) > INTERVAL && !lock;
    }
    
    uint private blockNum = 0;
    bool private lock = false;
    uint private distsLeft = 0;
    function performUpkeep(bytes calldata /* performData */) external override {
        // Until this (single) transaction is not completed, lock the entire function.
        require(blockNum != block.number, "!block.number");
        blockNum = block.number;
        require(!lock,"locked");
        lock = true;
        require((block.timestamp - lastKeep) > INTERVAL, "!time");
        lastKeep = block.timestamp;

        _distributeRewards();

        // Push price update
        chad.updatePrice();

        if((dists - distsLeft) > 6) {
            // Reset the count
            distsLeft = dists;

            // Self keep to fill the treasury
            uint usdc = USDC.balanceOf(address(this));
            if(usdc > (100 * 10**_decimals)) {
                // cut the USDC left in half
                uint halfUSDC = usdc / 2;
                // 1 half for Liquidity
                swapAndLiquify(halfUSDC);

                // Because we are buying WJK off the market, the price goes down.
                // and then when we supply the tokens to the liquidity pool
                // we need to supply less wjk for the same amount of usdc
                // thus, we are left with more WJK
                wjk.burn(wjk.balanceOf(address(this))); // So we burn the leftovers
                // We can predict how much USDC we are left with, but its a lot 
                // better to just call balnaceOf() instead
                // Because we will need to fetch the old and & new price, which
                // is expensive

                // Most tokens pair with WFTM, thus we need to swap our tokens with WFTM
                uint wftm = swap(address(USDC), address(WFTM), USDC.balanceOf(address(this)), address(this));

                // Now we swap WFTM with the tokens we want to invest in
                uint numOfTokens = getRoleMemberCount(TOKENS);
                uint share = wftm / numOfTokens - 1;
                address token;
                for(uint x = 0; x < numOfTokens; x++) {
                    token = getRoleMember(TOKENS, x);
                    uint tBalance = swap(address(WFTM), token, share, address(this));
                    IERC20(token).approve(address(treasury), tBalance);
                    /*

                        The issue with Soyfarms is that when you deposit, you reset your epoch time
                        and as a result you are missing on your first reward, you cannot get your
                        reward if you keep depositing and reseting your epoch
                        and soyfarms are designed that way, to not receive rewards on your first epoch
                        after deposit.

                    */
                    treasury.deposit(token, tBalance, true);
                }
            }
        }

        // Withdraw rewards from Soyfarms
        treasury.fillBonds();

        totalUpkeeps++;

        emit SelfKeep();

        lock = false;
    }

    uint public dists = 0;
    uint public lastDist = block.timestamp;
    uint private blockNum2 = block.number;
    function distributeRewards() public {
        // Can be executed once per 1 hour (3600)
        if(blockNum2 != block.number && (block.timestamp - lastDist) > DIST_INTERVAL) {
            lastDist = block.timestamp;
            blockNum2 = block.number;
            dists++;

            _distributeRewards();
        }
    }

    function _distributeRewards() private {
        // Launch keeps
        uint stop = getRoleMemberCount(TARGETS);
        for (uint x = 0; x < stop; x++) {
            IDistribute(getRoleMember(TARGETS, x)).distributeRewards();
        }
    }

    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        wjk = IERC(newAddress);
    }
    
    function setAddressStaking(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        swjk = newAddress;
    }

    function setAddressBonds(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        chad = IChad(newAddress);
    }

    function setAddressTreasury(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = ITreasury(newAddress);
    }

    function swapAndLiquify(uint usdcAmount) private {
        // Solidity is not accurate, because it uses whole numbers instead of fractions
        // So if we get a fraction it will eliminate the dot and we won't get precise amount
        // Its better to give up on the last number than deal with a failed tx
        uint half = usdcAmount / 2 - 1; 
        uint wjkAmount = swap(address(USDC), address(wjk), half, address(this)); 
        addLiquidity(half, wjkAmount);
    }

    function swap(address token0, address token1, uint amount, address to) private returns (uint) {
        address[] memory path = new address[](2);
        path[0] = token0;  
        path[1] = token1;

        IERC20(token0).approve(address(SWAP_ROUTER), amount);
        uint[] memory amounts = SWAP_ROUTER.swapExactTokensForTokens(amount, 0, path, to, block.timestamp);
        return amounts[amounts.length - 1];
    }

    function addLiquidity(uint usdcAmount, uint wjkAmount) private {
        USDC.approve(address(SWAP_ROUTER), usdcAmount);
        wjk.approve(address(SWAP_ROUTER), wjkAmount);

        SWAP_ROUTER.addLiquidity(
            address(wjk), address(USDC),
            wjkAmount, usdcAmount,
            0,0, 
            address(this),
            block.timestamp);
    }
}

interface IERC is IERC20 {
    function burn(uint) external;
}

interface IChad {
    function updatePrice() external;
}

interface ITreasury {
    function fillBonds() external;
    function deposit(address, uint, bool) external;
}

interface IDistribute {
    function distributeRewards() external;
}

interface IStakeLocker {
    function depositUSDC(uint) external;
}