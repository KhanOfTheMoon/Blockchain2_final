// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AMMPool} from "../../src/amm/AMMPool.sol";

contract AMMPoolTest is Test {
    AMMPool pool;

    // Checklist:
    // - add liquidity
    // - remove liquidity
    // - swap x * y = k behavior
    // - 0.3% fee application
    // - slippage checks
    // - reentrancy resistance

    function setUp() public {}
    function test_AddLiquidity() public {}
    function test_RemoveLiquidity() public {}
    function test_Swap() public {}
    function test_SlippageRevert() public {}
}
