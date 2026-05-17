// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error ZeroAddress();
error ZeroAmount();
error InsufficientBalance();
error InsufficientLiquidity();
error SlippageExceeded();
error DeadlineExpired();
error Unauthorized();
error StalePrice(uint256 updatedAt, uint256 staleAfter);
error InvalidPrice();
error PoolAlreadyExists();
error PoolNotFound();
error MintNotImplemented();
error BurnNotImplemented();
