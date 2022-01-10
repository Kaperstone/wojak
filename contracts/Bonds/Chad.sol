// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../Common.sol";

abstract contract Bonds is Common, ERC20 {
    using SafeERC20 for IERC20;

    event Bond(uint busdIn, uint wjkMinted);
    event BondClaimed(uint stakedOut);

    uint internal priceAtStaking = 0;
    uint internal priceAtBonding = 0;
    uint internal priceAtSelfKeeping = 0;
    uint internal priceAtFarming = 0;
    
    uint public busdBonded = 0;
    uint public bondPrice = 0;

    address[] internal bonders;
    mapping(address => uint) public timeleft;

    constructor() ERC20("Chad Bond", "CHAD") Common() {}

    // For treausry
    function bond(uint wjkAmount) public {
        (bool _isBonder, ) = isBonder(msg.sender);
        require(!_isBonder, "!alreadyopen");

        require(WJK.balanceOf(address(this)) >= wjkAmount, "Not enough WJK in contract");

        // Doesn't have a bond, check if he have enough and attempt to transfer BUSD to the smart contract
        uint totalForPayment = wjkAmount * (bondPrice - (bondPrice / 5)); // 20% discount // In BUSD

        require(BUSD.balanceOf(msg.sender) >= totalForPayment, "Insufficient BUSD");
        BUSD.safeTransferFrom(msg.sender, address(keeper), totalForPayment);

        busdBonded += totalForPayment;

        timeleft[msg.sender] = block.timestamp + 345600;
        addBonder(msg.sender);

        updateBondPrice();

        // Mint Chad
        _mint(msg.sender, wjkAmount);
        // Mint equivalent WJK to this contract
        wojak.mint(address(this), wjkAmount);
        // Put into staking for him, it will automatically start accumulating interest
        staking.stake(wjkAmount);

        emit Bond(totalForPayment, wjkAmount);
    }

    function claimBond() public {
        uint bonded = balanceOf(msg.sender);
        require(bonded > 0, "Not enough bonds");

        require(block.timestamp > timeleft[msg.sender], "You cannot unbond yet.");

        _burn(msg.sender, bonded);
        removeBonder(msg.sender);

        sWJK.safeTransfer(msg.sender, bonded);

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

    function updateTokenPriceAtFarming() public onlyRole(KEEPER_ROLE) {
        priceAtFarming = getWJKPrice();
        bondPrice = (priceAtStaking + priceAtBonding + priceAtSelfKeeping + priceAtFarming) / 4;
    }

    function updateTokenPriceAtSelfKeep() public onlyRole(KEEPER_ROLE) {
        priceAtSelfKeeping = getWJKPrice();
        bondPrice = (priceAtStaking + priceAtBonding + priceAtSelfKeeping + priceAtFarming) / 4;
    }

    function updateTokenPriceAtStaking() public onlyRole(KEEPER_ROLE) {
        priceAtStaking = getWJKPrice();
        bondPrice = (priceAtStaking + priceAtBonding + priceAtSelfKeeping + priceAtFarming) / 4;
    }

    function getWJKPrice() public view returns(uint) {
        (uint res0, uint res1, ) = pairAddress.getReserves();

        return 1 * res1 / res0; // return amount of BUSD needed to buy WJK
    }

    function _beforeTokenTransfer(
        address /* from */,
        address /* to */,
        uint256 /* amount */
    ) internal virtual override {
        require(false, "!illegal");
    }
}
