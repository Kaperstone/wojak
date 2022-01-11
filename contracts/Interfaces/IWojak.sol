// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWojak is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(uint amount) external;
    function isExcluded(address _address) external view returns(bool, uint);
    function addExclusion(address excludeAddress) external;
    function removeExclusion(address excludeAddress) external;

    function setAddressKeeper(address newAddress) external;
}