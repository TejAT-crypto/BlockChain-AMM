//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../library/Math.sol";
import "../library/float.sol";
import "../interfaces/ITrade.sol";
import "../node_modules/solmate/src/tokens/ERC20.sol";

contract DExPair is ERC20, Math {
    using float for uint224;

    uint112 private reserveA;
    uint112 private reserveB;
    uint256 public LastPrice_A;
    uint256 public LastPrice_B;
    uint32 private blockTime;

    address public tokenA;
    address public tokenB;

    uint256 constant limit = 1000;

    constructor() ERC20("DEx Pair", "SWD", 18){}

    function init(address token0_, address token1_) public {
        if (tokenA != address(0) || tokenB != address(0))
            require(tokenA == address(0) && tokenB == address(0), "Pair Already exists");

        tokenA = token0_;
        tokenB = token1_;
    }

    /* Burn Function allows users to burn their 
    liquidity tokens and receive their share of 
    tokenA and tokenB in exchange*/

    event Burn(address indexed sender, uint256 amountOfA, uint256 amountOfB,address to);

    function burn(address trader) public returns (uint256 amountOfA, uint256 amountOfB){
        uint256 bal_A = IERC20(tokenA).balanceOf(address(this));
        uint256 bal_B = IERC20(tokenB).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];
        
        amountOfA = (liquidity * bal_A) / totalSupply;
        amountOfB = (liquidity * bal_B) / totalSupply;

        require(amountOfA > 0 && amountOfB > 0,"Not enough liquidity to burn");

        _burn(msg.sender, liquidity);

        _safeTransfer(tokenA, trader, amountOfA);
        _safeTransfer(tokenB, trader, amountOfB);

        bal_A = IERC20(tokenA).balanceOf(address(this));
        bal_B = IERC20(tokenB).balanceOf(address(this));

        (uint112 reserveA_, uint112 reserveB_, ) = showReserve();
        _update(bal_A, bal_B, reserveA_, reserveB_);

        emit Burn(msg.sender, amountOfA, amountOfB,trader);
    }

    /* Mint Function allows users to mint new 
    liquidity tokens by depositing 
    tokenA and tokenB */

    event Mint(address indexed sender, uint256 amountOfA, uint256 amountOfB);

    function mint(address trader) public returns (uint256 liquidity){
        (uint112 reserveA_, uint112 reserveB_, ) = showReserve();
        uint256 bal_A = IERC20(tokenA).balanceOf(address(this));
        uint256 bal_B = IERC20(tokenB).balanceOf(address(this));
        uint256 amountOfA = bal_A - reserveA_;
        uint256 amountOfB = bal_B - reserveB_;

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amountOfA * amountOfB) - limit;
            _mint(address(0), limit);
        } else {
            liquidity = Math.min(
                (amountOfA * totalSupply) / reserveA_,
                (amountOfB * totalSupply) / reserveB_
            );
        }
        require(liquidity > 0, "Insufficient Liquidity available for trade");

        _mint(trader, liquidity);
        _update(bal_A, bal_B, reserveA_, reserveB_);

        emit Mint(trader, amountOfA, amountOfB);
    }

    /* Sync function syncs the current reserves 
    of tokenA and tokenB in the contract*/
    
    event Sync(uint256 reserveA, uint256 reserveB);

    function sync() public {
        (uint112 reserveA_, uint112 reserveB_, ) = showReserve();
        _update( IERC20(tokenA).balanceOf(address(this)), 
            IERC20(tokenB).balanceOf(address(this)),
            reserveA_, reserveB_);
    }

    /* Swap function allows users to swap their 
    tokens by providing an output price for tokenA 
    and tokenB they want to receive in exchange*/

    event Swap(address indexed sender, uint256 Amount_A, uint256 Amount_B, address indexed to);

    function swap(uint256 Amount_A, uint256 Amount_B, address to, bytes calldata data) public {
        
        uint256 Deposit_A; 
        uint256 Deposit_B; 

        require(Amount_A != 0 || Amount_B != 0,"Invalid output amount");
        
        (uint112 reserveA_, uint112 reserveB_, ) = showReserve();

        require(Amount_A <= reserveA_ && Amount_B <= reserveB_,
        "Insufficient liquidity");

        /* swap Fee included in code*/
        if(Amount_A > 0) _safeTransfer(tokenA, to , Amount_A );
        if(Amount_B > 0) _safeTransfer(tokenB, to , Amount_B );

        uint256 bal_A = IERC20(tokenA).balanceOf(address(this)) - Amount_A;
        uint256 bal_B = IERC20(tokenB).balanceOf(address(this)) - Amount_B;
        
        if(bal_A - (reserveA - Amount_A) > 0) Deposit_A = bal_A- (reserveA - Amount_A);
        else {
            Deposit_A = 0;
            revert("Insufficient A tokens deposited");
        }

        if(bal_B - (reserveB - Amount_B) > 0) Deposit_B = bal_B- (reserveB - Amount_B);
        else {
            Deposit_B = 0;
            revert("Insufficient B tokens deposited");
        }

        uint256 temp_bal_A = (bal_A * 1000) - (Amount_A * 3);
        uint256 temp_bal_B = (bal_B * 1000) - (Amount_B * 3);


        require((temp_bal_A*temp_bal_B) >= (uint256(reserveA_)*uint256(reserveB_)* (1000**2))
        ,"Invalid operation");
        
        _update(bal_A, bal_B, reserveA_, reserveB_);

        if (Amount_A > 0) _safeTransfer(tokenA, to, Amount_A);
        if (Amount_B > 0) _safeTransfer(tokenB, to, Amount_B);
        if (data.length > 0)
            ITrade(to).swapCall(msg.sender, Amount_A, Amount_B, data);
        emit Swap(msg.sender, Amount_A, Amount_B, to);
    }

    /*Private Functions*///////////////////////////////////////////////////////////

    function _update(uint256 bal_A, uint256 bal_B, uint112 reserveA_, uint112 reserveB_) private {
        require(bal_A <=type(uint112).max && bal_B <=type(uint112).max,"uint112 overflow");

        unchecked {
            uint32 timeElapsed = uint32(block.timestamp) - blockTime;
            if (timeElapsed > 0 && reserveA_ > 0 && reserveB_ > 0) {
                LastPrice_A += (uint256(float.encode(reserveB_).uqdiv(reserveA_)) * timeElapsed);
                LastPrice_B += (uint256(float.encode(reserveA_).uqdiv(reserveB_)) * timeElapsed);
            }
        }

        reserveA = uint112(bal_A);
        reserveB = uint112(bal_B);
        blockTime = uint32(block.timestamp);

        emit Sync(reserveA, reserveB);
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool flag, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, value)
        );
        require(flag && (data.length == 0 || abi.decode(data, (bool))),
        "Trade failed. Aborting..");
    }
    
    function showReserve() public view returns (uint112, uint112, uint32){
        return (reserveA, reserveB, blockTime);
    }
}

interface IERC20 {
    function balanceOf(address) external returns (uint256);
    function transfer(address to, uint256 amount) external;
}