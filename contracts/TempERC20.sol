// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../contracts/DexERC20.sol";

contract TempERC20 is DexERC20 {
    constructor(uint256 _totalSupply) {
        _mint(msg.sender, _totalSupply);
    }
}