//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../libraries/Math.sol";
import "../libraries/float.sol";
import "../interfaces/ITrade.sol";
import "../interfaces/IFactory.sol";
import "../interfaces/IPair.sol";
import "../contracts/DexERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DExPair is DexERC20, IPair {
    using float for uint224;
    using SafeERC20 for IERC20;
    using Math for uint256;

    error ValidFactory(address sender, address factory);
    error Balance_overflow();
    error Insuf_liquidity();
    error Liquidity_burn();
    error Liquidity_mint();
    error Invalid_Inputs();
    error Invalid_outputs();
    error Operation_invalid();
    error Invalid_Address(address to);
    error Initialised();

    uint112 private reserveA;
    uint112 private reserveB;
    uint256 public LastPrice_A;
    uint256 public LastPrice_B;
    uint32 private blockTime;
    uint256 public prod;
    address public factory;
    address public tokenA;
    address public tokenB;

    uint256 constant limit = 1000;

    constructor() {
        factory = msg.sender;
    }

    function init(address token0_, address token1_) public {
        if (factory != msg.sender) revert ValidFactory(msg.sender, factory);
        if (tokenA != address(0) || tokenB != address(0)) revert Initialised();

        tokenA = token0_;
        tokenB = token1_;
    }

    /* Burn Function allows users to burn their 
    liquidity tokens and receive their share of 
    tokenA and tokenB in exchange*/

    function burn(
        address trader
    ) external override returns (uint256 amountOfA, uint256 amountOfB) {
        (uint112 reserveA_, uint112 reserveB_, ) = getreserves();

        address tknA = tokenA;
        address tknB = tokenB;
        uint256 bal_A = IERC20(tokenA).balanceOf(address(this));
        uint256 bal_B = IERC20(tokenB).balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        bool isFee = _mintFee(reserveA_, reserveB_);
        uint256 _totsupply = totalSupply();
        amountOfA = (liquidity * bal_A) / _totsupply;
        amountOfB = (liquidity * bal_B) / _totsupply;

        if (amountOfA == 0 || amountOfB == 0) revert Liquidity_burn();

        _burn(address(this), liquidity);

        IERC20(tknA).safeTransfer(trader, amountOfA);
        IERC20(tknB).safeTransfer(trader, amountOfB);

        bal_A = IERC20(tknA).balanceOf(address(this));
        bal_B = IERC20(tknB).balanceOf(address(this));

        _update(bal_A, bal_B, reserveA_, reserveB_);
        if (isFee) prod = uint256(reserveA) * (reserveB);
        emit Burn(msg.sender, amountOfA, amountOfB, trader);
    }

    /* Mint Function allows users to mint new 
    liquidity tokens by depositing 
    tokenA and tokenB */

    function mint(
        address trader
    ) external override returns (uint256 liquidity) {
        (uint112 reserveA_, uint112 reserveB_, ) = getreserves();
        uint256 bal_A = IERC20(tokenA).balanceOf(address(this));
        uint256 bal_B = IERC20(tokenB).balanceOf(address(this));
        uint256 amountOfA = bal_A - reserveA_;
        uint256 amountOfB = bal_B - reserveB_;

        bool isFee = _mintFee(reserveA_, reserveB_);
        uint256 _totsupply = totalSupply();

        if (_totsupply == 0) {
            liquidity = Math.sqrt(amountOfA * amountOfB) - limit;
            _mint(address(1), limit);
        } else {
            liquidity = Math.min(
                (amountOfA * _totsupply) / reserveA_,
                (amountOfB * _totsupply) / reserveB_
            );
        }
        if (liquidity <= 0) revert Liquidity_mint();

        _mint(trader, liquidity);
        _update(bal_A, bal_B, reserveA_, reserveB_);

        if (isFee) prod = uint256(reserveA) * reserveB;
        emit Mint(msg.sender, amountOfA, amountOfB);
    }

    /* Sync function syncs the current reserves 
    of tokenA and tokenB in the contract*/

    function sync() external override {
        _update(
            IERC20(tokenA).balanceOf(address(this)),
            IERC20(tokenB).balanceOf(address(this)),
            reserveA,
            reserveB
        );
    }

    /* Swap function allows users to swap their 
    tokens by providing an output price for tokenA 
    and tokenB they want to receive in exchange*/

    function swap(
        uint256 Amount_A,
        uint256 Amount_B,
        address to,
        bytes calldata data
    ) external override {
        uint256 bal_A;
        uint256 bal_B;

        if (Amount_A == 0 && Amount_B == 0) revert Invalid_outputs();

        (uint112 reserveA_, uint112 reserveB_, ) = getreserves();

        if (Amount_A > reserveA_ || Amount_B > reserveB_)
            revert Insuf_liquidity();

        {
            address tknA = tokenA;
            address tknB = tokenB;
            if (to == tknA || to == tknB) revert Invalid_Address(to);
            if (Amount_A > 0) IERC20(tknA).safeTransfer(to, Amount_A);
            if (Amount_B > 0) IERC20(tknB).safeTransfer(to, Amount_B);

            if (data.length > 0)
                ITrade(to).swapCall(msg.sender, Amount_A, Amount_B, data);

            bal_A = IERC20(tknA).balanceOf(address(this));
            bal_B = IERC20(tknB).balanceOf(address(this));
        }

        uint256 A_in = bal_A > (reserveA_ - Amount_A)
            ? bal_A - (reserveA_ - Amount_A)
            : 0;
        uint256 B_in = bal_B > (reserveB_ - Amount_B)
            ? bal_B - (reserveB_ - Amount_B)
            : 0;

        if (A_in == 0 && B_in == 0) revert Invalid_Inputs();
        {
            uint256 temp_bal_A = (bal_A * 1000) - (A_in * 3);
            uint256 temp_bal_B = (bal_B * 1000) - (B_in * 3);
            if (
                temp_bal_A * temp_bal_B <
                uint256(reserveA_) * uint256(reserveB_) * (1000 ** 2)
            ) revert Operation_invalid();
        }

        _update(bal_A, bal_B, reserveA_, reserveB_);

        emit Swap(msg.sender, A_in, B_in, Amount_A, Amount_B, to);
    }

    function skim(address to) external override {
        address tknA = tokenA;
        address tknB = tokenB;
        IERC20(tknA).safeTransfer(
            to,
            IERC20(tknA).balanceOf(address(this)) - reserveA
        );
        IERC20(tknB).safeTransfer(
            to,
            IERC20(tknB).balanceOf(address(this)) - reserveB
        );
    }

    /*Private Functions*/ //////////////////////////////////////////////////////////

    function _update(
        uint256 bal_A,
        uint256 bal_B,
        uint112 reserveA_,
        uint112 reserveB_
    ) private {
        if (bal_A > type(uint112).max || bal_B > type(uint112).max)
            revert Balance_overflow();

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - blockTime;
            if (timeElapsed > 0 && reserveA_ > 0 && reserveB_ > 0) {
                LastPrice_A += (uint256(
                    float.encode(reserveB_).uqdiv(reserveA_)
                ) * timeElapsed);
                LastPrice_B += (uint256(
                    float.encode(reserveA_).uqdiv(reserveB_)
                ) * timeElapsed);
            }
        }

        reserveA = uint112(bal_A);
        reserveB = uint112(bal_B);
        blockTime = uint32(block.timestamp);

        emit Sync(reserveA, reserveB);
    }

    function _mintFee(
        uint112 reserveA_,
        uint112 reserveB_
    ) private returns (bool isFee) {
        address feeTo = IFactory(factory).fTo();
        isFee = feeTo != address(0);
        uint256 product = prod;
        if (isFee) {
            if (product != 0) {
                uint256 rootK = Math.sqrt(uint256(reserveA_) * (reserveB_));
                uint256 rootKLast = Math.sqrt(product);
                if (rootK > rootKLast) {
                    uint256 num = totalSupply() * (rootK - rootKLast);
                    uint256 den = (rootK * 5) + rootKLast;
                    uint256 liquidity = num / den;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (product != 0) {
            prod = 0;
        }
    }

    function getreserves()
        public
        view
        returns (uint112 reserveA_, uint112 reserveB_, uint32 blockTimest)
    {
        reserveA_ = reserveA;
        reserveB_ = reserveB;
        blockTimest = blockTime;
    }
}
