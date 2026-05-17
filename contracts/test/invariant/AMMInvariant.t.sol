// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StdInvariant, Test} from "forge-std/Test.sol";

contract AMMInvariantTest is StdInvariant, Test {
    // Checklist:
    // - reserve product does not break under bounded actions
    // - LP supply remains coherent with reserves
    // - swaps preserve non-negative reserves

    function setUp() public {}
    function invariant_ReservesRemainSane() public {}
    function invariant_LPSupplyCoherent() public {}
}
