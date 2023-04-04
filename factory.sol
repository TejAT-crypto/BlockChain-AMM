// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DExPair.sol";
// import "./IPair.sol";

contract Factory {
    error SameAddresses();
    error PairExist();
    error ZeroAddress();

    event CreatedPair(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    mapping(address => mapping(address => address)) public newPairs;
    address[] public allPair;

    function createPairs(address tokenA, address tokenB) public returns (address pair){
        if(tokenA == tokenB){
            revert SameAddresses();
        }
        address token0;
        address token1;
        if(tokenA < tokenB){
            token0 = tokenA;
            token1 = tokenB;
        }
        else{
            token0 = tokenB;
            token1 = tokenA;
        }
        if(token0 == address(0)){
            revert ZeroAddress();
        }
        if(newPairs[token0][token1] != address(0)){
            revert PairExist();
        }
        bytes memory ByteCode = type(DExPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly{
            pair := create2(0, add(ByteCode, 32), mload(ByteCode), salt)
        }
        IDExPair(pair).init(token0, token1);

        newPairs[token0][token1] = pair;
        newPairs[token1][token0] = pair;
        allPair.push(pair);

        emit CreatedPair(token0, token1, pair, allPair.length);
    }
}