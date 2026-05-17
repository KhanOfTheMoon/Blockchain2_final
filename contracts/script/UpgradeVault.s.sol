// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {UpgradeableVaultV2} from "../src/vault/UpgradeableVaultV2.sol";

interface IUUPSUpgrade {
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

interface ITimelockExecute {
    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;
}

contract UpgradeVault is Script {
    function run(address proxyAddress, address newImplementation) external {
        address implementation = newImplementation;
        if (implementation == address(0)) {
            implementation = _deployV2();
        }

        bytes memory initData = _buildInitData();
        bytes memory upgradeCall = abi.encodeCall(IUUPSUpgrade.upgradeToAndCall, (implementation, initData));
        address timelock = vm.envOr("UPGRADE_TIMELOCK_ADDRESS", address(0));

        vm.startBroadcast();
        if (timelock == address(0)) {
            IUUPSUpgrade(proxyAddress).upgradeToAndCall(implementation, initData);
        } else {
            bytes32 predecessor = vm.envOr("UPGRADE_TIMELOCK_PREDECESSOR", bytes32(0));
            bytes32 salt = vm.envOr("UPGRADE_TIMELOCK_SALT", bytes32(0));
            ITimelockExecute(timelock).execute(proxyAddress, 0, upgradeCall, predecessor, salt);
        }
        vm.stopBroadcast();

        console2.log("UpgradeableVault proxy:", proxyAddress);
        console2.log("UpgradeableVaultV2 implementation:", implementation);
        console2.log("Upgrade caller:", timelock == address(0) ? msg.sender : timelock);
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
