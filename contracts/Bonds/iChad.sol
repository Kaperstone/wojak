// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface Bunker {
    function BondBUSD(uint busdAmount) external;
    function bondWBNB(uint wbnbAmount) external;
    function updateBondPrice() external;
    function claimBond() external;
    function attemptRemoveMeAsBonder() external;
    function burnAllMyTokens() external;
    function isBonder(address _address) external;
    function updateTokenPriceAtBurn() external;
    function updateTokenPriceAtStaking() external;
    function getWJKPrice(uint amount) external;
    function getBNBPrice(uint amount) external;
    function setWojakAddress(address newAddress) external;
    function setTreasuryAddress(address newAddress) external;
    function setPairAddress(address newAddress) external;
    function setBNBPairAddress(address newAddress) external;
}