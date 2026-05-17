// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Treasury} from "../../src/governance/Treasury.sol";

contract TreasuryTest is Test {
    Treasury treasury;

    // Checklist:
    // - receive ETH
    // - timelock-only withdrawals
    // - ERC20 withdrawals via SafeERC20
    // - ETH withdrawals via call
    // - zero address protections

    function setUp() public {}
    function test_ReceiveEth() public {}
    function test_WithdrawERC20() public {}
    function test_WithdrawETH() public {}
    function test_OnlyTimelockCanWithdraw() public {}
}
