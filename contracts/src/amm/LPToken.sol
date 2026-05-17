// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LPToken is ERC20, Ownable {
    address public pool;

    event PoolSet(address indexed pool);
    event LiquidityMinted(address indexed to, uint256 amount);
    event LiquidityBurned(address indexed from, uint256 amount);

    error NotPool();
    error PoolAlreadySet();
    error ZeroAddress();

    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {}

    modifier onlyPool() {
        if (msg.sender != pool) revert NotPool();
        _;
    }

    function setPool(address pool_) external onlyOwner {
        if (pool_ == address(0)) revert ZeroAddress();
        if (pool != address(0)) revert PoolAlreadySet();

        pool = pool_;

        emit PoolSet(pool_);
    }

    function mint(address to, uint256 amount) external onlyPool {
        if (to == address(0)) revert ZeroAddress();

        _mint(to, amount);

        emit LiquidityMinted(to, amount);
    }

    function burn(address from, uint256 amount) external onlyPool {
        if (from == address(0)) revert ZeroAddress();

        _burn(from, amount);

        emit LiquidityBurned(from, amount);
    }
}
