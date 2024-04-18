// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

interface IOrderedCallbacksArray {
    event CallbackAdded(address indexed callback, uint256 atIndex);

    event CallbackRemoved(address indexed callback, uint256 atIndex);

    function callbacksLength() external view returns (uint256);

    function addCallback(address _callback) external;

    function insertCallback(address _callback, uint256 _atIndex) external;

    function removeCallback(uint256 _atIndex) external;

    function callbacks(uint256 _atIndex) external view returns (address);
}
