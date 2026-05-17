// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {AMMPool} from "../../src/amm/AMMPool.sol";
import {AMMFactory} from "../../src/amm/AMMFactory.sol";
import {LPToken} from "../../src/amm/LPToken.sol";
import {
    DeadlineExpired,
    InsufficientLiquidity,
    SlippageExceeded,
    ZeroAddress,
    ZeroAmount
} from "../../src/utils/Errors.sol";

contract MockERC20AMMPoolTest is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AMMPoolTest is Test {
    AMMFactory factory;
    AMMPool pool;
    LPToken lpToken;
    MockERC20AMMPoolTest token0;
    MockERC20AMMPoolTest token1;

    address user1 = address(0x1);
    address user2 = address(0x2);

    uint256 constant INITIAL_BALANCE = 100_000 ether;
    uint256 constant DEADLINE = type(uint256).max;

    function setUp() public {
        factory = new AMMFactory();

        token0 = new MockERC20AMMPoolTest("Token 0", "TK0");
        token1 = new MockERC20AMMPoolTest("Token 1", "TK1");

        (address poolAddr, address lpTokenAddr) =
            factory.createPool(address(token0), address(token1), "LP Token", "LP");

        pool = AMMPool(poolAddr);
        lpToken = LPToken(lpTokenAddr);

        token0.transfer(user1, INITIAL_BALANCE);
        token1.transfer(user1, INITIAL_BALANCE);
        token0.transfer(user2, INITIAL_BALANCE);
        token1.transfer(user2, INITIAL_BALANCE);
    }

    function _addInitialLiquidity(uint256 amount0, uint256 amount1) internal returns (uint256 liquidity) {
        vm.startPrank(user1);
        token0.approve(address(pool), amount0);
        token1.approve(address(pool), amount1);
        liquidity = pool.addLiquidity(amount0, amount1, 0, 0, DEADLINE);
        vm.stopPrank();
    }

    function test_AddLiquidity_MintsInitialLP() public {
        vm.startPrank(user1);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10 ether);

        uint256 liquidity = pool.addLiquidity(10 ether, 10 ether, 0, 0, DEADLINE);

        assertGt(liquidity, 0);
        assertEq(lpToken.balanceOf(user1), liquidity);
        assertEq(pool.reserve0(), 10 ether);
        assertEq(pool.reserve1(), 10 ether);
        vm.stopPrank();
    }

    function test_AddLiquidity_MintsProportionalLP() public {
        uint256 firstLiquidity = _addInitialLiquidity(10 ether, 10 ether);

        vm.startPrank(user2);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10 ether);

        uint256 secondLiquidity = pool.addLiquidity(10 ether, 10 ether, 0, 0, DEADLINE);

        assertEq(secondLiquidity, firstLiquidity);
        assertEq(lpToken.balanceOf(user2), secondLiquidity);
        assertEq(pool.reserve0(), 20 ether);
        assertEq(pool.reserve1(), 20 ether);
        vm.stopPrank();
    }

    function test_AddLiquidity_UsesOptimalAmountForUnbalancedDeposit() public {
        _addInitialLiquidity(10 ether, 10 ether);

        vm.startPrank(user2);
        token0.approve(address(pool), 20 ether);
        token1.approve(address(pool), 30 ether);

        uint256 liquidity = pool.addLiquidity(10 ether, 20 ether, 0, 0, DEADLINE);

        assertGt(liquidity, 0);
        assertEq(pool.reserve0(), 20 ether);
        assertEq(pool.reserve1(), 20 ether);
        vm.stopPrank();
    }

    function test_AddLiquidity_RejectsZeroAmount0() public {
        vm.startPrank(user1);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10 ether);

        vm.expectRevert(ZeroAmount.selector);
        pool.addLiquidity(0, 10 ether, 0, 0, DEADLINE);

        vm.stopPrank();
    }

    function test_AddLiquidity_RejectsZeroAmount1() public {
        vm.startPrank(user1);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10 ether);

        vm.expectRevert(ZeroAmount.selector);
        pool.addLiquidity(10 ether, 0, 0, 0, DEADLINE);

        vm.stopPrank();
    }

    function test_AddLiquidity_RejectsExpiredDeadline() public {
        vm.warp(100);

        vm.startPrank(user1);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10 ether);

        vm.expectRevert(DeadlineExpired.selector);
        pool.addLiquidity(10 ether, 10 ether, 0, 0, block.timestamp - 1);

        vm.stopPrank();
    }

    function test_AddLiquidity_EnforcesSlippageOnInitialLiquidity() public {
        vm.startPrank(user1);
        token0.approve(address(pool), 10 ether);
        token1.approve(address(pool), 10 ether);

        vm.expectRevert(SlippageExceeded.selector);
        pool.addLiquidity(10 ether, 10 ether, 11 ether, 0, DEADLINE);

        vm.expectRevert(SlippageExceeded.selector);
        pool.addLiquidity(10 ether, 10 ether, 0, 11 ether, DEADLINE);

        vm.stopPrank();
    }

    function test_RemoveLiquidity_ReturnsProportionalTokens() public {
        uint256 liquidity = _addInitialLiquidity(10 ether, 10 ether);

        vm.startPrank(user1);

        uint256 balance0Before = token0.balanceOf(user1);
        uint256 balance1Before = token1.balanceOf(user1);

        (uint256 amount0, uint256 amount1) = pool.removeLiquidity(liquidity / 2, 0, 0, DEADLINE);

        assertEq(amount0, 5 ether);
        assertEq(amount1, 5 ether);
        assertEq(token0.balanceOf(user1) - balance0Before, amount0);
        assertEq(token1.balanceOf(user1) - balance1Before, amount1);
        assertEq(pool.reserve0(), 5 ether);
        assertEq(pool.reserve1(), 5 ether);

        vm.stopPrank();
    }

    function test_RemoveLiquidity_RejectsZeroLiquidity() public {
        vm.startPrank(user1);

        vm.expectRevert(ZeroAmount.selector);
        pool.removeLiquidity(0, 0, 0, DEADLINE);

        vm.stopPrank();
    }

    function test_RemoveLiquidity_RejectsExpiredDeadline() public {
        _addInitialLiquidity(10 ether, 10 ether);

        vm.warp(100);

        vm.startPrank(user1);

        vm.expectRevert(DeadlineExpired.selector);
        pool.removeLiquidity(1 ether, 0, 0, block.timestamp - 1);

        vm.stopPrank();
    }

    function test_RemoveLiquidity_EnforcesSlippageProtection() public {
        uint256 liquidity = _addInitialLiquidity(10 ether, 10 ether);

        vm.startPrank(user1);

        vm.expectRevert(SlippageExceeded.selector);
        pool.removeLiquidity(liquidity, 20 ether, 0, DEADLINE);

        vm.expectRevert(SlippageExceeded.selector);
        pool.removeLiquidity(liquidity, 0, 20 ether, DEADLINE);

        vm.stopPrank();
    }

    function test_Swap_Token0ToToken1() public {
        _addInitialLiquidity(100 ether, 100 ether);

        vm.startPrank(user2);
        token0.approve(address(pool), 1 ether);

        uint256 balanceBefore = token1.balanceOf(user2);
        uint256 amountOut = pool.swap(true, 1 ether, 0, user2, DEADLINE);

        assertGt(amountOut, 0);
        assertEq(token1.balanceOf(user2) - balanceBefore, amountOut);
        assertEq(pool.reserve0(), 101 ether);
        assertEq(pool.reserve1(), 100 ether - amountOut);

        vm.stopPrank();
    }

    function test_Swap_Token1ToToken0() public {
        _addInitialLiquidity(100 ether, 100 ether);

        vm.startPrank(user2);
        token1.approve(address(pool), 1 ether);

        uint256 balanceBefore = token0.balanceOf(user2);
        uint256 amountOut = pool.swap(false, 1 ether, 0, user2, DEADLINE);

        assertGt(amountOut, 0);
        assertEq(token0.balanceOf(user2) - balanceBefore, amountOut);
        assertEq(pool.reserve1(), 101 ether);
        assertEq(pool.reserve0(), 100 ether - amountOut);

        vm.stopPrank();
    }

    function test_Swap_AppliesFee() public {
    _addInitialLiquidity(100 ether, 100 ether);

    vm.startPrank(user2);
    token0.approve(address(pool), 10 ether);

    uint256 amountOut = pool.swap(true, 10 ether, 0, user2, DEADLINE);

    uint256 amountIn = 10 ether;
    uint256 reserveIn = 100 ether;
    uint256 reserveOut = 100 ether;

    uint256 noFeeAmountOut = (amountIn * reserveOut) / (reserveIn + amountIn);

    assertLt(amountOut, noFeeAmountOut);

    vm.stopPrank();
}

    function test_Swap_RejectsZeroInput() public {
        _addInitialLiquidity(10 ether, 10 ether);

        vm.startPrank(user2);

        vm.expectRevert(ZeroAmount.selector);
        pool.swap(true, 0, 0, user2, DEADLINE);

        vm.stopPrank();
    }

    function test_Swap_RejectsZeroRecipient() public {
        _addInitialLiquidity(10 ether, 10 ether);

        vm.startPrank(user2);
        token0.approve(address(pool), 1 ether);

        vm.expectRevert(ZeroAddress.selector);
        pool.swap(true, 1 ether, 0, address(0), DEADLINE);

        vm.stopPrank();
    }

    function test_Swap_RejectsExpiredDeadline() public {
        _addInitialLiquidity(10 ether, 10 ether);

        vm.warp(100);

        vm.startPrank(user2);
        token0.approve(address(pool), 1 ether);

        vm.expectRevert(DeadlineExpired.selector);
        pool.swap(true, 1 ether, 0, user2, block.timestamp - 1);

        vm.stopPrank();
    }

    function test_Swap_EnforcesMinimumOutput() public {
        _addInitialLiquidity(100 ether, 100 ether);

        vm.startPrank(user2);
        token0.approve(address(pool), 1 ether);

        vm.expectRevert(SlippageExceeded.selector);
        pool.swap(true, 1 ether, type(uint256).max, user2, DEADLINE);

        vm.stopPrank();
    }

    function test_Swap_PreservesKInvariant() public {
        _addInitialLiquidity(100 ether, 100 ether);

        uint256 kBefore = pool.reserve0() * pool.reserve1();

        vm.startPrank(user2);
        token0.approve(address(pool), 10 ether);
        pool.swap(true, 10 ether, 0, user2, DEADLINE);
        vm.stopPrank();

        uint256 kAfter = pool.reserve0() * pool.reserve1();

        assertGe(kAfter, kBefore);
    }

    function test_Swap_RejectsWhenNoLiquidity() public {
        vm.startPrank(user2);
        token0.approve(address(pool), 1 ether);

        vm.expectRevert();
        pool.swap(true, 1 ether, 0, user2, DEADLINE);

        vm.stopPrank();
    }

    function test_LPToken_MintOnlyPool() public {
        vm.startPrank(user1);

        vm.expectRevert(LPToken.NotPool.selector);
        lpToken.mint(user1, 1 ether);

        vm.stopPrank();
    }

    function test_LPToken_BurnOnlyPool() public {
        vm.startPrank(user1);

        vm.expectRevert(LPToken.NotPool.selector);
        lpToken.burn(user1, 1 ether);

        vm.stopPrank();
    }
}
