const EthaRegistryTruffle = artifacts.require("EthaRegistry");
const SmartWallet = artifacts.require("SmartWallet");
const AaveLogic = artifacts.require("AaveLogic");
const TransferLogic = artifacts.require("TransferLogic");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const {
  constants: { MAX_UINT256 },
} = require("@openzeppelin/test-helpers");

const { assert } = require("hardhat");
const hre = require("hardhat");

const FEE = 1000;
const HOLDER = "0xdd79dc5b781b14ff091686961adc5d47e434f4b0";
const MULTISIG = "0x9Fd332a4e9C7F2f0dbA90745c1324Cc170D16fE4";

// TOKENS
const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const ADAI_ADDRESS = "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d";

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

contract("Smart Wallet", ([walletOwner, externalWallet]) => {
  let registry, wallet, transfers, compound, aave, dydx, uniswap, chi;

  before(async function () {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [HOLDER],
    });

    dai = await IERC20.at(DAI_ADDRESS);

    await dai.transfer(walletOwner, toWei(500), { from: HOLDER });

    const EthaRegistry = await ethers.getContractFactory("EthaRegistry");

    transfers = await TransferLogic.new();
    aave = await AaveLogic.new();

    smartWalletImpl = await SmartWallet.new();

    const proxy = await upgrades.deployProxy(EthaRegistry, [
      smartWalletImpl.address,
      MULTISIG,
      MULTISIG,
      FEE,
    ]);

    registry = await EthaRegistryTruffle.at(proxy.address);

    await registry.enableLogicMultiple([transfers.address, aave.address]);
  });

  it("should deploy a smart wallet", async function () {
    const tx = await registry.deployWallet({ from: walletOwner });
    const swAddress = await registry.wallets(walletOwner);
    wallet = await SmartWallet.at(swAddress);
    console.log("\tUSER SW:", swAddress);
    console.log("\tGas Used:", tx.receipt.gasUsed);
  });

  it("should deposit DAI to the smart wallet", async function () {
    await dai.approve(wallet.address, MAX_UINT256, {
      from: walletOwner,
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
      from: walletOwner,
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
      from: walletOwner,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const aDaiContract = await IERC20.at(ADAI_ADDRESS);
    const invested = await aDaiContract.balanceOf(wallet.address);
    assert.equal(invested, String(50e18));
  });

  it("should invest DAI to Aave Protocol using meta tx", async function () {
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

    const metadata = web3.eth.abi.encodeFunctionCall(
      {
        name: "execute",
        type: "function",
        inputs: [
          {
            type: "address[]",
            name: "targets",
          },
          {
            type: "bytes[]",
            name: "datas",
          },
          {
            type: "bool",
            name: "burnCHI",
          },
        ],
      },
      [[aave.address], [data], false]
    );

    const hash = await wallet.getHash(metadata);
    const sig = await web3.eth.sign(hash, walletOwner);

    const tx = await wallet.executeMetaTransaction(sig, metadata, {
      from: externalWallet,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);
  });
});
