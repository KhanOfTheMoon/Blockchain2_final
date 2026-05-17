import { useState } from 'react';
import { appConfig } from '../config/appConfig.js';

const placeholderAddress = '0x000000000000000000000000000000000000dEaD';

export function useWalletPlaceholder() {
  const [connected, setConnected] = useState(false);
  const [address, setAddress] = useState('');
  const [chainId, setChainId] = useState(appConfig.supportedChainId || 1);
  const [error, setError] = useState('');

  const connectWallet = () => {
    setConnected(true);
    setAddress(placeholderAddress);
    setChainId(appConfig.supportedChainId || 1);
    setError('');
  };

  const disconnectWallet = () => {
    setConnected(false);
    setAddress('');
    setError('Wallet disconnected placeholder.');
  };

  const setWrongNetwork = () => {
    setChainId(0);
    setError('Wrong network placeholder. Connect the selected L2 testnet before transacting.');
  };

  return {
    connected,
    address,
    chainId,
    isWrongNetwork: connected && chainId !== appConfig.supportedChainId,
    error,
    connectWallet,
    disconnectWallet,
    setWrongNetwork,
    delegateAddress: '0x000000000000000000000000000000000000bEEF',
    tokenBalance: '0.00',
    votingPower: '0.00'
  };
}
