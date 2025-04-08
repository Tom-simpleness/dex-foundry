// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IPoolFactory {
    event PoolCreated(address indexed tokenA, address indexed tokenB, address pool);

    function createPool(address tokenA, address tokenB) external returns (address pool);
    function setFeeRecipient(address _feeRecipient) external;
    function setFee(uint256 _fee) external;
    function setProtocolFeePortion(uint256 _protocolFeePortion) external;
    function fee() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function protocolFeePortion() external view returns (uint256);
    function tokenPairToPoolAddress(address tokenA, address tokenB) external view returns (address pool);
} 