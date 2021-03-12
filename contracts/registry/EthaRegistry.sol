//SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../wallet/SmartWallet.sol";
import "../utils/CloneFactory.sol";

/**
 * @title Logic Registry
 */
contract LogicRegistry is OwnableUpgradeable {
    using SafeMath for uint256;

    event LogEnableLogic(address logicAddress);
    event LogDisableLogic(address logicAddress);

    /// @notice Map of logic proxy state
    mapping(address => bool) public logicProxies;

    /// @dev
    /// @param _logicAddress (address)
    /// @return  (bool)
    function logic(address _logicAddress) public view returns (bool) {
        return logicProxies[_logicAddress];
    }

    /// @dev Enable logic proxy address
    /// @param _logicAddress (address)
    function enableLogic(address _logicAddress) public onlyOwner {
        require(_logicAddress != address(0), "ZERO ADDRESS");
        logicProxies[_logicAddress] = true;
        emit LogEnableLogic(_logicAddress);
    }

    /// @dev Enable multiple logic proxy addresses
    /// @param _logicAddresses (addresses)
    function enableLogicMultiple(address[] memory _logicAddresses)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _logicAddresses.length; i++) {
            enableLogic(_logicAddresses[i]);
        }
    }

    /// @dev Disable logic proxy address
    /// @param _logicAddress (address)
    function disableLogic(address _logicAddress) public onlyOwner {
        require(_logicAddress != address(0), "ZERO ADDRESS");
        logicProxies[_logicAddress] = false;
        emit LogDisableLogic(_logicAddress);
    }
}

/**
 * @dev Deploys a new proxy instance and sets msg.sender as owner of proxy
 */
contract WalletRegistry is LogicRegistry, CloneFactory {
    event Created(address indexed owner, address proxy);
    event LogRecord(
        address indexed currentOwner,
        address indexed nextOwner,
        address proxy
    );

    /// @dev implementation address of Smart Wallet
    address public implementation;

    /// @notice Address to UserWallet proxy map
    mapping(address => SmartWallet) public wallets;

    /// @dev Deploys a new proxy instance and sets custom owner of proxy
    /// Throws if the owner already have a UserWallet
    /// @return wallet - address of new Smart Wallet
    function deployWallet() public returns (SmartWallet wallet) {
        require(
            wallets[msg.sender] == SmartWallet(0),
            "multiple-proxy-per-user-not-allowed"
        );
        address payable _wallet = address(uint160(createClone(implementation)));
        wallet = SmartWallet(_wallet);
        wallet.initialize(address(this), msg.sender);
        wallets[msg.sender] = wallet; // will be changed via record() in next line execution
        emit Created(msg.sender, address(wallet));
    }

    /// @dev Change the address implementation of the Smart Wallet
    /// @param _impl new implementation address of Smart Wallet
    function setImplementation(address _impl) external onlyOwner {
        implementation = _impl;
    }
}

/// @title InstaRegistry
/// @dev Initializing Registry
contract EthaRegistry is WalletRegistry {
    /// @dev address of recipient receiving the protocol fees
    address public feeRecipient;

    /// @dev fee percentage charged to user in witdrawals (1% = 1000)
    uint256 fee;

    /// @dev keep track of token addresses not allowed to withdraw (i.e. cETH)
    mapping(address => bool) public notAllowed;

    function initialize(
        address _impl,
        address _owner,
        address _feeRecipient,
        uint256 _fee
    ) public initializer {
        require(
            _owner != address(0) && _feeRecipient != address(0),
            "ZERO ADDRESS"
        );

        implementation = _impl;
        __Ownable_init();
        fee = _fee;
        feeRecipient = _feeRecipient;

        notAllowed[0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d] = true; // ADAI
        notAllowed[0x9bA00D6856a4eDF4665BcA2C2309936572473B7E] = true; // AUSDC
        notAllowed[0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04] = true; // AETH
        notAllowed[0x71fc860F7D3A592A4a98740e39dB31d25db65ae8] = true; // AUSDT

        notAllowed[0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643] = true; // CDAI
        notAllowed[0x39AA39c021dfbaE8faC545936693aC917d5E7563] = true; // CUSDC
        notAllowed[0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5] = true; // CETH
        notAllowed[0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9] = true; // CUSDT
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function getFee() external view returns (uint256) {
        return fee;
    }

    function changeFeeRecipient(address _feeRecipient) public onlyOwner {
        feeRecipient = _feeRecipient;
    }

    /**
     * @dev add erc20 token contract to not allowance set
     */
    function addNotAllowed(address erc20) external onlyOwner {
        notAllowed[erc20] = true;
    }

    /**
     * @dev remove erc20 token contract from not allowance set
     */
    function removeNotAllowed(address erc20) external onlyOwner {
        notAllowed[erc20] = false;
    }

    /**
     * @dev get ethereum address
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev Withdraw ETH/ERC20 to recipient
     */
    function withdraw(
        address erc20,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(erc20 != address(0) && recipient != address(0), "ZERO ADDRESS");
        if (erc20 == getAddressETH()) {
            uint256 srcBal = address(this).balance;
            if (srcBal > amount) {
                address(uint160(recipient)).transfer(amount);
            }
        } else {
            IERC20 erc20Contract = IERC20(erc20);
            uint256 srcBal = erc20Contract.balanceOf(address(this));
            if (srcBal > amount) {
                erc20Contract.transfer(recipient, amount);
            }
        }
    }
}
