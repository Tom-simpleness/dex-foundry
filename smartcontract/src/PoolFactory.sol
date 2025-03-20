// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPoolFactory.sol";
import "./Pool.sol";

contract PoolFactory is IPoolFactory, Ownable {
    mapping(address => mapping(address => address)) public getPair;
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
        require(tokenA != tokenB, "Factory: identical addresses");
        require(tokenA != address(0) && tokenB != address(0), "Factory: zero address");
        
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        
        // Requirement: Prevent duplicate pools
        require(getPair[token0][token1] == address(0), "Factory: pool exists");
        
        // Create a new pool
        bytes memory bytecode = type(Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // Initialize pool
        Pool(pool).initialize(token0, token1, address(this));
        
        // Store pool address in mapping
        getPair[token0][token1] = pool;
        getPair[token1][token0] = pool;
        allPairs.push(pool);
        
        // Transfer ownership to this factory
        Pool(pool).transferOwnership(address(this));
        
        emit PoolCreated(token0, token1, pool, allPairs.length);
    }
    
    function getPool(address tokenA, address tokenB) external view override returns (address) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return getPair[token0][token1];
    }
    
    function getFee() external view override returns (uint256) {
        return fee;
    }
    
    function getFeeRecipient() external view override returns (address) {
        return feeRecipient;
    }
    
    function getProtocolFeePortion() external view returns (uint256) {
        return protocolFeePortion;
    }
    
    // Requirement: Only owner can set fee recipient
    function setFeeRecipient(address _feeRecipient) external override onlyOwner {
        require(_feeRecipient != address(0), "Factory: zero address");
        feeRecipient = _feeRecipient;
    }
    
    // Requirement: Only owner can set fee, with maximum limit
    function setFee(uint256 _fee) external override onlyOwner {
        // Prevent setting unreasonably high fees (max 5%)
        require(_fee <= 500, "Factory: fee too high");
        fee = _fee;
    }
    
    // Requirement: Only owner can set protocol fee portion
    function setProtocolFeePortion(uint256 _protocolFeePortion) external onlyOwner {
        // Ensure the portion is between 0% and 100%
        require(_protocolFeePortion <= 10000, "Factory: invalid protocol fee portion");
        protocolFeePortion = _protocolFeePortion;
    }
} 