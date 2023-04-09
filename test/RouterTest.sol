// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "@nomiclabs/hardhat-waffle";
import "hardhat-waffle/contracts/Test.sol";
import "../contracts/fact.sol";
import "../contracts/DExPair.sol";
import "../contracts/Router.sol";
import "../contracts/mintable_token.sol";

contract RouterTest is Test {
    Factory fact;
    Router router;

    ERC20token tkn0;
    ERC20token tkn1;
    ERC20token tkn2;

    function setUp() public {
        fact = new Factory();
        router = new Router(address(fact));

        tkn0 = new ERC20token("Token 0", "TKN0");
        tkn1 = new ERC20token("Token 1", "TKN1");
        tkn2 = new ERC20token("Token 2", "TKN2");

        tkn0.mint(20 ether, address(this));
        tkn1.mint(20 ether, address(this));
        tkn2.mint(20 ether, address(this));
    }

    function encodeError(string memory error)
        internal
        pure
        returns (bytes memory encoded)
    {
        encoded = abi.encodeWithSignature(error);
    }

    function addLiquidityCreatesPairTest() public {
        tkn0.approve(address(router), 1 ether);
        tkn1.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tkn0),
            address(tkn1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address pairAddress = fact.pairs(address(tkn0), address(tkn1));
        assertEq(pairAddress, 0x28D60B002aE759608479991e780DD542C929539D);
    }

    function addLiquidityNoPairTest() public {
        tkn0.approve(address(router), 1 ether);
        tkn1.approve(address(router), 1 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tkn0),
                address(tkn1),
                1 ether,
                1 ether,
                1 ether,
                1 ether,
                address(this)
            );

        assertEq(amountA, 1 ether);
        assertEq(amountB, 1 ether);
        assertEq(liquidity, 1 ether - 1000);

        address pairAddress = fact.pairs(address(tkn0), address(tkn1));

        assertEq(tkn0.balanceOf(pairAddress), 1 ether);
        assertEq(tkn1.balanceOf(pairAddress), 1 ether);

        DExPair pair = DExPair(pairAddress);

        assertEq(pair.token0(), address(tkn1));
        assertEq(pair.token1(), address(tkn0));
        assertEq(pair.totalSupply(), 1 ether);
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);

        assertEq(tkn0.balanceOf(address(this)), 19 ether);
        assertEq(tkn1.balanceOf(address(this)), 19 ether);
    }

    function addLiquidityAmountBOptimalIsOkTest() public {
        address pairAddress = fact.createPair(
            address(tkn0),
            address(tkn1)
        );

        DExPair pair = DExPair(pairAddress);

        assertEq(pair.token0(), address(tkn1));
        assertEq(pair.token1(), address(tkn0));

        tkn0.transfer(pairAddress, 1 ether);
        tkn1.transfer(pairAddress, 2 ether);
        pair.mint(address(this));

        tkn0.approve(address(router), 1 ether);
        tkn1.approve(address(router), 2 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tkn0),
                address(tkn1),
                1 ether,
                2 ether,
                1 ether,
                1.9 ether,
                address(this)
            );

        assertEq(amountA, 1 ether);
        assertEq(amountB, 2 ether);
        assertEq(liquidity, 1414213562373095048);
    }

    function addLiquidityAmountBOptimalIsTooLowTest() public {
        address pairAddress = fact.createPair(
            address(tkn0),
            address(tkn1)
        );

        DExPair pair = DExPair(pairAddress);
        assertEq(pair.token0(), address(tkn1));
        assertEq(pair.token1(), address(tkn0));

        tkn0.transfer(pairAddress, 5 ether);
        tkn1.transfer(pairAddress, 10 ether);
        pair.mint(address(this));

        tkn0.approve(address(router), 1 ether);
        tkn1.approve(address(router), 2 ether);

        vm.expectRevert(encodeError("InsufficientBAmount()"));
        router.addLiquidity(
            address(tkn0),
            address(tkn1),
            1 ether,
            2 ether,
            1 ether,
            2 ether,
            address(this)
        );
    }

    function addLiquidityAmountBOptimalTooHighAmountATooLowTest() public {
        address pairAddress = fact.createPair(
            address(tkn0),
            address(tkn1)
        );
        DExPair pair = DExPair(pairAddress);

        assertEq(pair.token0(), address(tkn1));
        assertEq(pair.token1(), address(tkn0));

        tkn0.transfer(pairAddress, 10 ether);
        tkn1.transfer(pairAddress, 5 ether);
        pair.mint(address(this));

        tkn0.approve(address(router), 2 ether);
        tkn1.approve(address(router), 1 ether);

        vm.expectRevert(encodeError("InsufficientAAmount()"));
        router.addLiquidity(
            address(tkn0),
            address(tkn1),
            2 ether,
            0.9 ether,
            2 ether,
            1 ether,
            address(this)
        );
    }

    function addLiquidityAmountBOptimalIsTooHighAmountAOkTest() public {
        address pairAddress = fact.createPair(
            address(tkn0),
            address(tkn1)
        );
        DExPair pair = DExPair(pairAddress);

        assertEq(pair.token0(), address(tkn1));
        assertEq(pair.token1(), address(tkn0));

        tkn0.transfer(pairAddress, 10 ether);
        tkn1.transfer(pairAddress, 5 ether);
        pair.mint(address(this));

        tkn0.approve(address(router), 2 ether);
        tkn1.approve(address(router), 1 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = router
            .addLiquidity(
                address(tkn0),
                address(tkn1),
                2 ether,
                0.9 ether,
                1.7 ether,
                1 ether,
                address(this)
            );
        assertEq(amountA, 1.8 ether);
        assertEq(amountB, 0.9 ether);
        assertEq(liquidity, 1272792206135785543);
    }

    function removeLiquidityTest() public {
        tkn0.approve(address(router), 1 ether);
        tkn1.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tkn0),
            address(tkn1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address pairAddress = fact.pairs(address(tkn0), address(tkn1));
        DExPair pair = DExPair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        pair.approve(address(router), liquidity);

        router.removeLiquidity(
            address(tkn0),
            address(tkn1),
            liquidity,
            1 ether - 1000,
            1 ether - 1000,
            address(this)
        );

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 1000);
        assertEq(reserve1, 1000);
        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.totalSupply(), 1000);
        assertEq(tkn0.balanceOf(address(this)), 20 ether - 1000);
        assertEq(tkn1.balanceOf(address(this)), 20 ether - 1000);
    }

    function removeLiquidityPartiallyTest() public {
        tkn0.approve(address(router), 1 ether);
        tkn1.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tkn0),
            address(tkn1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address pairAddress = fact.pairs(address(tkn0), address(tkn1));
        DExPair pair = DExPair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        liquidity = (liquidity * 3) / 10;
        pair.approve(address(router), liquidity);

        router.removeLiquidity(
            address(tkn0),
            address(tkn1),
            liquidity,
            0.3 ether - 300,
            0.3 ether - 300,
            address(this)
        );

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        assertEq(reserve0, 0.7 ether + 300);
        assertEq(reserve1, 0.7 ether + 300);
        assertEq(pair.balanceOf(address(this)), 0.7 ether - 700);
        assertEq(pair.totalSupply(), 0.7 ether + 300);
        assertEq(tkn0.balanceOf(address(this)), 20 ether - 0.7 ether - 300);
        assertEq(tkn1.balanceOf(address(this)), 20 ether - 0.7 ether - 300);
    }

    function removeLiquidityInsufficientAAmountTest() public {
        tkn0.approve(address(router), 1 ether);
        tkn1.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tkn0),
            address(tkn1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address pairAddress = fact.pairs(address(tkn0), address(tkn1));
        DExPair pair = DExPair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        pair.approve(address(router), liquidity);

        vm.expectRevert(encodeError("InsufficientAAmount()"));
        router.removeLiquidity(
            address(tkn0),
            address(tkn1),
            liquidity,
            1 ether,
            1 ether - 1000,
            address(this)
        );
    }

    function removeLiquidityInsufficientBAmountTest() public {
        tkn0.approve(address(router), 1 ether);
        tkn1.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tkn0),
            address(tkn1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address pairAddress = fact.pairs(address(tkn0), address(tkn1));
        DExPair pair = DExPair(pairAddress);
        uint256 liquidity = pair.balanceOf(address(this));

        pair.approve(address(router), liquidity);

        vm.expectRevert(encodeError("InsufficientBAmount()"));
        router.removeLiquidity(
            address(tkn0),
            address(tkn1),
            liquidity,
            1 ether - 1000,
            1 ether,
            address(this)
        );
    }

    function swapExactTokensForTokensTest() public {
        tkn0.approve(address(router), 1 ether);
        tkn1.approve(address(router), 2 ether);
        tkn2.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tkn0),
            address(tkn1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        router.addLiquidity(
            address(tkn1),
            address(tkn2),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address[] memory path = new address[](3);
        path[0] = address(tkn0);
        path[1] = address(tkn1);
        path[2] = address(tkn2);

        tkn0.approve(address(router), 0.3 ether);
        router.swapExactTokensForTokens(
            0.3 ether,
            0.1 ether,
            path,
            address(this)
        );

        // Swap 0.3 TKNA for ~0.186 TKNB
        assertEq(
            tkn0.balanceOf(address(this)),
            20 ether - 1 ether - 0.3 ether
        );
        assertEq(tkn1.balanceOf(address(this)), 20 ether - 2 ether);
        assertEq(
            tkn2.balanceOf(address(this)),
            20 ether - 1 ether + 0.186691414219734305 ether
        );
    }

    function swapTokensForExactTokensTest() public {
        tkn0.approve(address(router), 1 ether);
        tkn1.approve(address(router), 2 ether);
        tkn2.approve(address(router), 1 ether);

        router.addLiquidity(
            address(tkn0),
            address(tkn1),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        router.addLiquidity(
            address(tkn1),
            address(tkn2),
            1 ether,
            1 ether,
            1 ether,
            1 ether,
            address(this)
        );

        address[] memory path = new address[](3);
        path[0] = address(tkn0);
        path[1] = address(tkn1);
        path[2] = address(tkn2);

        tkn0.approve(address(router), 0.3 ether);
        router.swapTokensForExactTokens(
            0.186691414219734305 ether,
            0.3 ether,
            path,
            address(this)
        );

        // Swap 0.3 TKNA for ~0.186 TKNB
        assertEq(
            tkn0.balanceOf(address(this)),
            20 ether - 1 ether - 0.3 ether
        );
        assertEq(tkn1.balanceOf(address(this)), 20 ether - 2 ether);
        assertEq(
            tkn2.balanceOf(address(this)),
            20 ether - 1 ether + 0.186691414219734305 ether
        );
    }
}