require("dotenv").config();
const Web3 = require("web3");
const web3 = new Web3(process.env.NODE_URL);

// PARAMS
const MINT_CHI_TOKENS = false;
const BURN_CHI_TOKENS = false;
const CREATE_WALLET = true;
const NET_ID = "666";

const log = require("./excel");

const registryArt = require("../registry.json");

const smartWalletArt = require("../build/contracts/SmartWallet.json");
const transferArt = require("../build/contracts/TransferLogic.json");
const uniswapArt = require("../build/contracts/UniswapLogic.json");
const gasTokenArt = require("../build/contracts/IGasToken.json");
const ethaTokenArt = require("../build/contracts/RewardsToken.json");
const stakingTokenArt = require("../build/contracts/StakingToken.json");
const stakingArt = require("../build/contracts/StakingLogic.json");
const stakingFactoryArt = require("../build/contracts/StakingRewardsFactory.json");
const stakingRewardsArt = require("../build/contracts/StakingRewards.json");

const erc20Abi = require("./abis/erc20");
const gasTokenAbi = require("./abis/gasTokens");

// Addresses
const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const GAS_TOKENS = "0x0000000000004946c0e9F43F4Dee607b0eF1fA1c"; // CHI
const UNI_LP_TOKEN = "0xa478c2975ab1ea89e8196811f51a7b7ade33eb11"; // ETH/DAI

// Contract Instances
const registry = new web3.eth.Contract(registryArt.abi, registryArt.address);
const gasTokens = new web3.eth.Contract(gasTokenArt.abi, GAS_TOKENS);

const ethaToken = new web3.eth.Contract(
  ethaTokenArt.abi,
  ethaTokenArt.networks[NET_ID].address
);

const uniLpToken = new web3.eth.Contract(
  stakingTokenArt.abi,
  stakingTokenArt.networks[NET_ID].address
);

const stakingFactoryContract = new web3.eth.Contract(
  stakingFactoryArt.abi,
  stakingFactoryArt.networks[NET_ID].address
);

const infinite = String(
  web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1))
);

let wallet,
  smartWallet,
  walletAddress,
  initialChi,
  row = 2;

const walletCreation = async () => {
  console.log("Creating Smart Wallet...");
  const tx = await registry.methods
    .deployWallet()
    .send({ from: wallet, gas: web3.utils.toHex(5e6) });

  console.log("Gas Used:", tx.gasUsed);
  log("Wallet creation", tx.gasUsed, row++);

  walletAddress = await registry.methods.wallets(wallet).call();
  console.log("Smart Wallet Created!:", walletAddress);
};

const mintGasTokens = async () => {
  console.log("\nMinting CHI Tokens...");
  await gasTokens.methods
    .mint(100)
    .send({ from: wallet, gas: web3.utils.toHex(6e6) });
  initialChi = await gasTokens.methods.balanceOf(wallet).call();
  console.log("User CHI Tokens balance", initialChi);

  console.log("Approving SW to spend CHI tokens...");
  await gasTokens.methods
    .approve(walletAddress, 100)
    .send({ from: wallet, gas: web3.utils.toHex(6e6) });
};

const deposit = async () => {
  console.log("\nDepositing 5 ETH to SW");

  const depositEncode = web3.eth.abi.encodeFunctionCall(
    {
      name: "deposit",
      type: "function",
      inputs: [
        {
          type: "address",
          name: "erc20",
        },
        {
          type: "uint256",
          name: "amount",
        },
      ],
    },
    [ETH_ADDRESS, String(10e18)]
  );

  let tx = await smartWallet.methods
    .execute(
      [transferArt.networks[NET_ID].address],
      [depositEncode],
      BURN_CHI_TOKENS
    )
    .send({ from: wallet, gas: web3.utils.toHex(5e6), value: String(10e18) });

  console.log("Gas Used:", tx.gasUsed);
  log("Depositing ETH to SW", tx.gasUsed, row++);

  let balance = await web3.eth.getBalance(walletAddress);
  console.log(`SW ETH balance: `, +web3.utils.fromWei(balance));
};

const stakeUniswapLP = async () => {
  // Creating ETH/DAI Pool
  await stakingFactoryContract.methods
    .deploy(UNI_LP_TOKEN, web3.utils.toWei("1000"), 7 * 24 * 60 * 60)
    .send({ from: wallet, gas: web3.utils.toHex(5e6) });

  await stakingFactoryContract.methods
    .notifyRewardAmounts()
    .send({ from: wallet, gas: web3.utils.toHex(5e6) });

  const {
    stakingRewards,
  } = await stakingFactoryContract.methods
    .stakingRewardsInfoByStakingToken(UNI_LP_TOKEN)
    .call();

  console.log(stakingRewards);

  // Stake LP in Synthetix Contract
  const data1 = web3.eth.abi.encodeFunctionCall(
    {
      name: "swapV2",
      type: "function",
      inputs: [
        {
          type: "address",
          name: "fromToken",
        },
        {
          type: "address",
          name: "destToken",
        },
        {
          type: "uint256",
          name: "amount",
        },
      ],
    },
    [ETH_ADDRESS, DAI_ADDRESS, String(1e18)]
  );

  const data2 = web3.eth.abi.encodeFunctionCall(
    {
      name: "addLiquidity",
      type: "function",
      inputs: [
        {
          type: "address",
          name: "tokenA",
        },
        {
          type: "address",
          name: "tokenB",
        },
        {
          type: "uint256",
          name: "amtA",
        },
        {
          type: "uint256",
          name: "amtB",
        },
      ],
    },
    [ETH_ADDRESS, DAI_ADDRESS, String(1e18), String(500e18)]
  );

  // Stake LP in Synthetix Contract
  const data3 = web3.eth.abi.encodeFunctionCall(
    {
      name: "stake",
      type: "function",
      inputs: [
        {
          type: "address",
          name: "rewards",
        },
        {
          type: "address",
          name: "lpToken",
        },
        {
          type: "uint256",
          name: "amt",
        },
      ],
    },
    [stakingRewards, UNI_LP_TOKEN, infinite]
  );

  console.log("\nAdding ETH/ETHA liquidity and staking...");
  const tx = await smartWallet.methods
    .execute(
      [
        uniswapArt.networks[NET_ID].address,
        uniswapArt.networks[NET_ID].address,
        stakingArt.networks[NET_ID].address,
      ],
      [data1, data2, data3],
      BURN_CHI_TOKENS
    )
    .send({ from: wallet, gas: web3.utils.toHex(5e6) });

  console.log("Gas Used:", tx.gasUsed);
  log("Adding Liquity and Staking", tx.gasUsed, row++);

  let balance = await uniLpToken.methods.balanceOf(walletAddress).call();
  console.log(`Uni LP Tokens: `, +web3.utils.fromWei(balance));

  const rewardsContract = new web3.eth.Contract(
    stakingRewardsArt.abi,
    stakingRewards
  );

  const invested = await rewardsContract.methods
    .balanceOf(walletAddress)
    .call();
  console.log(`SW LP tokens invested: `, +web3.utils.fromWei(invested));

  const earned = await rewardsContract.methods.earned(walletAddress).call();
  console.log(`SW ETHA tokens earned: `, +web3.utils.fromWei(earned));
};

const start = async () => {
  try {
    const accounts = await web3.eth.getAccounts();
    wallet = accounts[0];
    // INITIALIZE

    if (CREATE_WALLET) await walletCreation();

    walletAddress = await registry.methods.wallets(wallet).call();
    smartWallet = new web3.eth.Contract(smartWalletArt.abi, walletAddress);

    if (MINT_CHI_TOKENS) await mintGasTokens();

    // DEPOSIT LP
    await deposit();

    // STAKE
    await stakeUniswapLP();
  } catch (error) {
    console.log(error.message);
  }
};

start();
