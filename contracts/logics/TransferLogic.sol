//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IERC20 {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface IRegistry {
    function notAllowed(address erc20) external view returns (bool);
}

interface ISmartWallet {
    function registry() external view returns (address);
}

contract TransferLogic {
    event LogDeposit(address erc20, uint256 tokenAmt);
    event LogWithdraw(address erc20, uint256 tokenAmt);

    /**
     * @dev get ethereum address
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    /**
     * @dev Deposit ERC20 from user
     * @dev user must approve token transfer first
     */
    function deposit(address erc20, uint256 amount) external payable {
        if (erc20 != getAddressETH()) {
            IERC20(erc20).transferFrom(msg.sender, address(this), amount);
        }

        emit LogDeposit(erc20, amount);
    }

    /**
     * @dev Withdraw ETH/ERC20 to user
     */
    function withdraw(address erc20, uint256 amount) external {
        address registry = ISmartWallet(address(this)).registry();
        bool isNotAllowed = IRegistry(registry).notAllowed(erc20);

        require(!isNotAllowed, "Token withdraw not allowed");
        uint256 withdrawAmt = amount;

        if (erc20 == getAddressETH()) {
            uint256 srcBal = address(this).balance;
            if (amount > srcBal) {
                withdrawAmt = srcBal;
            }
            msg.sender.transfer(withdrawAmt);
        } else {
            IERC20 erc20Contract = IERC20(erc20);
            uint256 srcBal = erc20Contract.balanceOf(address(this));
            if (amount > srcBal) {
                withdrawAmt = srcBal;
            }
            erc20Contract.transfer(msg.sender, withdrawAmt);
        }

        emit LogWithdraw(erc20, amount);
    }
}
