// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {UpgradeableVaultV1} from "../../src/vault/UpgradeableVaultV1.sol";
import {UpgradeableVaultV2} from "../../src/vault/UpgradeableVaultV2.sol";

contract UpgradeableVaultTest is Test {
    UpgradeableVaultV1 v1;

    // Checklist:
    // - initialize once
    // - deposit and withdraw accounting
    // - UUPS authorization
    // - storage gap compatibility
    // - upgrade to V2 keeps state intact

    function setUp() public {}
    function test_Initialize() public {}
    function test_DepositWithdrawAccounting() public {}
    function test_UpgradeAuthorization() public {}
    function test_UpgradeToV2PreservesState() public {}
}
