// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AMMFactory} from "../../src/amm/AMMFactory.sol";

contract AMMFactoryTest is Test {
    AMMFactory factory;

    // Checklist:
    // - createPool with CREATE
    // - createPoolDeterministic with CREATE2
    // - predictable deterministic address
    // - duplicate pool prevention

    function setUp() public {}
    function test_CreatePool() public {}
    function test_CreatePoolDeterministic() public {}
    function test_PredictDeterministicAddress() public {}
}
