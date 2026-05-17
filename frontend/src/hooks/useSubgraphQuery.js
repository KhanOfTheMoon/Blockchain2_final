import { useEffect, useState } from 'react';
import { appConfig } from '../config/appConfig.js';

export function useSubgraphQuery(query) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;

    async function fetchData() {
      if (!appConfig.subgraphUrl) {
        setError('Subgraph endpoint placeholder not configured.');
        return;
      }

      setLoading(true);
      setError('');

      try {
        const response = await fetch(appConfig.subgraphUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ query })
        });

        const payload = await response.json();
        if (!cancelled) {
          setData(payload.data ?? null);
          setError(payload.errors?.[0]?.message ?? '');
        }
      } catch (fetchError) {
        if (!cancelled) {
          setError(fetchError instanceof Error ? fetchError.message : 'Unknown subgraph fetch error.');
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    fetchData();
    return () => {
      cancelled = true;
    };
  }, [query]);

  return { data, loading, error };
}
