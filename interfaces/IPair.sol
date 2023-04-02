// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPair {
    function init(address,address) external;

    function getRes() external returns (
        uint112,
        uint112,
        uint32
    );

    function mint(address) external returns (uint256);

    function burn(address) external returns (uint256,uint256);

    function transfer_from(address, address, uint256) external returns (bool);

    function swap(uint256, uint256, address, bytes calldata) external;
}