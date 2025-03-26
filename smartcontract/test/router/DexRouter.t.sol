// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import {Test, console} from "forge-std/Test.sol";
import "../../src/DexRouter.sol";
import "../../src/Pool.sol";
import "../../src/PoolFactory.sol";
import "../../src/mocks/TokenFactory.sol";

contract DexRouterTest is Test {
    address constant OWNER = address(1);
    address constant USER = address(2);
    
    // Adresses Uniswap (mainnet)
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    DexRouter router;
    PoolFactory factory;
    TokenFactory tokenFactory;
    address token1;
    address token2;
    
    function setUp() public {
        // Fork mainnet
        string memory rpcUrl = vm.rpcUrl("mainnet");
        vm.createSelectFork(rpcUrl, 22076386);
        
        // Déployer les contrats
        vm.startPrank(OWNER);
        
        tokenFactory = new TokenFactory();
        token1 = tokenFactory.createToken("Test Token 1", "TT1", 1_000_000 * 10**18);
        token2 = tokenFactory.createToken("Test Token 2", "TT2", 1_000_000 * 10**18);
        
        factory = new PoolFactory();
        factory.createPool(token1, token2);
        
        router = new DexRouter(address(factory), UNISWAP_ROUTER);
        
        // Donner des tokens à USER
        TestToken(token1).mint(USER, 10_000 * 10**18);
        TestToken(token2).mint(USER, 10_000 * 10**18);
        
        // Donner du WETH à USER pour tester Uniswap
        // Il faut d'abord deal des ETH puis wrap
        deal(USER, 10 ether);
        vm.stopPrank();
        
        // USER wrap ETH en WETH
        vm.startPrank(USER);
        (bool success,) = WETH.call{value: 5 ether}("");
        require(success, "WETH deposit failed");
        vm.stopPrank();
        
        // Ajouter de la liquidité au pool local
        vm.startPrank(OWNER);
        TestToken(token1).approve(factory.getPool(token1, token2), type(uint256).max);
        TestToken(token2).approve(factory.getPool(token1, token2), type(uint256).max);
        Pool(factory.getPool(token1, token2)).addLiquidity(1_000 * 10**18, 1_000 * 10**18);
        vm.stopPrank();
    }
    
    function test_swapOnLocalPool() public {
        vm.startPrank(USER);
        
        // Approuver le router
        TestToken(token1).approve(address(router), 100 * 10**18);
        
        // Swapper token1 pour token2
        uint256 balanceBefore = TestToken(token2).balanceOf(USER);
        uint256 amountOut = router.swap(token1, token2, 100 * 10**18, 1, USER);
        uint256 balanceAfter = TestToken(token2).balanceOf(USER);
        
        // Vérifier que le swap a bien eu lieu
        assertEq(balanceAfter - balanceBefore, amountOut);
        assertGt(amountOut, 0, "Should receive tokens");
        
        vm.stopPrank();
    }
    
    function test_forwardToUniswap() public {
        vm.startPrank(USER);
        
        // Approuver le router pour WETH
        IERC20(WETH).approve(address(router), 1 ether);
        
        // Solde USDC avant
        uint256 usdcBefore = IERC20(USDC).balanceOf(USER);
        
        // Swapper WETH pour USDC via Uniswap
        uint256 amountOut = router.swap(WETH, USDC, 1 ether, 1, USER);
        
        // Solde USDC après
        uint256 usdcAfter = IERC20(USDC).balanceOf(USER);
        
        // Vérifier que le forwarding a bien eu lieu
        assertEq(usdcAfter - usdcBefore, amountOut);
        assertGt(amountOut, 0, "Should receive USDC");
        
        vm.stopPrank();
    }
    
    function test_checkForwardingFee() public {
        vm.startPrank(USER);
        
        // Approuver le router pour WETH
        IERC20(WETH).approve(address(router), 1 ether);
        
        // Solde WETH de OWNER avant
        uint256 ownerWethBefore = IERC20(WETH).balanceOf(OWNER);
        
        // Swapper WETH pour USDC via Uniswap
        router.swap(WETH, USDC, 1 ether, 1, USER);
        
        // Solde WETH de OWNER après
        uint256 ownerWethAfter = IERC20(WETH).balanceOf(OWNER);
        
        // Vérifier que OWNER a reçu la fee de forwarding (0.5%)
        uint256 expectedFee = 1 ether * 50 / 10000; // 0.5%
        assertEq(ownerWethAfter - ownerWethBefore, expectedFee);
        
        vm.stopPrank();
    }
    
    function test_setForwardingFee() public {
        vm.prank(OWNER);
        router.setForwardingFee(100); // 1%
        
        assertEq(router.forwardingFee(), 100);
        
        vm.prank(USER);
        vm.expectRevert("Not owner");
        router.setForwardingFee(50);
    }
    
    function test_setOwner() public {
        vm.prank(OWNER);
        router.setOwner(USER);
        
        assertEq(router.owner(), USER);
        
        // L'ancien owner ne peut plus changer le fee
        vm.prank(OWNER);
        vm.expectRevert("Not owner");
        router.setForwardingFee(100);
        
        // Le nouveau owner peut changer le fee
        vm.prank(USER);
        router.setForwardingFee(100);
        assertEq(router.forwardingFee(), 100);
    }
}