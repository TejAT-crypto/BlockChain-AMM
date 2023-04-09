// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "@nomiclabs/hardhat-waffle";
import "hardhat-waffle/contracts/Test.sol";
import "../contracts/factory.sol";
import "../contracts/DExPair.sol";
import "../contracts/mintable_token.sol";

contract FactoryTest is Test {
    Factory fact;

    ERC20token tkn0;
    ERC20token tkn1;
    ERC20token tkn2;
    ERC20token tkn3;

    function SetUp() public {
        fact = new Factory;
        tkn0 = new ERC20token("Token 0", "TKN0");
        tkn1 = new ERC20token("Token 1", "TKN1");
        tkn2 = new ERC20token("Token 2", "TKN2");
        tkn3 = new ERC20token("Token 3", "TKN3");
    }

    function errorEncode(string memory err) internal pure returns (bytes memory encoded){
        encoded = abi.encodeWithSignature(err);
    }

    function createPairTest() public{
        address pairAddr = fact.createPairs(address(tkn0),address(tkn1));
        DExPair pair = DExPair(pairAddr);
        // assertEq(pair.token0(), address(tkn0));
        // assertEq(pair.token1(), address(tkn1));
    }

    // function testZeroAddress() public {
    //     vm.expectRevert(encodeError("ZeroAddress()"));
    //     fact.createPairs(address(0), address(tkn0));

    //     vm.expectRevert(encodeError("ZeroAddress()"));
    //     fact.createPairs(address(tkn1), address(0));
    // }

    // function testPairExists() public {
    //     fact.createPairs(address(tkn1), address(tkn0));

    //     vm.expectRevert(encodeError("PairExist()"));
    //     fact.createPairs(address(tkn1), address(tkn0));
    // }

    // function testIdenticalTokens() public {
    //     vm.expectRevert(encodeError("SameAddresses()"));
    //     fact.createPairs(address(tkn0), address(tkn0));
    // }
}
