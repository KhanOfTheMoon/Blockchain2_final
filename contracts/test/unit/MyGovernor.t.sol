// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {GovernanceToken} from "../../src/token/GovernanceToken.sol";
import {MyGovernor} from "../../src/governance/MyGovernor.sol";
import {Treasury} from "../../src/governance/Treasury.sol";

contract MyGovernorTest is Test {
    uint256 private constant TIMELOCK_DELAY = 2 days;
    uint256 private constant VOTING_DELAY = 1 days;
    uint256 private constant VOTING_PERIOD = 1 weeks;
    uint256 private constant PROPOSAL_THRESHOLD = 10_000 ether;
    uint8 private constant VOTE_AGAINST = 0;
    uint8 private constant VOTE_FOR = 1;

    address private proposer = address(0xA11CE);
    address private forVoter = address(0xB0B);
    address private againstVoter = address(0xCAFE);
    address payable private recipient = payable(address(0xD00D));

    GovernanceToken private token;
    TimelockController private timelock;
    MyGovernor private governor;
    Treasury private treasury;

    function setUp() public {
        vm.warp(100);

        token = new GovernanceToken();

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, address(this));
        governor = new MyGovernor(token, timelock);
        treasury = new Treasury(address(timelock));

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), address(this));

        token.delegate(address(this));
        vm.warp(block.timestamp + 1);
    }

    function test_Parameters() public {
        assertEq(governor.votingDelay(), VOTING_DELAY);
        assertEq(governor.votingPeriod(), VOTING_PERIOD);
        assertEq(governor.proposalThreshold(), PROPOSAL_THRESHOLD);
        assertEq(governor.quorum(block.timestamp - 1), 40_000 ether);
        assertEq(governor.timelock(), address(timelock));
        assertEq(timelock.getMinDelay(), TIMELOCK_DELAY);
    }

    function test_DelegationAndVotingPower() public {
        token.transfer(forVoter, 25_000 ether);

        vm.prank(forVoter);
        token.delegate(forVoter);

        vm.warp(block.timestamp + 1);

        assertEq(token.delegates(forVoter), forVoter);
        assertEq(token.getVotes(forVoter), 25_000 ether);
    }

    function test_ProposalCreationAboveThreshold() public {
        uint256 proposalId = _proposeTreasuryWithdraw("proposal above threshold");

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));
        assertGt(governor.proposalSnapshot(proposalId), block.timestamp);
    }

    function test_ProposalCreationBelowThresholdReverts() public {
        token.transfer(proposer, PROPOSAL_THRESHOLD - 1);
        vm.prank(proposer);
        token.delegate(proposer);
        vm.warp(block.timestamp + 1);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _treasuryWithdrawProposal(0);

        vm.prank(proposer);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "below threshold");
    }

    function test_FullLifecycleProposeVoteQueueExecute() public {
        uint256 amount = 1 ether;
        vm.deal(address(treasury), amount);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _treasuryWithdrawProposal(amount);
        string memory description = "withdraw treasury ETH";
        bytes32 descriptionHash = keccak256(bytes(description));

        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        _advanceToActive(proposalId);
        governor.castVote(proposalId, VOTE_FOR);

        _advancePastDeadline(proposalId);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        vm.expectRevert();
        governor.execute{value: 0}(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute{value: 0}(targets, values, calldatas, descriptionHash);

        assertEq(recipient.balance, amount);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }

    function test_ProposalDefeatedWhenQuorumNotMet() public {
        token.transfer(proposer, PROPOSAL_THRESHOLD);
        vm.prank(proposer);
        token.delegate(proposer);
        vm.warp(block.timestamp + 1);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _treasuryWithdrawProposal(0);
        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "no quorum");

        _advanceToActive(proposalId);
        vm.prank(proposer);
        governor.castVote(proposalId, VOTE_FOR);

        _advancePastDeadline(proposalId);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    function test_ProposalDefeatedWhenMajorityVotesAgainst() public {
        token.transfer(proposer, PROPOSAL_THRESHOLD);
        token.transfer(forVoter, 50_000 ether);
        token.transfer(againstVoter, 100_000 ether);

        vm.prank(proposer);
        token.delegate(proposer);
        vm.prank(forVoter);
        token.delegate(forVoter);
        vm.prank(againstVoter);
        token.delegate(againstVoter);
        vm.warp(block.timestamp + 1);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _treasuryWithdrawProposal(0);
        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, "majority against");

        _advanceToActive(proposalId);
        vm.prank(forVoter);
        governor.castVote(proposalId, VOTE_FOR);
        vm.prank(againstVoter);
        governor.castVote(proposalId, VOTE_AGAINST);

        _advancePastDeadline(proposalId);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    function test_TimelockDelayIsEnforced() public {
        uint256 proposalId = _passAndQueueProposal("delay enforced", 0);

        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _treasuryWithdrawProposal(0);
        vm.expectRevert();
        governor.execute(targets, values, calldatas, keccak256(bytes("delay enforced")));

        vm.warp(block.timestamp + TIMELOCK_DELAY);
        governor.execute(targets, values, calldatas, keccak256(bytes("delay enforced")));
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }

    function test_TreasuryGovernanceCallSucceedsThroughTimelock() public {
        vm.deal(address(treasury), 1 ether);

        uint256 proposalId = _passAndQueueProposal("treasury governed", 0.25 ether);
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _treasuryWithdrawProposal(0.25 ether);
        governor.execute(targets, values, calldatas, keccak256(bytes("treasury governed")));

        assertEq(recipient.balance, 0.25 ether);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    }

    function _proposeTreasuryWithdraw(string memory description) private returns (uint256) {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _treasuryWithdrawProposal(0);
        return governor.propose(targets, values, calldatas, description);
    }

    function _passAndQueueProposal(string memory description, uint256 amount) private returns (uint256 proposalId) {
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            _treasuryWithdrawProposal(amount);
        bytes32 descriptionHash = keccak256(bytes(description));

        proposalId = governor.propose(targets, values, calldatas, description);
        _advanceToActive(proposalId);
        governor.castVote(proposalId, VOTE_FOR);
        _advancePastDeadline(proposalId);
        governor.queue(targets, values, calldatas, descriptionHash);
    }

    function _treasuryWithdrawProposal(uint256 amount)
        private
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = address(treasury);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(Treasury.withdrawETH, (recipient, amount));
    }

    function _advanceToActive(uint256 proposalId) private {
        vm.warp(governor.proposalSnapshot(proposalId) + 1);
    }

    function _advancePastDeadline(uint256 proposalId) private {
        vm.warp(governor.proposalDeadline(proposalId) + 1);
    }
}
