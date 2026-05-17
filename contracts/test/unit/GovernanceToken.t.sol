// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../../src/token/GovernanceToken.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken token;

    // Checklist:
    // - initial supply minting
    // - delegation changes voting power
    // - permit signatures
    // - voting snapshots after transfers
    // - revert paths for disabled minting

    function setUp() public {
        token = new GovernanceToken();
    }

    function test_InitialSupply() public {}
    function test_DelegationSupport() public {}
    function test_PermitFlow() public {}
    function test_VotingSnapshotAfterTransfer() public {}
    function test_MintDisabled() public {}
}
