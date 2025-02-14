// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {MockERC20} from "uniswapx/test/util/mock/MockERC20.sol";

contract MockSetToken is MockERC20 {
    MockERC20 public underlyingToken;
    uint256 public underlyingUnit;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        MockERC20 _underlyingToken,
        uint256 _underlyingUnit
    ) MockERC20(_name, _symbol, _decimals) {
        underlyingToken = _underlyingToken;
        underlyingUnit = _underlyingUnit;
    }

    function issue(address _recipient, uint256 _amount) external {
        uint256 underlyingAmount = _amount * underlyingUnit;
        underlyingToken.transferFrom(msg.sender, address(this), underlyingAmount);
        _mint(_recipient, _amount);
    }

    function redeem(address _recipient, uint256 _amount) external {
        uint256 underlyingAmount = _amount * underlyingUnit;
        _burn(msg.sender, _amount);
        underlyingToken.transfer(_recipient, underlyingAmount);
    }
}
