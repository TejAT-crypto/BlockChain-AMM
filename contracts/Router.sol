// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../contracts/Factory.sol";
import "../interfaces/IDERC20.sol";
import "../library/Library.sol";
import "../interfaces/IRouter.sol";
import "../interfaces/IWETH.sol";

contract Router is IRouter {
    error RouterExpired(uint256 deadline, uint256 blockTimestamp);
    error ExcessiveInputAmount(uint256 amtIn, uint256 amtOutMin);
    error InsufficientAAmount(uint256 amtAopt, uint256 amtAmin);
    error InsufficientBAmount(uint256 amtBopt, uint256 amtBmin);
    error InsufficientOutputAmount(uint256 amtOut, uint256 amtOutMin);
    error RouterInvalidPath(address first, address WETH);

    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable WETH;

    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp)
            revert RouterExpired(deadline, block.timestamp);
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH);
    }

    function addLiquidityGen(
        address tokenA,
        address tokenB,
        uint256 amtAdesired,
        uint256 amtBdesired,
        uint256 amtAmin,
        uint256 amtBmin
    ) private returns (uint256 amtA, uint256 amtB) {
        if (Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            Factory(factory).createPairs(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = Library.getReserves(
            factory,
            tokenA,
            tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            (amtA, amtB) = (amtAdesired, amtBdesired);
        } else {
            uint256 amtBopt = Library.quote(amtAdesired, reserveA, reserveB);
            if (amtBopt <= amtBdesired) {
                if (amtBopt < amtBmin)
                    revert InsufficientBAmount(amtBopt, amtBmin);
                (amtA, amtB) = (amtAdesired, amtBopt);
            } else {
                uint256 amtAopt = Library.quote(
                    amtBdesired,
                    reserveB,
                    reserveA
                );
                assert(amtAopt <= amtAdesired);
                if (amtAopt < amtAmin)
                    revert InsufficientAAmount(amtAopt, amtAmin);
                (amtA, amtB) = (amtAopt, amtBdesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amtAdesired,
        uint256 amtBdesired,
        uint256 amtAmin,
        uint256 amtBmin,
        address to,
        uint256 deadline
    )
        external
        ensure(deadline)
        returns (uint256 amtA, uint256 amtB, uint256 liq)
    {
        (amtA, amtB) = addLiquidityGen(
            tokenA,
            tokenB,
            amtAdesired,
            amtBdesired,
            amtAmin,
            amtBmin
        );
        address pair = Library.pairFor(factory, tokenA, tokenB);
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amtA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amtB);
        liq = IPair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint256 amtTokendesired,
        uint256 amtTokenmin,
        uint256 amtETHmin,
        address to,
        uint256 deadline
    )
        external
        payable
        ensure(deadline)
        returns (uint256 amtToken, uint256 amtETH, uint256 liq)
    {
        (amtToken, amtETH) = addLiquidityGen(
            token,
            WETH,
            amtTokendesired,
            msg.value,
            amtTokenmin,
            amtETHmin
        );
        address pair = Library.pairFor(factory, token, WETH);
        IERC20(token).safeTransferFrom(msg.sender, pair, amtToken);
        IWETH(WETH).deposit{value: amtETH}();
        assert(IWETH(WETH).transfer(pair, amtETH));
        liq = IPair(pair).mint(to);
        if (msg.value > amtETH)
            Library.SafeTransferEth(msg.sender, msg.value - amtETH);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liq,
        uint256 amtAmin,
        uint256 amtBmin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amtA, uint256 amtB) {
        address pair = Library.pairFor(factory, tokenA, tokenB);
        IERC20(pair).transferFrom(msg.sender, pair, liq);
        (uint256 amt0, uint256 amt1) = IPair(pair).burn(to);
        (address token0, ) = Library.sortTokens(tokenA, tokenB);
        (amtA, amtB) = tokenA == token0 ? (amt0, amt1) : (amt1, amt0);

        if (amtA < amtAmin) revert InsufficientAAmount(amtA, amtAmin);

        if (amtB < amtBmin) revert InsufficientBAmount(amtB, amtBmin);
    }

    function removeLiquidityETH(
        address token,
        uint256 liq,
        uint256 amtTokenmin,
        uint256 amtETHmin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amtToken, uint256 amtETH) {
        (amtToken, amtETH) = removeLiquidity(
            token,
            WETH,
            liq,
            amtTokenmin,
            amtETHmin,
            address(this),
            deadline
        );
        IERC20(token).safeTransfer(to, amtToken);
        IWETH(WETH).withdraw(amtETH);
        Library.SafeTransferEth(to, amtETH);
    }

    function removeLiquiditywpermit(
        address tokenA,
        address tokenB,
        uint256 liq,
        uint256 amtAmin,
        uint256 amtBmin,
        address to,
        uint256 deadline,
        bool appMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amtA, uint256 amtB) {
        address pair = Library.pairFor(factory, tokenA, tokenB);
        uint256 value = appMax ? type(uint256).max : liq;
        IDERC20(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );

        (amtA, amtB) = removeLiquidity(
            tokenA,
            tokenB,
            liq,
            amtAmin,
            amtBmin,
            to,
            deadline
        );
    }

    function removeLiquidityETHwpermit(
        address token,
        uint256 liq,
        uint256 amtTokenmin,
        uint256 amtETHmin,
        address to,
        uint256 deadline,
        bool appMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amtToken, uint256 amtETH) {
        address pair = Library.pairFor(factory, token, WETH);
        uint256 value = appMax ? type(uint256).max : liq;
        IDERC20(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amtToken, amtETH) = removeLiquidityETH(
            token,
            liq,
            amtTokenmin,
            amtETHmin,
            to,
            deadline
        );
    }

    function swapGen(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) private {
        for (uint256 i; i < path.length - 1; i++) {
            (address inp, address out) = (path[i], path[i + 1]);
            (address token0, ) = Library.sortTokens(inp, out);
            uint256 amtOut = amounts[i + 1];
            (uint256 amt0Out, uint256 amt1Out) = inp == token0
                ? (uint256(0), amtOut)
                : (amtOut, uint256(0));
            address to = i < path.length - 2
                ? Library.pairFor(factory, out, path[i + 2])
                : _to;
            IPair(Library.pairFor(factory, inp, out)).swap(
                amt0Out,
                amt1Out,
                to,
                new bytes(0)
            );
        }
    }

    function swapExactTFT(
        uint256 amtIn,
        uint256 amtOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = Library.getAmountsOut(factory, amtIn, path);
        if (amounts[amounts.length - 1] < amtOutMin)
            revert InsufficientOutputAmount(
                amounts[amounts.length - 1],
                amtOutMin
            );
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        swapGen(amounts, path, to);
    }

    function swapTokensFET(
        uint256 amtOut,
        uint256 amtInmax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = Library.getAmountsIn(factory, amtOut, path);
        if (amounts[0] > amtInmax)
            revert ExcessiveInputAmount(amounts[0], amtInmax);
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        swapGen(amounts, path, to);
    }

    function swapExactETHFT(
        uint256 amtOutmin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        if (path[0] != WETH) revert RouterInvalidPath(path[0], WETH);
        amounts = Library.getAmountsOut(factory, msg.value, path);
        if (amounts[amounts.length - 1] < amtOutmin)
            revert InsufficientOutputAmount(
                amounts[amounts.length - 1],
                amtOutmin
            );

        IWETH(WETH).deposit{value: amounts[0]}();
        assert(
            IWETH(WETH).transfer(
                Library.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        swapGen(amounts, path, to);
    }

    function swapTokensforEETH(
        uint256 amtOut,
        uint256 amtInmax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        if (path[path.length - 1] != WETH)
            revert RouterInvalidPath(path[path.length - 1], WETH);
        amounts = Library.getAmountsIn(factory, amtOut, path);
        if (amounts[0] > amtInmax)
            revert ExcessiveInputAmount(amounts[0], amtInmax);
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        swapGen(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        Library.SafeTransferEth(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint256 amtIn,
        uint256 amtOutmin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        if (path[path.length - 1] != WETH)
            revert RouterInvalidPath(path[path.length - 1], WETH);
        amounts = Library.getAmountsOut(factory, amtIn, path);
        if (amounts[amounts.length - 1] < amtOutmin)
            revert InsufficientOutputAmount(
                amounts[amounts.length - 1],
                amtOutmin
            );

        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        swapGen(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        Library.SafeTransferEth(to, amounts[amounts.length - 1]);
    }

    function swapETHforET(
        uint256 amtOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        if (path[0] != WETH) revert RouterInvalidPath(path[0], WETH);
        amounts = Library.getAmountsIn(factory, amtOut, path);
        if (amounts[0] <= msg.value)
            revert ExcessiveInputAmount(amounts[0], msg.value);

        IWETH(WETH).deposit{value: amounts[0]}();
        assert(
            IWETH(WETH).transfer(
                Library.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        swapGen(amounts, path, to);
        if (msg.value > amounts[0])
            Library.SafeTransferEth(msg.sender, msg.value - amounts[0]);
    }

    function quote(
        uint256 amtA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure returns (uint256 amtB) {
        return Library.quote(amtA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amtIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amtOut) {
        return Library.getAmountOut(amtIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amtOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amtIn) {
        return Library.getAmountOut(amtOut, reserveIn, reserveOut);
    }

    function getAmountsOut(
        uint256 amtIn,
        address[] memory path
    ) public view returns (uint256[] memory amounts) {
        return Library.getAmountsOut(factory, amtIn, path);
    }

    function getAmountsIn(
        uint256 amtOut,
        address[] memory path
    ) public view returns (uint256[] memory amounts) {
        return Library.getAmountsIn(factory, amtOut, path);
    }
}
