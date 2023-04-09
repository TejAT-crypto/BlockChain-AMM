// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "@nomiclabs/hardhat-waffle";
import "hardhat-waffle/contracts/Test.sol";
import "../contracts/library.sol";
import "../contracts/factory.sol";
import "../contracts/DExPair.sol";
import "../contracts/mintable_token.sol";

contract LibraryTest is Test {
    Factory fact;

    ERC20token tkn0;
    ERC20token tkn1;
    ERC20token tkn2;
    ERC20token tkn3;

    DExPair pair;
    DExPair pair2;
    DExPair pair3;

    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

    function setUp() public {
        fact = new Factory();

        tkn0 = new ERC20token("Token 0", "TKN0");
        tkn1 = new ERC20token("Token 1", "TKN1");
        tkn2 = new ERC20token("Token 2", "TKN2");
        tkn3 = new ERC20token("Token 3", "TKN3");

        tkn0.mint(10 ether, address(this));
        tkn1.mint(10 ether, address(this));
        tkn2.mint(10 ether, address(this));
        tkn3.mint(10 ether, address(this));

        address pairAddress = fact.createPair(
            address(tkn0),
            address(tkn1)
        );
        pair = DExPair(pairAddress);

        pairAddress = fact.createPair(address(tkn1), address(tkn2));
        pair2 = DExPair(pairAddress);

        pairAddress = fact.createPair(address(tkn2), address(tkn3));
        pair3 = DExPair(pairAddress);
    }

    function getReservesTest() public {
        tkn0.transfer(address(pair), 1.1 ether);
        tkn1.transfer(address(pair), 0.8 ether);

        DExPair(address(pair)).mint(address(this));

        (uint256 reserve0, uint256 reserve1) = Library.getReserves(
            address(fact),
            address(tkn0),
            address(tkn1)
        );

        assertEq(reserve0, 1.1 ether);
        assertEq(reserve1, 0.8 ether);
    }

    function quoteTest() public {
        uint256 amountOut = Library.quote(1 ether, 1 ether, 1 ether);
        assertEq(amountOut, 1 ether);

        amountOut = Library.quote(1 ether, 2 ether, 1 ether);
        assertEq(amountOut, 0.5 ether);

        amountOut = Library.quote(1 ether, 1 ether, 2 ether);
        assertEq(amountOut, 2 ether);
    }

    function pairForTest() public {
        address pairAddress = Library.pairFor(
            address(fact),
            address(tkn0),
            address(tkn1)
        );

        assertEq(pairAddress, fact.pairs(address(tkn0), address(tkn1)));
    }

    function pairForTestTokensSorting() public {
        address pairAddress = Library.pairFor(
            address(fact),
            address(tkn1),
            address(tkn0)
        );

        assertEq(pairAddress, fact.pairs(address(tkn0), address(tkn1)));
    }

    function pairForNonexistentFactoryTest() public {
        address pairAddress = Library.pairFor(
            address(0xaabbcc),
            address(tkn1),
            address(tkn0)
        );

        assertEq(pairAddress, 0xeD35720306D07EC7Df3C7c76c47d7f8c19FC430F);
    }

    function getAmountOutTest() public {
        uint256 amountOut = Library.getAmountOut(
            1000,
            1 ether,
            1.5 ether
        );
        assertEq(amountOut, 1495);
    }

    function getAmountOutZeroInputAmountTest() public {
        vm.expectRevert(encodeError("InsufficientAmount()"));
        Library.getAmountOut(0, 1 ether, 1.5 ether);
    }

    function getAmountOutZeroInputReserveTest() public {
        vm.expectRevert(encodeError("InsufficientLiquidity()"));
        Library.getAmountOut(1000, 0, 1.5 ether);
    }

    function getAmountOutZeroOutputReserveTest() public {
        vm.expectRevert(encodeError("InsufficientLiquidity()"));
        Library.getAmountOut(1000, 1 ether, 0);
    }

    function getAmountsOutTest() public {
        tkn0.transfer(address(pair), 1 ether);
        tkn1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        tkn1.transfer(address(pair2), 1 ether);
        tkn2.transfer(address(pair2), 0.5 ether);
        pair2.mint(address(this));

        tkn2.transfer(address(pair3), 1 ether);
        tkn3.transfer(address(pair3), 2 ether);
        pair3.mint(address(this));

        address[] memory path = new address[](4);
        path[0] = address(tkn0);
        path[1] = address(tkn1);
        path[2] = address(tkn2);
        path[3] = address(tkn3);

        uint256[] memory amounts = Library.getAmountsOut(
            address(fact),
            0.1 ether,
            path
        );

        assertEq(amounts.length, 4);
        assertEq(amounts[0], 0.1 ether);
        assertEq(amounts[1], 0.181322178776029826 ether);
        assertEq(amounts[2], 0.076550452221167502 ether);
        assertEq(amounts[3], 0.141817942760565270 ether);
    }

    function getAmountsOutInvalidPathTest() public {
        address[] memory path = new address[](1);
        path[0] = address(tkn0);

        vm.expectRevert(encodeError("InvalidPath()"));
        Library.getAmountsOut(address(fact), 0.1 ether, path);
    }

    function getAmountInTest() public {
        uint256 amountIn = Library.getAmountIn(
            1495,
            1 ether,
            1.5 ether
        );
        assertEq(amountIn, 1000);
    }

    function getAmountInZeroInputAmountTest() public {
        vm.expectRevert(encodeError("InsufficientAmount()"));
        Library.getAmountIn(0, 1 ether, 1.5 ether);
    }

    function getAmountInZeroInputReserveTest() public {
        vm.expectRevert(encodeError("InsufficientLiquidity()"));
        Library.getAmountIn(1000, 0, 1.5 ether);
    }

    function getAmountInZeroOutputReserveTest() public {
        vm.expectRevert(encodeError("InsufficientLiquidity()"));
        Library.getAmountIn(1000, 1 ether, 0);
    }

    function getAmountsInTest() public {
        tkn0.transfer(address(pair), 1 ether);
        tkn1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        tkn1.transfer(address(pair2), 1 ether);
        tkn2.transfer(address(pair2), 0.5 ether);
        pair2.mint(address(this));

        tkn2.transfer(address(pair3), 1 ether);
        tkn3.transfer(address(pair3), 2 ether);
        pair3.mint(address(this));

        address[] memory path = new address[](4);
        path[0] = address(tkn0);
        path[1] = address(tkn1);
        path[2] = address(tkn2);
        path[3] = address(tkn3);

        uint256[] memory amounts = Library.getAmountsIn(
            address(fact),
            0.1 ether,
            path
        );

        assertEq(amounts.length, 4);
        assertEq(amounts[0], 0.063113405152841847 ether);
        assertEq(amounts[1], 0.118398043685444580 ether);
        assertEq(amounts[2], 0.052789948793749671 ether);
        assertEq(amounts[3], 0.100000000000000000 ether);
    }

    function getAmountsInInvalidPathTest() public {
        address[] memory path = new address[](1);
        path[0] = address(tkn0);

        vm.expectRevert(encodeError("InvalidPath()"));
        Library.getAmountsIn(address(fact), 0.1 ether, path);
    }
}