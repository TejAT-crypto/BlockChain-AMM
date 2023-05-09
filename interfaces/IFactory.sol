// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IFactory {
    event CreatedPair(
        address indexed token_A,
        address indexed token_B,
        address pair,
        uint256
    );

    function feesTo() external view returns (address);
    function feesToSetter() external view returns(address);

    function getPairs (address tokenA, address tokenB) external view returns(address pair); 

    function allPair(uint256) external view returns (address pair);
    function createPairs(address tokenA, address tokenB) external returns (address pair);
    function allPairLength() external view returns (uint256);

    function _setFeesTo(address) external;

    function _setFeesToSetter(address) external;
}