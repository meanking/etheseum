//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface AaveLendingPoolInterface {
    function deposit(
        address reserve,
        uint256 amount,
        uint16 referralCode
    ) external payable;

    function borrow(
        address reserve,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode
    ) external;

    function repay(
        address _reserve,
        uint256 amount,
        address payable onBehalfOf
    ) external payable;

    function rebalanceStableBorrowRate(address reserve, address user) external;

    function getReserveData(address reserve)
        external
        view
        returns (
            uint256 totalLiquidity,
            uint256 availableLiquidity,
            uint256 totalBorrowsStable,
            uint256 totalBorrowsVariable,
            uint256 liquidityRate,
            uint256 variableBorrowRate,
            uint256 stableBorrowRate,
            uint256 averageStableBorrowRate,
            uint256 utilizationRate,
            uint256 liquidityIndex,
            uint256 variableBorrowIndex,
            address aTokenAddress,
            uint40 lastUpdateTimestamp
        );

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalLiquidityETH,
            uint256 totalCollateralETH,
            uint256 totalBorrowsETH,
            uint256 totalFeesETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function getUserReserveData(address reserve, address user)
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentBorrowBalance,
            uint256 principalBorrowBalance,
            uint256 borrowRateMode,
            uint256 borrowRate,
            uint256 liquidityRate,
            uint256 originationFee,
            uint256 variableBorrowIndex,
            uint256 lastUpdateTimestamp,
            bool usageAsCollateralEnabled
        );

    function setUserUseReserveAsCollateral(
        address _reserve,
        bool _useAsCollateral
    ) external;
}

interface ATokenInterface {
    function redeem(uint256 amount) external;

    function principalBalanceOf(address user) external view returns (uint256);

    function balanceOf(address user) external view returns (uint256);

    function transferFrom(
        address,
        address,
        uint256
    ) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function transferAllowed(address from, uint256 amount)
        external
        returns (bool);

    function underlyingAssetAddress() external pure returns (address);
}

interface LendingPoolAddressProviderInterface {
    function getLendingPool() external view returns (address);

    function getLendingPoolCore() external view returns (address);
}

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

interface ISmartWallet {
    function registry() external pure returns (address);
}

interface IRegistry {
    function getFee() external pure returns (uint256);

    function feeRecipient() external pure returns (address payable);
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

    /**
     * @dev get Aave Lending Pool Address
     */
    function getLendingPoolAddress()
        public
        view
        returns (address lendingPoolAddress)
    {

            LendingPoolAddressProviderInterface adr
         = LendingPoolAddressProviderInterface(
            0x24a42fD28C976A61Df5D00D0599C34c4f90748c8
        ); //Mainnet
        return adr.getLendingPool();
    }

    function getLendingPoolCoreAddress()
        public
        view
        returns (address lendingPoolCoreAddress)
    {

            LendingPoolAddressProviderInterface adr
         = LendingPoolAddressProviderInterface(
            0x24a42fD28C976A61Df5D00D0599C34c4f90748c8
        ); //Mainnet
        return adr.getLendingPoolCore();
    }

    /**
     * @dev Transfer ETH/ERC20 to user
     */
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

    /**
     * @dev setting allowance to Aave for the "user proxy" if required
     */
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

contract AaveResolver is Helpers {
    event LogMint(address erc20, uint256 tokenAmt, address owner);
    event LogRedeem(address erc20, uint256 tokenAmt, address owner);

    /**
     * @dev Deposit ETH/ERC20 and mint Aave Tokens
     */
    function mintAToken(address erc20, uint256 tokenAmt) external payable {
        require(tokenAmt > 0, "amount-shoul-be-greaterThan-zero");
        if (erc20 == getAddressETH()) {
            require(tokenAmt <= address(this).balance, "notEnoughEthereum");
            AaveLendingPoolInterface aToken = AaveLendingPoolInterface(
                getLendingPoolAddress()
            );
            aToken.deposit{value:tokenAmt}(erc20, tokenAmt, 0);
        } else {
            ERC20Interface token = ERC20Interface(erc20);
            require(
                tokenAmt <= token.balanceOf(address(this)),
                "amountToBeDeposited-greaterThanAvailableBalance"
            );
            AaveLendingPoolInterface aToken = AaveLendingPoolInterface(
                getLendingPoolAddress()
            );
            setApproval(erc20, tokenAmt, getLendingPoolCoreAddress());
            aToken.deposit(erc20, tokenAmt, 0);
        }
        emit LogMint(erc20, tokenAmt, address(this));
    }

    /**
     * @dev Redeem ETH/ERC20 and burn Aave Tokens
     * @param aTokenAmt Amount of AToken To burn
     */
    function redeemAToken(address aErc20, uint256 aTokenAmt) external {
        require(aTokenAmt > 0, "amount-shoul-be-greaterThan-zero");
        ERC20Interface token = ERC20Interface(aErc20);
        require(
            aTokenAmt <= token.balanceOf(address(this)),
            "amountToBeRedeemed-greaterThanAvailableBalance"
        );
        ATokenInterface aToken = ATokenInterface(aErc20);
        address tokenAddress = aToken.underlyingAssetAddress();
        aToken.redeem(aTokenAmt);

        address registry = ISmartWallet(address(this)).registry();
        uint256 fee = IRegistry(registry).getFee();
        address payable feeRecipient = IRegistry(registry).feeRecipient();

        require(feeRecipient != address(0), "ZERO ADDRESS");

        if (tokenAddress == getAddressETH()) {
            feeRecipient.transfer(div(mul(aTokenAmt, fee), 100000));
        } else {
            ERC20Interface(tokenAddress).transfer(
                feeRecipient,
                div(mul(aTokenAmt, fee), 100000)
            );
        }
        emit LogRedeem(tokenAddress, aTokenAmt, address(this));
    }
}

contract AaveLogic is AaveResolver {
    receive() external payable {}
}
