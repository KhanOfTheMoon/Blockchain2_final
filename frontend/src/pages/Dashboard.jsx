import PageShell from '../components/PageShell.jsx';
import ContractEventFeed from '../components/ContractEventFeed.jsx';

export default function Dashboard({ wallet }) {
  return (
    <PageShell
      title="Dashboard"
      subtitle="Track protocol balance, voting power, and delegation state from one place."
    >
      <div className="card-grid">
        <article className="stat-card">
          <span>Token Balance</span>
          <strong>{wallet.tokenBalance}</strong>
          <p>Placeholder for wallet token balance fetched from the governance token contract.</p>
        </article>
        <article className="stat-card">
          <span>Voting Power</span>
          <strong>{wallet.votingPower}</strong>
          <p>Derived from ERC20Votes snapshots once the user delegates voting power.</p>
        </article>
        <article className="stat-card">
          <span>Delegate Address</span>
          <strong>{wallet.delegateAddress}</strong>
          <p>Display current delegate address and surface a delegation action here later.</p>
        </article>
      </div>

      <ContractEventFeed />
    </PageShell>
  );
}
