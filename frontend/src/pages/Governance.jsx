import PageShell from '../components/PageShell.jsx';

const proposals = [
  { id: 1, title: 'Bootstrap liquidity incentives', state: 'Active' },
  { id: 2, title: 'Upgrade vault implementation', state: 'Pending' },
  { id: 3, title: 'Treasury budget renewal', state: 'Queued' }
];

export default function Governance() {
  return (
    <PageShell
      title="Governance"
      subtitle="Proposal list and vote-action placeholders for Governor + Timelock flows."
    >
      <div className="proposal-list">
        {proposals.map((proposal) => (
          <article className="panel proposal-card" key={proposal.id}>
            <div className="proposal-meta">
              <strong>Proposal #{proposal.id}</strong>
              <span className="status-chip">{proposal.state}</span>
            </div>
            <h2>{proposal.title}</h2>
            <div className="vote-row">
              <button type="button" className="primary-button">For</button>
              <button type="button" className="secondary-button">Against</button>
              <button type="button" className="secondary-button">Abstain</button>
            </div>
            <p className="helper-text">TODO: fetch proposal state, cast vote, and show queue/execute timings.</p>
          </article>
        ))}
      </div>
    </PageShell>
  );
}
