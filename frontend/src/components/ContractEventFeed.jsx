import { useEffect, useMemo, useState } from 'react';
import { BrowserProvider, Contract, JsonRpcProvider, Interface } from 'ethers';

import { abis } from '../abi/index.js';
import { appConfig } from '../config/appConfig.js';

const contractCatalog = {
  governanceToken: {
    label: 'Governance Token',
    eventNames: ['VotingPowerDelegated', 'InitialSupplyMinted']
  },
  treasury: {
    label: 'Treasury',
    eventNames: ['EthReceived', 'EthWithdrawn', 'Erc20Withdrawn']
  },
  ammFactory: {
    label: 'AMM Factory',
    eventNames: ['PoolCreated']
  },
  ammPool: {
    label: 'AMM Pool',
    eventNames: ['LiquidityAdded', 'LiquidityRemoved', 'Swap']
  },
  vault: {
    label: 'Upgradeable Vault',
    eventNames: ['Deposited', 'Withdrawn']
  },
  priceOracle: {
    label: 'Price Oracle',
    eventNames: ['OracleConfigured']
  }
};

function normalizeValue(value) {
  if (typeof value === 'bigint') {
    return value.toString();
  }

  if (Array.isArray(value)) {
    return value.map(normalizeValue);
  }

  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, entry]) => [key, normalizeValue(entry)]));
  }

  return value;
}

function formatArgs(args) {
  if (!args) {
    return {};
  }

  return Object.fromEntries(Object.entries(args).filter(([key]) => Number.isNaN(Number(key))).map(([key, value]) => [key, normalizeValue(value)]));
}

async function createProvider() {
  if (typeof window !== 'undefined' && window.ethereum) {
    return new BrowserProvider(window.ethereum);
  }

  if (appConfig.rpcUrl) {
    return new JsonRpcProvider(appConfig.rpcUrl);
  }

  return null;
}

export default function ContractEventFeed() {
  const [contractKey, setContractKey] = useState('vault');
  const [eventName, setEventName] = useState(contractCatalog.vault.eventNames[0]);
  const [fromBlock, setFromBlock] = useState('0');
  const [status, setStatus] = useState('Idle');
  const [error, setError] = useState('');
  const [events, setEvents] = useState([]);
  const [address, setAddress] = useState('');

  const contractInfo = abis[contractKey];
  const selectedContract = contractCatalog[contractKey];

  const availableEvents = useMemo(() => selectedContract.eventNames, [selectedContract]);

  useEffect(() => {
    setEventName(selectedContract.eventNames[0]);
  }, [selectedContract]);

  useEffect(() => {
    const resolvedAddress = appConfig.contracts[contractKey] || contractInfo.address || '';
    setAddress(resolvedAddress);
  }, [contractKey, contractInfo.address]);

  useEffect(() => {
    let active = true;
    let contract;

    async function loadEvents() {
      setError('');
      setStatus('Connecting');
      setEvents([]);

      const resolvedAddress = appConfig.contracts[contractKey] || contractInfo.address || '';
      if (!resolvedAddress) {
        setStatus('Missing address');
        return;
      }

      const provider = await createProvider();
      if (!provider) {
        if (active) {
          setStatus('Missing RPC');
          setError('Set VITE_RPC_URL or open the app with MetaMask installed.');
        }
        return;
      }

      try {
        const network = await provider.getNetwork();
        const currentBlock = await provider.getBlockNumber();
        const startBlock = Number(fromBlock || 0);
        const queryFromBlock = Number.isFinite(startBlock) && startBlock >= 0 ? startBlock : Math.max(currentBlock - 5000, 0);
        const iface = new Interface(contractInfo.abi);

        contract = new Contract(resolvedAddress, contractInfo.abi, provider);
        const filter = contract.filters[eventName]();
        const logs = await contract.queryFilter(filter, queryFromBlock, 'latest');

        const formatted = logs.map((log) => {
          const parsed = iface.parseLog(log);
          return {
            id: `${log.transactionHash}:${log.index}`,
            blockNumber: log.blockNumber,
            transactionHash: log.transactionHash,
            eventName: parsed.name,
            args: formatArgs(parsed.args),
            source: resolvedAddress,
            chainId: network.chainId.toString()
          };
        });

        if (active) {
          setEvents(formatted.reverse());
          setStatus(`Loaded ${formatted.length} events`);
        }

        const liveHandler = (...handlerArgs) => {
          const event = handlerArgs[handlerArgs.length - 1];
          const parsed = iface.parseLog(event.log);
          setEvents((current) => [
            {
              id: `${event.log.transactionHash}:${event.log.index}`,
              blockNumber: event.log.blockNumber,
              transactionHash: event.log.transactionHash,
              eventName: parsed.name,
              args: formatArgs(parsed.args),
              source: resolvedAddress,
              chainId: network.chainId.toString()
            },
            ...current
          ]);
        };

        contract.on(eventName, liveHandler);

        return () => {
          contract.off(eventName, liveHandler);
        };
      } catch (loadError) {
        if (active) {
          setStatus('Load failed');
          setError(loadError instanceof Error ? loadError.message : String(loadError));
        }
      }
    }

    let cleanup = () => {};

    loadEvents().then((maybeCleanup) => {
      if (typeof maybeCleanup === 'function') {
        cleanup = maybeCleanup;
      }
    });

    return () => {
      active = false;
      cleanup();
    };
  }, [contractKey, contractInfo.abi, eventName, fromBlock, contractInfo.address]);

  return (
    <section className="panel panel-soft">
      <div className="panel-header">
        <div>
          <p className="eyebrow">Live Events</p>
          <h2>ABI-driven event feed</h2>
          <p className="helper-text">Reads logs from RPC or MetaMask using the contract ABI and listens for new events.</p>
        </div>
        <span className="status-chip">{status}</span>
      </div>

      <div className="form-grid" style={{ marginTop: '1rem' }}>
        <label>
          Contract
          <select value={contractKey} onChange={(event) => setContractKey(event.target.value)}>
            {Object.entries(contractCatalog).map(([key, item]) => (
              <option key={key} value={key}>
                {item.label}
              </option>
            ))}
          </select>
        </label>

        <label>
          Event
          <select value={eventName} onChange={(event) => setEventName(event.target.value)}>
            {availableEvents.map((item) => (
              <option key={item} value={item}>
                {item}
              </option>
            ))}
          </select>
        </label>

        <label>
          Address
          <input value={address} readOnly placeholder="Set VITE_*_ADDRESS or fill contract address" />
        </label>

        <label>
          From block
          <input value={fromBlock} onChange={(event) => setFromBlock(event.target.value)} placeholder="0" />
        </label>
      </div>

      <div className="kv-grid">
        <div>
          <span>Contract ABI</span>
          <strong>{contractInfo.abi.length} entries</strong>
        </div>
        <div>
          <span>Selected event</span>
          <strong>{eventName}</strong>
        </div>
      </div>

      {error ? <div className="error-banner" style={{ marginTop: '1rem' }}>{error}</div> : null}

      <div className="proposal-list" style={{ marginTop: '1rem' }}>
        {events.length === 0 ? (
          <div className="panel">
            <p className="helper-text">No events loaded yet. Configure a contract address and RPC endpoint, then this view will show history plus live updates.</p>
          </div>
        ) : (
          events.map((entry) => (
            <article className="panel" key={entry.id}>
              <div className="proposal-meta">
                <div>
                  <strong>{entry.eventName}</strong>
                  <p className="helper-text">Block {entry.blockNumber} · Chain {entry.chainId}</p>
                </div>
                <span className="status-chip">{entry.transactionHash.slice(0, 10)}...</span>
              </div>
              <pre className="code-block">{JSON.stringify(entry.args, null, 2)}</pre>
            </article>
          ))
        )}
      </div>
    </section>
  );
}