// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IKeeper {
    function adminCheckUp() external view returns (bool upkeepNeeded);

    function setAddressToken(address newAddress) external;
    function setAddressStaking(address newAddress) external;
    function setAddressChad(address newAddress) external;
    function setAddressTreasury(address newAddress) external;
    function setAddressSoyFarm(address newAddress) external;
}