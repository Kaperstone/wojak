// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IPancakeswap.sol";

contract Chad is ERC20, AccessControlEnumerable {
    using SafeERC20 for IIERC20;
    using SafeERC20 for IStaking;

    event Bond(uint usdcIn, uint wjkMinted);
    event BondClaimed(uint stakedOut);

    bytes32 private constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    bytes32 private constant BONDERS = keccak256("BONDERS");
    
    IIERC20 public constant USDC = IIERC20(0x04068DA6C83AFCFA0e13ba15A6696662335D5B75);
    IUniswapV2Factory public constant SWAP_FACTORY = IUniswapV2Factory(0x152eE697f2E276fA89E96742e9bB9aB1F2E61bE3);

    IWojak public wjk = IWojak(address(0));
    IStaking public swjk = IStaking(address(0));
    address public keeper = address(0);

    mapping(uint => uint) private prices;
    
    uint public usdcCollected = 0;
    uint public bondPrice = 0;

    mapping(address => uint) private bondLock;

    uint public bonded = 0;

    constructor() ERC20("Chad Bond", "CHAD") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }

    // For treausry
    function bond(uint wjkAmount) public returns (uint) {
        require(wjkAmount > 10**16, "Bond too small"); // 0.01 wjk

        // Bonds bought, transfer the amount bought to the staking right away
        // So the amount of wjk we are left, is really what we are left with.
        require(wjk.balanceOf(address(this)) >= wjkAmount, "!availableBonds");

        // Doesn't have a bond, check if he have enough and attempt to transfer USDC to the smart contract
        uint totalForPayment = wjkAmount * (bondPrice - (bondPrice / 5)) / 10**(18 + 18 - USDC.decimals()); // 20% discount // In USDC
        USDC.safeTransferFrom(msg.sender, keeper, totalForPayment);

        bonded += wjkAmount;
        usdcCollected += totalForPayment;

        bondLock[msg.sender] = block.timestamp + 600; //345600;

        // Put into staking for him, it will automatically start accumulating interest
        wjk.approve(address(swjk), wjkAmount);
        uint staked = swjk.stake(wjkAmount);
        // Mint Chad 1:1 to his eligable swjk
        _mint(msg.sender, staked);

        _grantRole(BONDERS, msg.sender);

        emit Bond(totalForPayment, wjkAmount);
        IKeeper(keeper).distributeRewards();

        return totalForPayment;
    }

    function claimBond() public onlyRole(BONDERS) returns (uint) {
        uint bondSize = balanceOf(msg.sender);
        require(bondSize > 0, "Not enough bonds");

        require(block.timestamp > bondLock[msg.sender], "You cannot claim bond yet");

        _burn(msg.sender, bondSize);
        // Transfer him his boomers
        swjk.safeTransfer(msg.sender, bondSize);

        _revokeRole(BONDERS, msg.sender);

        emit BondClaimed(bondSize);
        IKeeper(keeper).distributeRewards();

        return bondSize;
    }

    function timeleft(address _bonder) public view returns (uint) {
        return bondLock[_bonder];
    }

    uint private x = 0; // No need to create a public function for this
    function updatePrice() public onlyRole(CONTRACT_ROLE) {
        // Record a trace of 5
        address pair = SWAP_FACTORY.getPair(address(wjk), address(USDC));
        (uint res0, uint res1, ) = IUniswapV2Pair(pair).getReserves();
        prices[x++] = res0*10**(36 - USDC.decimals()) / res1;

        uint sum = 0;
        for(uint y=0;y<5;y++) sum += prices[y];
        bondPrice = sum / 5; // Create an average price for the last 5 iterations
        // Every 5 iterations = reset
        if(x == 5) x = 0;
    }

    // Restrict transfers of the token
    function _beforeTokenTransfer(
        address from,
        address to,
        uint /* amount */
    ) internal virtual override {
        if(from != address(0) && to != address(0) && from != address(this) && to != address(this)) require(false, "!illegal");
    }

    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        wjk = IWojak(newAddress);
    }

    function setAddressStaking(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        swjk = IStaking(newAddress);
    }

    function setAddressKeeper(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        keeper = newAddress;
    }
}

interface IWojak is IERC20 {
    function mint(address, uint) external;
    function burn(uint) external;
}

interface IStaking is IERC20 {
    function stake(uint) external returns (uint);
}

interface IIERC20 is IERC20 {
    function decimals() external returns (uint);
}

interface IKeeper {
    function distributeRewards() external;
}