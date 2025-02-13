pragma solidity ^0.8.0;

interface IFlashMintDexV5 {
    /* ============ Structs ============ */

    struct LeveragedTokenData {
        address collateralAToken;
        address collateralToken;
        uint256 collateralAmount;
        address debtToken;
        uint256 debtAmount;
    }

    struct SwapData {
        address[] path;
        uint24[] fees;
        int24[] tickSpacing;
        address pool; // For Curve swaps
        bytes32[] poolIds; // For Balancer V2 multihop swaps
        uint8 exchange;
    }

    /* ============ Events ============ */

    event FlashMint( // The recipient address of the issued SetTokens
        // The issued SetToken
        // The address of the input asset(ERC20/ETH) used to issue the SetTokens
        // The amount of input tokens used for issuance
        // The amount of SetTokens received by the recipient
        address indexed _recipient,
        address indexed _setToken,
        address indexed _inputToken,
        uint256 _amountInputToken,
        uint256 _amountSetIssued
    );

    event FlashRedeem( // The recipient address which redeemed the SetTokens
        // The redeemed SetToken
        // The address of output asset(ERC20/ETH) received by the recipient
        // The amount of SetTokens redeemed for output tokens
        // The amount of output tokens received by the recipient
        address indexed _recipient,
        address indexed _setToken,
        address indexed _outputToken,
        uint256 _amountSetRedeemed,
        uint256 _amountOutputToken
    );

    /* ============ Functions ============ */

    function getLeveragedTokenData(address _setToken, uint256 _setAmount, bool _isIssuance)
        external
        view
        returns (LeveragedTokenData memory);

    function approveToken(address _token) external;

    function getIssueExactSet(
        address _setToken,
        uint256 _setAmount,
        uint256 _maxAmountInputToken,
        SwapData memory _swapDataDebtForCollateral,
        SwapData memory _swapDataInputToken
    ) external returns (uint256);

    function getRedeemExactSet(
        address _setToken,
        uint256 _setAmount,
        SwapData memory _swapDataCollateralForDebt,
        SwapData memory _swapDataOutputToken
    ) external returns (uint256);

    function redeemExactSetForETH(
        address _setToken,
        uint256 _setAmount,
        uint256 _minAmountOutputToken,
        SwapData memory _swapDataCollateralForDebt,
        SwapData memory _swapDataOutputToken
    ) external;

    function redeemExactSetForERC20(
        address _setToken,
        uint256 _setAmount,
        address _outputToken,
        uint256 _minAmountOutputToken,
        SwapData memory _swapDataCollateralForDebt,
        SwapData memory _swapDataOutputToken
    ) external;

    function issueExactSetFromERC20(
        address _setToken,
        uint256 _setAmount,
        address _inputToken,
        uint256 _maxAmountInputToken,
        SwapData memory _swapDataDebtForCollateral,
        SwapData memory _swapDataInputToken
    ) external;

    function issueExactSetFromETH(
        address _setToken,
        uint256 _setAmount,
        SwapData memory _swapDataDebtForCollateral,
        SwapData memory _swapDataInputToken
    ) external payable;

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;

    function approveTokens(address[] memory _tokens) external;

    function approveSetToken(address _setToken) external;
}
