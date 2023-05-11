// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DExPair.sol";
import "../interfaces/IPair.sol";

contract Factory {
    event CreatedPair(
        address indexed token_A,
        address indexed token_B,
        address pair,
        uint256
    );

    error SameAddresses();
    error PairExist();
    error ZeroAddress();
    error IsForbidden(address feesTo, address feesToSetter);

    address public feesTo;
    address public feesToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPair;

    constructor(address feeToSetter) {
        feesToSetter = feeToSetter;
    }

    function allPairLength() external view returns (uint256) {
        return allPair.length;
    }

    function createPairs(address tokenA, address tokenB)
        external
        returns (address pair)
    {
        if (tokenA == tokenB) revert SameAddresses();

        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        if (token0 == address(0)) revert ZeroAddress();

        if (getPair[token0][token1] != address(0)) revert PairExist();

        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        pair = address(new DExPair{salt: salt}());

        IPair(pair).init(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPair.push(pair);

        emit CreatedPair(token0, token1, pair, allPair.length);
    }

    function _setFeesTo(address _feesTo) external {
        if (msg.sender != feesToSetter) {
            revert IsForbidden(msg.sender, feesToSetter);
        }
        feesTo = _feesTo;
    }

    function _setFeesToSetter(address _feesToSetter) external {
        if (msg.sender != feesToSetter) {
            revert IsForbidden(msg.sender, feesToSetter);
        }
        feesToSetter = _feesToSetter;
    }

    // function getPair(
    //     address tokenA,
    //     address tokenB
    // ) public view returns (address) {
    //     return newPairs[tokenA][tokenB];
    // }
}
