// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./factory.sol";
import "./DExPair.sol";
import "./Library.sol";


contract Router{
    error ExcessiveInputAmount();
    error InsufficientAAmount();
    error InsufficientBAmount();
    error InsufficientOutputAmount();


    Factory factory;

    constructor (address factoryAddress){
        factory = Factory(factoryAddress);
    } 

    function addLiquidity(
        address token_A,
        address token_B,
        uint256 amtAin,
        uint256 amtBin,
        uint256 amtAmin,
        uint256 amtBmin,
        address to        
    )
    public returns (
        uint256 amtA,
        uint256 amtB,
        uint256 liquidity
    )
    {
        if(factory.newPairs(token_A, token_B) == address(0)){
            factory.createPairs(token_A, token_B);
        }

        (amtA, amtB) = _calculateLiquidity(
            token_A,
            token_B,
            amtAin,
            amtBin,
            amtAmin,
            amtBmin
        );

        address pairAddress = Library.pairFor(
            address(factory),
            token_A,
            token_B
        );

        _safeTransferFrom(token_A, msg.sender, pairAddress, amtA);
        _safeTransferFrom(token_B, msg.sender, pairAddress, amtB);

        liquidity = IPair(pairAddress).mint(to);
    }
    function removeLiquidity(
        address token_A,
        address token_B,
        uint256 liquidity,
        uint256 amtAmin,
        uint256 amtBmin,
        address to
    ) public returns (uint256 amtA, uint256 amtB) {
        address pair = Library.pairFor(
            address(factory),
            token_A,
            token_B
        );
        IPair(pair).transferFrom(msg.sender, pair, liquidity);
        (amtA, amtB) = IPair(pair).burn(to);
        if(amtA < amtAmin) revert InsufficientAAmount();
        if(amtB < amtBmin) revert InsufficientBAmount();
    }
    function swapTokensIn(
        uint256 amtIn,
        uint256 amtOutMin,
        address[] calldata path,
        address to
    )public returns (uint256[] memory amounts){
        amounts = Library.getAmountsOut(
            address(factory),
            amtIn,
            path
        );
        if(amounts[amounts.length-1] < amtOutMin){
            revert InsufficientOutputAmount();
        }
        _safeTransferFrom(
                path[0],
                msg.sender,
                Library.pairFor(address(factory), path[0], path[1]),
                amounts[0]
            );
        _swap(amounts, path, to);
    }

    function swapTokensOut(
        uint256 amtOut,
        uint256 amtInMax,
        address[] calldata path,
        address to
    )public returns (uint256[] memory amounts){
        amounts = Library.getAmountsOut(
            address(factory),
            amtOut,
            path
        );
        if(amounts[amounts.length-1] > amtInMax){
            revert ExcessiveInputAmount();
        }
        _safeTransferFrom(
                path[0],
                msg.sender,
                Library.pairFor(address(factory), path[0], path[1]),
                amounts[0]
            );
        _swap(amounts, path, to);
    }

    //PRIVATE FUNCTIONS

    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal {
        for(uint256 i; i < path.length - 1; i++){
            (address input, address output) = (path[i], path[i+1]);
            (address token_A, ) = Library.sortTokens(input, output);
            uint256 amtOut = amounts[i+1];
            (uint256 amt0Out, uint256 amt1Out) = input == token_A
                ? (uint256(0), amtOut)
                : (amtOut, uint256(0));
            address to = i < path.length - 2 ? Library.pairFor(address(factory), output, path[i+2]) : _to;
            IPair(
                Library.pairFor(address(factory), input, output)
            ).swap(amt0Out, amt1Out, to, "");
        }
    }
    function _calculateLiquidity(
        address token_A,
        address token_B,
        uint256 amtAdesired,
        uint256 amtBdesired,
        uint256 amtAmin,
        uint256 amtBmin
    )internal returns(uint256 amtA, uint256 amtB){
        (uint256 reserveA, uint256 reserveB) = Library.getReserves(
            address(factory),
            token_A,
            token_B
        );
        if(reserveA == 0 && reserveB == 0){
            (amtA, amtB) = (amtAdesired, amtBdesired);
        } 
        else{
            uint256 amtBopt = Library.quote(
                amtAdesired,
                reserveA,
                reserveB
            );
            if(amtBopt<=amtBdesired){
                if(amtBopt<=amtBmin){
                    revert InsufficientBAmount();
                }
                (amtA, amtB) = (amtAdesired, amtBopt);
            }
            else{
                uint256 amtAopt = Library.quote(
                    amtBdesired,
                    reserveA,
                    reserveB
                );
                assert(amtAopt<=amtAdesired);
                if(amtAopt<=amtAmin){
                    revert InsufficientAAmount();
                }
                (amtA, amtB) = (amtAopt, amtBdesired);  
            }
        }
    }

    function _safeTransferFrom(
        address token, 
        address to,
        address from,
        uint256 value
    ) private{
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature(
                "transferfrom(address, adress, uint256)",
                from, 
                to, 
                value
            )
        );
        require(!success || (data.length == 0 && abi.decode(data, (bool))),
        "Trade failed. Aborting..");
    }

}