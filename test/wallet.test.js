const EthaRegistryTruffle = artifacts.require("EthaRegistry");
const SmartWallet = artifacts.require("SmartWallet");
const UniswapLogic = artifacts.require("UniswapLogic");
const AaveLogic = artifacts.require("AaveLogic");
const TransferLogic = artifacts.require("TransferLogic");
const DyDxLogic = artifacts.require("DyDxLogic");
const CompoundLogic = artifacts.require("CompoundLogic");
const ISoloMargin = artifacts.require("ISoloMargin");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const {
  expectRevert,
  balance: ozBalance,
  constants: { MAX_UINT256 },
} = require("@openzeppelin/test-helpers");

const { assertion } = require("@openzeppelin/test-helpers/src/expectRevert");
const { assert } = require("hardhat");
const hre = require("hardhat");

const FEE = 1000;
const USER = "0xdd79dc5b781b14ff091686961adc5d47e434f4b0";
const CHI_HOLDER = "0xca3650b0a1158c7736253c74d67a536d805d2f3e";
const MULTISIG = "0x9Fd332a4e9C7F2f0dbA90745c1324Cc170D16fE4";
const SOLO_MARGIN = "0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e";

// TOKENS
const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const ADAI_ADDRESS = "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d";
const CDAI_ADDRESS = "0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643";
const CHI_ADDRESS = "0x0000000000004946c0e9F43F4Dee607b0eF1fA1c";

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

contract("Smart Wallet", () => {
  let registry, wallet, transfers, compound, aave, dydx, uniswap, chi;

  before(async function () {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [USER],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [CHI_HOLDER],
    });

    dai = await IERC20.at(DAI_ADDRESS);
    chi = await IERC20.at(CHI_ADDRESS);

    await chi.transfer(USER, 200, { from: CHI_HOLDER });

    const EthaRegistry = await ethers.getContractFactory("EthaRegistry");

    transfers = await TransferLogic.new();
    compound = await CompoundLogic.new();
    aave = await AaveLogic.new();
    dydx = await DyDxLogic.new();
    uniswap = await UniswapLogic.new();
    smartWalletImpl = await SmartWallet.new();

    const proxy = await upgrades.deployProxy(EthaRegistry, [
      smartWalletImpl.address,
      MULTISIG,
      MULTISIG,
      FEE,
    ]);

    registry = await EthaRegistryTruffle.at(proxy.address);

    await registry.enableLogicMultiple([
      transfers.address,
      uniswap.address,
      aave.address,
      compound.address,
      dydx.address,
    ]);
  });

  it("should deploy a smart wallet", async function () {
    const tx = await registry.deployWallet({ from: USER });
    const swAddress = await registry.wallets(USER);
    wallet = await SmartWallet.at(swAddress);
    console.log("\tUSER SW:", swAddress);
    console.log("\tGas Used:", tx.receipt.gasUsed);

    await chi.approve(swAddress, MAX_UINT256, { from: USER });
  });

  it("should fund user with CHI and approve SW", async function () {
    await chi.transfer(USER, 200, { from: CHI_HOLDER });
    await chi.approve(wallet.address, MAX_UINT256, { from: USER });
  });

  it("should deposit DAI to the smart wallet", async function () {
    await dai.approve(wallet.address, MAX_UINT256, {
      from: USER,
    });
    const data = web3.eth.abi.encodeFunctionCall(
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
      [DAI_ADDRESS, toWei(500)]
    );

    const tx = await wallet.execute([transfers.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await dai.balanceOf(wallet.address);
    assert.equal(balance, toWei(500));
  });

  it("should invest DAI to Aave Protocol", async function () {
    const data = web3.eth.abi.encodeFunctionCall(
      {
        name: "mintAToken",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "erc20",
          },
          {
            type: "uint256",
            name: "tokenAmt",
          },
        ],
      },
      [DAI_ADDRESS, String(50e18)]
    );

    const tx = await wallet.execute([aave.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const aDaiContract = await IERC20.at(ADAI_ADDRESS);
    const invested = await aDaiContract.balanceOf(wallet.address);
    assert.equal(invested, String(50e18));
  });

  it("should invest DAI to Aave Protocol burning CHI tokens", async function () {
    const data = web3.eth.abi.encodeFunctionCall(
      {
        name: "mintAToken",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "erc20",
          },
          {
            type: "uint256",
            name: "tokenAmt",
          },
        ],
      },
      [DAI_ADDRESS, String(50e18)]
    );

    const tx = await wallet.execute([aave.address], [data], true, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const aDaiContract = await IERC20.at(ADAI_ADDRESS);
    const invested = await aDaiContract.balanceOf(wallet.address);
    assert(fromWei(invested) > 100); // 50 + 50 + interest earned
  });

  it("should invest DAI to Compound Protocol", async function () {
    const data = web3.eth.abi.encodeFunctionCall(
      {
        name: "mintCToken",
        type: "function",
        inputs: [
          {
            type: "address",
            name: "erc20",
          },
          {
            type: "address",
            name: "cErc20",
          },
          {
            type: "uint256",
            name: "tokenAmt",
          },
        ],
      },
      [DAI_ADDRESS, CDAI_ADDRESS, String(50e18)]
    );

    const tx = await wallet.execute([compound.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const cDaiContract = await IERC20.at(CDAI_ADDRESS);
    const invested = await cDaiContract.balanceOf(wallet.address);
    assert(fromWei(invested) > 0);
  });

  it("should invest DAI to DyDx Protocol", async function () {
    const data = web3.eth.abi.encodeFunctionCall(
      {
        name: "deposit",
        type: "function",
        inputs: [
          {
            type: "uint256",
            name: "marketId",
          },
          {
            type: "address",
            name: "erc20Addr",
          },
          {
            type: "uint256",
            name: "tokenAmt",
          },
        ],
      },
      [3, DAI_ADDRESS, String(50e18)]
    );

    const tx = await wallet.execute([dydx.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const soloMargin = await ISoloMargin.at(SOLO_MARGIN);
    let { value } = await soloMargin.getAccountWei([wallet.address, 0], 3);
    assert(fromWei(value), 50); // balance just after invested is 49.9999999999
  });

  it("should swap all remaining DAI to ETH using Uniswap", async function () {
    const data = web3.eth.abi.encodeFunctionCall(
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
      [DAI_ADDRESS, ETH_ADDRESS, MAX_UINT256]
    );

    const tx = await wallet.execute([uniswap.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await dai.balanceOf(wallet.address);
    assert.equal(balance, 0);

    const balanceEth = await web3.eth.getBalance(wallet.address);
    assert(fromWei(balanceEth) > 0);
  });
});
