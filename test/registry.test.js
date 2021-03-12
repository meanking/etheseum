const { expectRevert } = require("@openzeppelin/test-helpers");

const FEE = 1000;

contract("EthaRegistry", ([owner, alice, multisig, random]) => {
  let registry;

  before(async function () {
    const EthaRegistry = await ethers.getContractFactory("EthaRegistry");
    registry = await upgrades.deployProxy(EthaRegistry, [
      multisig,
      multisig,
      FEE,
    ]);
  });

  it("should check not allowed addresses", async function () {
    const notAllowed = await registry.notAllowed(
      "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d"
    );
    assert(notAllowed);
  });

  it("should upgrade proxy contract", async function () {
    const EthaRegistryMockV2 = await ethers.getContractFactory(
      "EthaRegistryMockV2"
    );
    registry = await upgrades.upgradeProxy(
      registry.address,
      EthaRegistryMockV2
    );
  });

  it("should check if contract remains with the same storage", async function () {
    const notAllowed = await registry.notAllowed(
      "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d" // aDAI
    );
    assert(notAllowed);
  });

  it("should be able to register a logic contract", async function () {
    const AaveLogic = await ethers.getContractFactory("AaveLogic");
    const aave = await AaveLogic.deploy();

    await registry.enableLogic(aave.address);

    const registered = await registry.logicProxies(aave.address);

    assert(registered);
  });

  it("should be able to register a multiple logic contracts", async function () {
    const TransferLogic = await ethers.getContractFactory("TransferLogic");
    const CompoundLogic = await ethers.getContractFactory("CompoundLogic");
    const transfers = await TransferLogic.deploy();
    const compound = await CompoundLogic.deploy();

    await registry.enableLogicMultiple([transfers.address, compound.address]);

    let registered = await registry.logicProxies(transfers.address);
    assert(registered);

    registered = await registry.logicProxies(compound.address);
    assert(registered);
  });
});
