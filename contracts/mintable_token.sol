//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../node_modules/solmate/src/tokens/ERC20.sol";
// import "https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol";

contract ERC20token is ERC20{
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol,10){}

    function mint(uint256 amount, address to)public{
        _mint(to,amount);
    }
}
