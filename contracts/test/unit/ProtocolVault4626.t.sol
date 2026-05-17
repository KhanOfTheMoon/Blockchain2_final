// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProtocolVault4626} from "../../src/vault/ProtocolVault4626.sol";

contract ProtocolVault4626Test is Test {
    ProtocolVault4626 vault;

    // Checklist:
    // - deposit
    // - withdraw
    // - mint
    // - redeem
    // - rounding behavior
    // - preview consistency

    function setUp() public {}
    function test_Deposit() public {}
    function test_Withdraw() public {}
    function test_Mint() public {}
    function test_Redeem() public {}
}
