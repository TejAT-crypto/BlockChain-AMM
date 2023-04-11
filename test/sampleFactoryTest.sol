// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/Factory.sol";
import "../contracts/DExPair.sol";

contract FactoryTest {
    Factory factory;
    IERC20 tokenA;
    IERC20 tokenB;
    address owner;

    function beforeEach() public {
        factory = new Factory();
        tokenA = IERC20(address(0x1));
        tokenB = IERC20(address(0x2));
        owner = msg.sender;
    }

    function test_createPair() public {
        address pair = factory.createPairs(address(tokenA), address(tokenB));
        DExPair dexPair = DExPair(pair);

        // Check pair addresses
        address pairA = factory.newPairs(address(tokenA), address(tokenB));
        address pairB = factory.newPairs(address(tokenB), address(tokenA));
        assert(pairA == pair && pairB == pair);

        // Check pair tokens
        assert(dexPair.token0() == address(tokenA));
        assert(dexPair.token1() == address(tokenB));

        // Check pair owner
        assert(dexPair.owner() == owner);
    }

    function test_createPair_sameAddresses() public {
        try factory.createPairs(address(tokenA), address(tokenA)) {
            assert(false, "Expected SameAddresses error");
        } catch Error(string memory reason) {
            assert(
                keccak256(abi.encodePacked(reason)) ==
                    keccak256(abi.encodePacked("SameAddresses()")),
                "Unexpected error message"
            );
        }
    }

    function test_createPair_zeroAddress() public {
        try factory.createPairs(address(tokenA), address(0)) {
            assert(false, "Expected ZeroAddress error");
        } catch Error(string memory reason) {
            assert(
                keccak256(abi.encodePacked(reason)) ==
                    keccak256(abi.encodePacked("ZeroAddress()")),
                "Unexpected error message"
            );
        }
    }

    function test_createPair_pairExists() public {
        factory.createPairs(address(tokenA), address(tokenB));

        try factory.createPairs(address(tokenA), address(tokenB)) {
            assert(false, "Expected PairExist error");
        } catch Error(string memory reason) {
            assert(
                keccak256(abi.encodePacked(reason)) ==
                    keccak256(abi.encodePacked("PairExist()")),
                "Unexpected error message"
            );
        }
    }
}
