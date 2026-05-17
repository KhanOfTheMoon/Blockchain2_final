// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {AMMPool} from "../../src/amm/AMMPool.sol";
import {AMMFactory} from "../../src/amm/AMMFactory.sol";
import {LPToken} from "../../src/amm/LPToken.sol";

contract MockAMMFuzzERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000_000 ether);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AMMFuzzTest is Test {
    AMMFactory internal factory;
    AMMPool internal pool;
    LPToken internal lpToken;

    MockAMMFuzzERC20 internal token0;
    MockAMMFuzzERC20 internal token1;

    address internal user1 = address(0x1);
    address internal user2 = address(0x2);

    uint256 internal constant DEADLINE = type(uint256).max;
    uint256 internal constant MAX_FUZZ_AMOUNT = 1_000_000 ether;

    function setUp() public {
        factory = new AMMFactory();

        MockAMMFuzzERC20 tokenA = new MockAMMFuzzERC20("Token A", "TKA");
        MockAMMFuzzERC20 tokenB = new MockAMMFuzzERC20("Token B", "TKB");

        (address poolAddr, address lpTokenAddr) =
            factory.createPool(address(tokenA), address(tokenB), "LP Token", "LP");

        pool = AMMPool(poolAddr);
        lpToken = LPToken(lpTokenAddr);

        token0 = MockAMMFuzzERC20(address(pool.token0()));
        token1 = MockAMMFuzzERC20(address(pool.token1()));

        token0.mint(user1, MAX_FUZZ_AMOUNT);
        token1.mint(user1, MAX_FUZZ_AMOUNT);
        token0.mint(user2, MAX_FUZZ_AMOUNT);
        token1.mint(user2, MAX_FUZZ_AMOUNT);

        vm.startPrank(user1);
        token0.approve(address(pool), MAX_FUZZ_AMOUNT);
        token1.approve(address(pool), MAX_FUZZ_AMOUNT);
        pool.addLiquidity(100 ether, 100 ether, 1, 1, DEADLINE);
        vm.stopPrank();
    }

    function testFuzz_AddLiquidity(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 1e15, 100_000 ether);
        amount1 = bound(amount1, 1e15, 100_000 ether);

        uint256 reserve0Before = pool.reserve0();
        uint256 reserve1Before = pool.reserve1();
        uint256 lpSupplyBefore = lpToken.totalSupply();
        uint256 userLpBefore = lpToken.balanceOf(user2);

        vm.startPrank(user2);
        token0.approve(address(pool), amount0);
        token1.approve(address(pool), amount1);

        uint256 liquidity = pool.addLiquidity(amount0, amount1, 0, 0, DEADLINE);

        vm.stopPrank();

        assertGt(liquidity, 0, "liquidity must be positive");
        assertEq(lpToken.balanceOf(user2), userLpBefore + liquidity, "user LP balance mismatch");
        assertGt(lpToken.totalSupply(), lpSupplyBefore, "LP total supply should increase");

        assertGe(pool.reserve0(), reserve0Before, "reserve0 should not decrease");
        assertGe(pool.reserve1(), reserve1Before, "reserve1 should not decrease");

        assertEq(
            pool.reserve0(), token0.balanceOf(address(pool)), "reserve0 must match token0 balance"
        );
        assertEq(
            pool.reserve1(), token1.balanceOf(address(pool)), "reserve1 must match token1 balance"
        );
    }

    function testFuzz_SwapToken0To1(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e15, 10 ether);

        uint256 kBefore = pool.reserve0() * pool.reserve1();
        uint256 token1BalanceBefore = token1.balanceOf(user2);

        vm.startPrank(user2);
        token0.approve(address(pool), amountIn);

        uint256 amountOut = pool.swap(true, amountIn, 0, user2, DEADLINE);

        vm.stopPrank();

        assertGt(amountOut, 0, "swap output must be positive");
        assertEq(token1.balanceOf(user2), token1BalanceBefore + amountOut, "token1 output mismatch");

        uint256 kAfter = pool.reserve0() * pool.reserve1();

        assertGe(kAfter, kBefore, "k must not decrease after token0 to token1 swap");
        assertEq(
            pool.reserve0(), token0.balanceOf(address(pool)), "reserve0 must match token0 balance"
        );
        assertEq(
            pool.reserve1(), token1.balanceOf(address(pool)), "reserve1 must match token1 balance"
        );
    }

    function testFuzz_SwapToken1To0(uint256 amountIn) public {
        amountIn = bound(amountIn, 1e15, 10 ether);

        uint256 kBefore = pool.reserve0() * pool.reserve1();
        uint256 token0BalanceBefore = token0.balanceOf(user2);

        vm.startPrank(user2);
        token1.approve(address(pool), amountIn);

        uint256 amountOut = pool.swap(false, amountIn, 0, user2, DEADLINE);

        vm.stopPrank();

        assertGt(amountOut, 0, "swap output must be positive");
        assertEq(token0.balanceOf(user2), token0BalanceBefore + amountOut, "token0 output mismatch");

        uint256 kAfter = pool.reserve0() * pool.reserve1();

        assertGe(kAfter, kBefore, "k must not decrease after token1 to token0 swap");
        assertEq(
            pool.reserve0(), token0.balanceOf(address(pool)), "reserve0 must match token0 balance"
        );
        assertEq(
            pool.reserve1(), token1.balanceOf(address(pool)), "reserve1 must match token1 balance"
        );
    }

    function testFuzz_RemoveLiquidity(uint256 lpAmount) public {
        vm.startPrank(user2);
        token0.approve(address(pool), 100 ether);
        token1.approve(address(pool), 100 ether);

        uint256 mintedLiquidity = pool.addLiquidity(100 ether, 100 ether, 0, 0, DEADLINE);
        lpAmount = bound(lpAmount, 1, mintedLiquidity);

        uint256 lpBalanceBefore = lpToken.balanceOf(user2);
        uint256 token0BalanceBefore = token0.balanceOf(user2);
        uint256 token1BalanceBefore = token1.balanceOf(user2);

        (uint256 amount0, uint256 amount1) = pool.removeLiquidity(lpAmount, 0, 0, DEADLINE);

        vm.stopPrank();

        assertGt(amount0, 0, "removed token0 amount must be positive");
        assertGt(amount1, 0, "removed token1 amount must be positive");

        assertEq(lpToken.balanceOf(user2), lpBalanceBefore - lpAmount, "LP should be burned");
        assertEq(token0.balanceOf(user2), token0BalanceBefore + amount0, "token0 return mismatch");
        assertEq(token1.balanceOf(user2), token1BalanceBefore + amount1, "token1 return mismatch");

        assertEq(
            pool.reserve0(), token0.balanceOf(address(pool)), "reserve0 must match token0 balance"
        );
        assertEq(
            pool.reserve1(), token1.balanceOf(address(pool)), "reserve1 must match token1 balance"
        );
    }
}
