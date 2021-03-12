//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/IVault.sol";

interface ERC20Interface {
    function allowance(address, address) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function approve(address, uint256) external;

    function transfer(address, uint256) external;

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);
}

contract DSMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "math-not-safe");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = _a / _b;
        // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold
        return c;
    }

    uint256 constant WAD = 10**18;

    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
}

contract Helpers is DSMath {
    /**
     * @dev get ethereum address
     */
    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }


    function transferToken(address erc20) internal {
        if (erc20 == getAddressETH()) {
            msg.sender.transfer(address(this).balance);
        } else {
            ERC20Interface erc20Contract = ERC20Interface(erc20);
            uint256 srcBal = erc20Contract.balanceOf(address(this));
            if (srcBal > 0) {
                erc20Contract.transfer(msg.sender, srcBal);
            }
        }
    }


    function setApproval(
        address erc20,
        uint256 srcAmt,
        address to
    ) internal {
        ERC20Interface erc20Contract = ERC20Interface(erc20);
        uint256 tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, sub(srcAmt, tokenAllowance));
        }
    }
}

contract InverseResolver is Helpers {
     event LogVaultDeposit(address erc20, uint256 tokenAmt);
     event LogVaultDepositAndWait(address erc20, uint256 tokenAmt);
     event LogVaultWithdraw(address erc20, uint256 tokenAmt);
     event LogVaultWithdrawPending(address erc20, uint256 tokenAmt);
     event LogVaultClaim(uint256 claimAmount);

    function deposit(address erc20, uint256 tokenAmt, address vault) external payable {
        require(tokenAmt > 0, "amount-shoul-be-greaterThan-zero");
            ERC20Interface token = ERC20Interface(erc20);
            require(
                tokenAmt <= token.balanceOf(address(this)),
                "amountToBeDeposited-greaterThanAvailableBalance"
            );
            IVault ethaVault = IVault(vault);
            setApproval(erc20, tokenAmt, vault);
            ethaVault.deposit(tokenAmt);
        emit LogVaultDeposit(erc20, tokenAmt);
    }

    function depositAndWait(address erc20, uint256 tokenAmt, address vault) external payable {
        require(tokenAmt > 0, "amount-shoul-be-greaterThan-zero");
            ERC20Interface token = ERC20Interface(erc20);
            require(
                tokenAmt <= token.balanceOf(address(this)),
                "amountToBeDeposited-greaterThanAvailableBalance"
            );
            IVault ethaVault = IVault(vault);
            setApproval(erc20, tokenAmt, vault);
            ethaVault.depositAndWait(tokenAmt);
        emit LogVaultDepositAndWait(erc20, tokenAmt);
    }

}

contract InverseLogic is InverseResolver {
    receive() external payable {}
}