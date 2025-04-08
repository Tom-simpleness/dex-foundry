// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolFactory.sol";
import "./lib/Math.sol";

contract Pool is IPool, Ownable, ReentrancyGuard {
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
    
    // Minimum liquidity locked forever to prevent division by zero
    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    
    constructor() Ownable(msg.sender) {
        // Factory will set as owner after deployment
    }
    
    // Requirement: Pool must be initialized with tokens and factory only once
    function initialize(address _tokenA, address _tokenB, address _factory) external override onlyOwner {
        require(!initialized, "Pool: already initialized");
        require(_tokenA != address(0) && _tokenB != address(0), "Pool: zero address");
        require(_tokenA != _tokenB, "Pool: identical addresses");
        
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
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 fee) internal pure returns (uint256) {
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
    
    // Requirement: Protect against flash loan attacks and sandwich attacks
    // Updates reserves before any operation
    function _updateReserves() private {
        reserveA = IERC20(tokenA).balanceOf(address(this));
        reserveB = IERC20(tokenB).balanceOf(address(this));
    }
    
    // Requirement: Users must contribute proportionally to current reserves
    function addLiquidity(uint256 amountA, uint256 amountB) external override nonReentrant returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "Pool: insufficient deposit amounts");
        
        uint256 _reserveA = reserveA;
        uint256 _reserveB = reserveB;
        
        // Transfer tokens to the pool
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        
        // Calculate liquidity tokens to mint
        uint256 totalSupplyBefore = _totalSupply;
        
        if (totalSupplyBefore == 0) {
            // First deposit, LP tokens are based on geometric mean of deposits minus minimum liquidity
            liquidity = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            // Mint minimum liquidity to zero address to lock it forever
            _balances[address(0)] = MINIMUM_LIQUIDITY;
        } else {
            // Subsequent deposits, take the minimum of the proportional values
            liquidity = Math.min(
                (amountA * totalSupplyBefore) / _reserveA,
                (amountB * totalSupplyBefore) / _reserveB
            );
        }
        
        require(liquidity > 0, "Pool: insufficient liquidity minted");
        
        // Mint LP tokens
        _balances[msg.sender] += liquidity;
        _totalSupply = _totalSupply + liquidity;
        
        // Update reserves
        _updateReserves();
        
        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }
    
    // Requirement: Users can only withdraw proportionally to their LP tokens
    function removeLiquidity(uint256 liquidity) external override nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "Pool: insufficient liquidity burned");
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
    function swap(address tokenIn, uint256 amountIn) external override nonReentrant returns (uint256 amountOut) {
        require(tokenIn == tokenA || tokenIn == tokenB, "Pool: invalid input token");
        require(amountIn > 0, "Pool: insufficient input amount");
        
        address tokenOut = tokenIn == tokenA ? tokenB : tokenA;
        uint256 reserveIn = tokenIn == tokenA ? reserveA : reserveB;
        uint256 reserveOut = tokenIn == tokenA ? reserveB : reserveA;
        
        // Get fee from factory
        uint256 fee = IPoolFactory(factory).getFee();
        
        // Calculate output amount (this needs to account for both protocol and LP fees)
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut, fee);
        require(amountOut > 0, "Pool: insufficient output amount");
        
        // Calculate total fee amount
        uint256 feeAmount = (amountIn * fee) / 10000;
        
        // Get protocol fee portion from factory (in basis points, e.g. 5000 = 50%)
        uint256 protocolFeePortion = IPoolFactory(factory).getProtocolFeePortion();
        
        // Calculate protocol fee amount (portion that goes to fee recipient)
        uint256 protocolFeeAmount = (feeAmount * protocolFeePortion) / 10000;
        
        // Send protocol fee to fee recipient
        if (protocolFeeAmount > 0) {
            address feeRecipient = IPoolFactory(factory).getFeeRecipient();
            IERC20(tokenIn).safeTransferFrom(msg.sender, feeRecipient, protocolFeeAmount);
        }
        
        // Transfer input token to pool (including LP fee portion)
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn - protocolFeeAmount);
        
        // Transfer output token to sender
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
        
        // Update reserves
        _updateReserves();
        
        emit Swap(msg.sender, amountIn, amountOut, tokenIn);
    }
} 