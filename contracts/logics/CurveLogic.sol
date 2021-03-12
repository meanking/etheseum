//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface ICurve {
    // solium-disable-next-line mixedcase
    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256 dy);

    // solium-disable-next-line mixedcase
    function get_dy(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256 dy);

    // solium-disable-next-line mixedcase
    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external;

    // solium-disable-next-line mixedcase
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 minDy
    ) external;
}

interface ICurveRegistry {
    function find_pool_for_coins(
        address _from,
        address _to,
        uint256 i
    ) external view returns (address);

    function get_exchange_amount(
        address _pool,
        address _from,
        address _to,
        uint256 _amount
    ) external view returns (uint256);
}

interface IERC20 {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
}

contract CurveLogic {
    ICurveRegistry curveRegistry = ICurveRegistry(
        0x7002B727Ef8F5571Cb5F9D70D13DBEEb4dFAe9d1
    );

    // CURVE POOLS
    ICurve internal constant curveCompound = ICurve(
        0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56
    );
    ICurve internal constant curveUSDT = ICurve(
        0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C
    );
    ICurve internal constant curveY = ICurve(
        0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51
    );
    ICurve internal constant curveBinance = ICurve(
        0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27
    );
    ICurve internal constant curveSynth = ICurve(
        0xA5407eAE9Ba41422680e2e00537571bcC53efBfD
    );
    ICurve internal constant curvePAX = ICurve(
        0x06364f10B501e868329afBc005b3492902d6C763
    );

    // TOKENS
    address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant TUSD_ADDRESS = 0x0000000000085d4780B73119b644AE5ecd22b376;
    address constant BUSD_ADDRESS = 0x4Fabb145d64652a948d72533023f6E7A623C7C53;
    address constant SUSD_ADDRESS = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
    address constant PAX_ADDRESS = 0x8E870D67F660D95d5be530380D0eC0bd388289E1;

    function getBestRate(
        address src,
        address dest,
        uint256 srcAmt,
        uint256 limit
    ) external view returns (address pool, uint256 destAmt) {
        for (uint256 i = 0; i <= limit; i++) {
            address checkPool = curveRegistry.find_pool_for_coins(src, dest, i);
            uint256 result = curveRegistry.get_exchange_amount(
                checkPool,
                src,
                dest,
                srcAmt
            );
            if (result > destAmt) {
                destAmt = result;
                pool = checkPool;
            }
        }
    }

    /**
     * @dev setting allowance to compound for the "user proxy" if required
     */
    function setApproval(
        address erc20,
        uint256 srcAmt,
        address to
    ) internal {
        IERC20 erc20Contract = IERC20(erc20);
        uint256 tokenAllowance = erc20Contract.allowance(address(this), to);
        if (srcAmt > tokenAllowance) {
            erc20Contract.approve(to, srcAmt - tokenAllowance);
        }
    }

    function swapOnCurveCompound(
        address src,
        address dest,
        uint256 srcAmt
    ) public returns (uint256) {
        int128 i = (src == DAI_ADDRESS ? 1 : 0) + (src == USDC_ADDRESS ? 2 : 0);
        int128 j = (dest == DAI_ADDRESS ? 1 : 0) +
            (dest == USDC_ADDRESS ? 2 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(curveCompound));

        curveCompound.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }

    function swapOnCurveUSDT(
        address src,
        address dest,
        uint256 srcAmt
    ) public returns (uint256) {
        int128 i = (src == DAI_ADDRESS ? 1 : 0) +
            (src == USDC_ADDRESS ? 2 : 0) +
            (src == USDT_ADDRESS ? 3 : 0);
        int128 j = (dest == DAI_ADDRESS ? 1 : 0) +
            (dest == USDC_ADDRESS ? 2 : 0) +
            (dest == USDT_ADDRESS ? 3 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(curveUSDT));

        curveUSDT.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }

    function swapOnCurveY(
        address src,
        address dest,
        uint256 srcAmt
    ) public returns (uint256) {
        int128 i = (src == DAI_ADDRESS ? 1 : 0) +
            (src == USDC_ADDRESS ? 2 : 0) +
            (src == USDT_ADDRESS ? 3 : 0) +
            (src == TUSD_ADDRESS ? 4 : 0);
        int128 j = (dest == DAI_ADDRESS ? 1 : 0) +
            (dest == USDC_ADDRESS ? 2 : 0) +
            (dest == USDT_ADDRESS ? 3 : 0) +
            (dest == TUSD_ADDRESS ? 4 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(curveY));

        curveY.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }

    function swapOnCurvePAX(
        address src,
        address dest,
        uint256 srcAmt
    ) public returns (uint256) {
        int128 i = (src == DAI_ADDRESS ? 1 : 0) +
            (src == USDC_ADDRESS ? 2 : 0) +
            (src == USDT_ADDRESS ? 3 : 0) +
            (src == PAX_ADDRESS ? 4 : 0);
        int128 j = (dest == DAI_ADDRESS ? 1 : 0) +
            (dest == USDC_ADDRESS ? 2 : 0) +
            (dest == USDT_ADDRESS ? 3 : 0) +
            (dest == PAX_ADDRESS ? 4 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(curvePAX));

        curvePAX.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }

    function swapOnCurveSynth(
        address src,
        address dest,
        uint256 srcAmt
    ) public returns (uint256) {
        int128 i = (src == DAI_ADDRESS ? 1 : 0) +
            (src == USDC_ADDRESS ? 2 : 0) +
            (src == USDT_ADDRESS ? 3 : 0) +
            (src == SUSD_ADDRESS ? 4 : 0);
        int128 j = (dest == DAI_ADDRESS ? 1 : 0) +
            (dest == USDC_ADDRESS ? 2 : 0) +
            (dest == USDT_ADDRESS ? 3 : 0) +
            (dest == SUSD_ADDRESS ? 4 : 0);
        if (i == 0 || j == 0) {
            return 0;
        }

        setApproval(src, srcAmt, address(curveSynth));

        curveSynth.exchange_underlying(i - 1, j - 1, srcAmt, 0);
    }
}
