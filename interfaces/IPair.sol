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

    function getreserves()
        external
        view
        returns (uint112 reserveA, uint112 reserveB, uint32 blockTime);

    function mint(address) external returns (uint256);

    function burn(address) external returns (uint256 amountA, uint256 amountB);

    function swap(
        uint256 amountA,
        uint256 amountB,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function init(address, address) external;
}
