// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {GovernanceToken} from "../src/token/GovernanceToken.sol";
import {MembershipNFT} from "../src/token/MembershipNFT.sol";
import {Treasury} from "../src/governance/Treasury.sol";
import {AMMFactory} from "../src/amm/AMMFactory.sol";
import {ProtocolVault4626} from "../src/vault/ProtocolVault4626.sol";
import {UpgradeableVaultV1} from "../src/vault/UpgradeableVaultV1.sol";
import {MockAggregator} from "../src/oracle/MockAggregator.sol";

contract Deploy is Script {
    function run() external returns (address governanceToken, address governor, address treasury) {
        // TODO: replace placeholder deployment ordering with the final production wiring.
        // TODO: deploy TimelockController, register proposer/executor roles, then hand control to governance.
        vm.startBroadcast();

        GovernanceToken token = new GovernanceToken();
        MembershipNFT membershipNft = new MembershipNFT();
        MockAggregator mockAggregator = new MockAggregator(8, 2_000_000_000_000);
        Treasury deployedTreasury = new Treasury(msg.sender);
        AMMFactory factory = new AMMFactory();
        ProtocolVault4626 vault = new ProtocolVault4626(token, "Protocol Vault Share", "pVAULT");
        UpgradeableVaultV1 upgradeableVault = new UpgradeableVaultV1();

        vm.stopBroadcast();

        governanceToken = address(token);
        governor = address(0); // TODO: replace with a real governor deployment after timelock setup.
        treasury = address(deployedTreasury);
        membershipNft;
        mockAggregator;
        factory;
        vault;
        upgradeableVault;
    }
}
