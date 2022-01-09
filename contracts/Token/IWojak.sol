// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../_lib/contracts/token/ERC20/IERC20.sol";

interface IWojak is IERC20 {
    function addExclusion(address excludeAddress) external;
    function removeExclusion(address excludeAddress) external;
    function setRouterAddress(address newAddress) external;
    function setTreasuryAddress(address newAddress) external;
}