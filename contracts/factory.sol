// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DExPair.sol";
import "../interfaces/IFactory.sol";

contract Factory is IFactory{
    error SameAddresses();
    error PairExist();
    error ZeroAddress();
    error IsForbidden(address feesTo, address feesToSetter);

    address public feesTo;
    address public feesToSetter;

    mapping(address => mapping(address => address)) public newPairs;
    address[] public allPair;

    constructor(address feeToSetter){
        feesToSetter = feeToSetter;
    }

    function allPairLength() external view returns (unint256){
        return allPair.length;
    }

    function createPairs(address tokenA, address tokenB) external returns (address pair){
        if(tokenA == tokenB){
            revert SameAddresses();
        }
        address token_A;
        address token_B;
        if(tokenA < tokenB){
            token_A = tokenA;
            token_B = tokenB;
        }
        else{
            token_A = tokenB;
            token_B = tokenA;
        }
        if(token_A == address(0)){
            revert ZeroAddress();
        }
        if(newPairs[token_A][token_B] != address(0)){
            revert PairExist();
        }
        //bytes memory ByteCode = type(DExPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token_A, token_B));
        // assembly{
        //     pair := create2(0, add(ByteCode, 32), mload(ByteCode), salt)
        // }

        pair = address(new DExPair{salt: salt}());

        IPair(pair).init(token_A, token_B);

        newPairs[token_A][token_B] = pair;
        newPairs[token_B][token_A] = pair;
        allPair.push(pair);

        emit CreatedPair(token_A, token_B, pair, allPair.length);
    }

    function _setFeesTo(address _feesTo) external {
        if(msg.sender != feesToSetter){
            revert IsForbidden(msg.sender, feesToSetter);
        }
        feesTo = _feesTo;
    }

    function _setFeesToSetter(address _feesToSetter) external {
        if(msg.sender != feesToSetter){
            revert IsForbidden(msg.sender, feesToSetter);
        }
        feesToSetter = _feesToSetter;
    }
}