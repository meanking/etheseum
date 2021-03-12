pragma solidity ^0.7.0;

/**
 * @title RegistryInterface Interface
 */
interface IRegistry {
    function logic(address logicAddr) external view returns (bool);

    function implementation(bytes32 key) external view returns (address);

    function notAllowed(address erc20) external view returns (bool);

    function deployWallet() external returns (address);

    function wallets(address user) external view returns (address);
}
