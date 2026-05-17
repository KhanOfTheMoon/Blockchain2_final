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
          <p className="eyebrow">Blockchain Final Project Template</p>
          <h1>DeFi Super-App</h1>
          <p className="subtitle">AMM, ERC4626 vault, DAO governance, oracle integration, and subgraph skeleton.</p>
        </div>
        <div className="topbar-actions">
          <button type="button" className="primary-button" onClick={wallet.connectWallet}>Connect Wallet</button>
          <button type="button" className="secondary-button" onClick={wallet.disconnectWallet}>Disconnect</button>
          <button type="button" className="ghost-button" onClick={wallet.setWrongNetwork}>Wrong Network Demo</button>
        </div>
      </header>

      <div className="content-grid">
        <aside className="sidebar">
          <WalletStatus wallet={wallet} />
          <ErrorMessage message={wallet.error} />
          <nav className="tab-list" aria-label="Primary">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                type="button"
                className={tab.id === activeTab ? 'tab-button active' : 'tab-button'}
                onClick={() => setActiveTab(tab.id)}
              >
                {tab.label}
              </button>
            ))}
          </nav>
        </aside>

        <main className="main-panel">{activePage}</main>
      </div>
    </div>
  );
}
