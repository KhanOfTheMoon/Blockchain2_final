// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {MyGovernor} from "../src/governance/MyGovernor.sol";
import {GovernanceToken} from "../src/token/GovernanceToken.sol";
import {MembershipNFT} from "../src/token/MembershipNFT.sol";
import {Treasury} from "../src/governance/Treasury.sol";
import {AMMFactory} from "../src/amm/AMMFactory.sol";
import {ChainlinkPriceOracle} from "../src/oracle/ChainlinkPriceOracle.sol";
import {UpgradeableVaultV1} from "../src/vault/UpgradeableVaultV1.sol";
import {MockAggregator} from "../src/oracle/MockAggregator.sol";

contract Deploy is Script {
    uint256 public constant TIMELOCK_DELAY = 2 days;
    uint256 public constant DEFAULT_ORACLE_STALE_PERIOD = 1 days;
    uint8 public constant DEFAULT_MOCK_FEED_DECIMALS = 8;
    uint256 public constant DEFAULT_MOCK_FEED_ANSWER = 2_000e8;

    function run()
        external
        returns (
            address governanceToken,
            address timelock,
            address governor,
            address treasury,
            address ammFactory,
            address oracle,
            address vaultImplementation,
            address vaultProxy
        )
    {
        address executor = vm.envOr("TIMELOCK_EXECUTOR", address(0));
        address chainlinkFeed = vm.envOr("CHAINLINK_FEED_ADDRESS", address(0));
        uint256 oracleStalePeriod = vm.envOr("ORACLE_STALE_PERIOD", DEFAULT_ORACLE_STALE_PERIOD);
        uint8 mockFeedDecimals = uint8(vm.envOr("MOCK_FEED_DECIMALS", uint256(DEFAULT_MOCK_FEED_DECIMALS)));
        uint256 mockFeedAnswer = vm.envOr("MOCK_FEED_INITIAL_ANSWER", DEFAULT_MOCK_FEED_ANSWER);

        vm.startBroadcast();

        GovernanceToken token = new GovernanceToken();
        MembershipNFT membershipNft = new MembershipNFT();

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        TimelockController deployedTimelock =
            new TimelockController(TIMELOCK_DELAY, proposers, executors, msg.sender);

        MyGovernor deployedGovernor = new MyGovernor(token, deployedTimelock);
        Treasury deployedTreasury = new Treasury(address(deployedTimelock));
        AMMFactory factory = new AMMFactory();

        if (chainlinkFeed == address(0)) {
            MockAggregator mockAggregator = new MockAggregator(mockFeedDecimals, int256(mockFeedAnswer));
            chainlinkFeed = address(mockAggregator);
            console2.log("MockAggregator:", chainlinkFeed);
        }
        ChainlinkPriceOracle priceOracle = new ChainlinkPriceOracle(chainlinkFeed, oracleStalePeriod);

        UpgradeableVaultV1 upgradeableVaultImplementation = new UpgradeableVaultV1();
        bytes memory vaultInitData = abi.encodeCall(UpgradeableVaultV1.initialize, (address(deployedTimelock)));
        ERC1967Proxy upgradeableVaultProxy =
            new ERC1967Proxy(address(upgradeableVaultImplementation), vaultInitData);

        deployedTimelock.grantRole(deployedTimelock.PROPOSER_ROLE(), address(deployedGovernor));
        deployedTimelock.grantRole(deployedTimelock.CANCELLER_ROLE(), address(deployedGovernor));
        deployedTimelock.grantRole(deployedTimelock.EXECUTOR_ROLE(), executor);
        deployedTimelock.revokeRole(deployedTimelock.TIMELOCK_ADMIN_ROLE(), msg.sender);

        vm.stopBroadcast();

        governanceToken = address(token);
        timelock = address(deployedTimelock);
        governor = address(deployedGovernor);
        treasury = address(deployedTreasury);
        ammFactory = address(factory);
        oracle = address(priceOracle);
        vaultImplementation = address(upgradeableVaultImplementation);
        vaultProxy = address(upgradeableVaultProxy);

        console2.log("GovernanceToken:", governanceToken);
        console2.log("TimelockController:", timelock);
        console2.log("MyGovernor:", governor);
        console2.log("Treasury:", treasury);
        console2.log("AMMFactory:", ammFactory);
        console2.log("ChainlinkPriceOracle:", oracle);
        console2.log("UpgradeableVaultV1 implementation:", vaultImplementation);
        console2.log("UpgradeableVaultV1 proxy:", vaultProxy);
        console2.log("MembershipNFT:", address(membershipNft));
        membershipNft;
    }
}
