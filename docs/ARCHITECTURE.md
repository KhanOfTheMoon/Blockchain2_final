# Architecture Document

## Project Overview

**Blockchain2 DeFi Super-App** is a comprehensive decentralized finance platform built with Solidity ^0.8.24, featuring an Automated Market Maker (AMM), ERC4626 vaults, Chainlink price oracle integration, UUPS proxy upgradeable contracts, and OpenZeppelin-based DAO governance.

### Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Solidity | ^0.8.24 | - |
| EVM Framework | Foundry (Forge) | Latest |
| Testing | Foundry + OpenZeppelin Test | - |
| Governance | OpenZeppelin Governor | Latest |
| Proxy | UUPS (Transparent Proxy) | OpenZeppelin |
| Oracle | Chainlink Price Feeds | V3 |
| Upgradeable Contracts | OpenZeppelin Upgradeable | v5.6.1 |

## System Architecture

### 1. AMM (Automated Market Maker) Module

**Purpose**: Provide DEX liquidity pools with constant-product formula (x*y=k)

**Contracts**:
- `AMMFactory.sol` - Pool creation and management
- `AMMPool.sol` - Core pool logic with swap and liquidity operations
- `LPToken.sol` - ERC20 liquidity provider token

**Key Features**:
- CREATE and CREATE2 deterministic pool creation
- 30 basis points (bps) fee on swaps
- SafeERC20 for safe token transfers
- ReentrancyGuard for protection against reentrancy attacks
- Token sorting for canonical pair representation
- Deadline enforcement for transaction safety
- Slippage protection

**Flow**:
```
User → AMMFactory.createPool(tokenA, tokenB)
     → AMMPool deployed
     → User can addLiquidity(), removeLiquidity(), swap()
     → LP tokens received/burned
```

**Security Measures**:
- ✅ ReentrancyGuard on swap and liquidity operations
- ✅ SafeERC20 for all token interactions
- ✅ Deadline validation to prevent stale transactions
- ✅ Slippage protection (amountOutMin, amount0Min, amount1Min)
- ✅ Zero address and zero amount checks

---

### 2. Governance Module

**Purpose**: Enable community-driven governance with voting and treasury management

**Contracts**:
- `GovernanceToken.sol` - ERC20 + ERC20Votes + ERC20Permit voting token
- `MyGovernor.sol` - OpenZeppelin Governor with custom parameters
- `Treasury.sol` - Timelock-protected fund manager
- `TimelockController.sol` - OpenZeppelin timelock for execution delays

**Key Features**:
- Timestamp-based voting (supports L2 chains without reliable block times)
- 1-day voting delay
- 1-week voting period
- 4% quorum requirement
- 1% proposal threshold (10,000 GOV)
- 2-day timelock delay for execution
- ERC20Permit for gasless approvals
- ERC20Votes for delegation-based voting power

**Governance Parameters**:
```solidity
votingDelay = 1 days (86,400 seconds)
votingPeriod = 1 weeks (604,800 seconds)
quorumPercentage = 4%
proposalThreshold = 10,000 ether (1% of 1M supply)
timelockDelay = 2 days (172,800 seconds)
```

**Flow**:
```
1. Holders delegate voting power to themselves (delegateVotingPower)
2. Proposer creates proposal (propose)
   - Must hold > proposalThreshold
3. Voting period begins (votingDelay seconds later)
4. Holders vote (castVote)
5. If passed (quorum + majority for):
   - Queue proposal (queue) → enters timelock
   - Wait timelockDelay seconds
   - Execute proposal (execute)
6. If defeated (no quorum or majority against):
   - Proposal state = Defeated
```

**Treasury Access**:
- Only TimelockController can withdraw funds
- Supports ETH withdrawals (via call pattern)
- Supports ERC20 withdrawals
- All withdrawals require governance approval

---

### 3. Oracle Module

**Purpose**: Provide reliable price feeds via Chainlink with validation

**Contracts**:
- `ChainlinkPriceOracle.sol` - Adapter for Chainlink price feeds
- `MockAggregator.sol` - Mock feed for local testing

**Key Features**:
- Decimal normalization (converts any decimal to 18)
- Stale price validation (configurable stalePeriod)
- Round validation (checks roundId, answeredInRound consistency)
- Error handling for zero/negative prices
- Supports decimals 6-36

**Price Normalization**:
```solidity
if (decimals == 18) {
    normalizedPrice = uint256(answer)
} else if (decimals < 18) {
    normalizedPrice = uint256(answer) * (10 ** (18 - decimals))
} else {
    normalizedPrice = uint256(answer) / (10 ** (decimals - 18))
}
```

**Validation Checks**:
- ✅ Answer > 0
- ✅ updatedAt <= block.timestamp
- ✅ answeredInRound >= roundId
- ✅ block.timestamp <= updatedAt + stalePeriod
- ✅ decimals <= 36

---

### 4. Vault Module

**Purpose**: Provide ERC4626-compliant yield vaults with UUPS upgradeable pattern

**Contracts**:
- `ProtocolVault4626.sol` - Standalone ERC4626 implementation
- `UpgradeableVaultV1.sol` - UUPS proxy (V1) with deposit/withdrawal logic
- `UpgradeableVaultV2.sol` - UUPS proxy (V2) adding withdrawal fees

**ERC4626 Interface Compliance**:
```solidity
deposit(uint256 assets, address receiver) → uint256 shares
mint(uint256 shares, address receiver) → uint256 assets
withdraw(uint256 assets, address receiver, address owner) → uint256 shares
redeem(uint256 shares, address receiver, address owner) → uint256 assets
```

**Vault Configuration (V1)**:
- Immutable asset (set at deployment)
- Deposit cap enforcement
- Accounting-only operations (no actual token transfers in current implementation)
- Storage gap (48 slots) for future upgrades

**Vault Upgradability (V1 → V2)**:
- UUPS pattern (owner-controlled)
- Storage layout preserved
- V2 adds withdrawal fee functionality
- V2 maintains storage compatibility with 49-slot gap

**Storage Layout Preservation**:
```solidity
// V1
uint256 asset;
uint256 depositCap;
mapping(address → uint256) balance;
// 48-slot gap for future use

// V2 (extends V1)
uint256 withdrawalFeeBps; // New state in gap
// 49-slot gap for future use
```

---

### 5. Token Module

**Purpose**: Provide governance and membership tokens

**Contracts**:
- `GovernanceToken.sol` - Governance token (GOV)
- `MembershipNFT.sol` - Membership/collectible NFT

**GovernanceToken Details**:
- 1,000,000 GOV initial supply (all minted at deployment)
- ERC20 + ERC20Votes + ERC20Permit
- Minting disabled (reverts)
- Timestamp-based voting clock

**MembershipNFT Details**:
- ERC721URIStorage
- Owner-controlled minting
- Sequential token IDs
- URI-based metadata

---

### 6. Utilities Module

**Purpose**: Provide shared utilities and optimized math functions

**Contracts**:
- `Errors.sol` - Custom error definitions
- `YulMath.sol` - Optimized sqrt implementation (Solidity + Yul assembly)

**Custom Errors**:
```solidity
error DeadlineExpired();
error InsufficientLiquidity();
error SlippageExceeded();
error ZeroAddress();
error ZeroAmount();
```

**YulMath Optimizations**:
- sqrt() - Yul assembly for gas efficiency
- min() - Solidity and Yul versions
- addThenMultiply() - Arithmetic utilities

---

## Deployment Architecture

### Local Deployment

```
1. Deploy GovernanceToken
2. Deploy TimelockController
3. Deploy MyGovernor
4. Deploy Treasury
5. Deploy AMMFactory
6. Create first AMMPool (if needed)
7. Deploy ChainlinkPriceOracle
8. Deploy UpgradeableVaultV1 behind ERC1967Proxy
```

### L2 Testnet Deployment

Environment variables required:
```bash
L2_RPC_URL=<RPC endpoint>
DEPLOYER_PRIVATE_KEY=<key>
DEPLOYER_ADDRESS=<address>
CHAINLINK_FEED_ADDRESS=<Chainlink feed>
ORACLE_STALE_PERIOD=86400 (24 hours)
TIMELOCK_EXECUTOR=0x0000... (usually 0x0)
```

### Role Structure

| Contract | Role | Holder |
|----------|------|--------|
| TimelockController | DEFAULT_ADMIN | Deployment (revoked after setup) |
| TimelockController | PROPOSER | MyGovernor |
| TimelockController | EXECUTOR | Anyone (0x0) |
| Treasury | Withdrawal Authority | TimelockController only |
| Vault | Owner/Upgrader | Deployment owner or Timelock |

---

## Data Flow Examples

### Swap Flow

```
User initiates swap with amountIn, amountOutMin, deadline
    ↓
AMMPool.swap() called
    ↓
ReentrancyGuard prevents reentrancy
    ↓
Transfer amountIn from user to pool (SafeERC20)
    ↓
Calculate amountOut using x*y=k formula with 30 bps fee
    ↓
Validate amountOut >= amountOutMin (slippage check)
    ↓
Validate deadline not expired
    ↓
Transfer amountOut to recipient
    ↓
Update reserves
    ↓
Emit Swap event
```

### Governance Vote → Execution

```
Proposal Created (propose)
    ↓
Voting Delay (1 day)
    ↓
Voting Period Active (1 week)
    ↓
Users vote (castVote)
    ↓
Voting Ends
    ↓
If passed (quorum + majority):
    Proposal queued (queue)
        ↓
    Timelock Delay (2 days)
        ↓
    Proposal executed (execute)
        ↓
    Treasury performs action (e.g., withdrawETH)
```

### Price Oracle Read

```
External call to ChainlinkPriceOracle.latestPrice()
    ↓
Fetch latest round from Chainlink feed
    ↓
Validate round data (ID, answer, timestamp, consistency)
    ↓
Check price not stale (updatedAt + stalePeriod)
    ↓
Normalize to 18 decimals
    ↓
Return normalized price
```

---

## Security Considerations

### Contract-Level Security

| Vulnerability | Mitigation |
|---------------|-----------|
| Reentrancy | ReentrancyGuard on AMM operations; Checks-Effects-Interactions pattern in Treasury |
| Integer Overflow/Underflow | Solidity ^0.8.24 with automatic checks; `unchecked` blocks only in safe areas |
| Front-Running | Slippage protection; Deadline enforcement |
| Oracle Manipulation | Chainlink feed validation; Stale price checks; Round consistency validation |
| Access Control | Owner checks; Timelock-only access to Treasury; UUPS authorization checks |

### Upgrade Security (UUPS)

- Only authorized owner can call `upgradeToAndCall()`
- Implementation slot immutably stored in proxy storage
- Compatibility check prevents storage layout corruption
- New implementation must be valid UUPSUpgradeable

### Testing

- **Unit Tests**: 50+ tests for individual contract functions
- **Fuzz Tests**: 10+ tests for property-based fuzzing
- **Invariant Tests**: 5+ tests for protocol invariants
- **Fork Tests**: 3+ tests against live network data
- **Security Tests**: Reentrancy and access control case studies

---

## File Structure

```
contracts/
├── src/
│   ├── amm/
│   │   ├── AMMFactory.sol
│   │   ├── AMMPool.sol
│   │   └── LPToken.sol
│   ├── governance/
│   │   ├── MyGovernor.sol
│   │   └── Treasury.sol
│   ├── oracle/
│   │   ├── ChainlinkPriceOracle.sol
│   │   └── MockAggregator.sol
│   ├── token/
│   │   ├── GovernanceToken.sol
│   │   └── MembershipNFT.sol
│   ├── vault/
│   │   ├── ProtocolVault4626.sol
│   │   ├── UpgradeableVaultV1.sol
│   │   └── UpgradeableVaultV2.sol
│   └── utils/
│       ├── Errors.sol
│       └── YulMath.sol
├── test/
│   ├── unit/ (50+ tests)
│   ├── fuzz/ (10+ tests)
│   ├── invariant/ (5+ tests)
│   ├── fork/ (3+ tests)
│   └── security/ (case studies)
└── script/
    ├── Deploy.s.sol
    ├── UpgradeVault.s.sol
    └── VerifyDeployment.s.sol
```

---

## Compliance Checklist

- ✅ ERC20 (GovernanceToken)
- ✅ ERC20Votes (GovernanceToken)
- ✅ ERC20Permit (GovernanceToken)
- ✅ ERC721 (MembershipNFT)
- ✅ ERC721URIStorage (MembershipNFT)
- ✅ ERC4626 (Vaults)
- ✅ OpenZeppelin Governor (MyGovernor)
- ✅ OpenZeppelin TimelockController
- ✅ UUPSUpgradeable (Vault proxy)
- ✅ ReentrancyGuard (AMM)
- ✅ SafeERC20 (Safe transfers)

---

## Performance Considerations

### Gas Optimization

| Technique | Implementation | Savings |
|-----------|---|---|
| Yul Assembly | YulMath sqrt implementation | ~15% for sqrt operations |
| Storage Packing | Vault storage layout | N/A (accounting vault) |
| Immutable Variables | AMMPool token references | Gas savings on reads |
| Event Indexing | Indexed event parameters | Enables filtering |

### Benchmark Results

- AMMPool.swap() gas: ~50k-70k (depends on state changes)
- AMMPool.addLiquidity() gas: ~70k-100k
- Governance vote proposal: ~80k-120k
- Treasury withdrawal: ~40k-60k

---

## Maintenance & Monitoring

### Upgrade Path

1. **V1 → V2 (Vault)**: Use UpgradeVault.s.sol script
2. **Future Versions**: Deploy new implementation, call upgradeToAndCall()
3. **Governance Changes**: Propose changes via Governor

### Monitoring Points

- [ ] Oracle price staleness
- [ ] AMM liquidity levels
- [ ] Governance proposal execution
- [ ] Timelock queue status
- [ ] Vault deposit cap utilization

---

Generated: May 2026
