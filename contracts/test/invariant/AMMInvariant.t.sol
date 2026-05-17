// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {AMMPool} from "../../src/amm/AMMPool.sol";
import {AMMFactory} from "../../src/amm/AMMFactory.sol";
import {LPToken} from "../../src/amm/LPToken.sol";

contract MockAMMInvariantERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AMMHandler is Test {
    AMMPool public pool;
    LPToken public lpToken;
    MockAMMInvariantERC20 public token0;
    MockAMMInvariantERC20 public token1;

    uint256 public successfulAdds;
    uint256 public successfulRemoves;
    uint256 public successfulSwaps;

    uint256 internal constant DEADLINE = type(uint256).max;

    constructor(
        AMMPool pool_,
        LPToken lpToken_,
        MockAMMInvariantERC20 token0_,
        MockAMMInvariantERC20 token1_
    ) {
        pool = pool_;
        lpToken = lpToken_;
        token0 = token0_;
        token1 = token1_;
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external {
        amount0 = bound(amount0, 1e15, 100 ether);
        amount1 = bound(amount1, 1e15, 100 ether);

        token0.mint(address(this), amount0);
        token1.mint(address(this), amount1);

        token0.approve(address(pool), amount0);
        token1.approve(address(pool), amount1);

        try pool.addLiquidity(amount0, amount1, 0, 0, DEADLINE) returns (uint256 liquidity) {
            assertGt(liquidity, 0, "liquidity must be positive");
            successfulAdds++;
        } catch {}
    }

    function swap0to1(uint256 amountIn) external {
        amountIn = bound(amountIn, 1e15, 10 ether);

        uint256 kBefore = pool.reserve0() * pool.reserve1();

        token0.mint(address(this), amountIn);
        token0.approve(address(pool), amountIn);

        try pool.swap(true, amountIn, 0, address(this), DEADLINE) returns (uint256 amountOut) {
            assertGt(amountOut, 0, "swap output must be positive");

            uint256 kAfter = pool.reserve0() * pool.reserve1();

            assertGe(kAfter, kBefore, "k must not decrease after swap0to1");
            successfulSwaps++;
        } catch {}
    }

    function swap1to0(uint256 amountIn) external {
        amountIn = bound(amountIn, 1e15, 10 ether);

        uint256 kBefore = pool.reserve0() * pool.reserve1();

        token1.mint(address(this), amountIn);
        token1.approve(address(pool), amountIn);

        try pool.swap(false, amountIn, 0, address(this), DEADLINE) returns (uint256 amountOut) {
            assertGt(amountOut, 0, "swap output must be positive");

            uint256 kAfter = pool.reserve0() * pool.reserve1();

            assertGe(kAfter, kBefore, "k must not decrease after swap1to0");
            successfulSwaps++;
        } catch {}
    }

    function removeLiquidity(uint256 lpAmount) external {
        uint256 handlerLpBalance = lpToken.balanceOf(address(this));
        if (handlerLpBalance == 0) return;

        lpAmount = bound(lpAmount, 1, handlerLpBalance);

        try pool.removeLiquidity(lpAmount, 0, 0, DEADLINE) returns (
            uint256 amount0, uint256 amount1
        ) {
            assertGt(amount0, 0, "removed token0 amount must be positive");
            assertGt(amount1, 0, "removed token1 amount must be positive");

            successfulRemoves++;
        } catch {}
    }
}

contract AMMInvariantTest is StdInvariant, Test {
    AMMFactory internal factory;
    AMMPool internal pool;
    LPToken internal lpToken;

    MockAMMInvariantERC20 internal token0;
    MockAMMInvariantERC20 internal token1;

    AMMHandler internal handler;

    function setUp() public {
        factory = new AMMFactory();

        MockAMMInvariantERC20 tokenA = new MockAMMInvariantERC20("Token A", "TKA");
        MockAMMInvariantERC20 tokenB = new MockAMMInvariantERC20("Token B", "TKB");

        (address poolAddr, address lpTokenAddr) =
            factory.createPool(address(tokenA), address(tokenB), "LP Token", "LP");

        pool = AMMPool(poolAddr);
        lpToken = LPToken(lpTokenAddr);

        token0 = MockAMMInvariantERC20(address(pool.token0()));
        token1 = MockAMMInvariantERC20(address(pool.token1()));

        token0.mint(address(this), 1_000 ether);
        token1.mint(address(this), 1_000 ether);

        token0.approve(address(pool), 1_000 ether);
        token1.approve(address(pool), 1_000 ether);

        pool.addLiquidity(100 ether, 100 ether, 1, 1, type(uint256).max);

        handler = new AMMHandler(pool, lpToken, token0, token1);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = AMMHandler.addLiquidity.selector;
        selectors[1] = AMMHandler.swap0to1.selector;
        selectors[2] = AMMHandler.swap1to0.selector;
        selectors[3] = AMMHandler.removeLiquidity.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_ReservesMatchActualTokenBalances() public view {
        assertEq(
            pool.reserve0(),
            token0.balanceOf(address(pool)),
            "reserve0 must equal actual token0 balance"
        );

        assertEq(
            pool.reserve1(),
            token1.balanceOf(address(pool)),
            "reserve1 must equal actual token1 balance"
        );
    }

    function invariant_LPSupplyEqualsKnownBalances() public view {
        uint256 knownBalances = lpToken.balanceOf(address(this))
            + lpToken.balanceOf(address(handler)) + lpToken.balanceOf(address(0));

        assertEq(
            lpToken.totalSupply(), knownBalances, "LP total supply must equal known LP balances"
        );
    }

    function invariant_PositiveSupplyHasPositiveReserves() public view {
        if (lpToken.totalSupply() > 0) {
            assertGt(pool.reserve0(), 0, "positive LP supply should have token0 reserves");
            assertGt(pool.reserve1(), 0, "positive LP supply should have token1 reserves");
        }
    }

    function invariant_PoolAddressMatchesFactory() public view {
        assertEq(
            factory.getPool(address(token0), address(token1)),
            address(pool),
            "factory should return pool for token0-token1"
        );

        assertEq(
            factory.getPool(address(token1), address(token0)),
            address(pool),
            "factory should return pool for token1-token0"
        );
    }
}
