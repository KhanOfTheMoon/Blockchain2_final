export default function WalletStatus({ wallet }) {
  return (
    <section className="panel panel-soft">
      <div className="panel-header">
        <h2>Wallet</h2>
        <div className="status-chip">{wallet.connected ? 'Connected' : 'Disconnected'}</div>
      </div>
      <div className="kv-grid">
        <div>
          <span>Address</span>
          <strong>{wallet.address || 'Wallet not connected yet'}</strong>
        </div>
        <div>
          <span>Chain ID</span>
          <strong>{wallet.chainId || 'Not set'}</strong>
        </div>
        <div>
          <span>Network</span>
          <strong>{wallet.isWrongNetwork ? 'Wrong network placeholder' : 'Expected testnet'}</strong>
        </div>
      </div>
    </section>
  );
}
