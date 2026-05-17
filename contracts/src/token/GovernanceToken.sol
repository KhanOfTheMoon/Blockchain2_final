// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;

    event VotingPowerDelegated(address indexed delegator, address indexed delegatee);
    event InitialSupplyMinted(address indexed to, uint256 amount);

    error MintDisabled();

    constructor() ERC20("Governance Token", "GOV") ERC20Permit("Governance Token") {
        _mint(msg.sender, INITIAL_SUPPLY);
        emit InitialSupplyMinted(msg.sender, INITIAL_SUPPLY);
    }

    /// @notice Voting power snapshots are captured by ERC20Votes at each transfer/delegation checkpoint.
    /// @dev Users must delegate to themselves or another address to activate governance voting power.
    function delegateVotingPower(address delegatee) external {
        delegate(delegatee);
        emit VotingPowerDelegated(msg.sender, delegatee);
    }

    /// @notice Placeholder for future mint logic if the token design changes.
    function mint(address /*to*/, uint256 /*amount*/) external pure {
        revert MintDisabled();
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
