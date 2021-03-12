pragma solidity ^0.7.0;

interface IRewards {
    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward() external;

    function exit() external;

    function balanceOf(address account) external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function rewardRate() external view returns (uint256);

    function rewardsDuration() external view returns (uint256);
}
