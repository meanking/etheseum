//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/IUniswapFactory.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapExchange.sol";
import "../interfaces/IUniswapV2Exchange.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IWETH.sol";
import "../utils/UniversalERC20.sol";

contract UniswapLogic {
    using SafeMath for uint256;
    using UniversalERC20 for IERC20;
    using UniversalERC20 for IWETH;
    using UniswapV2ExchangeLib for IUniswapV2Exchange;

    IUniswapFactory internal constant uniswapFactory = IUniswapFactory(
        0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95
    );

    IUniswapV2Factory internal constant uniswapV2 = IUniswapV2Factory(
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
    );

    IUniswapV2Router internal constant router = IUniswapV2Router(
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );

    IWETH internal constant weth = IWETH(
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    );

    function swapV1(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) external payable {
        uint256 returnAmount = amount == uint256(-1)
            ? fromToken.balanceOf(address(this))
            : amount;

        if (!fromToken.isETH()) {
            IUniswapExchange fromExchange = uniswapFactory.getExchange(
                fromToken
            );

            if (fromExchange != IUniswapExchange(0)) {
                fromToken.universalApprove(address(fromExchange), returnAmount);
                returnAmount = fromExchange.tokenToEthSwapInput(
                    returnAmount,
                    1,
                    block.timestamp
                );
            }
        }

        if (!destToken.isETH()) {
            IUniswapExchange toExchange = uniswapFactory.getExchange(destToken);
            if (toExchange != IUniswapExchange(0)) {
                returnAmount = toExchange.ethToTokenSwapInput{value:returnAmount}(1, block.timestamp);
            }
        }
    }

    function swapV2(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) external payable {
        uint256 realAmt = amount == uint256(-1)
            ? fromToken.balanceOf(address(this))
            : amount;

        uint256 returnAmount = 0;

        if (fromToken.isETH()) {
            weth.deposit{value:realAmt}();
        }

        IERC20 fromTokenReal = fromToken.isETH() ? weth : fromToken;
        IERC20 toTokenReal = destToken.isETH() ? weth : destToken;
        IUniswapV2Exchange exchange = uniswapV2.getPair(
            fromTokenReal,
            toTokenReal
        );
        returnAmount = exchange.getReturn(fromTokenReal, toTokenReal, realAmt);

        fromTokenReal.universalTransfer(address(exchange), realAmt);
        if (uint256(address(fromTokenReal)) < uint256(address(toTokenReal))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }

        if (destToken.isETH()) {
            weth.withdraw(weth.balanceOf(address(this)));
        }
    }

    function addLiquidity(
        IERC20 tokenA,
        IERC20 tokenB,
        uint256 amtA,
        uint256 amtB
    ) external payable {
        uint256 realAmtA = amtA == uint256(-1)
            ? tokenA.universalBalanceOf(address(this))
            : amtA;

        uint256 realAmtB = amtB == uint256(-1)
            ? tokenB.universalBalanceOf(address(this))
            : amtB;

        IERC20 tokenAReal = tokenA.isETH() ? weth : tokenA;
        IERC20 tokenBReal = tokenB.isETH() ? weth : tokenB;

        // Wrap Ether
        if (tokenA.isETH()) {
            weth.deposit{value:realAmtA}();
        }
        if (tokenB.isETH()) {
            weth.deposit{value:realAmtB}();
        }

        // Approve Router
        tokenAReal.universalApprove(address(router), realAmtA);
        tokenBReal.universalApprove(address(router), realAmtB);

        router.addLiquidity(
            address(tokenAReal),
            address(tokenBReal),
            realAmtA,
            realAmtB,
            1,
            1,
            address(this),
            block.timestamp + 1
        );
    }

    function removeLiquidity(
        IERC20 tokenA,
        IERC20 tokenB,
        IERC20 poolToken,
        uint256 amtPoolTokens
    ) external payable {
        uint256 realAmt = amtPoolTokens == uint256(-1)
            ? poolToken.universalBalanceOf(address(this))
            : amtPoolTokens;

        // Approve Router
        poolToken.universalApprove(address(router), realAmt);

        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            realAmt,
            1,
            1,
            address(this),
            block.timestamp + 1
        );
    }
    
    receive() external payable {}
}
