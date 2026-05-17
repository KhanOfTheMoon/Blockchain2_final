// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UpgradeableVaultV1} from "./UpgradeableVaultV1.sol";

contract UpgradeableVaultV2 is UpgradeableVaultV1 {
    /// @dev Storage layout extension:
    /// slots 0-50 are inherited from V1 and must not be reordered.
    /// slot 51: withdrawalFeeBps, consuming one slot from V1's original reserved gap.
    /// slots 52-100: reserved for future V2-compatible upgrades.
    uint256 public withdrawalFeeBps;

    event WithdrawalFeeUpdated(uint256 withdrawalFeeBps);

    function initializeV2(uint256 initialWithdrawalFeeBps) external reinitializer(2) onlyOwner {
        withdrawalFeeBps = initialWithdrawalFeeBps;
        emit WithdrawalFeeUpdated(initialWithdrawalFeeBps);
    }

    function setWithdrawalFeeBps(uint256 newFeeBps) external onlyOwner {
        withdrawalFeeBps = newFeeBps;
        emit WithdrawalFeeUpdated(newFeeBps);
    }

    uint256[49] private __gapV2;
}
