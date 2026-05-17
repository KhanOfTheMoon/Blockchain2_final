import { useState } from 'react';

import ErrorMessage from './components/ErrorMessage.jsx';
import WalletStatus from './components/WalletStatus.jsx';
import Dashboard from './pages/Dashboard.jsx';
import AMM from './pages/AMM.jsx';
import Vault from './pages/Vault.jsx';
import Governance from './pages/Governance.jsx';
import SubgraphData from './pages/SubgraphData.jsx';
import { useWalletPlaceholder } from './hooks/useWalletPlaceholder.js';

const tabs = [
  { id: 'dashboard', label: 'Dashboard' },
  { id: 'amm', label: 'AMM' },
  { id: 'vault', label: 'Vault' },
  { id: 'governance', label: 'Governance' },
  { id: 'subgraph', label: 'Subgraph' }
];

export default function App() {
  const wallet = useWalletPlaceholder();
  const [activeTab, setActiveTab] = useState('dashboard');

  const activePage = {
    dashboard: <Dashboard wallet={wallet} />,
    amm: <AMM />,
    vault: <Vault />,
    governance: <Governance />,
    subgraph: <SubgraphData />
  }[activeTab];

  return (
    <div className="app-shell">
      <header className="topbar">
        <div>
          <h1 className="main-title">DeFi Superapp</h1>
          <p className="subtitle">AMM | Vault | Governance | Oracle | Subgraph</p>
        </div>
        <div className="topbar-actions">
          <button type="button" className="primary-button" onClick={wallet.connectWallet}>Connect Wallet</button>
          <button type="button" className="secondary-button" onClick={wallet.disconnectWallet}>Disconnect</button>
        </div>
      </header>

      <nav className="tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            className={tab.id === activeTab ? 'active' : ''}
            onClick={() => setActiveTab(tab.id)}
            aria-current={tab.id === activeTab ? 'page' : undefined}
          >
            {tab.label}
          </button>
        ))}
      </nav>

      <main className="main-content">{activePage}</main>
    </div>
  );
}
