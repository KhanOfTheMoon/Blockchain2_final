// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UpgradeableVaultV1} from "./UpgradeableVaultV1.sol";

contract UpgradeableVaultV2 is UpgradeableVaultV1 {
    uint256 public withdrawalFeeBps;

    event WithdrawalFeeUpdated(uint256 withdrawalFeeBps);

    function initializeV2(uint256 initialWithdrawalFeeBps) external reinitializer(2) {
        withdrawalFeeBps = initialWithdrawalFeeBps;
        emit WithdrawalFeeUpdated(initialWithdrawalFeeBps);
    }

    function setWithdrawalFeeBps(uint256 newFeeBps) external onlyOwner {
        withdrawalFeeBps = newFeeBps;
        emit WithdrawalFeeUpdated(newFeeBps);
    }

    uint256[49] private __gapV2;
}
