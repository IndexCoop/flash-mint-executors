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
        address pool;         // For Curve swaps
        bytes32[] poolIds;    // For Balancer V2 multihop swaps
        uint8 exchange;
    }

    /* ============ Events ============ */

    event FlashMint(
        address indexed _recipient,     // The recipient address of the issued SetTokens
        address indexed _setToken,    // The issued SetToken
        address indexed _inputToken,    // The address of the input asset(ERC20/ETH) used to issue the SetTokens
        uint256 _amountInputToken,      // The amount of input tokens used for issuance
        uint256 _amountSetIssued        // The amount of SetTokens received by the recipient
    );

    event FlashRedeem(
        address indexed _recipient,     // The recipient address which redeemed the SetTokens
        address indexed _setToken,    // The redeemed SetToken
        address indexed _outputToken,   // The address of output asset(ERC20/ETH) received by the recipient
        uint256 _amountSetRedeemed,     // The amount of SetTokens redeemed for output tokens
        uint256 _amountOutputToken      // The amount of output tokens received by the recipient
    );

    /* ============ Functions ============ */

    function getLeveragedTokenData(
        address _setToken,
        uint256 _setAmount,
        bool _isIssuance
    ) external view returns (LeveragedTokenData memory);

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