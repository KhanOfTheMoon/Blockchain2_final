import PageShell from '../components/PageShell.jsx';
import { useSubgraphQuery } from '../hooks/useSubgraphQuery.js';

const sampleQuery = `query ExampleDashboardData {
  swaps(first: 5, orderBy: timestamp, orderDirection: desc) {
    id
    amountIn
    amountOut
    timestamp
  }
}`;

export default function SubgraphData() {
  const { data, loading, error } = useSubgraphQuery(sampleQuery);

  return (
    <PageShell
      title="Subgraph Data"
      subtitle="Fetch indexed protocol data from the GraphQL endpoint placeholder."
    >
      <div className="panel">
        <p className="helper-text">Endpoint: {import.meta.env.VITE_SUBGRAPH_URL || 'not configured yet'}</p>
        <pre className="code-block">{sampleQuery}</pre>
        {loading ? <p className="helper-text">Loading placeholder data...</p> : null}
        {error ? <div className="error-banner">{error}</div> : null}
        <pre className="code-block">{JSON.stringify(data, null, 2) || 'No indexed data loaded yet.'}</pre>
      </div>
    </PageShell>
  );
}
