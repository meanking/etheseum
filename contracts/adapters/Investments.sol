pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../interfaces/ILendingPool.sol";
import "../interfaces/ISoloMargin.sol";
import "../interfaces/ICToken.sol";
import "../interfaces/IAToken.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface IAaveAddressProvider {
    function getLendingPool() external view returns (address);

    function getLendingPoolCore() external view returns (address);
}

contract Investments {
    using SafeMath for uint256;

    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    mapping(address => address) internal cTokens;

    IAaveAddressProvider aaveProvider = IAaveAddressProvider(
        0x24a42fD28C976A61Df5D00D0599C34c4f90748c8
    );

    ISoloMargin solo = ISoloMargin(0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e);

    struct Balance {
        uint256 dydx;
        uint256 compound;
        uint256 aave;
    }

    constructor() public {
        cTokens[0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359] = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC;
        cTokens[0x1985365e9f78359a9B6AD760e32412f4a445E862] = 0x158079Ee67Fce2f58472A96584A73C7Ab9AC95c1;
        cTokens[0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE] = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
        cTokens[0x6B175474E89094C44Da98b954EedeAC495271d0F] = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
        cTokens[0x0D8775F648430679A709E98d2b0Cb6250d2887EF] = 0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E;
        cTokens[0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599] = 0xC11b1268C1A384e55C48c2391d8d480264A3A7F4;
        cTokens[0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48] = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;
        cTokens[0xE41d2489571d322189246DaFA5ebDe1F4699F498] = 0xB3319f5D18Bc0D84dD1b4825Dcde5d5f7266d407;
        cTokens[0xdAC17F958D2ee523a2206206994597C13D831ec7] = 0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9;
    }

    function getCToken(address token) public view returns (address) {
        return cTokens[token];
    }

    function getMarketId(address token) internal pure returns (uint256) {
        if (token == ETH) {
            return uint256(0);
        } else if (token == USDC) {
            return uint256(2);
        } else if (token == DAI) {
            return uint256(3);
        } else {
            return uint256(-1);
        }
    }

    function getDydxBalance(address token, address user)
        public
        view
        returns (uint256)
    {
        uint256 marketId = getMarketId(token);
        if (marketId == uint256(-1)) return 0;

        ISoloMargin.Wei memory accountWei = solo.getAccountWei(
            ISoloMargin.Info(user, 0),
            marketId
        );
        return accountWei.sign ? accountWei.value : 0;
    }

    function getCompoundBalance(address token, address user)
        public
        view
        returns (uint256)
    {
        CTokenInterface cToken = CTokenInterface(getCToken(token));
        // TODO: check exchange rate
        (, uint256 balance, , uint256 rate) = cToken.getAccountSnapshot(user);

        return balance.mul(rate).div(1 ether);
    }

    function getAaveBalance(address token, address account)
        public
        view
        returns (uint256 balance)
    {
        (balance, , ) = ILendingPool(aaveProvider.getLendingPool())
            .getUserReserveData(token, account);
    }

    function getBalances(address[] calldata tokens, address user)
        external
        view
        returns (Balance[] memory)
    {
        Balance[] memory balances = new Balance[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            balances[i].compound = getCompoundBalance(tokens[i], user);
            balances[i].aave = getAaveBalance(tokens[i], user);
            balances[i].dydx = getDydxBalance(tokens[i], user);
        }

        return balances;
    }
}
