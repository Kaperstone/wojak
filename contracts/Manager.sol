// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Manager is AccessControlEnumerable {

    address public constant boo = 0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE;
    address public constant credit = 0x77128DFdD0ac859B33F44050c6fa272F34872B5E;
    address public constant scream = 0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475;
    address public constant tarot = 0xC5e2B037D30a390e62180970B3aa4E91868764cD;
    address public constant usdc = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address public constant bifi = 0xd6070ae98b8069de6B494332d1A1a81B6179D960;
    address public constant crv = 0x1E4F97b9f9F913c46F1632781732927B9019C68b;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    address public wojak = address(0);
    function setAddressToken(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { wojak = newAddress; }

    address public stake = address(0);
    function setAddressStaking(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { stake = newAddress; }

    address public bonds = address(0);
    function setAddressBonds(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { bonds = newAddress; }

    address public keeper = address(0);
    function setAddressKeeper(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { keeper = newAddress; }

    address public locker = address(0);
    function setAddressLocker(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { locker = newAddress; }

    address public treasury = address(0);
    function setAddressTreasury(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { treasury = newAddress; }

    address public zoomer = address(0);
    function setAddressZoomer(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { zoomer = newAddress; }

    address public boosoy = address(0);
    function setAddressBooSoy(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { boosoy = newAddress; }

    address public creditsoy = address(0);
    function setAddressCreditSoy(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { creditsoy = newAddress; }

    address public screamsoy = address(0);
    function setAddressScreamSoy(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { screamsoy = newAddress; }

    address public tarotsoy = address(0);
    function setAddressTarotSoy(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { tarotsoy = newAddress; }

    address public usdcsoy = address(0);
    function setAddressUsdcSoy(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { usdcsoy = newAddress; }

    address public bifisoy = address(0);
    function setAddressBifiSoy(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { bifisoy = newAddress; }

    address public crvsoy = address(0);
    function setAddressCrvSoy(address newAddress) public onlyRole(DEFAULT_ADMIN_ROLE) { crvsoy = newAddress; }


    // Lets shorthand all of this shit.

    bytes32 private constant CONTRACT_ROLE = keccak256("CONTRACT_ROLE");
    bytes32 private constant TARGETS = keccak256("TARGETS");
    bytes32 private constant TOKENS = keccak256("TOKENS");
    
    function updateKeeperContracts() public onlyRole(DEFAULT_ADMIN_ROLE) { 
        IERC(keeper).grantRole(TARGETS, stake);
        IERC(keeper).grantRole(TARGETS, zoomer);
        IERC(keeper).grantRole(TARGETS, locker);
        IERC(keeper).grantRole(TARGETS, boosoy);
        IERC(keeper).grantRole(TARGETS, creditsoy);
        IERC(keeper).grantRole(TARGETS, screamsoy);
        IERC(keeper).grantRole(TARGETS, tarotsoy);
        IERC(keeper).grantRole(TARGETS, usdcsoy);
        IERC(keeper).grantRole(TARGETS, bifisoy);
        IERC(keeper).grantRole(TARGETS, crvsoy);

        IERC(keeper).grantRole(TOKENS, boo);
        IERC(keeper).grantRole(TOKENS, credit);
        IERC(keeper).grantRole(TOKENS, scream);
        IERC(keeper).grantRole(TOKENS, tarot);
        IERC(keeper).grantRole(TOKENS, bifi);
        IERC(keeper).grantRole(TOKENS, crv);
    }

    function updateContract() public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC(wojak).grantRole(CONTRACT_ROLE, stake);
        IERC(wojak).grantRole(CONTRACT_ROLE, zoomer);

        // Stake
        IERC(stake).grantRole(CONTRACT_ROLE, keeper);
        IERC(zoomer).grantRole(CONTRACT_ROLE, keeper);
        IERC(bonds).grantRole(CONTRACT_ROLE, keeper);
        IERC(treasury).grantRole(CONTRACT_ROLE, keeper);
        IERC(locker).grantRole(CONTRACT_ROLE, keeper);

        // Soyfarms
        IERC(boosoy).grantRole(CONTRACT_ROLE, keeper);
        IERC(creditsoy).grantRole(CONTRACT_ROLE, keeper);
        IERC(screamsoy).grantRole(CONTRACT_ROLE, keeper);
        IERC(tarotsoy).grantRole(CONTRACT_ROLE, keeper);
        IERC(usdcsoy).grantRole(CONTRACT_ROLE, keeper);
        IERC(bifisoy).grantRole(CONTRACT_ROLE, keeper);
        IERC(crvsoy).grantRole(CONTRACT_ROLE, keeper);

        IERC(boosoy).grantRole(CONTRACT_ROLE, locker);
        IERC(creditsoy).grantRole(CONTRACT_ROLE, locker);
        IERC(screamsoy).grantRole(CONTRACT_ROLE, locker);
        IERC(tarotsoy).grantRole(CONTRACT_ROLE, locker);
        IERC(usdcsoy).grantRole(CONTRACT_ROLE, locker);
        IERC(bifisoy).grantRole(CONTRACT_ROLE, locker);
        IERC(crvsoy).grantRole(CONTRACT_ROLE, locker);

        IERC(boosoy).grantRole(CONTRACT_ROLE, treasury);
        IERC(creditsoy).grantRole(CONTRACT_ROLE, treasury);
        IERC(screamsoy).grantRole(CONTRACT_ROLE, treasury);
        IERC(tarotsoy).grantRole(CONTRACT_ROLE, treasury);
        IERC(usdcsoy).grantRole(CONTRACT_ROLE, treasury);
        IERC(bifisoy).grantRole(CONTRACT_ROLE, treasury);
        IERC(crvsoy).grantRole(CONTRACT_ROLE, treasury);

        IERC(zoomer).grantRole(CONTRACT_ROLE, boosoy);
        IERC(zoomer).grantRole(CONTRACT_ROLE, creditsoy);
        IERC(zoomer).grantRole(CONTRACT_ROLE, screamsoy);
        IERC(zoomer).grantRole(CONTRACT_ROLE, tarotsoy);
        IERC(zoomer).grantRole(CONTRACT_ROLE, usdcsoy);
        IERC(zoomer).grantRole(CONTRACT_ROLE, bifisoy);
        IERC(zoomer).grantRole(CONTRACT_ROLE, crvsoy);

        // An interesting one.
        IERC(keeper).grantRole(DEFAULT_ADMIN_ROLE, treasury);

        IBOOMER(stake).setAddressToken(wojak);
        IBOOMER(stake).setAddressBonds(bonds);
        IBOOMER(stake).setAddressKeeper(keeper);

        ICHAD(bonds).setAddressToken(wojak);
        ICHAD(bonds).setAddressStaking(stake);
        ICHAD(bonds).setAddressKeeper(keeper);

        IZOOMER(zoomer).setAddressToken(wojak);
        IZOOMER(zoomer).setAddressBonds(bonds);
        IZOOMER(zoomer).setAddressKeeper(keeper);

        IKEEPER(keeper).setAddressToken(wojak);
        IKEEPER(keeper).setAddressStaking(stake);
        IKEEPER(keeper).setAddressBonds(bonds);
        IKEEPER(keeper).setAddressTreasury(treasury);

        ILOCKER(locker).setAddressToken(wojak);
        ILOCKER(locker).setAddressStaking(stake);
        ILOCKER(locker).addStrategy(boo, boosoy);
        ILOCKER(locker).addStrategy(credit, creditsoy);
        ILOCKER(locker).addStrategy(scream, screamsoy);
        ILOCKER(locker).addStrategy(tarot, tarotsoy);
        ILOCKER(locker).addStrategy(usdc, usdcsoy);
        ILOCKER(locker).addStrategy(bifi, bifisoy);
        ILOCKER(locker).addStrategy(crv, crvsoy);


        ITREASURY(treasury).setAddressToken(wojak);
        ITREASURY(treasury).setAddressBonds(bonds);
        ITREASURY(treasury).setAddressKeeper(keeper);
        ITREASURY(treasury).addStrategy(boo, boosoy);
        ITREASURY(treasury).addStrategy(credit, creditsoy);
        ITREASURY(treasury).addStrategy(scream, screamsoy);
        ITREASURY(treasury).addStrategy(tarot, tarotsoy);
        ITREASURY(treasury).addStrategy(usdc, usdcsoy);
        ITREASURY(treasury).addStrategy(bifi, bifisoy);
        ITREASURY(treasury).addStrategy(crv, crvsoy);

        ISOY(boosoy).setAddressToken(wojak);
        ISOY(boosoy).setAddressStaking(zoomer);
        ISOY(boosoy).setAddressLocker(locker);
        ISOY(boosoy).setAddressKeeper(keeper);

        ISOY(creditsoy).setAddressToken(wojak);
        ISOY(creditsoy).setAddressStaking(zoomer);
        ISOY(creditsoy).setAddressLocker(locker);
        ISOY(creditsoy).setAddressKeeper(keeper);
        
        ISOY(screamsoy).setAddressToken(wojak);
        ISOY(screamsoy).setAddressStaking(zoomer);
        ISOY(screamsoy).setAddressLocker(locker);
        ISOY(screamsoy).setAddressKeeper(keeper);

        ISOY(tarotsoy).setAddressToken(wojak);
        ISOY(tarotsoy).setAddressStaking(zoomer);
        ISOY(tarotsoy).setAddressLocker(locker);
        ISOY(tarotsoy).setAddressKeeper(keeper);

        ISOY(usdcsoy).setAddressToken(wojak);
        ISOY(usdcsoy).setAddressStaking(zoomer);
        ISOY(usdcsoy).setAddressLocker(locker);
        ISOY(usdcsoy).setAddressKeeper(keeper);

        ISOY(bifisoy).setAddressToken(wojak);
        ISOY(bifisoy).setAddressStaking(zoomer);
        ISOY(bifisoy).setAddressLocker(locker);
        ISOY(bifisoy).setAddressKeeper(keeper);

        ISOY(crvsoy).setAddressToken(wojak);
        ISOY(crvsoy).setAddressStaking(zoomer);
        ISOY(crvsoy).setAddressLocker(locker);
        ISOY(crvsoy).setAddressKeeper(keeper);
    }
}

interface IERC is IERC20 {
    function grantRole(bytes32, address) external;
}

interface IBOOMER {
    function setAddressToken(address) external;
    function setAddressBonds(address) external;
    function setAddressKeeper(address) external;
}

interface ICHAD {
    function setAddressToken(address) external;
    function setAddressStaking(address) external;
    function setAddressKeeper(address) external;
}

interface IZOOMER {
    function setAddressToken(address) external;
    function setAddressBonds(address) external;
    function setAddressKeeper(address) external;
}

interface IKEEPER {
    function setAddressToken(address) external;
    function setAddressStaking(address) external;
    function setAddressBonds(address) external;
    function setAddressTreasury(address) external;
}

interface ILOCKER {
    function setAddressToken(address) external;
    function setAddressStaking(address) external;
    function addStrategy(address, address) external;
}

interface ITREASURY {
    function setAddressToken(address) external;
    function setAddressBonds(address) external;
    function setAddressKeeper(address) external;
    function addStrategy(address, address) external;
}

interface ISOY {
    function setAddressToken(address) external;
    function setAddressStaking(address) external;
    function setAddressLocker(address) external;
    function setAddressKeeper(address) external;
}