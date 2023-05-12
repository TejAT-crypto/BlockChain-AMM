// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function fTo() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairLength() external view returns (uint256);

    function createPairs(address tokenA, address tokenB)
        external
        returns (address pair);

    function _setFeesTo(address) external;

    function _setFeesToSetter(address) external;
}