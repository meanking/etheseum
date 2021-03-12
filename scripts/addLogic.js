const EthaRegistry = artifacts.require("EthaRegistry");

//truffle exec scripts/addLogic.js <logicAddress> --network kovan

module.exports = async callback => {
  try {
    const registry = await EthaRegistry.deployed();
    const logicAddress = process.argv[4];

    console.log(`Adding Logic Address...`);
    await registry.enableLogic(logicAddress);

    console.log(`Done!`);

    callback();
  } catch (e) {
    callback(e);
  }
};
