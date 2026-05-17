# Deployment Notes

This project deploys the governance system, treasury, oracle adapter, AMM factory, and an upgradeable UUPS vault through `contracts/script/Deploy.s.sol`.

## Required Environment

Set these values before deploying:

```bash
export L2_RPC_URL=
export DEPLOYER_PRIVATE_KEY=
export DEPLOYER_ADDRESS=
export TIMELOCK_EXECUTOR=0x0000000000000000000000000000000000000000
export CHAINLINK_FEED_ADDRESS=0x0000000000000000000000000000000000000000
export ORACLE_STALE_PERIOD=86400
export MOCK_FEED_DECIMALS=8
export MOCK_FEED_INITIAL_ANSWER=200000000000
```

`CHAINLINK_FEED_ADDRESS=0x0000000000000000000000000000000000000000` deploys a local `MockAggregator`. For an L2 testnet deployment, set it to the selected Chainlink feed address.

After deployment, fill:

```bash
export GOVERNOR_ADDRESS=
export TIMELOCK_ADDRESS=
export TREASURY_ADDRESS=
export VAULT_ADDRESS=
export VAULT_IMPLEMENTATION_ADDRESS=
```

## Commands

Build:

```bash
cd contracts
forge build
```

Run tests:

```bash
cd contracts
forge test
```

Local deployment:

```bash
anvil
cd contracts
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

L2 testnet deployment:

```bash
cd contracts
forge script script/Deploy.s.sol:Deploy --rpc-url $L2_RPC_URL --broadcast --verify
```

Verify deployed wiring:

```bash
cd contracts
forge script script/VerifyDeployment.s.sol:VerifyDeployment --rpc-url $L2_RPC_URL
```

Upgrade the vault from V1 to V2:

```bash
cd contracts
forge script script/UpgradeVault.s.sol:UpgradeVault \
  --sig "run(address,address)" \
  $VAULT_ADDRESS \
  0x0000000000000000000000000000000000000000 \
  --rpc-url $L2_RPC_URL \
  --broadcast
```

Passing `address(0)` as the second argument deploys a fresh `UpgradeableVaultV2` implementation. Set `UPGRADE_CALL_INIT=true` and `UPGRADE_WITHDRAWAL_FEE_BPS=<fee>` to call `initializeV2` during the upgrade.

## Governance Parameters

`MyGovernor` uses OpenZeppelin Governor with timestamp-based voting checkpoints. `GovernanceToken.clock()` returns `Time.timestamp()`, so Governor delay and period values are seconds, not blocks.

Configured values:

- Voting delay: `1 days`
- Voting period: `1 weeks`
- Quorum: `4%`
- Proposal threshold: `10,000 GOV`, equal to `1%` of the `1,000,000 GOV` initial supply
- Timelock delay: `2 days`

Because the clock is timestamp-based, no L2 block-time conversion is needed.

## Timelock Roles

`Deploy.s.sol` creates `TimelockController` with a temporary deployer admin, deploys `MyGovernor`, then assigns:

- Proposer: `MyGovernor`
- Canceller: `MyGovernor`
- Executor: `TIMELOCK_EXECUTOR`, defaulting to `address(0)` for open execution
- Admin: deployer admin is revoked after role setup

The deployer should not retain `TIMELOCK_ADMIN_ROLE` after deployment.

## Treasury Control

`Treasury` is constructed with the Timelock address. Its withdrawal functions are guarded by `onlyTimelock`, so direct deployer calls cannot withdraw ETH or ERC20 tokens. Treasury actions must be executed through the governance lifecycle:

```text
propose -> vote -> queue -> execute
```

## UUPS Vault

`Deploy.s.sol` deploys:

- `UpgradeableVaultV1` implementation
- `ERC1967Proxy` initialized with `UpgradeableVaultV1.initialize(timelock)`

The proxy owner is the Timelock. This means upgrades are authorized by the Timelock-controlled owner, not by the deployer.

## Upgrade Path

The supported path is:

```text
UpgradeableVaultV1 implementation -> ERC1967Proxy -> UpgradeableVaultV2 implementation
```

`UpgradeableVaultV2` inherits `UpgradeableVaultV1`, appends `withdrawalFeeBps`, and does not reorder V1 state. Existing V1 storage is:

- `totalDeposits`
- `balances`
- `depositCap`
- reserved storage gap

V2 consumes the next compatible storage slot after V1 state and preserves balances, total deposits, owner, and vault config.

## Post-Deployment Verification

`VerifyDeployment.s.sol` fails loudly if any invariant is broken. It checks:

- Governor, Timelock, Treasury, vault proxy, and implementation addresses are non-zero
- Governor voting delay, period, quorum, proposal threshold, and Timelock address
- Timelock delay is `2 days`
- Governor has proposer role
- expected executor has executor role
- deployer does not retain Timelock admin role
- Treasury is Timelock-controlled
- vault proxy owner is Timelock
- proxy implementation matches `VAULT_IMPLEMENTATION_ADDRESS`
- implementation is UUPS-compatible
