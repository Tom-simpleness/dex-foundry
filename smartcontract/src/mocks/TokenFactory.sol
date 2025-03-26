// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./ITokenFactory.sol";

contract TestToken is ERC20 {
    address public creator;
    
    constructor(string memory name, string memory symbol, uint256 initialSupply, address owner) ERC20(name, symbol) {
        _mint(owner, initialSupply);
        creator = owner;
    }
    
    function mint(address to, uint256 amount) external {
        require(msg.sender == creator, "TestToken: only creator can mint");
        _mint(to, amount);
    }
}

contract TokenFactory is ITokenFactory, Ownable {
    mapping(address => bool) public isTokenFromFactory;
    mapping(address => address) public tokenCreator;
    
    constructor() Ownable(msg.sender) {}
    
    function createToken(string memory name, string memory symbol, uint256 initialSupply) external override returns (address) {
        TestToken token = new TestToken(name, symbol, initialSupply, msg.sender);
        isTokenFromFactory[address(token)] = true;
        tokenCreator[address(token)] = msg.sender;
        return address(token);
    }
    
    function mint(address token, address to, uint256 amount) external override {
        // Requirement: Only tokens created by this factory can be minted
        require(isTokenFromFactory[token], "TokenFactory: token not created by factory");
        
        // Ensure only the creator can mint
        require(tokenCreator[token] == msg.sender, "TokenFactory: only creator can mint");
        
        TestToken(token).mint(to, amount);
    }
} 