pragma solidity ^0.7.0;

interface ATokenInterface {
    function redeem(uint256 amount) external;
    function principalBalanceOf(address user) external view returns (uint256);
    function balanceOf(address user) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferAllowed(address from, uint256 amount)
        external
        returns (bool);
}
