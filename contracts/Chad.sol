// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./Interfaces/IChad.sol";
import "./Interfaces/IPancakeswap.sol";

contract Chad is ERC20, AccessControl {
    using SafeERC20 for IERC20;

    event Bond(uint busdIn, uint wjkMinted);
    event BondClaimed(uint stakedOut);

    bytes32 public constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    
    IERC20 public constant BUSD = IERC20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7);
    IUniswapV2Factory public constant pancakeswapFactory = IUniswapV2Factory(0xB7926C0430Afb07AA7DEfDE6DA862aE0Bde767bc);
    // IERC20 public constant BUSD = IERC20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7);    
    // IUniswapV2Pair public constant pancakeswapFactory = IUniswapV2Pair(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);

    IWojak public WJK = IWojak(address(0));
    address public keeper = address(0);
    IStaking public sWJK = IStaking(address(0));

    uint internal priceAtStaking = 0;
    uint internal priceAtBonding = 0;
    uint internal priceAtSelfKeeping = 0;
    uint internal priceAtFarming = 0;
    
    uint public busdBonded = 0;
    uint public bondPrice = 0;

    uint public availToMint = 0;

    address[] internal bonders;
    mapping(address => uint) public timeleft;

    constructor() ERC20("Chad Bond", "CHAD") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTRACT_ROLE, msg.sender);
    }

    // For treausry
    function bond(uint wjkAmount) public {
        (bool _isBonder, ) = isBonder(msg.sender);
        require(!_isBonder, "!alreadyopen");

        require(availToMint > availToMint, "!availableBonds");

        require(WJK.balanceOf(address(this)) >= wjkAmount, "Not enough WJK in contract");

        // Doesn't have a bond, check if he have enough and attempt to transfer BUSD to the smart contract
        uint totalForPayment = wjkAmount * (bondPrice - (bondPrice / 5)); // 20% discount // In BUSD

        require(BUSD.balanceOf(msg.sender) >= totalForPayment, "Insufficient BUSD");
        BUSD.safeTransferFrom(msg.sender, keeper, totalForPayment);

        busdBonded += totalForPayment;

        timeleft[msg.sender] = block.timestamp + 345600;
        addBonder(msg.sender);

        updateBondPrice();

        // Mint Chad
        _mint(msg.sender, wjkAmount);
        availToMint -= wjkAmount;
        // Mint equivalent WJK to this contract
        WJK.mint(address(this), wjkAmount);
        // Put into staking for him, it will automatically start accumulating interest
        sWJK.stake(wjkAmount);

        emit Bond(totalForPayment, wjkAmount);
    }

    function claimBond() public {
        uint bonded = balanceOf(msg.sender);
        require(bonded > 0, "Not enough bonds");

        require(block.timestamp > timeleft[msg.sender], "You cannot unbond yet.");

        _burn(msg.sender, bonded);
        removeBonder(msg.sender);

        sWJK.transfer(msg.sender, bonded);

        emit BondClaimed(bonded);
    }

    function attemptRemoveMeAsBonder() public {
        if(balanceOf(msg.sender) == 0) removeBonder(msg.sender);
    }

    function burnAllMyTokens() public {
        _burn(msg.sender, balanceOf(msg.sender));
    }

    function isBonder(address _address) public view returns(bool, uint) {
        for (uint x = 0; x < bonders.length; x++){
            if (_address == bonders[x]) return (true, x);
        }
        return (false, 0);
    }

    function addBonder(address _bonder) internal {
        (bool _isBonder, ) = isBonder(_bonder);
        if(!_isBonder) bonders.push(_bonder);
    }

    function removeBonder(address _bonder) internal {
        (bool _isBonder, uint x) = isBonder(_bonder);
        if(_isBonder) {
            bonders[x] = bonders[bonders.length - 1];
            bonders.pop();
        } 
    }

    uint internal lastBondUpdate = block.timestamp;
    function updateBondPrice() internal {
        if(block.timestamp > lastBondUpdate) {
            priceAtBonding = getWJKPrice();
            // Average price
            bondPrice = (priceAtStaking + priceAtBonding + priceAtSelfKeeping + priceAtFarming) / 4;

            lastBondUpdate = block.timestamp + 21600;
        }
    }

    function increaseAvailable() public onlyRole(CONTRACT_ROLE) {
        availToMint += sWJK.lastMinted() / 10; // 10% off the last mint
    }

    function updateTokenPriceAtFarming() public onlyRole(CONTRACT_ROLE) {
        priceAtFarming = getWJKPrice();
        bondPrice = (priceAtStaking + priceAtBonding + priceAtSelfKeeping + priceAtFarming) / 4;
    }

    function updateTokenPriceAtSelfKeep() public onlyRole(CONTRACT_ROLE) {
        priceAtSelfKeeping = getWJKPrice();
        bondPrice = (priceAtStaking + priceAtBonding + priceAtSelfKeeping + priceAtFarming) / 4;
    }

    function updateTokenPriceAtStaking() public onlyRole(CONTRACT_ROLE) {
        priceAtStaking = getWJKPrice();
        bondPrice = (priceAtStaking + priceAtBonding + priceAtSelfKeeping + priceAtFarming) / 4;
    }

    function getWJKPrice() public view returns(uint) {
        address pair = pancakeswapFactory.getPair(address(WJK), address(BUSD));
        (uint res0, uint res1, ) = IUniswapV2Pair(pair).getReserves();

        return 1 * res1 / res0; // return amount of BUSD needed to buy WJK
    }

    function _beforeTokenTransfer(
        address /* from */,
        address /* to */,
        uint256 /* amount */
    ) internal virtual override {
        require(false, "!illegal");
    }

    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        WJK = IWojak(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressKeeper(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        keeper = newAddress;
        grantRole(CONTRACT_ROLE, newAddress);
    }

    function setAddressStaking(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        sWJK = IStaking(newAddress);
        grantRole(CONTRACT_ROLE, newAddress);
    }
}

interface IWojak is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint amount) external;
}

interface IStaking is IERC20 {
    function stake(uint wjkAmount) external returns (uint256);
    function lastMinted() external view returns(uint256);
}