// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {LPToken} from "./LPToken.sol";
import {DeadlineExpired, InsufficientLiquidity, SlippageExceeded, ZeroAddress, ZeroAmount} from "../utils/Errors.sol";

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

    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address factory_, address token0_, address token1_, address lpToken_) {
        if (factory_ == address(0) || token0_ == address(0) || token1_ == address(0) || lpToken_ == address(0)) {
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

    /// @notice Constant-product AMM template with 0.3% fee and slippage checks.
    /// @dev TODO: harden the first-liquidity path, dust handling, and fee-on-transfer edge cases.
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external nonReentrant deadlineNotExpired(deadline) returns (uint256 liquidity) {
        if (amount0Desired == 0 || amount1Desired == 0) revert ZeroAmount();

        uint256 amount0 = amount0Desired;
        uint256 amount1 = amount1Desired;

        if (reserve0 != 0 && reserve1 != 0) {
            uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) revert SlippageExceeded();
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
                if (amount0Optimal < amount0Min) revert SlippageExceeded();
                amount0 = amount0Optimal;
            }
            liquidity = Math.min((amount0 * lpToken.totalSupply()) / reserve0, (amount1 * lpToken.totalSupply()) / reserve1);
        } else {
            if (amount0 < amount0Min || amount1 < amount1Min) revert SlippageExceeded();
            liquidity = Math.sqrt(amount0 * amount1);
        }

        if (liquidity == 0) revert InsufficientLiquidity();

        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        reserve0 += amount0;
        reserve1 += amount1;
        lpToken.mint(msg.sender, liquidity);

        emit LiquidityAdded(msg.sender, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external nonReentrant deadlineNotExpired(deadline) returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) revert ZeroAmount();

        uint256 totalSupply = lpToken.totalSupply();
        amount0 = (liquidity * reserve0) / totalSupply;
        amount1 = (liquidity * reserve1) / totalSupply;
        if (amount0 < amount0Min || amount1 < amount1Min) revert SlippageExceeded();

        lpToken.burn(msg.sender, liquidity);
        reserve0 -= amount0;
        reserve1 -= amount1;
        token0.safeTransfer(msg.sender, amount0);
        token1.safeTransfer(msg.sender, amount1);

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

        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut < amountOutMin) revert SlippageExceeded();

        tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        tokenOut.safeTransfer(to, amountOut);

        if (zeroForOne) {
            reserve0 = reserveIn + amountIn;
            reserve1 = reserveOut - amountOut;
        } else {
            reserve1 = reserveIn + amountIn;
            reserve0 = reserveOut - amountOut;
        }

        emit Swap(msg.sender, address(tokenIn), address(tokenOut), amountIn, amountOut);
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - FEE_BPS);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * BPS_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
