// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../_lib/contracts/token/ERC20/ERC20.sol";
import "../_lib/contracts/utils/SafeERC20.sol";

import "../_lib/Common.sol";

abstract contract Bonds is Common, ERC20 {
    using SafeERC20 for IERC20;

    uint priceAtStaking = 0;
    uint priceAtBonding = 0;
    uint priceAtSelfKeeping = 0;
    uint priceAtFarming = 0;
    
    uint bonded = 0;
    uint bondPrice = 0;

    address[] internal bonders;
    mapping(address => uint) public timeleft;

    constructor(bool testnet) ERC20("Chad Bond", "CHAD") Common(testnet) {}

    // For treausry
    function Bond(uint wjkAmount) public {
        (bool _isBonder, ) = isBonder(msg.sender);
        require(!_isBonder, "You already have an open bond, you can only bond once.");

        require(WJK.balanceOf(address(this)) >= wjkAmount, "There are not enough WJK in the contract to give you");

        // Doesn't have a bond, check if he have enough and attempt to transfer BUSD to the smart contract
        uint totalForPayment = wjkAmount * (bondPrice - (bondPrice / 5)); // 20% discount // In BUSD
        
        require(BUSD.balanceOf(msg.sender) >= totalForPayment, "Insufficient BUSD");
        BUSD.safeTransferFrom(msg.sender, address(keeper), totalForPayment);

        timeleft[msg.sender] = block.timestamp;
        addBonder(msg.sender);

        updateBondPrice();

        // Mint Chad
        _mint(msg.sender, wjkAmount);
        // Mint equivalent WJK to this contract
        WJK.mint(address(this), wjkAmount);
        // Put into staking for him, it will automatically start accumulating interest
        staking.Stake(wjkAmount);
    }

    function claimBond() public {
        uint Bonded = balanceOf(msg.sender);
        require(Bonded > 0, "You don't hold any `Chad Bond` tokens");

        require((block.timestamp - timeleft[msg.sender]) >= 86400, "You cannot unbond yet.");

        _burn(msg.sender, Bonded);
        removeBonder(msg.sender);

        sWJK.safeTransfer(msg.sender, Bonded);
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

    uint lastBondUpdate = block.timestamp;
    function updateBondPrice() internal {
        if((lastBondUpdate + 21600) <= block.timestamp) {
            priceAtBonding = getWJKPrice();
            // Average price
            bondPrice = (priceAtStaking + priceAtBonding + priceAtSelfKeeping + priceAtFarming) / 4;

            lastBondUpdate = block.timestamp;
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
        (uint Res0, uint Res1, ) = pairAddress.getReserves();

        return 1 * Res1 / Res0; // return amount of BUSD needed to buy WJK
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 brutto
    ) internal virtual override {
        require(false, "!illegal");
    }
}
