// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AMMPool} from "./AMMPool.sol";
import {LPToken} from "./LPToken.sol";
import {PoolAlreadyExists, ZeroAddress} from "../utils/Errors.sol";

contract AMMFactory {
    mapping(address => mapping(address => address)) public getPool;

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        address pool,
        address lpToken,
        bytes32 salt,
        bool deterministic
    );

    function createPool(
        address tokenA,
        address tokenB,
        string calldata lpName,
        string calldata lpSymbol
    ) external returns (address pool, address lpToken) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        if (getPool[token0][token1] != address(0)) revert PoolAlreadyExists();

        LPToken lp = new LPToken(lpName, lpSymbol);
        AMMPool newPool = new AMMPool(address(this), token0, token1, address(lp));
        lp.setPool(address(newPool));

        getPool[token0][token1] = address(newPool);
        emit PoolCreated(token0, token1, address(newPool), address(lp), bytes32(0), false);
        return (address(newPool), address(lp));
    }

    function createPoolDeterministic(
        address tokenA,
        address tokenB,
        string calldata lpName,
        string calldata lpSymbol,
        bytes32 salt
    ) external returns (address pool, address lpToken) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        if (getPool[token0][token1] != address(0)) revert PoolAlreadyExists();

        bytes32 lpSalt = keccak256(abi.encodePacked("LP", token0, token1, salt));
        bytes32 poolSalt = keccak256(abi.encodePacked("POOL", token0, token1, salt));

        LPToken lp = new LPToken{salt: lpSalt}(lpName, lpSymbol);
        AMMPool newPool = new AMMPool{salt: poolSalt}(address(this), token0, token1, address(lp));
        lp.setPool(address(newPool));

        getPool[token0][token1] = address(newPool);
        emit PoolCreated(token0, token1, address(newPool), address(lp), salt, true);
        return (address(newPool), address(lp));
    }

    /// @notice Predicts the pool address for the deterministic CREATE2 path.
    /// @dev The LP token is also created deterministically, so its salt must stay in sync with the deploy path.
    function predictDeterministicAddress(
        address tokenA,
        address tokenB,
        string calldata lpName,
        string calldata lpSymbol,
        bytes32 salt
    ) external view returns (address predictedPool) {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        bytes32 lpSalt = keccak256(abi.encodePacked("LP", token0, token1, salt));
        bytes32 poolSalt = keccak256(abi.encodePacked("POOL", token0, token1, salt));

        bytes memory lpBytecode = abi.encodePacked(type(LPToken).creationCode, abi.encode(lpName, lpSymbol));
        address predictedLp = _computeAddress(lpSalt, keccak256(lpBytecode));

        bytes memory poolBytecode = abi.encodePacked(
            type(AMMPool).creationCode,
            abi.encode(address(this), token0, token1, predictedLp)
        );
        predictedPool = _computeAddress(poolSalt, keccak256(poolBytecode));
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert ZeroAddress();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address predicted) {
        predicted = address(
            uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash))))
        );
    }
}
