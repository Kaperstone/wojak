// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/access/AccessControl.sol";
import "./@openzeppelin/contracts/Pancakeswap.sol";
import "./@openzeppelin/contracts/utils/SafeERC20.sol";

contract Bonds is ERC20, AccessControl {
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    uint priceAtStaking = 0;
    uint priceAtLastBond = 0;
    uint priceAtLastBurn = 0;

    address[] internal bonders;

    IBEP20 public WBNB = IBEP20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IBEP20 internal BUSD = IBEP20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    IBEP20 internal wojakAddress = IBEP20(address(0));
    IBEP20 internal treasuryAddress = IBEP20(address(0));
    IUniswapV2Pair internal pairAddress = IUniswapV2Pair(address(0));
    IUniswapV2Pair internal bnbPairAddress = IUniswapV2Pair(address(0));

    uint bonded = 0;

    uint bondPrice = 0;

    mapping(address => uint) public timeleft;
    

    constructor() ERC20("Chad Bond", "CHADBOND") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TREASURY_ROLE, msg.sender);
    }

    // For treausry
    function BondBUSD(uint busdAmount) public {
        // Special pricing mechanism

        require((block.timestamp - timeleft[msg.sender]) > 86400, "You cannot bond yet.");

        (bool _isBonder, ) = isBonder(msg.sender);
        require(!_isBonder, "You already have an open bond, you can only bond once.");

        // Doesn't have a bond, create a bond
        uint busdPricePerWJK = bondPrice - (bondPrice / 5); // 20% discount
        uint wjkAmount = busdAmount / busdPricePerWJK;
        require((wojakAddress.balanceOf(address(this)) - wjkAmount) >= wjkAmount, "There are not enough WJK in the contract to give you");
        require(BUSD.transferFrom(msg.sender, address(treasuryAddress), busdAmount), "Not enough BUSD is held or is not enough allowance");

        timeleft[msg.sender] = block.timestamp;

        priceAtLastBond = getWJKPrice(1*10**18);
        updateBondPrice();

        addBonder(msg.sender);
        // Mint bWJK
        _mint(msg.sender, wjkAmount);
    }

    // For liquidity
    function bondWBNB(uint wbnbAmount) public {
        // Special pricing mechanism

        require((block.timestamp - timeleft[msg.sender]) > 86400, "You cannot bond yet.");

        (bool _isBonder, ) = isBonder(msg.sender);
        require(!_isBonder, "You already have an open bond, you can only bond once.");

       uint totalInBUSD = getBNBPrice(wbnbAmount);

        // Doesn't have a bond, create a bond
        uint busdPricePerWJK = bondPrice - (bondPrice / 10); // 10% discount
        uint wjkAmount = totalInBUSD / busdPricePerWJK;
        require((WBNB.balanceOf(address(this)) - wjkAmount) >= wjkAmount, "There are not enough WJK in the contract to give you");
        require(BUSD.transferFrom(msg.sender, address(treasuryAddress), wbnbAmount), "Not enough BUSD is held or is not enough allowance");

        timeleft[msg.sender] = block.timestamp;

        priceAtLastBond = getWJKPrice(1*10**18);
        updateBondPrice();

        addBonder(msg.sender);
        // Mint bWJK
        _mint(msg.sender, wjkAmount);
    }

    uint lastBondUpdate = block.timestamp;
    function updateBondPrice() public {
        require((lastBondUpdate - 21600) >= block.timestamp, "Once per 6h");
        bondPrice = (priceAtStaking + priceAtLastBond + priceAtLastBurn) / 3;
    }

    function claimBond() public {
        uint Bonded = balanceOf(msg.sender);
        require(Bonded > 0, "You don't hold any `Chad Bond` tokens");

        require((block.timestamp - timeleft[msg.sender]) > 86400, "You cannot unbond yet.");

        wojakAddress.transfer(msg.sender, Bonded);

        removeBonder(msg.sender);
        _burn(msg.sender, Bonded);
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

    function updateTokenPriceAtBurn() public onlyRole(TREASURY_ROLE) {
        priceAtLastBurn = getWJKPrice(1*10**18);
        updateBondPrice();
    }

    function updateTokenPriceAtStaking() public onlyRole(TREASURY_ROLE) {
        priceAtStaking = getWJKPrice(1*10**18);
        updateBondPrice();
    }

    function getWJKPrice(uint amount) public view returns(uint) {
        (uint Res0, uint Res1, ) = pairAddress.getReserves();

        return ((amount * Res1) / Res0); // return amount of BUSD needed to buy WJK
    }

    function getBNBPrice(uint amount) public view returns(uint) {
        (uint Res0, uint Res1, ) = bnbPairAddress.getReserves();

        return ((amount * Res1) / Res0); // return amount of BUSD needed to buy WJK
    }

    function setWojakAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        wojakAddress = IBEP20(newAddress);
    }

    function setTreasuryAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        treasuryAddress = IBEP20(newAddress);
    }

    function setPairAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        pairAddress = IUniswapV2Pair(newAddress);
    }

    function setBNBPairAddress(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        bnbPairAddress = IUniswapV2Pair(newAddress);
    }
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
