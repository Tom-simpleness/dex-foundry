// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPoolFactory.sol";
import "./Pool.sol";

// --- Custom Errors ---
error FactoryIdenticalAddresses();
error FactoryZeroAddress();
error FactoryPoolExists();
error FactoryFeeTooHigh();
error FactoryInvalidProtocolFeePortion();

contract PoolFactory is IPoolFactory, Ownable {
    mapping(address => mapping(address => address)) public tokenPairToPoolAddress;
    address[] public allPairs;
    uint256 public fee = 30; // 0.3% fee
    address public feeRecipient;
    uint256 public protocolFeePortion = 5000; // 50% of fees to protocol by default, 50% to LPs
    
    constructor() Ownable(msg.sender) {
        feeRecipient = msg.sender;
    }
    
    // Requirement: Ensure token addresses are sorted to prevent duplicate pools
    function _sortTokens(address tokenA, address tokenB) internal pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }
    
    // Requirement: Only allow creating pools for valid token pairs
    function createPool(address tokenA, address tokenB) external override returns (address pool) {
        if (tokenA == tokenB) revert FactoryIdenticalAddresses();
        if (tokenA == address(0) || tokenB == address(0)) revert FactoryZeroAddress();
        
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        
        // Requirement: Prevent duplicate pools
        if (tokenPairToPoolAddress[token0][token1] != address(0)) revert FactoryPoolExists();
        
        // Create a new pool
        bytes memory bytecode = type(Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // --- Effects: Update state BEFORE external call ---
        tokenPairToPoolAddress[token0][token1] = pool;
        tokenPairToPoolAddress[token1][token0] = pool;
        allPairs.push(pool);
        
        // --- Effect: Emit event BEFORE interaction ---
        emit PoolCreated(token0, token1, pool); 
        
        // --- Interaction: Initialize pool AFTER updating state and emitting event ---
        Pool(pool).initialize(token0, token1, address(this));
    }
    
    // Requirement: Only owner can set fee recipient
    function setFeeRecipient(address _feeRecipient) external override onlyOwner {
        if (_feeRecipient == address(0)) revert FactoryZeroAddress();
        feeRecipient = _feeRecipient;
    }
    
    // Requirement: Only owner can set fee, with maximum limit
    function setFee(uint256 _fee) external override onlyOwner {
        // Prevent setting unreasonably high fees (max 5%)
        if (_fee > 500) revert FactoryFeeTooHigh();
        fee = _fee;
    }
    
    // Requirement: Only owner can set protocol fee portion
    function setProtocolFeePortion(uint256 _protocolFeePortion) external onlyOwner {
        // Ensure the portion is between 0% and 100%
        if (_protocolFeePortion > 10000) revert FactoryInvalidProtocolFeePortion();
        protocolFeePortion = _protocolFeePortion;
    }
} 