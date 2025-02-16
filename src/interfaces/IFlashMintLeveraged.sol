// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library DEXAdapter {

    struct Addresses {
        address quickRouter;
        address sushiRouter;
        address uniV3Router;
        address uniV3Quoter;
        address curveAddressProvider;
        address curveCalculator;
        address weth;
    }

    struct SwapData {
        address[] path;
        uint24[] fees;
        address pool;
        uint8 exchange;
    }
}

interface IFlashMintLeveraged {
    struct LeveragedTokenData {
        address collateralAToken;
        address collateralToken;
        uint256 collateralAmount;
        address debtToken;
        uint256 debtAmount;
    }

    event FlashMint(
        address indexed _recipient,
        address indexed _setToken,
        address indexed _inputToken,
        uint256 _amountInputToken,
        uint256 _amountSetIssued
    );
    event FlashRedeem(
        address indexed _recipient,
        address indexed _setToken,
        address indexed _outputToken,
        uint256 _amountSetRedeemed,
        uint256 _amountOutputToken
    );

    receive() external payable;

    function LENDING_POOL() external view returns (address);
    function ROUNDING_ERROR_MARGIN() external view returns (uint256);
    function aaveLeverageModule() external view returns (address);
    function addresses()
        external
        view
        returns (
            address quickRouter,
            address sushiRouter,
            address uniV3Router,
            address uniV3Quoter,
            address curveAddressProvider,
            address curveCalculator,
            address weth
        );
    function approveSetToken(address _setToken) external;
    function approveToken(address _token) external;
    function approveTokens(address[] memory _tokens) external;
    function balancerV2Vault() external view returns (address);
    function debtIssuanceModule() external view returns (address);
    function getIssueExactSet(
        address _setToken,
        uint256 _setAmount,
        DEXAdapter.SwapData memory _swapDataDebtForCollateral,
        DEXAdapter.SwapData memory _swapDataInputToken
    ) external returns (uint256);
    function getLeveragedTokenData(address _setToken, uint256 _setAmount, bool _isIssuance)
        external
        view
        returns (LeveragedTokenData memory);
    function getRedeemExactSet(
        address _setToken,
        uint256 _setAmount,
        DEXAdapter.SwapData memory _swapDataCollateralForDebt,
        DEXAdapter.SwapData memory _swapDataOutputToken
    ) external returns (uint256);
    function issueExactSetFromERC20(
        address _setToken,
        uint256 _setAmount,
        address _inputToken,
        uint256 _maxAmountInputToken,
        DEXAdapter.SwapData memory _swapDataDebtForCollateral,
        DEXAdapter.SwapData memory _swapDataInputToken
    ) external;
    function issueExactSetFromETH(
        address _setToken,
        uint256 _setAmount,
        DEXAdapter.SwapData memory _swapDataDebtForCollateral,
        DEXAdapter.SwapData memory _swapDataInputToken
    ) external payable;
    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
    function redeemExactSetForERC20(
        address _setToken,
        uint256 _setAmount,
        address _outputToken,
        uint256 _minAmountOutputToken,
        DEXAdapter.SwapData memory _swapDataCollateralForDebt,
        DEXAdapter.SwapData memory _swapDataOutputToken
    ) external;
    function redeemExactSetForETH(
        address _setToken,
        uint256 _setAmount,
        uint256 _minAmountOutputToken,
        DEXAdapter.SwapData memory _swapDataCollateralForDebt,
        DEXAdapter.SwapData memory _swapDataOutputToken
    ) external;
    function setController() external view returns (address);
}
