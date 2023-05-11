// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IPair.sol";

library Library {
    error SameAddresses(address tokenA, address tokenB);
    error InsufficientAmount();
    error InsufficientLiquidity();
    error ZeroAddress();
    error InsufficientInputAmount();
    error InsufficientOutputAmount();
    error InvalidPath(address[] path);
    error FailedSendingEth(address recipient, uint256 amt);

    function getReserves(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token_A, ) = sortTokens(tokenA, tokenB);
        (uint256 reserve_A, uint256 reserve_B, ) = IPair(
            pairFor(factoryAddress, tokenA, tokenB)
        ).getreserves();
        (reserveA, reserveB) = tokenA == token_A
            ? (reserve_A, reserve_B)
            : (reserve_B, reserve_A);
    }

    function quote(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        amountOut = (amountIn * reserveOut) / reserveIn;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token_A, address token_B) {
        if (tokenA == tokenB) {
            revert SameAddresses(tokenA, tokenB);
        }
        (token_A, token_B) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        if (token_A == address(0)) {
            revert ZeroAddress();
        }
    }

    function pairFor(
        address factoryAddress,
        address tokenA,
        address tokenB
    ) internal pure returns (address pairAddress) {
        (address token_A, address token_B) = sortTokens(tokenA, tokenB);
        pairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factoryAddress,
                            keccak256(abi.encodePacked(token_A, token_B)),
                            hex"9c34ce45d92a14ff3c7ccab22f0573890919ad7d806c1865e525ec3d73a409e0"
                        )
                    )
                )
            )
        );
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amtOut) {
        if (amountIn == 0) revert InsufficientInputAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        amtOut = numerator / denominator;
    }

    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amts) {
        if (path.length < 2) revert InvalidPath(path);
        amts = new uint256[](path.length);
        amts[0] = amountIn;

        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserve_A, uint256 reserve_B) = getReserves(
                factory,
                path[i],
                path[i + 1]
            );
            amts[i + 1] = getAmountOut(amts[i], reserve_A, reserve_B);
        }
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amtIn) {
        if (amountOut == 0) revert InsufficientOutputAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;

        amtIn = (numerator / denominator) + 1;
    }

    function getAmountsIn(
        address factory,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256[] memory amts) {
        if (path.length < 2) revert InvalidPath(path);
        amts = new uint256[](path.length);
        amts[amts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserve_A, uint256 reserve_B) = getReserves(
                factory,
                path[i - 1],
                path[i]
            );
            amts[i - 1] = getAmountIn(amts[i], reserve_A, reserve_B);
        }
    }

    function SafeTransferEth(address recipient, uint256 amount) internal {
        (bool sent, ) = recipient.call{value: amount}("");
        if (!sent) {
            revert FailedSendingEth(recipient, amount);
        }
    }
}
