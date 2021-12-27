// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface iWojak {
    function mint(address to, uint amount) external;
    function burnEverything() external;

    function addExclusion(address excludeAddress) external;
    function removeExclusion(address excludeAddress) external;
    function setRouterAddress(address newAddress) external;
    function setTreasuryAddress(address newAddress) external;
}