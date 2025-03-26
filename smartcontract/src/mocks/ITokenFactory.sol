// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

interface ITokenFactory {
    function createToken(string memory name, string memory symbol, uint256 initialSupply) external returns (address);
    function mint(address token, address to, uint256 amount) external;
} 