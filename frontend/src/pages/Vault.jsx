import PageShell from '../components/PageShell.jsx';

export default function Vault() {
  return (
    <PageShell
      title="Vault"
      subtitle="ERC4626 deposit and withdraw placeholder for yield-bearing assets."
    >
      <div className="split-grid">
        <section className="panel">
          <h2>Deposit</h2>
          <label>
            Assets
            <input type="number" placeholder="0.0" />
          </label>
          <button type="button" className="primary-button">Deposit Placeholder</button>
        </section>
        <section className="panel">
          <h2>Withdraw</h2>
          <label>
            Shares / Assets
            <input type="number" placeholder="0.0" />
          </label>
          <button type="button" className="secondary-button">Withdraw Placeholder</button>
        </section>
      </div>
      <p className="helper-text">TODO: wire previewDeposit, previewRedeem, rounding helpers, and asset/share accounting.</p>
    </PageShell>
  );
}
