// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPair {
    event Mint(address indexed sender, uint256 amountA, uint256 amountB);
    event Burn(
        address indexed sender,
        uint256 amountA,
        uint256 amountB,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 A_in,
        uint256 B_in,
        uint256 amountA,
        uint256 amountB,
        address indexed to
    );
    event Sync(uint256 reserveA, uint256 reserveB);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function tokenA() external view returns (address);

    function tokenB() external view returns (address);

    function init(address, address) external;

    function showReserve()
        external
        view
        returns (uint112 reserveA, uint112 reserveB, uint32 blockTime);

    function LastPrice_A() external view returns (uint256);

    function LastPrice_B() external view returns (uint256);

    function prod() external view returns (uint256 liquidity);

    function mint(address) external returns (uint256);

    function burn(address) external returns (uint256 amountA, uint256 amountB);

    function transferFrom(address, address, uint256) external returns (bool);

    function swap(
        uint256 amountA,
        uint256 amountB,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}
