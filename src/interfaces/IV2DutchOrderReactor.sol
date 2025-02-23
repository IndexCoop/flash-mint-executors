// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IV2DutchOrderReactor {
    struct SignedOrder {
        bytes order;
        bytes sig;
    }

    error DeadlineBeforeEndTime();
    error DuplicateFeeOutput(address duplicateToken);
    error EndTimeBeforeStartTime();
    error FeeTooLarge(address token, uint256 amount, address recipient);
    error IncorrectAmounts();
    error InputAndOutputFees();
    error InvalidCosignature();
    error InvalidCosignerInput();
    error InvalidCosignerOutput();
    error InvalidFeeToken(address feeToken);
    error InvalidReactor();
    error NativeTransferFailed();
    error NoExclusiveOverride();

    event Fill(bytes32 indexed orderHash, address indexed filler, address indexed swapper, uint256 nonce);
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event ProtocolFeeControllerSet(address oldFeeController, address newFeeController);

    receive() external payable;

    function execute(SignedOrder memory order) external payable;
    function executeBatch(SignedOrder[] memory orders) external payable;
    function executeBatchWithCallback(SignedOrder[] memory orders, bytes memory callbackData) external payable;
    function executeWithCallback(SignedOrder memory order, bytes memory callbackData) external payable;
    function feeController() external view returns (address);
    function owner() external view returns (address);
    function permit2() external view returns (address);
    function setProtocolFeeController(address _newFeeController) external;
    function transferOwnership(address newOwner) external;
}
