# Blockchain Final Project Template

## Project Overview
This repository is a scaffold for a full-stack DeFi Super-App built around an AMM, an ERC4626 vault, a governance token, a Governor + Timelock DAO, and a Chainlink price oracle.

This is a template only. It includes contract skeletons, test stubs, documentation templates, a frontend shell, a subgraph scaffold, and CI placeholders.

## Scenario
Default scenario: **DeFi Super-App with AMM + ERC4626 Vault + DAO + Chainlink Price Oracle**.

## Architecture Summary
- Smart contracts live in `contracts/` and are organized by domain.
- The frontend lives in `frontend/` and is written with React + Vite.
- The Graph scaffold lives in `subgraph/`.
- Design and audit templates live in `docs/`.
- CI is in `.github/workflows/ci.yml`.

## Contracts
- Governance token: `GovernanceToken.sol`
- Membership NFT: `MembershipNFT.sol`
- Governor: `MyGovernor.sol`
- Treasury: `Treasury.sol`
- AMM pool and factory: `AMMPool.sol`, `AMMFactory.sol`, `LPToken.sol`
- ERC4626 vault: `ProtocolVault4626.sol`
- Upgradeable vaults: `UpgradeableVaultV1.sol`, `UpgradeableVaultV2.sol`
- Oracle: `ChainlinkPriceOracle.sol`, `MockAggregator.sol`
- Utilities: `YulMath.sol`, `Errors.sol`

## Installation
### Contracts
```bash
cd contracts
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
forge install smartcontractkit/chainlink-brownie-contracts
forge install foundry-rs/forge-std
```

### Frontend
```bash
cd frontend
npm install
```

## Test Commands
### Foundry tests
```bash
cd contracts
forge test
```

### Fuzz and invariant templates
```bash
cd contracts
forge test --match-path test/fuzz
forge test --match-path test/invariant
```

### Fork tests
```bash
cd contracts
forge test --match-path test/fork
```

### Security case studies
```bash
cd contracts
forge test --match-path test/security
```

## Coverage Commands
```bash
cd contracts
forge coverage
```

## Slither Commands
```bash
cd contracts
slither .
```

## Deployment Commands
Full deployment notes are in `docs/DEPLOYMENT.md`.

### Build
```bash
cd contracts
forge build
```

### Test
```bash
cd contracts
forge test
```

### Local deployment
Start a local chain:

```bash
anvil
```

Deploy:

```bash
cd contracts
forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

### L2 testnet deployment
```bash
cd contracts
forge script script/Deploy.s.sol:Deploy --rpc-url $L2_RPC_URL --broadcast --verify
```

### Verify deployment wiring
```bash
cd contracts
forge script script/VerifyDeployment.s.sol:VerifyDeployment --rpc-url $L2_RPC_URL
```

### Upgrade vault V1 to V2
```bash
cd contracts
forge script script/UpgradeVault.s.sol:UpgradeVault \
  --sig "run(address,address)" \
  $VAULT_ADDRESS \
  0x0000000000000000000000000000000000000000 \
  --rpc-url $L2_RPC_URL \
  --broadcast
```

## Governance and Upgrade Parameters
- Governor clock mode: timestamp-based via `GovernanceToken.clock()`, so voting values are seconds.
- Voting delay: `1 days`.
- Voting period: `1 weeks`.
- Quorum: `4%`.
- Proposal threshold: `10,000 GOV`, or `1%` of the initial `1,000,000 GOV` supply.
- Timelock delay: `2 days`.
- Timelock proposer/canceller: Governor.
- Timelock executor: `TIMELOCK_EXECUTOR`, defaulting to `address(0)`.
- Timelock admin: deployer admin is revoked after setup.
- Treasury: controlled by Timelock through `Treasury.timelock()`.
- Upgradeable vault: `UpgradeableVaultV1` is deployed behind an `ERC1967Proxy`; proxy owner is Timelock.
- Upgrade path: `UpgradeableVaultV1 -> UpgradeableVaultV2`, preserving V1 storage layout and adding V2 state after existing V1 variables.

## Frontend Commands
```bash
cd frontend
npm run dev
npm run build
npm run preview
```

## Subgraph Commands
```bash
# Fill in ABI files, generated types, and network details before running.
```

## Deployed Addresses
| Contract | Address | Notes |
| --- | --- | --- |
| GovernanceToken | TBD | Fill after deployment |
| Governor | TBD | Fill after deployment |
| Timelock | TBD | Fill after deployment |
| Treasury | TBD | Fill after deployment |
| AMMFactory | TBD | Fill after deployment |
| UpgradeableVaultV1 proxy | TBD | Fill after deployment |
| UpgradeableVaultV1 implementation | TBD | Fill after deployment |
| ChainlinkPriceOracle | TBD | Fill after deployment |

## Verified Explorer Links
- GovernanceToken: TBD
- Governor: TBD
- Treasury: TBD
- AMMFactory: TBD
- UpgradeableVaultV1 proxy: TBD
- UpgradeableVaultV1 implementation: TBD
- ChainlinkPriceOracle: TBD

## Known Limitations
- This repository is not a finished protocol.
- Contract logic is intentionally incomplete in several places.
- Subgraph ABI bindings must be generated and linked.
- Frontend wallet, network, and transaction flows are placeholders.
- Deployment still needs real L2 addresses and explorer verification links after broadcast.

## Team Contributions
Fill in `docs/TEAM_CONTRIBUTIONS.md` with owner-by-owner responsibilities, review areas, and demo tasks.

## Next Steps
1. Replace the placeholder logic in the contracts with production implementations.
2. Add the OpenZeppelin and Chainlink dependencies to the Foundry project.
3. Generate the subgraph ABI bindings and wire event handlers.
4. Connect the frontend to real wallet, chain, and GraphQL data sources.
5. Run the audit, gas, and architecture templates against the completed codebase.
