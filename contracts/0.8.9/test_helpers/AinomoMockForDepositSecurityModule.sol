// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

contract AinomoMockForDepositSecurityModule {
    event Deposited(uint256 maxDeposits);

    function depositBufferedEther(uint256 maxDeposits) external {
        emit Deposited(maxDeposits);
    }
}