pragma solidity ^0.7.0;

interface IGasToken {
    function approve(address, uint256) external;

    function transfer(address, uint256) external;

    function balanceOf(address account) external view returns (uint256);

    function freeUpTo(uint256 value) external returns (uint256 freed);

    function freeFromUpTo(address from, uint256 value)
        external
        returns (uint256 freed);

    function mint(uint256 value) external;
}
