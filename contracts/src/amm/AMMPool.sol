// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {LPToken} from "./LPToken.sol";
import {
    DeadlineExpired,
    InsufficientLiquidity,
    SlippageExceeded,
    ZeroAddress,
    ZeroAmount
} from "../utils/Errors.sol";

contract AMMPool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BPS = 30;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    address public immutable factory;
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    LPToken public immutable lpToken;

    uint256 public reserve0;
    uint256 public reserve1;

    event LiquidityAdded(
        address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity
    );

    event Swap(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address recipient
    );

    constructor(address factory_, address token0_, address token1_, address lpToken_) {
        if (
            factory_ == address(0) || token0_ == address(0) || token1_ == address(0)
                || lpToken_ == address(0)
        ) {
            revert ZeroAddress();
        }

        factory = factory_;
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        lpToken = LPToken(lpToken_);
    }

    modifier deadlineNotExpired(uint256 deadline) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        _;
    }

    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external nonReentrant deadlineNotExpired(deadline) returns (uint256 liquidity) {
        if (amount0Desired == 0 || amount1Desired == 0) revert ZeroAmount();

        uint256 amount0ToTransfer = amount0Desired;
        uint256 amount1ToTransfer = amount1Desired;

        uint256 totalSupply = lpToken.totalSupply();

        if (reserve0 != 0 || reserve1 != 0) {
            if (reserve0 == 0 || reserve1 == 0 || totalSupply == 0) {
                revert InsufficientLiquidity();
            }

            uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;

            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) revert SlippageExceeded();
                amount1ToTransfer = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
                if (amount0Optimal < amount0Min) revert SlippageExceeded();
                amount0ToTransfer = amount0Optimal;
            }
        } else {
            if (amount0Desired < amount0Min || amount1Desired < amount1Min) {
                revert SlippageExceeded();
            }
        }

        uint256 balance0Before = token0.balanceOf(address(this));
        uint256 balance1Before = token1.balanceOf(address(this));

        token0.safeTransferFrom(msg.sender, address(this), amount0ToTransfer);
        token1.safeTransferFrom(msg.sender, address(this), amount1ToTransfer);

        uint256 balance0After = token0.balanceOf(address(this));
        uint256 balance1After = token1.balanceOf(address(this));

        uint256 amount0Actual = balance0After - balance0Before;
        uint256 amount1Actual = balance1After - balance1Before;

        if (amount0Actual == 0 || amount1Actual == 0) revert ZeroAmount();
        if (amount0Actual < amount0Min || amount1Actual < amount1Min) {
            revert SlippageExceeded();
        }

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0Actual * amount1Actual);
        } else {
            liquidity = Math.min(
                (amount0Actual * totalSupply) / reserve0, (amount1Actual * totalSupply) / reserve1
            );
        }

        if (liquidity == 0) revert InsufficientLiquidity();

        _updateReserves(balance0After, balance1After);

        lpToken.mint(msg.sender, liquidity);

        emit LiquidityAdded(msg.sender, amount0Actual, amount1Actual, liquidity);
    }

    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    )
        external
        nonReentrant
        deadlineNotExpired(deadline)
        returns (uint256 amount0, uint256 amount1)
    {
        if (liquidity == 0) revert ZeroAmount();

        uint256 totalSupply = lpToken.totalSupply();
        if (totalSupply == 0) revert InsufficientLiquidity();

        amount0 = (liquidity * reserve0) / totalSupply;
        amount1 = (liquidity * reserve1) / totalSupply;

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();
        if (amount0 < amount0Min || amount1 < amount1Min) revert SlippageExceeded();

        lpToken.burn(msg.sender, liquidity);

        token0.safeTransfer(msg.sender, amount0);
        token1.safeTransfer(msg.sender, amount1);

        _syncReserves();

        emit LiquidityRemoved(msg.sender, amount0, amount1, liquidity);
    }

    function swap(
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external nonReentrant deadlineNotExpired(deadline) returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        IERC20 tokenIn = zeroForOne ? token0 : token1;
        IERC20 tokenOut = zeroForOne ? token1 : token0;

        uint256 reserveIn = zeroForOne ? reserve0 : reserve1;
        uint256 reserveOut = zeroForOne ? reserve1 : reserve0;

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 oldK = reserve0 * reserve1;

        uint256 balanceInBefore = tokenIn.balanceOf(address(this));
        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 balanceInAfter = tokenIn.balanceOf(address(this));

        uint256 amountInActual = balanceInAfter - balanceInBefore;
        if (amountInActual == 0) revert ZeroAmount();

        amountOut = _getAmountOut(amountInActual, reserveIn, reserveOut);

        if (amountOut == 0) revert InsufficientLiquidity();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();
        if (amountOut < amountOutMin) revert SlippageExceeded();

        tokenOut.safeTransfer(to, amountOut);

        _syncReserves();

        if (reserve0 * reserve1 < oldK) revert InsufficientLiquidity();

        emit Swap(msg.sender, address(tokenIn), address(tokenOut), amountInActual, amountOut, to);
    }

    function getReserves() external view returns (uint256 reserve0_, uint256 reserve1_) {
        return (reserve0, reserve1);
    }

    function getAmountOut(bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        uint256 reserveIn = zeroForOne ? reserve0 : reserve1;
        uint256 reserveOut = zeroForOne ? reserve1 : reserve0;

        return _getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - FEE_BPS);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * BPS_DENOMINATOR) + amountInWithFee;

        amountOut = numerator / denominator;
    }

    function _syncReserves() internal {
        reserve0 = token0.balanceOf(address(this));
        reserve1 = token1.balanceOf(address(this));
    }

    function _updateReserves(uint256 newReserve0, uint256 newReserve1) internal {
        reserve0 = newReserve0;
        reserve1 = newReserve1;
    }
}
