const StakingRewardsFactory = artifacts.require("StakingRewardsFactory");

const REWARD_AMOUNT = web3.utils.toWei("12500");
const REWARDS_DURATION = 3 * 365 * 24 * 60 * 60; // 3 years

//truffle exec truffleScripts/stakingPool.js --network mainnet

module.exports = async (callback) => {
  try {

    const stakingTokenAddress = ""; // Uni Lp Token

    const factory = await StakingRewardsFactory.deployed();
    await factory.deploy(stakingTokenAddress, REWARD_AMOUNT, REWARDS_DURATION);

    // Enable Staking
    await factory.notifyRewardAmounts();

    callback();
  } catch (e) {
    callback(e);
  }
};