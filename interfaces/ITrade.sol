// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface ITrade {
    function swapCall(
        address sender,
        uint256 outAmt0,
        uint256 outAmt1,
        bytes calldata data
    ) external;
}