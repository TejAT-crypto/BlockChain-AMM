//SPDX -License-Identifier: Unlicense

pragma solidity ^0.8.10;

//import "Factory.sol";
//import "SwapPair.sol";
//import "Library.sol";


contract Router{
    error ExcessiveInputAmount();
    error InsufficientAAmount();
    error InsufficientBAmount();
    error InsufficientOutputAmount();
    error SafeTransferFailed();


    Factory factory;

    constructor (address factoryAddress){
        factory = Factory(factoryAddress);
    } 

    function addLiquidity(
        address A,
        address B,
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
        if(factory.pairs(A, B) == address(0)){
            factory.createPair(A, B);
        }

        (amtA, amtB) = _createLiquidity(
            A,
            B,
            amtAin,
            amtBin,
            amtAmin,
            amtBmin
        );

        address pairAddress = Library.paiFor(
            address(factory),
            A,
            B
        );

        _safeTransferFrom(A, msg.sender, pairAddress, amtA);
        _safeTransferFrom(B, msg.sender, pairAddress, amtB);

        liquidity = Pair(pairAddress).mint(to);
    }
    function removeLiquidity(
        address A,
        address B,
        uint256 liquidity,
        uint256 amtAmin,
        uint256 amtBmin,
        address to
    ) public returns (uint256 amtA, uint256 amtB) {
        address pair = Library.pairFor(
            address(factory),
            A,
            B
        );
        Pair(pair).transferFrom(msg.sender, pair, liquidity);
        (amtA, amtB) = Pair(pair).burn(to);
        if(amtA < amtAmin) revert InsufficientAAmount();
        if(amtB < amtBmin) revert InsufficientBAmount();
    }
    function swapTokens(
        uint256 amtIn,
        uint256 amtOutMin,
        address[] calldata path,
        address to
    )public returns (uint256[] memory amounts){
        amounts = Library.getAmountOut(
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

    function swapTokens(
        uint256 amtOut,
        uint256 amtInMax,
        address[] calldata path,
        address to
    )public returns (uint256[] memory amounts){
        amounts = Library.getAmountOut(
            address(factory),
            amtOut,
            path
        );
        if(amounts[amounts.length-1] > amtInMax){
            revert ExecessiveInputAmount();
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
            (address token0, ) = Library.sortTokens(input, output);
            uint256 amtOut = amounts[i+1];
            (uint256 amt0Out, uint256 amt1Out) = input == token0
                ? (uint256(0), amtOut)
                : (amtOut, uint256(0));
            address to = i < path.length - 2 ? Library.pairFor(address(factory), output, path[i+2]) : _to;
            swapPair(
                Library.pairFor(address(factory), input, output)
            ).swap(amt0Out, amt1Out, to, "");
        }
    }
    fucntion _calculateLiquidity(
        address A,
        address B,
        uint256 amtAdesired,
        uint256 amtBdesired,
        uint256 amtAmin,
        uint256 amtBmin
    )internal returns(uint256 A, uint256 B){
        (uint256 reserveA, uint256 reserveB) = Library.getReserves(
            address(factory),
            A,
            B
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
        bool success, bytes memory data) = token.call(
            abi.encodeWithSignature(
                "transferfrom(address, adress, uint256)",
                from, 
                to, 
                value
            )
        );
        if(!success || (data.length != 0 && !abi.decode(data, bool)))
            revert SafeTransferFailed();
    }

}