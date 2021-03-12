const EthaRegistryTruffle = artifacts.require("EthaRegistry");
const SmartWallet = artifacts.require("SmartWallet");
const TransferLogic = artifacts.require("TransferLogic");
const UniswapLogic = artifacts.require("UniswapLogic");
const InverseLogic = artifacts.require("InverseLogic");
const Vault = artifacts.require("Vault");
const YTokenStrat = artifacts.require("YTokenStrat");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const {
  expectRevert,
  constants: { MAX_UINT256 },
} = require("@openzeppelin/test-helpers");

// const { assert } = require("hardhat");
const hre = require("hardhat");

const FEE = 1000;
const USER = "0xdd79dc5b781b14ff091686961adc5d47e434f4b0";
const MULTISIG = "0x9Fd332a4e9C7F2f0dbA90745c1324Cc170D16fE4";

// TOKENS
const ETH_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const YDAI_ADDRESS = "0xBFa4D8AA6d8a379aBFe7793399D3DdaCC5bBECBB";

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

contract("Inverse Vaults", () => {
  let registry, wallet, transfers, strat, uniswap, vault, inverse;

  before(async function () {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [USER],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [MULTISIG],
    });

    dai = await IERC20.at(DAI_ADDRESS);

    const EthaRegistry = await ethers.getContractFactory("EthaRegistry");

    transfers = await TransferLogic.new();
    uniswap = await UniswapLogic.new();
    inverse = await InverseLogic.new();
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
      inverse.address,
    ]);

    // Smart Wallet Creation
    await registry.deployWallet({ from: USER });
    const swAddress = await registry.wallets(USER);
    wallet = await SmartWallet.at(swAddress);

    // Deposit DAI
    await dai.transfer(swAddress, toWei(200), { from: USER });
  });

  it("should deploy the vault contract", async function () {
    vault = await Vault.new(
      DAI_ADDRESS,
      WETH_ADDRESS,
      MULTISIG,
      "Test DAI to ETH Vault",
      "testDAI>ETH"
    );
  });

  it("should deploy the YTokenStrat contract", async function () {
    strat = await YTokenStrat.new(vault.address, YDAI_ADDRESS);
  });

  it("Should connect Strat to Vault", async function () {
    await vault.setStrat(strat.address, false);
    assert.equal(await vault.strat(), strat.address);
    assert.equal(await vault.paused(), false);
  });

  it("Should deposit DAI to vault", async function () {
    const daiBalance = await dai.balanceOf(wallet.address);
    assert.equal(daiBalance, toWei(200));

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
            name: "tokenAmt",
          },
          {
            type: "address",
            name: "vault",
          },
        ],
      },
      [DAI_ADDRESS, String(50e18), vault.address]
    );

    const tx = await wallet.execute([inverse.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const vaultTokenBalance = await vault.balanceOf(wallet.address);
    assert(fromWei(vaultTokenBalance) > 0);
  });

  it("Should deposit DAI to vault using waiting functionality", async function () {
    const data = web3.eth.abi.encodeFunctionCall(
      {
        name: "depositAndWait",
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
          {
            type: "address",
            name: "vault",
          },
        ],
      },
      [DAI_ADDRESS, String(50e18), vault.address]
    );

    const tx = await wallet.execute([inverse.address], [data], false, {
      from: USER,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);
  });

  it("Should deposit DAI to vault starting with ETH", async function () {
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
      [ETH_ADDRESS, DAI_ADDRESS, toWei(1)]
    );

    const data2 = web3.eth.abi.encodeFunctionCall(
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
            name: "tokenAmt",
          },
          {
            type: "address",
            name: "vault",
          },
        ],
      },
      [DAI_ADDRESS, String(50e18), vault.address]
    );

    const tx = await wallet.execute(
      [uniswap.address, inverse.address],
      [data1, data2],
      false,
      {
        from: USER,
        gas: web3.utils.toHex(5e6),
        value: toWei(1),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const vaultTokenBalance = await vault.balanceOf(wallet.address);
    assert(fromWei(vaultTokenBalance) > 0);
  });
});
