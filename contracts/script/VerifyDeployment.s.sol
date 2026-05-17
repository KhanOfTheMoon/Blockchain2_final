// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IGovernorDeploymentView {
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function proposalThreshold() external view returns (uint256);
    function quorum(uint256 timepoint) external view returns (uint256);
    function timelock() external view returns (address);
}

interface ITimelockDeploymentView {
    function TIMELOCK_ADMIN_ROLE() external view returns (bytes32);
    function PROPOSER_ROLE() external view returns (bytes32);
    function EXECUTOR_ROLE() external view returns (bytes32);
    function getMinDelay() external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface ITreasuryDeploymentView {
    function timelock() external view returns (address);
}

interface IOwnableDeploymentView {
    function owner() external view returns (address);
}

interface IUUPSDeploymentView {
    function proxiableUUID() external view returns (bytes32);
}

contract VerifyDeployment is Script {
    uint256 private constant EXPECTED_VOTING_DELAY = 1 days;
    uint256 private constant EXPECTED_VOTING_PERIOD = 1 weeks;
    uint256 private constant EXPECTED_PROPOSAL_THRESHOLD = 10_000 ether;
    uint256 private constant EXPECTED_QUORUM = 40_000 ether;
    uint256 private constant EXPECTED_TIMELOCK_DELAY = 2 days;
    bytes32 private constant ERC1967_IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    error VerificationFailed(string check);

    function run() external view {
        address deployer = vm.envOr("DEPLOYER_ADDRESS", tx.origin);
        address governor = vm.envAddress("GOVERNOR_ADDRESS");
        address timelock = vm.envAddress("TIMELOCK_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address vaultProxy = vm.envAddress("VAULT_ADDRESS");
        address expectedImplementation = vm.envAddress("VAULT_IMPLEMENTATION_ADDRESS");
        address expectedExecutor = vm.envOr("TIMELOCK_EXECUTOR", address(0));
        uint256 quorumTimepoint = vm.envOr("VERIFY_QUORUM_TIMEPOINT", block.timestamp);

        _requireNonZero(governor, "governor address is zero");
        _requireNonZero(timelock, "timelock address is zero");
        _requireNonZero(treasury, "treasury address is zero");
        _requireNonZero(vaultProxy, "vault proxy address is zero");
        _requireNonZero(expectedImplementation, "vault implementation address is zero");

        IGovernorDeploymentView governorView = IGovernorDeploymentView(governor);
        ITimelockDeploymentView timelockView = ITimelockDeploymentView(timelock);
        ITreasuryDeploymentView treasuryView = ITreasuryDeploymentView(treasury);
        IOwnableDeploymentView vaultOwnerView = IOwnableDeploymentView(vaultProxy);

        _requireEq(governorView.votingDelay(), EXPECTED_VOTING_DELAY, "invalid voting delay");
        _requireEq(governorView.votingPeriod(), EXPECTED_VOTING_PERIOD, "invalid voting period");
        _requireEq(governorView.proposalThreshold(), EXPECTED_PROPOSAL_THRESHOLD, "invalid proposal threshold");
        _requireEq(governorView.quorum(quorumTimepoint), EXPECTED_QUORUM, "invalid quorum");
        _requireEq(governorView.timelock(), timelock, "governor timelock mismatch");
        _requireEq(timelockView.getMinDelay(), EXPECTED_TIMELOCK_DELAY, "invalid timelock delay");

        _requireTrue(
            timelockView.hasRole(timelockView.PROPOSER_ROLE(), governor),
            "governor missing proposer role"
        );
        _requireTrue(
            timelockView.hasRole(timelockView.EXECUTOR_ROLE(), expectedExecutor),
            "expected executor missing executor role"
        );
        _requireFalse(
            timelockView.hasRole(timelockView.TIMELOCK_ADMIN_ROLE(), deployer),
            "deployer still has timelock admin role"
        );

        _requireEq(treasuryView.timelock(), timelock, "treasury is not timelock-controlled");
        _requireEq(vaultOwnerView.owner(), timelock, "vault proxy owner is not timelock");
        _requireFalse(vaultOwnerView.owner() == deployer, "deployer owns upgradeable vault");

        address actualImplementation = _implementationOf(vaultProxy);
        _requireEq(actualImplementation, expectedImplementation, "proxy implementation mismatch");
        _requireEq(
            uint256(IUUPSDeploymentView(actualImplementation).proxiableUUID()),
            uint256(ERC1967_IMPLEMENTATION_SLOT),
            "implementation is not UUPS-compatible"
        );

        console2.log("Deployment verification passed");
        console2.log("Governor:", governor);
        console2.log("Timelock:", timelock);
        console2.log("Treasury:", treasury);
        console2.log("Vault proxy:", vaultProxy);
        console2.log("Vault implementation:", actualImplementation);
        console2.log("Executor role holder:", expectedExecutor);
        console2.log("Deployer checked:", deployer);
    }

    function _implementationOf(address proxyAddress) private view returns (address implementation) {
        implementation = address(uint160(uint256(vm.load(proxyAddress, ERC1967_IMPLEMENTATION_SLOT))));
    }

    function _requireNonZero(address value, string memory check) private pure {
        if (value == address(0)) revert VerificationFailed(check);
    }

    function _requireEq(address actual, address expected, string memory check) private pure {
        if (actual != expected) revert VerificationFailed(check);
    }

    function _requireEq(uint256 actual, uint256 expected, string memory check) private pure {
        if (actual != expected) revert VerificationFailed(check);
    }

    function _requireTrue(bool value, string memory check) private pure {
        if (!value) revert VerificationFailed(check);
    }

    function _requireFalse(bool value, string memory check) private pure {
        if (value) revert VerificationFailed(check);
    }
}
