// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IFlashMintDexV5} from "../../src/interfaces/IFlashMintDexV5.sol";
import {MockSetToken} from "./MockSetToken.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

contract MockFlashMint is IFlashMintDexV5 {
    mapping(address => bool) public approvedTokens;

    function getLeveragedTokenData(address _setToken, uint256 _setAmount, bool _isIssuance)
        external
        pure
        returns (LeveragedTokenData memory)
    {
        // Return dummy data
        return LeveragedTokenData(address(0), address(0), 0, address(0), 0);
    }

    function approveToken(address _token) external {
        approvedTokens[_token] = true;
    }

    function getIssueExactSet(
        address _setToken,
        uint256 _setAmount,
        uint256 _maxAmountInputToken,
        SwapData memory,
        SwapData memory
    ) public returns (uint256) {
        MockSetToken setToken = MockSetToken(_setToken);
        uint256 requiredAmount = _setAmount * setToken.underlyingUnit() / 1 ether;
        require(requiredAmount <= _maxAmountInputToken, "Exceeds max input");
        return requiredAmount;
    }

    function getRedeemExactSet(
        address _setToken,
        uint256 _setAmount,
        SwapData memory,
        SwapData memory
    ) public returns (uint256) {
        MockSetToken setToken = MockSetToken(_setToken);
        uint256 outputAmount = _setAmount * 1 ether / setToken.underlyingUnit();
        
        return outputAmount;
    }

    function redeemExactSetForETH(
        address _setToken,
        uint256 _setAmount,
        uint256 _minAmountOutputToken,
        SwapData memory _swapDataCollateralForDebt,
        SwapData memory _swapDataOutputToken
    ) external {
        revert("ETH operations not supported in mock");
    }

    function redeemExactSetForERC20(
        address _setToken,
        uint256 _setAmount,
        address _outputToken,
        uint256 _minAmountOutputToken,
        SwapData memory _swapDataCollateralForDebt,
        SwapData memory _swapDataOutputToken
    ) external {
        uint256 outputAmount = getRedeemExactSet(_setToken, _setAmount, _swapDataCollateralForDebt, _swapDataOutputToken);
        require(outputAmount >= _minAmountOutputToken, "Insufficient output amount");

        MockSetToken setToken = MockSetToken(_setToken);
        ERC20(setToken).transferFrom(msg.sender, address(setToken), _setAmount);
        setToken.redeem(msg.sender, _setAmount);
        
        emit FlashRedeem(
            msg.sender,
            _setToken,
            address(setToken.underlyingToken()),
            _setAmount,
            outputAmount
        );
    }

    function issueExactSetFromERC20(
        address _setToken,
        uint256 _setAmount,
        address _inputToken,
        uint256 _maxAmountInputToken,
        SwapData memory _swapDataDebtForCollateral,
        SwapData memory _swapDataInputToken
    ) external {
        uint256 requiredAmount = getIssueExactSet(
            _setToken, 
            _setAmount, 
            _maxAmountInputToken,
            _swapDataDebtForCollateral,
            _swapDataInputToken
        );

        MockSetToken setToken = MockSetToken(_setToken);
        ERC20(setToken.underlyingToken()).transferFrom(msg.sender, address(setToken), requiredAmount);
        setToken.issue(msg.sender, _setAmount);
        
        emit FlashMint(
            msg.sender,
            _setToken,
            address(setToken.underlyingToken()),
            requiredAmount,
            _setAmount
        );
    }

    function issueExactSetFromETH(
        address _setToken,
        uint256 _setAmount,
        SwapData memory _swapDataDebtForCollateral,
        SwapData memory _swapDataInputToken
    ) external payable {
        revert("ETH operations not supported in mock");
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        revert("Flash loans not supported in mock");
    }

    function approveTokens(address[] memory _tokens) external {
        for (uint256 i = 0; i < _tokens.length; i++) {
            approvedTokens[_tokens[i]] = true;
        }
    }

    function approveSetToken(address _setToken) external {
        approvedTokens[_setToken] = true;
    }
}
