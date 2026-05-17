// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract UpgradeableVaultV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @dev Storage layout:
    /// slot 0: totalDeposits
    /// slot 1: balances mapping seed
    /// slot 2: depositCap
    /// slots 3-50: reserved upgrade gap. V2 consumes the next compatible slot after this range.
    uint256 public totalDeposits;
    mapping(address => uint256) public balances;
    uint256 public depositCap;

    event Deposited(address indexed user, uint256 amount, uint256 totalDeposits);
    event Withdrawn(address indexed user, uint256 amount, uint256 totalDeposits);
    event DepositCapUpdated(uint256 depositCap);

    error CapExceeded();
    error InsufficientBalance();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        depositCap = type(uint256).max;
    }

    /// @notice Placeholder accounting-only deposit path to be replaced with real asset transfers.
    function deposit(uint256 amount) external {
        if (totalDeposits + amount > depositCap) revert CapExceeded();
        balances[msg.sender] += amount;
        totalDeposits += amount;
        emit Deposited(msg.sender, amount, totalDeposits);
    }

    /// @notice Placeholder withdraw path to be replaced with safe asset transfers.
    function withdraw(uint256 amount) external {
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        emit Withdrawn(msg.sender, amount, totalDeposits);
    }

    function setDepositCap(uint256 newCap) external onlyOwner {
        depositCap = newCap;
        emit DepositCapUpdated(newCap);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[48] private __gap;
}
