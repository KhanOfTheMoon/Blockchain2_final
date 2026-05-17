export const appConfig = {
  supportedChainId: Number(import.meta.env.VITE_CHAIN_ID ?? 0),
  rpcUrl: import.meta.env.VITE_RPC_URL ?? '',
  subgraphUrl: import.meta.env.VITE_SUBGRAPH_URL ?? '',
  contracts: {
    governanceToken: import.meta.env.VITE_GOVERNANCE_TOKEN_ADDRESS ?? '',
    governor: import.meta.env.VITE_GOVERNOR_ADDRESS ?? '',
    treasury: import.meta.env.VITE_TREASURY_ADDRESS ?? '',
    ammFactory: import.meta.env.VITE_AMM_FACTORY_ADDRESS ?? '',
    vault: import.meta.env.VITE_VAULT_ADDRESS ?? '',
    priceOracle: import.meta.env.VITE_PRICE_ORACLE_ADDRESS ?? ''
  }
};
