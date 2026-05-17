// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainlinkPriceOracle} from "../../src/oracle/ChainlinkPriceOracle.sol";

contract ChainlinkPriceOracleTest is Test {
    ChainlinkPriceOracle oracle;

    // Checklist:
    // - latestRoundData passthrough
    // - stale price revert
    // - decimals normalization
    // - negative/zero price rejection

    function setUp() public {}
    function test_LatestPrice() public {}
    function test_StalePriceReverts() public {}
    function test_Normalization() public {}
}
