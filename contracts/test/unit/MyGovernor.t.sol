// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../../src/token/GovernanceToken.sol";
import {MyGovernor} from "../../src/governance/MyGovernor.sol";

contract MyGovernorTest is Test {
    GovernanceToken token;
    MyGovernor governor;

    // Checklist:
    // - voting delay equals 1 day
    // - voting period equals 1 week
    // - quorum equals 4%
    // - proposal threshold equals 1%
    // - queue and execute via timelock

    function setUp() public {}
    function test_Parameters() public {}
    function test_ProposalCreation() public {}
    function test_VoteCounting() public {}
    function test_QueueAndExecuteFlow() public {}
}
