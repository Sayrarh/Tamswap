// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

interface ITamswapCallee {
    function tamswapCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
