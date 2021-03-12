const EthaRegistry = artifacts.require("EthaRegistry");

//truffle exec scripts/disableLogic.js <logicAddress> --network kovan

module.exports = async callback => {
  try {
    const registry = await EthaRegistry.deployed();
    const logicAddress = process.argv[4];

    console.log(`Disabling Logic Address...`);
    await registry.disableLogic(logicAddress);

    console.log(`Done!`);

    callback();
  } catch (e) {
    callback(e);
  }
};
