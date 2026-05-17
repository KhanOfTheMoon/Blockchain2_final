// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {UpgradeableVaultV1} from "../src/vault/UpgradeableVaultV1.sol";
import {UpgradeableVaultV2} from "../src/vault/UpgradeableVaultV2.sol";

contract UpgradeVault is Script {
    function run(address proxyAddress, address newImplementation) external {
        // TODO: wire the final proxy admin path and upgrade authorization flow.
        // TODO: submit the upgrade through governance or a timelock-controlled executor.
        proxyAddress;
        newImplementation;
    }

    function deployV2Implementation() external returns (address implementation) {
        vm.startBroadcast();
        UpgradeableVaultV2 v2 = new UpgradeableVaultV2();
        vm.stopBroadcast();
        implementation = address(v2);
    }
}
