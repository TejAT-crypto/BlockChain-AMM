// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IFactory {
    event CreatedPair(
        address indexed token_A,
        address indexed token_B,
        address pair,
        uint256
    );

    function createPairs(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairLength() external view returns (uint256);

    function feesTo() external view returns (address);

    function _setFeesTo(address) external;

    function _setFeesToSetter(address) external;
}
