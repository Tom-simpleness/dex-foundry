// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

interface IPoolFactory {
    event PoolCreated(address indexed tokenA, address indexed tokenB, address pool, uint256 poolsCount);

    function createPool(address tokenA, address tokenB) external returns (address pool);
    function getPool(address tokenA, address tokenB) external view returns (address pool);
    function getFee() external view returns (uint256);
    function getFeeRecipient() external view returns (address);
    function setFeeRecipient(address _feeRecipient) external;
    function setFee(uint256 _fee) external;
} 