// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {UpgradeableVaultV1} from "../src/vault/UpgradeableVaultV1.sol";
import {UpgradeableVaultV2} from "../src/vault/UpgradeableVaultV2.sol";

interface IUUPSUpgrade {
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

contract UpgradeVault is Script {
    function run(address proxyAddress, address newImplementation) external {
        address implementation = newImplementation;
        if (implementation == address(0)) {
            implementation = _deployV2();
        }

        bytes memory data = _buildInitData();

        vm.startBroadcast();
        IUUPSUpgrade(proxyAddress).upgradeToAndCall(implementation, data);
        vm.stopBroadcast();
    }

    function deployV2Implementation() external returns (address implementation) {
        implementation = _deployV2();
    }

    function _deployV2() private returns (address implementation) {
        vm.startBroadcast();
        UpgradeableVaultV2 v2 = new UpgradeableVaultV2();
        vm.stopBroadcast();
        implementation = address(v2);
    }

    function _buildInitData() private view returns (bytes memory data) {
        bool runInit = vm.envOr("UPGRADE_CALL_INIT", false);
        if (!runInit) {
            return bytes("");
        }

        uint256 feeBps = vm.envOr("UPGRADE_WITHDRAWAL_FEE_BPS", uint256(0));
        data = abi.encodeCall(UpgradeableVaultV2.initializeV2, (feeBps));
    }
}
