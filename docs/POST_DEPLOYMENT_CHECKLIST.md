# Post-Deployment Checklist

## Deployment Information

| Item | Value | Status |
|------|-------|--------|
| Network | [e.g., Sepolia, Polygon Amoy] | ⏳ To be filled |
| Deployer Address | [Address] | ⏳ To be filled |
| Deployment Date | [Date] | ⏳ To be filled |
| Block Number | [Block #] | ⏳ To be filled |
| Network Link | [Explorer URL] | ⏳ To be filled |

---

## Contract Deployments

### Core Contracts

- [ ] **GovernanceToken** ✅
  - Address: `0x0000000000000000000000000000000000000000`
  - Verified: ⏳
  - Block: [Block #]
  - Txn: [Hash]
  - Expected Supply: 1,000,000 GOV
  - Actual Supply: ✅ [Verified amount]

- [ ] **TimelockController**
  - Address: `0x0000000000000000000000000000000000000000`
  - Verified: ⏳
  - Delay: 2 days (172,800 seconds)
  - Admin Role Revoked: ⏳

- [ ] **MyGovernor**
  - Address: `0x0000000000000000000000000000000000000000`
  - Verified: ⏳
  - Token: [GovernanceToken address]
  - Timelock: [TimelockController address]

- [ ] **Treasury**
  - Address: `0x0000000000000000000000000000000000000000`
  - Verified: ⏳
  - Timelock: [TimelockController address]
  - Funding Amount: [ETH amount]

- [ ] **ChainlinkPriceOracle**
  - Address: `0x0000000000000000000000000000000000000000`
  - Verified: ⏳
  - Feed: [Chainlink feed address]
  - Stale Period: 86,400 seconds (24 hours)

- [ ] **AMMFactory**
  - Address: `0x0000000000000000000000000000000000000000`
  - Verified: ⏳

- [ ] **UpgradeableVaultV1**
  - Address (Proxy): `0x0000000000000000000000000000000000000000`
  - Address (Implementation): `0x0000000000000000000000000000000000000000`
  - Verified: ⏳
  - Owner/Admin: [Address]

---

## Role & Permission Verification

### TimelockController Roles

- [ ] DEFAULT_ADMIN_ROLE
  - Expected: Revoked (except for emergency)
  - Actual: [Status]
  - Verified: ⏳

- [ ] PROPOSER_ROLE
  - Expected: MyGovernor address
  - Actual: [Address]
  - Verified: ⏳

- [ ] EXECUTOR_ROLE
  - Expected: Anyone (0x0)
  - Actual: [Address]
  - Verified: ⏳

- [ ] CANCELLER_ROLE
  - Expected: MyGovernor address
  - Actual: [Address]
  - Verified: ⏳

### Vault Ownership

- [ ] Vault Owner/Admin
  - Expected: [Deployment address or Timelock]
  - Actual: [Address]
  - Verified: ⏳

- [ ] Upgrade Authority
  - Expected: Owner can call upgradeToAndCall()
  - Test: ⏳ Performed manual test

---

## Governance Configuration Validation

- [ ] **Voting Delay**
  - Expected: 1 day (86,400 seconds)
  - Actual: [Seconds]
  - Verified: ⏳

- [ ] **Voting Period**
  - Expected: 1 week (604,800 seconds)
  - Actual: [Seconds]
  - Verified: ⏳

- [ ] **Proposal Threshold**
  - Expected: 10,000 GOV (1% of supply)
  - Actual: [GOV amount]
  - Verified: ⏳

- [ ] **Quorum Percentage**
  - Expected: 4%
  - Actual: [Percentage]
  - Verified: ⏳

- [ ] **Timelock Delay**
  - Expected: 2 days (172,800 seconds)
  - Actual: [Seconds]
  - Verified: ⏳

---

## Oracle & Price Feed Validation

- [ ] **Chainlink Feed Live**
  - Feed Address: [Address]
  - Status: ⏳ Test oracle read
  - Latest Price: [Price]
  - Last Update: [Timestamp]
  - Decimals: [Expected 6-36]

- [ ] **Price Feed Staleness Check**
  - Configured Stale Period: 86,400 seconds
  - Test: ⏳ Verify staleness detection works

- [ ] **Oracle Decimal Normalization**
  - Test with 8-decimal feed: ⏳
  - Test with 6-decimal feed: ⏳
  - Normalized to 18 decimals: ✅

- [ ] **Mock Aggregator (if used)**
  - Address: [Address]
  - Decimals: [Expected 8]
  - Test Price: [Value]

---

## AMM Module Verification

- [ ] **AMMFactory Deployed**
  - Address: [Address]
  - CREATE method works: ⏳
  - CREATE2 method works: ⏳

- [ ] **First Pool Created** (if applicable)
  - Token0: [Address]
  - Token1: [Address]
  - Pool Address: [Address]
  - LP Token: [Address]
  - Liquidity Added: ⏳

- [ ] **Fee Configuration**
  - Expected: 30 bps
  - Actual: [BPS value]
  - Verified: ⏳

- [ ] **Swap Functionality**
  - Test swap execution: ⏳
  - Fee collection verified: ⏳
  - K-invariant maintained: ⏳

---

## Vault Module Verification

- [ ] **Vault Proxy Initialized**
  - Proxy Address: [Address]
  - Implementation Address: [Address]
  - Owner: [Address]

- [ ] **Deposit Cap Configured**
  - Expected: [Amount]
  - Actual: [Amount]
  - Verified: ⏳

- [ ] **ERC4626 Functions**
  - deposit() works: ⏳
  - mint() works: ⏳
  - withdraw() works: ⏳
  - redeem() works: ⏳

- [ ] **Preview Functions Accurate**
  - previewDeposit() matches deposit(): ⏳
  - previewMint() matches mint(): ⏳
  - previewWithdraw() matches withdraw(): ⏳
  - previewRedeem() matches redeem(): ⏳

- [ ] **Upgrade Path Ready**
  - V2 Implementation deployed: ⏳
  - Storage gap valid: ⏳
  - Test upgrade execution: ⏳

---

## Token Validation

- [ ] **GovernanceToken Supply**
  - Expected: 1,000,000 GOV
  - Actual: [Amount]
  - Verified: ⏳

- [ ] **Delegation Support**
  - Test self-delegation: ⏳
  - Test delegation to other: ⏳
  - Voting power updates: ⏳

- [ ] **Permit Functionality**
  - Test ERC20Permit signature: ⏳
  - Nonce tracking works: ⏳

- [ ] **Minting Disabled**
  - Test mint() reverts: ⏳

- [ ] **MembershipNFT** (if deployed)
  - Owner can mint: ⏳
  - Non-owner cannot mint: ⏳
  - URI storage works: ⏳

---

## Security & Access Control

- [ ] **Treasury Access Control**
  - Non-timelock cannot withdraw: ⏳
  - Only timelock can withdraw: ⏳
  - ETH withdrawal works: ⏳
  - ERC20 withdrawal works: ⏳

- [ ] **Reentrancy Guards**
  - AMMPool.swap() protected: ⏳
  - AMMPool.addLiquidity() protected: ⏳
  - AMMPool.removeLiquidity() protected: ⏳

- [ ] **Oracle Validation**
  - Stale price rejected: ⏳
  - Zero price rejected: ⏳
  - Invalid round rejected: ⏳

- [ ] **Vault Access**
  - Only owner can call upgradeToAndCall(): ⏳
  - Implementation validation enforced: ⏳

---

## Frontend Integration

- [ ] **ABIs Exported**
  - AMMFactory ABI: ⏳
  - AMMPool ABI: ⏳
  - Treasury ABI: ⏳
  - MyGovernor ABI: ⏳
  - GovernanceToken ABI: ⏳
  - Vault ABI: ⏳

- [ ] **Contract Addresses in Config**
  - File: `frontend/src/config/appConfig.js` or similar
  - All addresses updated: ⏳
  - Network ID correct: ⏳

- [ ] **Frontend Build Successful**
  - `npm run build` succeeds: ⏳
  - No errors in console: ⏳
  - Assets generated: ⏳

---

## Subgraph Deployment (if applicable)

- [ ] **Subgraph Entities Defined**
  - Pools: ⏳
  - Swaps: ⏳
  - Liquidity Events: ⏳
  - Governance Events: ⏳

- [ ] **Subgraph Indexed**
  - Sync status: ⏳ [Block number]
  - Query endpoint: [URL]
  - Sample query successful: ⏳

---

## Monitoring & Alerting

- [ ] **Event Monitoring**
  - Treasury withdrawals logged: ⏳
  - Governance proposals tracked: ⏳
  - Swap volume monitored: ⏳

- [ ] **Health Checks**
  - Oracle price updates: ⏳ [Check frequency]
  - Vault TVL: ⏳ [Value]
  - Governance status: ⏳ [Status]

- [ ] **Backup & Recovery**
  - Private keys secured: ⏳
  - Deployment scripts backed up: ⏳
  - Emergency procedures documented: ⏳

---

## Documentation & Handoff

- [ ] **Deployment Report**
  - All addresses recorded: ⏳
  - Roles assigned: ⏳
  - Configuration verified: ⏳

- [ ] **README Updated**
  - Deployment addresses: ⏳
  - Network information: ⏳
  - Deployed timestamp: ⏳

- [ ] **Configuration Files**
  - Environment variables set: ⏳
  - Contract addresses in config: ⏳
  - RPC endpoints configured: ⏳

- [ ] **Team Handoff**
  - Operations team trained: ⏳
  - Emergency procedures reviewed: ⏳
  - Contact list updated: ⏳

---

## Issues & Resolutions

### Issue #1
- **Description**: [Issue]
- **Severity**: [Low/Medium/High/Critical]
- **Resolution**: [Resolution]
- **Date Resolved**: [Date]
- **Verified**: ⏳

### Issue #2
- **Description**: [Issue]
- **Severity**: [Low/Medium/High/Critical]
- **Resolution**: [Resolution]
- **Date Resolved**: [Date]
- **Verified**: ⏳

---

## Final Approval

| Role | Name | Date | Approved |
|------|------|------|----------|
| Project Lead | [Name] | [Date] | ⏳ |
| Technical Lead | [Name] | [Date] | ⏳ |
| Security Lead | [Name] | [Date] | ⏳ |
| Operations Lead | [Name] | [Date] | ⏳ |

---

## Go-Live Decision

- [ ] **All Checks Passed**: ⏳
- [ ] **No Critical Issues**: ⏳
- [ ] **Team Approved**: ⏳
- [ ] **Monitoring Active**: ⏳

**Status**: ⏳ Ready for Production  
**Go-Live Date**: [Date]  
**Deployment Completed By**: [Name]  
**Approved By**: [Name]

---

## Post-Deployment Monitoring (First 30 Days)

| Date | Status | Notes | Action Items |
|------|--------|-------|--------------|
| Day 1 | ⏳ | [Notes] | [Items] |
| Day 7 | ⏳ | [Notes] | [Items] |
| Day 30 | ⏳ | [Notes] | [Items] |

---

**Document Version**: 1.0  
**Last Updated**: [Date]  
**Maintained By**: [Team]
