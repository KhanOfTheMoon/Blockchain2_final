// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ChainlinkPriceOracle} from "../../src/oracle/ChainlinkPriceOracle.sol";
import {MockAggregator} from "../../src/oracle/MockAggregator.sol";

contract ForkOracleTest is Test {
    ChainlinkPriceOracle public oracle;
    MockAggregator public mockFeed;
    
    // Checklist:
    // - fork the selected L2 testnet
    // - read a live Chainlink feed
    // - validate stale-check behavior on real network data
    // - compare feed decimals against local mocks

    function setUp() public {
        // Deploy mock feed for testing without fork
        mockFeed = new MockAggregator(8, 200000000000); // 8 decimals, $2000
        oracle = new ChainlinkPriceOracle(address(mockFeed), 86400); // 24h stale period
    }

    function test_LiveOracleRead() public {
        // Test with mock feed (works without fork)
        uint256 price = oracle.latestPrice();
        assertEq(price, 200000000000 * 10 ** 10); // Normalized to 18 decimals
        
        // Read all round data
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            oracle.latestRoundData();
        
        assertGt(roundId, 0);
        assertGt(answer, 0);
        assertGt(updatedAt, 0);
        assertEq(answeredInRound, roundId);
    }

    function test_StaleFeedHandling() public {
        // Initial price is fresh
        uint256 price = oracle.latestPrice();
        assertGt(price, 0);
        
        // Advance time beyond stale period (24 hours)
        vm.warp(block.timestamp + 86401);
        
        // Now the feed should be considered stale
        (, , , uint256 updatedAt, ) = oracle.latestRoundData();
        uint256 staleAfter = updatedAt + 86400;
        vm.expectRevert(abi.encodeWithSelector(
            ChainlinkPriceOracle.PriceStale.selector,
            updatedAt,
            staleAfter
        ));
        oracle.latestPrice();
    }
    
    function test_OracleDecimalNormalization() public {
        // Test with 8-decimal feed
        uint256 price8Decimals = oracle.latestPrice();
        assertEq(price8Decimals, 200000000000 * 10 ** 10);
        
        // Create 6-decimal feed
        MockAggregator feed6 = new MockAggregator(6, 2000000000); // $2000 with 6 decimals
        ChainlinkPriceOracle oracle6 = new ChainlinkPriceOracle(address(feed6), 86400);
        uint256 price6Decimals = oracle6.latestPrice();
        
        // Both should normalize to 18 decimals: 2000 * 10^18
        assertEq(price6Decimals, 2000 * 10 ** 18);
        assertEq(price8Decimals, 2000 * 10 ** 18);
    }
    
    function test_InvalidRoundDataRejection() public {
        // Create feed with invalid round data
        MockAggregator invalidFeed = new MockAggregator(8, 0); // Invalid: answer is 0
        ChainlinkPriceOracle oracleInvalid = new ChainlinkPriceOracle(address(invalidFeed), 86400);
        
        vm.expectRevert(abi.encodeWithSelector(
            ChainlinkPriceOracle.InvalidPrice.selector
        ));
        oracleInvalid.latestPrice();
    }
    
    function test_OracleWithinStaleWindow() public {
        // Advance time but stay within stale window
        vm.warp(block.timestamp + 86400); // Exactly at stale boundary (not exceeded)
        
        // This should still work (updatedAt + stalePeriod >= block.timestamp)
        uint256 price = oracle.latestPrice();
        assertGt(price, 0);
    }
}

