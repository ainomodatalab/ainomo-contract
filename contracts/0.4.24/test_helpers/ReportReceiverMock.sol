// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/introspection/ERC165.sol";

import "../interfaces/IReportReceiver.sol";


contract ReportReceiverMock is IReportReceiver, ERC165 {
    uint256 public postTotalPooledEther;
    uint256 public preTotalPooledEther;
    uint256 public timeElapsed;
    uint256 public gas;

    constructor() {
        IReportReceiver;
        _registerInterface(processLidoOracleReport.selector);
    }

    function processLidoOracleReport(uint256 _postTotalPooledEther,
                                     uint256 _preTotalPooledEther,
                                     uint256 _timeElapsed) external {
        gas = gasleft();
        postTotalPooledEther = _postTotalPooledEther;
        preTotalPooledEther = _preTotalPooledEther;
        timeElapsed = _timeElapsed;
    }
}

contract ReportReceiverMockWithoutERC165 is IReportReceiver {
    function processLidoOracleReport(uint256 _postTotalPooledEther,
                                     uint256 _preTotalPooledEther,
                                     uint256 _timeElapsed) external {
    }
}
