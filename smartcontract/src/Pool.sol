// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolFactory.sol";
import "./lib/Math.sol";

contract Pool is IPool, Ownable {
    using SafeERC20 for IERC20;

    address public tokenA;
    address public tokenB;
    address public factory;
    
    uint256 private reserveA;
    uint256 private reserveB;
    
    // LP token tracking
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;
    
    // Requirement: Prevent initialization after deployment
    bool private initialized;
    
    constructor() Ownable(msg.sender) {
        // Factory will set as owner after deployment
    }
    
    // Requirement: Pool must be initialized with tokens and factory only once
    function initialize(address _tokenA, address _tokenB, address _factory) external override onlyOwner {
        require(!initialized, "Pool: already initialized");
        // --- Checks --- 
        require(_tokenA != address(0), "Pool: tokenA cannot be zero address");
        require(_tokenB != address(0), "Pool: tokenB cannot be zero address");
        require(_factory != address(0), "Pool: factory cannot be zero address");

        // --- Effects --- 
        tokenA = _tokenA;
        tokenB = _tokenB;
        factory = _factory;
        initialized = true;
    }
    
    // Requirement: Ensure consistent ordering of tokens for pool identification
    function getTokens() external view override returns (address, address) {
        return (tokenA, tokenB);
    }
    
    function getReserves() public view override returns (uint256, uint256) {
        return (reserveA, reserveB);
    }
    
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    // Requirement: Calculate price with minimal rounding errors
    // Used for calculating output amounts in swaps
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 fee) private pure returns (uint256) {
        // Requirement: Ensure sufficient input amount
        require(amountIn > 0, "Math: INSUFFICIENT_INPUT_AMOUNT");
        // Requirement: Ensure pools have liquidity
        require(reserveIn > 0 && reserveOut > 0, "Math: INSUFFICIENT_LIQUIDITY");
        
        // Adjust for fee (fee is in basis points, e.g. 30 = 0.3%)
        uint256 amountInWithFee = amountIn * (10000 - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountInWithFee;
        
        return numerator / denominator;
    }
    
    // Synchronizes internal reserve variables with the actual token balances held by the pool.
    // Called before calculations in `swap` to use fresh balances, and after state changes
    // in `addLiquidity`/`removeLiquidity` to record the final state.
    function _updateReserves() private {
        reserveA = IERC20(tokenA).balanceOf(address(this));
        reserveB = IERC20(tokenB).balanceOf(address(this));
    }
    
    // Requirement: Users must contribute proportionally to current reserves
    function addLiquidity(uint256 amountA, uint256 amountB) external override returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "Pool: insufficient deposit amounts");
        
        // Read reserves *before* calculating liquidity
        (uint256 _reserveA, uint256 _reserveB) = (reserveA, reserveB); 
        
        // Calculate liquidity tokens to mint (Check)
        uint256 totalSupplyBefore = _totalSupply;
        
        if (totalSupplyBefore == 0) {
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            liquidity = Math.min(
                (amountA * totalSupplyBefore) / _reserveA,
                (amountB * totalSupplyBefore) / _reserveB
            );
        }
        
        require(liquidity > 0, "Pool: insufficient liquidity minted");
        
        // Update internal state (Effect)
        _balances[msg.sender] += liquidity;
        _totalSupply = _totalSupply + liquidity; 
        
        // Emit event (Effect)
        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);

        // Perform transfers (Interaction)
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        
        // Update reserves *after* everything
        _updateReserves();
    }
    
    // Requirement: Users can only withdraw proportionally to their LP tokens
    function removeLiquidity(uint256 liquidity) external override returns (uint256 amountA, uint256 amountB) {
        require(_balances[msg.sender] >= liquidity, "Pool: insufficient balance");
        
        uint256 totalSupplyBefore = _totalSupply;
        
        // Calculate token amounts
        amountA = (liquidity * reserveA) / totalSupplyBefore;
        amountB = (liquidity * reserveB) / totalSupplyBefore;
        
        require(amountA > 0 && amountB > 0, "Pool: insufficient amounts");
        
        // Burn LP tokens
        _balances[msg.sender] -= liquidity;
        _totalSupply = _totalSupply - liquidity;
        
        // Transfer tokens
        IERC20(tokenA).safeTransfer(msg.sender, amountA);
        IERC20(tokenB).safeTransfer(msg.sender, amountB);
        
        // Update reserves
        _updateReserves();
        
        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }
    
    // Requirement: Swaps must maintain the constant product formula k = x * y
    // Funds (tokenIn) must be transferred to the pool *before* calling this function.
    function swap(
        address tokenIn, 
        uint256 amountIn, 
        address recipient // Added recipient parameter
    ) external override returns (uint256 amountOut) { 
        require(tokenIn == tokenA || tokenIn == tokenB, "Pool: invalid input token");
        require(amountIn > 0, "Pool: insufficient input amount");
        require(recipient != address(0), "Pool: invalid recipient");
        
        _updateReserves(); // Update reserves based on current balances (including received tokenIn)

        address tokenOut = tokenIn == tokenA ? tokenB : tokenA;
        // Use reserves *after* update (which includes amountIn)
        uint256 reserveIn = tokenIn == tokenA ? reserveA : reserveB; 
        uint256 reserveOut = tokenIn == tokenA ? reserveB : reserveA; 

        // Adjust reserveIn to exclude the just-received amountIn for calculation
        uint256 reserveInForCalc = reserveIn - amountIn;
        
        // Get fee from factory
        uint256 fee = IPoolFactory(factory).fee();
        
        // Calculate output amount based on reserves *before* the swap
        amountOut = getAmountOut(amountIn, reserveInForCalc, reserveOut, fee);
        require(amountOut > 0, "Pool: insufficient output amount");
        require(amountOut < reserveOut, "Pool: insufficient liquidity for output"); // Prevent draining the pool
        
        // No need for feeAmount calculation or protocol fee transfer here, 
        // as the fee is inherently kept in the pool by the getAmountOut formula.
        // The _updateReserves call correctly reflects the new balances including the fee portion.

        // REMOVED: Transfer of tokenIn - Assumed already received
        // IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn - protocolFeeAmount);
        
        // Transfer output token to the final recipient
        IERC20(tokenOut).safeTransfer(recipient, amountOut);
        
        // Update reserves again to reflect the sent tokenOut (optional but good practice for consistency)
        // Although the next operation will call _updateReserves anyway
        _updateReserves(); 
        
        // Emit swap event - msg.sender is the entity calling swap (likely the Router)
        emit Swap(msg.sender, amountIn, amountOut, tokenIn);
    }
} 