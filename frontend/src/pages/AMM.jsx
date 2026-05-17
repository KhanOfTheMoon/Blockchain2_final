import PageShell from '../components/PageShell.jsx';

export default function AMM() {
  return (
    <PageShell
      title="AMM"
      subtitle="Swap form placeholder for the constant-product pool and LP position flows."
    >
      <div className="panel">
        <form className="form-grid">
          <label>
            Token In
            <input type="text" placeholder="0xTokenIn..." />
          </label>
          <label>
            Token Out
            <input type="text" placeholder="0xTokenOut..." />
          </label>
          <label>
            Amount In
            <input type="number" placeholder="0.0" />
          </label>
          <label>
            Minimum Amount Out
            <input type="number" placeholder="0.0" />
          </label>
          <button type="button" className="primary-button">Swap Placeholder</button>
        </form>
        <p className="helper-text">TODO: connect allowance checks, slippage protection, and transaction status handling.</p>
      </div>
    </PageShell>
  );
}
