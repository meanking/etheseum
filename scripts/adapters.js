require("dotenv").config();
const Web3 = require("web3");
const web3 = new Web3(process.env.NODE_URL);

const NET_ID = "666";

const registryArt = require("../registry.json");

const balancesArt = require("../build/contracts/Balances.json");
const investmentsArt = require("../build/contracts/Investments.json");
const dataArt = require("../build/contracts/ProtocolsData.json");

// Addresses
const ETH = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const USDC = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

// Contract Instances
const registry = new web3.eth.Contract(registryArt.abi, registryArt.address);
const investAdapter = new web3.eth.Contract(
  investmentsArt.abi,
  investmentsArt.networks[NET_ID].address
);
const dataAdapter = new web3.eth.Contract(
  dataArt.abi,
  dataArt.networks[NET_ID].address
);
const balanceAdapter = new web3.eth.Contract(
  balancesArt.abi,
  balancesArt.networks[NET_ID].address
);

const start = async () => {
  try {
    const tokens = [ETH, DAI, USDC, USDT];

    const wallet = "0x6a08dd8e7AB659c2cF3bA648ba845e3Bc0C4f073";

    const res = await balanceAdapter.methods.getBalances(tokens, wallet).call();
    console.log("Balances", res);

    const res2 = await dataAdapter.methods.getProtocolsData(ETH).call();
    console.log("Protocols Data", res2);

    const res3 = await investAdapter.methods.getBalances(tokens, wallet).call();
    console.log("Investments", res3);
  } catch (error) {
    console.log(error.message);
  }
};

start();
