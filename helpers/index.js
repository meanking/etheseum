const Helpers = {};

let artifacts = global["artifacts"];

Helpers.setArtifacts = function (newArtifacts) {
  artifacts = newArtifacts;
};

Helpers.deployWithProxy = async function (factory, proxyAdminAddress, ...args) {
  const AdminUpgradeabilityProxy = artifacts.require(
    "AdminUpgradeabilityProxy"
  );
  const implementation = await factory.new();

  const calldata = implementation.contract.methods
    .initialize(...args)
    .encodeABI();
  const proxy = await AdminUpgradeabilityProxy.new(
    implementation.address,
    proxyAdminAddress,
    calldata
  );

  const txHashes = [];

  txHashes.push(implementation.transactionHash);
  txHashes.push(proxy.transactionHash);

  const contract = await factory.at(proxy.address);

  return {
    implementation,
    proxy,
    contract,
    txHashes,
  };
};

module.exports = Helpers;
