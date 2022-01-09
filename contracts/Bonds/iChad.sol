// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IChad is IERC20 {
    function bond(uint wjkAmount) external;
    function claimBond() external;
    function attemptRemoveMeAsBonder() external;
    function burnAllMyTokens() external;
    function isBonder(address _address) external view returns(bool, uint);
    function updateTokenPriceAtFarming() external;
    function updateTokenPriceAtSelfKeep() external;
    function updateTokenPriceAtStaking() external;
    function getWJKPrice() external view returns(uint);
}