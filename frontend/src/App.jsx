import { useState } from "react";
import { ethers } from "ethers";
import "./App.css";

const GOVERNANCE_TOKEN = "0x8BaCd978227c916d8D2B23b833C9fc8b6790b892";
const GOVERNOR = "0x7Fa555f86ff582fa024A0cAD24f70daE06d4a086";
const ORACLE = "0xC484c4941118df78125DFd3Ce374B5AE4eA1Fde6";
const VAULT_PROXY = "0x03E8A10bA574171A0baE2519F39844B8Ea6b614a";

const DEMO_TOKEN = "0x74b24EDC2d8C5065C4Ae24D4b96780d69DA135ED";
const AMM_POOL = "0x699653684Ba8a4463C8784324b0E89C6E05D7F14";
const LP_TOKEN = "0x351CDaDEbC2493556c049Accd076498260656Eac";

const SUBGRAPH_URL = import.meta.env.VITE_SUBGRAPH_URL || "";

const ARBITRUM_SEPOLIA = {
  chainId: "0x66eee",
  chainName: "Arbitrum Sepolia",
  nativeCurrency: {
    name: "Sepolia ETH",
    symbol: "ETH",
    decimals: 18,
  },
  rpcUrls: ["https://sepolia-rollup.arbitrum.io/rpc"],
  blockExplorerUrls: ["https://sepolia.arbiscan.io"],
};

const ERC20_VOTES_ABI = [
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function balanceOf(address account) view returns (uint256)",
  "function getVotes(address account) view returns (uint256)",
  "function delegates(address account) view returns (address)",
  "function delegate(address delegatee)",
];

const ERC20_ABI = [
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function balanceOf(address account) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
];

const AMM_POOL_ABI = [
  "function token0() view returns (address)",
  "function token1() view returns (address)",
  "function getReserves() view returns (uint256,uint256)",
  "function getAmountOut(bool zeroForOne, uint256 amountIn) view returns (uint256)",
  "function swap(bool zeroForOne,uint256 amountIn,uint256 amountOutMin,address to,uint256 deadline) returns (uint256)",
];

const GOVERNOR_ABI = [
  "function state(uint256 proposalId) view returns (uint8)",
  "function castVote(uint256 proposalId, uint8 support) returns (uint256)",
  "function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)",
  "function hashProposal(address[] targets, uint256[] values, bytes[] calldatas, bytes32 descriptionHash) view returns (uint256)",
  "function votingDelay() view returns (uint256)",
  "function votingPeriod() view returns (uint256)",
];

const VAULT_INTERFACE_ABI = [
  "function setDepositCap(uint256 newDepositCap)",
];

const ORACLE_ABI = [
  "function latestPrice() view returns (uint256)",
];

const proposalStates = [
  "Pending",
  "Active",
  "Canceled",
  "Defeated",
  "Succeeded",
  "Queued",
  "Expired",
  "Executed",
];

function formatError(error) {
  const message =
    error?.shortMessage ||
    error?.reason ||
    error?.info?.error?.message ||
    error?.message ||
    "Unknown error";

  const lower = message.toLowerCase();

  if (lower.includes("user rejected")) {
    return "Transaction rejected by user.";
  }

  if (lower.includes("insufficient funds")) {
    return "Insufficient ETH for gas.";
  }

  if (lower.includes("insufficient balance")) {
    return "Insufficient token balance.";
  }

  if (lower.includes("governorinsufficientproposer")) {
    return "Not enough voting power to create proposal. Click Delegate to Self first, then Refresh Data.";
  }

  if (lower.includes("governorunexpectedproposalstate")) {
    return "Proposal is not Active yet. Wait 30 seconds after creation, then refresh proposal state.";
  }

  if (lower.includes("governoralreadycastvote")) {
    return "This wallet has already voted on this proposal.";
  }

  if (lower.includes("execution reverted")) {
    return "Transaction reverted. Check proposal state, voting power, token balance, allowance, or network.";
  }

  return message;
}

function shortAddress(address) {
  if (!address) return "-";
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function sameAddress(a, b) {
  return a?.toLowerCase() === b?.toLowerCase();
}

function loadSavedProposals() {
  try {
    const saved = localStorage.getItem("knownProposalsV2");
    return saved ? JSON.parse(saved) : [];
  } catch {
    return [];
  }
}

function saveProposals(proposals) {
  localStorage.setItem("knownProposalsV2", JSON.stringify(proposals));
}

export default function App() {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);

  const [account, setAccount] = useState("");
  const [chainId, setChainId] = useState("");

  const [ethBalance, setEthBalance] = useState("0");

  const [tokenBalance, setTokenBalance] = useState("0");
  const [votingPower, setVotingPower] = useState("0");
  const [delegateAddress, setDelegateAddress] = useState("");

  const [demoBalance, setDemoBalance] = useState("0");
  const [lpBalance, setLpBalance] = useState("0");

  const [oraclePrice, setOraclePrice] = useState("0");

  const [votingDelay, setVotingDelay] = useState("-");
  const [votingPeriod, setVotingPeriod] = useState("-");

  const [newDepositCap, setNewDepositCap] = useState("5000");
  const [proposalDescription, setProposalDescription] = useState(
    "Proposal: update vault deposit cap"
  );
  const [createdProposalId, setCreatedProposalId] = useState("");

  const [manualProposalId, setManualProposalId] = useState("");
  const [knownProposals, setKnownProposals] = useState(loadSavedProposals);
  const [proposalStateById, setProposalStateById] = useState({});
  const [proposalCountdownById, setProposalCountdownById] = useState({});

  const [token0, setToken0] = useState("");
  const [token1, setToken1] = useState("");
  const [token0Symbol, setToken0Symbol] = useState("TOKEN0");
  const [token1Symbol, setToken1Symbol] = useState("TOKEN1");
  const [reserve0, setReserve0] = useState("0");
  const [reserve1, setReserve1] = useState("0");
  const [ammLastUpdated, setAmmLastUpdated] = useState("");

  const [swapDirection, setSwapDirection] = useState("demoToGov");
  const [swapAmount, setSwapAmount] = useState("1");
  const [expectedOut, setExpectedOut] = useState("0");

  const [subgraphData, setSubgraphData] = useState("");

  const [status, setStatus] = useState("");
  const [error, setError] = useState("");

  const wrongNetwork = chainId && Number(chainId) !== 421614;

  async function getTxOverrides() {
    if (!provider) return {};

    try {
      const gasPriceHex = await provider.send("eth_gasPrice", []);
      const gasPrice = BigInt(gasPriceHex);

      return {
        gasPrice: (gasPrice * 150n) / 100n,
      };
    } catch {
      return {};
    }
  }

  function addKnownProposal(id) {
    if (!id) return;

    setKnownProposals((previous) => {
      if (previous.includes(id)) return previous;

      const updated = [id, ...previous];
      saveProposals(updated);
      return updated;
    });
  }

  function clearProposalList() {
    localStorage.removeItem("knownProposalsV2");
    setKnownProposals([]);
    setProposalStateById({});
    setCreatedProposalId("");
    setManualProposalId("");
    setStatus("Proposal list cleared.");
  }

  async function loadGovernorSettings(currentProvider) {
    const governor = new ethers.Contract(GOVERNOR, GOVERNOR_ABI, currentProvider);

    const delay = await governor.votingDelay();
    const period = await governor.votingPeriod();

    setVotingDelay(delay.toString());
    setVotingPeriod(period.toString());
  }

  async function loadTokenData(currentProvider, currentAccount) {
    const gov = new ethers.Contract(GOVERNANCE_TOKEN, ERC20_VOTES_ABI, currentProvider);
    const demo = new ethers.Contract(DEMO_TOKEN, ERC20_ABI, currentProvider);
    const lp = new ethers.Contract(LP_TOKEN, ERC20_ABI, currentProvider);
    const oracle = new ethers.Contract(ORACLE, ORACLE_ABI, currentProvider);

    const walletEthBalance = await currentProvider.getBalance(currentAccount);

    const govDecimals = await gov.decimals();
    const demoDecimals = await demo.decimals();
    const lpDecimals = await lp.decimals();

    const govBalanceRaw = await gov.balanceOf(currentAccount);
    const votesRaw = await gov.getVotes(currentAccount);
    const delegate = await gov.delegates(currentAccount);

    const demoBalanceRaw = await demo.balanceOf(currentAccount);
    const lpBalanceRaw = await lp.balanceOf(currentAccount);

    const price = await oracle.latestPrice();

    setEthBalance(ethers.formatEther(walletEthBalance));
    setTokenBalance(ethers.formatUnits(govBalanceRaw, govDecimals));
    setVotingPower(ethers.formatUnits(votesRaw, govDecimals));
    setDelegateAddress(delegate);
    setDemoBalance(ethers.formatUnits(demoBalanceRaw, demoDecimals));
    setLpBalance(ethers.formatUnits(lpBalanceRaw, lpDecimals));
    setOraclePrice(ethers.formatUnits(price, 18));
  }

  async function loadAmmData(currentProvider) {
    const pool = new ethers.Contract(AMM_POOL, AMM_POOL_ABI, currentProvider);

    const poolToken0 = await pool.token0();
    const poolToken1 = await pool.token1();

    const token0Contract = new ethers.Contract(poolToken0, ERC20_ABI, currentProvider);
    const token1Contract = new ethers.Contract(poolToken1, ERC20_ABI, currentProvider);

    const symbol0 = await token0Contract.symbol();
    const symbol1 = await token1Contract.symbol();

    const decimals0 = await token0Contract.decimals();
    const decimals1 = await token1Contract.decimals();

    const [reserve0Raw, reserve1Raw] = await pool.getReserves();

    setToken0(poolToken0);
    setToken1(poolToken1);
    setToken0Symbol(symbol0);
    setToken1Symbol(symbol1);
    setReserve0(ethers.formatUnits(reserve0Raw, decimals0));
    setReserve1(ethers.formatUnits(reserve1Raw, decimals1));
    setAmmLastUpdated(new Date().toLocaleTimeString());
  }

  async function loadProposalState(id, currentProvider = provider) {
    if (!currentProvider) {
      throw new Error("Connect wallet first.");
    }

    if (!id) {
      throw new Error("Proposal ID is empty.");
    }

    const governor = new ethers.Contract(GOVERNOR, GOVERNOR_ABI, currentProvider);
    const state = await governor.state(id);
    const stateName = proposalStates[Number(state)] || "Unknown";

    setProposalStateById((previous) => ({
      ...previous,
      [id]: stateName,
    }));

    return stateName;
  }

  async function loadAllProposalStates(currentProvider = provider) {
    if (knownProposals.length === 0) return;

    for (const id of knownProposals) {
      await loadProposalState(id, currentProvider);
    }
  }

  async function loadDataWith(currentProvider, currentAccount) {
    await loadTokenData(currentProvider, currentAccount);
    await loadAmmData(currentProvider);
    await loadGovernorSettings(currentProvider);
  }

  async function connectWallet() {
    try {
      setError("");
      setStatus("Connecting wallet...");

      if (!window.ethereum) {
        throw new Error("MetaMask is not installed.");
      }

      const browserProvider = new ethers.BrowserProvider(window.ethereum);
      await browserProvider.send("eth_requestAccounts", []);

      const walletSigner = await browserProvider.getSigner();
      const address = await walletSigner.getAddress();
      const network = await browserProvider.getNetwork();

      setProvider(browserProvider);
      setSigner(walletSigner);
      setAccount(address);
      setChainId(Number(network.chainId));

      if (Number(network.chainId) === 421614) {
        await loadDataWith(browserProvider, address);

        for (const id of knownProposals) {
          await loadProposalState(id, browserProvider);
        }

        setStatus("Wallet connected. New Governor with 30-second voting delay loaded.");
      } else {
        setStatus("Wallet connected. Wrong network.");
      }
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  async function switchNetwork() {
    try {
      setError("");
      setStatus("Switching to Arbitrum Sepolia...");

      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: ARBITRUM_SEPOLIA.chainId }],
        });
      } catch (switchError) {
        if (switchError.code === 4902) {
          await window.ethereum.request({
            method: "wallet_addEthereumChain",
            params: [ARBITRUM_SEPOLIA],
          });
        } else {
          throw switchError;
        }
      }

      await connectWallet();
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  async function refreshData() {
    try {
      setError("");

      if (!provider || !account) {
        throw new Error("Connect wallet first.");
      }

      if (wrongNetwork) {
        throw new Error("Wrong network. Switch to Arbitrum Sepolia.");
      }

      setStatus("Refreshing all data...");
      await loadDataWith(provider, account);
      await loadAllProposalStates(provider);
      setStatus("All data refreshed.");
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  async function readPoolReserves() {
    try {
      setError("");

      if (!provider) {
        throw new Error("Connect wallet first.");
      }

      if (wrongNetwork) {
        throw new Error("Wrong network. Switch to Arbitrum Sepolia.");
      }

      setStatus("Reading AMM pool reserves...");
      await loadAmmData(provider);
      setStatus("Pool reserves refreshed.");
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  async function delegateToSelf() {
    try {
      setError("");

      if (!signer || !account) {
        throw new Error("Connect wallet first.");
      }

      if (wrongNetwork) {
        throw new Error("Wrong network. Switch to Arbitrum Sepolia.");
      }

      const gov = new ethers.Contract(GOVERNANCE_TOKEN, ERC20_VOTES_ABI, signer);

      setStatus("Sending delegation transaction...");

      const tx = await gov.delegate(account, await getTxOverrides());
      await tx.wait();

      setStatus("Delegation successful. Refreshing voting power...");
      await refreshData();
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  function scheduleProposalRefresh(id) {
    setProposalCountdownById((previous) => ({
      ...previous,
      [id]: "Waiting 30 seconds...",
    }));

    setTimeout(async () => {
      try {
        const stateName = await loadProposalState(id);

        setProposalCountdownById((previous) => ({
          ...previous,
          [id]: stateName === "Active" ? "Proposal is now Active." : `Current state: ${stateName}`,
        }));

        setStatus(`Proposal ${shortAddress(id)} auto-checked after 30 seconds. State: ${stateName}.`);
      } catch (err) {
        setError(formatError(err));
      }
    }, 35_000);
  }

  async function createProposal() {
    try {
      setError("");

      if (!signer || !account) {
        throw new Error("Connect wallet first.");
      }

      if (wrongNetwork) {
        throw new Error("Wrong network. Switch to Arbitrum Sepolia.");
      }

      if (!newDepositCap || Number(newDepositCap) <= 0) {
        throw new Error("Enter a valid deposit cap.");
      }

      const gov = new ethers.Contract(GOVERNANCE_TOKEN, ERC20_VOTES_ABI, provider);
      const votesRaw = await gov.getVotes(account);

      if (votesRaw === 0n) {
        throw new Error("Voting power is 0. Click Delegate to Self first, wait for confirmation, then create proposal.");
      }

      const governor = new ethers.Contract(GOVERNOR, GOVERNOR_ABI, signer);
      const vaultInterface = new ethers.Interface(VAULT_INTERFACE_ABI);

      const capValue = ethers.parseEther(newDepositCap);

      const targets = [VAULT_PROXY];
      const values = [0n];
      const calldatas = [
        vaultInterface.encodeFunctionData("setDepositCap", [capValue]),
      ];

      const finalDescription = `${proposalDescription} | cap=${newDepositCap} | time=${Date.now()}`;
      const descriptionHash = ethers.id(finalDescription);

      const predictedProposalId = await governor.hashProposal(
        targets,
        values,
        calldatas,
        descriptionHash
      );

      setStatus("Creating proposal...");

      const tx = await governor.propose(
        targets,
        values,
        calldatas,
        finalDescription,
        await getTxOverrides()
      );

      await tx.wait();

      const id = predictedProposalId.toString();

      setCreatedProposalId(id);
      addKnownProposal(id);

      const stateName = await loadProposalState(id);

      setStatus(
        `Proposal created. Current state: ${stateName}. Wait about 30 seconds, then it should become Active.`
      );

      scheduleProposalRefresh(id);
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  async function addManualProposal() {
    try {
      setError("");

      if (!manualProposalId) {
        throw new Error("Enter proposal ID.");
      }

      addKnownProposal(manualProposalId);
      const stateName = await loadProposalState(manualProposalId);

      setStatus(`Proposal added. Current state: ${stateName}.`);
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  async function refreshProposalList() {
    try {
      setError("");

      if (knownProposals.length === 0) {
        throw new Error("No proposals yet. Create one first.");
      }

      setStatus("Refreshing proposal list...");

      for (const id of knownProposals) {
        await loadProposalState(id);
      }

      setStatus("Proposal list refreshed.");
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  async function voteOnProposal(support, selectedProposalId) {
    try {
      setError("");

      if (!signer) {
        throw new Error("Connect wallet first.");
      }

      if (!selectedProposalId) {
        throw new Error("Proposal ID is empty.");
      }

      if (wrongNetwork) {
        throw new Error("Wrong network. Switch to Arbitrum Sepolia.");
      }

      const currentState =
        proposalStateById[selectedProposalId] ||
        (await loadProposalState(selectedProposalId));

      if (currentState !== "Active") {
        throw new Error(`Proposal is ${currentState}. Wait 30 seconds after creation, then refresh proposal state.`);
      }

      const governor = new ethers.Contract(GOVERNOR, GOVERNOR_ABI, signer);

      setStatus("Submitting vote...");

      const tx = await governor.castVote(
        selectedProposalId,
        support,
        await getTxOverrides()
      );

      await tx.wait();

      const updatedState = await loadProposalState(selectedProposalId);

      setStatus(`Vote submitted. Proposal state: ${updatedState}.`);
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  function getSwapConfig() {
    const demoIsToken0 = sameAddress(token0, DEMO_TOKEN) || !token0;
    const govIsToken0 = sameAddress(token0, GOVERNANCE_TOKEN);

    if (swapDirection === "demoToGov") {
      return {
        zeroForOne: demoIsToken0,
        inputToken: DEMO_TOKEN,
        outputToken: GOVERNANCE_TOKEN,
        inputSymbol: "DEMO",
        outputSymbol: "GOV",
      };
    }

    return {
      zeroForOne: govIsToken0,
      inputToken: GOVERNANCE_TOKEN,
      outputToken: DEMO_TOKEN,
      inputSymbol: "GOV",
      outputSymbol: "DEMO",
    };
  }

  async function quoteSwap() {
    try {
      setError("");

      if (!provider) {
        throw new Error("Connect wallet first.");
      }

      if (!swapAmount || Number(swapAmount) <= 0) {
        throw new Error("Enter a valid swap amount.");
      }

      const config = getSwapConfig();

      const tokenIn = new ethers.Contract(config.inputToken, ERC20_ABI, provider);
      const decimals = await tokenIn.decimals();

      const amountIn = ethers.parseUnits(swapAmount, decimals);

      const pool = new ethers.Contract(AMM_POOL, AMM_POOL_ABI, provider);
      const outRaw = await pool.getAmountOut(config.zeroForOne, amountIn);

      const outputToken = new ethers.Contract(config.outputToken, ERC20_ABI, provider);
      const outputDecimals = await outputToken.decimals();

      setExpectedOut(ethers.formatUnits(outRaw, outputDecimals));
      setStatus("Swap quote loaded.");
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  async function approveSwapToken() {
    try {
      setError("");

      if (!signer) {
        throw new Error("Connect wallet first.");
      }

      if (wrongNetwork) {
        throw new Error("Wrong network. Switch to Arbitrum Sepolia.");
      }

      if (!swapAmount || Number(swapAmount) <= 0) {
        throw new Error("Enter a valid swap amount.");
      }

      const config = getSwapConfig();
      const tokenIn = new ethers.Contract(config.inputToken, ERC20_ABI, signer);
      const decimals = await tokenIn.decimals();
      const amountIn = ethers.parseUnits(swapAmount, decimals);

      setStatus(`Approving ${config.inputSymbol}...`);

      const tx = await tokenIn.approve(AMM_POOL, amountIn, await getTxOverrides());
      await tx.wait();

      setStatus(`${config.inputSymbol} approved for AMM pool.`);
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  async function executeSwap() {
    try {
      setError("");

      if (!signer || !account) {
        throw new Error("Connect wallet first.");
      }

      if (wrongNetwork) {
        throw new Error("Wrong network. Switch to Arbitrum Sepolia.");
      }

      if (!swapAmount || Number(swapAmount) <= 0) {
        throw new Error("Enter a valid swap amount.");
      }

      const config = getSwapConfig();
      const tokenIn = new ethers.Contract(config.inputToken, ERC20_ABI, signer);
      const decimals = await tokenIn.decimals();
      const amountIn = ethers.parseUnits(swapAmount, decimals);

      const currentAllowance = await tokenIn.allowance(account, AMM_POOL);

      if (currentAllowance < amountIn) {
        throw new Error(`Approve ${config.inputSymbol} first.`);
      }

      const pool = new ethers.Contract(AMM_POOL, AMM_POOL_ABI, signer);

      const quotedOut = await pool.getAmountOut(config.zeroForOne, amountIn);
      const minOut = (quotedOut * 95n) / 100n;
      const deadline = Math.floor(Date.now() / 1000) + 3600;

      setStatus(`Swapping ${config.inputSymbol} to ${config.outputSymbol}...`);

      const tx = await pool.swap(
        config.zeroForOne,
        amountIn,
        minOut,
        account,
        deadline,
        await getTxOverrides()
      );

      await tx.wait();

      setStatus("Swap completed.");
      await refreshData();
      await quoteSwap();
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  async function loadSubgraphData() {
    try {
      setError("");

      if (!SUBGRAPH_URL) {
        throw new Error(
          "Subgraph URL is not configured. Add VITE_SUBGRAPH_URL in frontend/.env."
        );
      }

      const query = `
        {
          swaps(first: 5, orderBy: timestamp, orderDirection: desc) {
            id
            trader
            amountIn
            amountOut
            timestamp
          }
        }
      `;

      const response = await fetch(SUBGRAPH_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ query }),
      });

      const data = await response.json();
      setSubgraphData(JSON.stringify(data, null, 2));
      setStatus("Subgraph data loaded.");
    } catch (err) {
      setError(formatError(err));
      setStatus("");
    }
  }

  return (
    <div className="container">
      <h1>DeFi Governance Dashboard</h1>

      {!account ? (
        <button onClick={connectWallet}>Connect MetaMask</button>
      ) : (
        <div className="card">
          <p>
            <b>Wallet:</b> {account}
          </p>

          <p>
            <b>Chain ID:</b> {chainId}
          </p>

          <p>
            <b>ETH Balance:</b> {Number(ethBalance).toFixed(6)}
          </p>

          <button onClick={refreshData} disabled={wrongNetwork}>
            Refresh Data
          </button>
        </div>
      )}

      {wrongNetwork && (
        <div className="warning">
          <p>Wrong network. Switch to Arbitrum Sepolia.</p>
          <button onClick={switchNetwork}>Switch Network</button>
        </div>
      )}

      <div className="card">
        <h2>Governance Token</h2>

        <p>
          <b>GOV Balance:</b> {tokenBalance}
        </p>

        <p>
          <b>Voting Power:</b> {votingPower}
        </p>

        <p>
          <b>Delegate:</b> {delegateAddress || "-"}
        </p>

        <button onClick={delegateToSelf} disabled={!account || wrongNetwork}>
          Delegate to Self
        </button>
      </div>

      <div className="card">
        <h2>Wallet Token Balances</h2>

        <p>
          <b>DEMO Balance:</b> {demoBalance}
        </p>

        <p>
          <b>LP Balance:</b> {lpBalance}
        </p>
      </div>

      <div className="card">
        <h2>Oracle</h2>

        <p>
          <b>Latest Price:</b> {oraclePrice}
        </p>
      </div>

      <div className="card">
        <h2>AMM Pool State</h2>

        <p>
          <b>Pool:</b> {AMM_POOL}
        </p>

        <p>
          <b>Token0:</b> {token0Symbol} ({shortAddress(token0)})
        </p>

        <p>
          <b>Token1:</b> {token1Symbol} ({shortAddress(token1)})
        </p>

        <p>
          <b>Reserve0:</b> {reserve0} {token0Symbol}
        </p>

        <p>
          <b>Reserve1:</b> {reserve1} {token1Symbol}
        </p>

        <p>
          <b>Last Updated:</b> {ammLastUpdated || "-"}
        </p>

        <button onClick={readPoolReserves} disabled={!account || wrongNetwork}>
          Read Pool Reserves
        </button>
      </div>

      <div className="card">
        <h2>AMM Swap</h2>

        <select
          value={swapDirection}
          onChange={(e) => {
            setSwapDirection(e.target.value);
            setExpectedOut("0");
          }}
        >
          <option value="demoToGov">DEMO → GOV</option>
          <option value="govToDemo">GOV → DEMO</option>
        </select>

        <input
          placeholder="Amount in"
          value={swapAmount}
          onChange={(e) => setSwapAmount(e.target.value)}
        />

        <p>
          <b>Expected Out:</b> {expectedOut}
        </p>

        <button onClick={quoteSwap} disabled={!account || wrongNetwork}>
          Quote
        </button>

        <button onClick={approveSwapToken} disabled={!account || wrongNetwork}>
          Approve Input Token
        </button>

        <button onClick={executeSwap} disabled={!account || wrongNetwork}>
          Swap
        </button>
      </div>

      <div className="card">
        <h2>Governance</h2>

        <p>
          <b>Voting Delay:</b> {votingDelay} seconds
        </p>

        <p>
          <b>Voting Period:</b> {votingPeriod} seconds
        </p>

        <h3>Create New Proposal</h3>

        <p className="muted">
          This Governor uses a 30-second voting delay. After creating a proposal,
          wait about 30 seconds, then click Refresh Proposal List. The proposal
          should become Active and voting buttons will unlock.
        </p>

        <input
          placeholder="New deposit cap, example: 5000"
          value={newDepositCap}
          onChange={(e) => setNewDepositCap(e.target.value)}
        />

        <input
          placeholder="Proposal description"
          value={proposalDescription}
          onChange={(e) => setProposalDescription(e.target.value)}
        />

        <button onClick={createProposal} disabled={!account || wrongNetwork}>
          Create Proposal
        </button>

        {createdProposalId && (
          <div className="proposal-box">
            <p>
              <b>Created Proposal ID:</b>
            </p>
            <p className="long-text">{createdProposalId}</p>
          </div>
        )}

        <hr />

        <h3>Proposal List</h3>

        <input
          placeholder="Paste existing Proposal ID"
          value={manualProposalId}
          onChange={(e) => setManualProposalId(e.target.value)}
        />

        <button onClick={addManualProposal} disabled={!account || wrongNetwork}>
          Add Proposal ID
        </button>

        <button onClick={refreshProposalList} disabled={!account || wrongNetwork}>
          Refresh Proposal List
        </button>

        <button onClick={clearProposalList}>
          Clear Proposal List
        </button>

        {knownProposals.length === 0 ? (
          <p className="muted">No proposals yet. Create one from this page.</p>
        ) : (
          knownProposals.map((id) => {
            const state = proposalStateById[id] || "Unknown";
            const canVote = state === "Active";

            return (
              <div className="proposal-box" key={id}>
                <p>
                  <b>Proposal ID:</b>
                </p>

                <p className="long-text">{id}</p>

                <p>
                  <b>State:</b> {state}
                </p>

                {proposalCountdownById[id] && (
                  <p className="muted">
                    {proposalCountdownById[id]}
                  </p>
                )}

                {!canVote && (
                  <p className="muted">
                    Voting disabled until proposal state becomes Active.
                  </p>
                )}

                <button onClick={() => loadProposalState(id)}>
                  Check State
                </button>

                <button
                  onClick={() => voteOnProposal(1, id)}
                  disabled={!account || wrongNetwork || !canVote}
                >
                  Vote FOR
                </button>

                <button
                  onClick={() => voteOnProposal(0, id)}
                  disabled={!account || wrongNetwork || !canVote}
                >
                  Vote AGAINST
                </button>

                <button
                  onClick={() => voteOnProposal(2, id)}
                  disabled={!account || wrongNetwork || !canVote}
                >
                  Vote ABSTAIN
                </button>
              </div>
            );
          })
        )}
      </div>

      <div className="card">
        <h2>Subgraph Data</h2>

        <p>
          This section is for The Graph. Add <b>VITE_SUBGRAPH_URL</b> in frontend/.env
          when the subgraph is deployed.
        </p>

        <button onClick={loadSubgraphData}>
          Load Recent Swaps from Subgraph
        </button>

        <pre>{subgraphData || "No subgraph data loaded yet."}</pre>
      </div>

      {status && <div className="status">{status}</div>}

      {error && <div className="error">{error}</div>}
    </div>
  );
}
