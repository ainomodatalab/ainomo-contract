// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

contract DepositContractMockForDepositSecurityModule {
    bytes32 internal depositRoot;

    function get_deposit_root() external view returns (bytes32) {
        return depositRoot;
    }

    function set_deposit_root(bytes32 _newRoot) external {
        depositRoot = _newRoot;
    }
}
