// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

interface IRouter {
    function factory() external view returns (address);

    function WETH() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amtADesired,
        uint256 amtBDesired,
        uint256 amtAMin,
        uint256 amtBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amtA, uint256 amtB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquiditywpermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amtAMin,
        uint256 amtBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHwpermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTFT(
        uint256 amtIn,
        uint256 amtOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensFET(
        uint256 amtOut,
        uint256 amtInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHFT(
        uint256 amtOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensforEETH(
        uint256 amtOut,
        uint256 amtInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amtIn,
        uint256 amtOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHforET(
        uint256 amtOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amtA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amtB);

    function getAmountOut(
        uint256 amtIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amtOut);

    function getAmountIn(
        uint256 amtOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amtIn);

    function getAmountsOut(
        uint256 amtIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);

    function getAmountsIn(
        uint256 amtOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}
