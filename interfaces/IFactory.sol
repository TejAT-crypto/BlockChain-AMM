// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IFactory {
    function allPairs(address, address) external pure returns (address);
    function formPair(address, address) external returns (address); 
}