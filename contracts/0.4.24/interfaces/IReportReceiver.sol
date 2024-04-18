// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;


/**
  * @title Interface defining a callback that the quorum will call on every quorum reached
  */
interface IReportReceiver {
    function processNomoOracleReport(uint256 _postTotalPooledEther,
                                     uint256 _preTotalPooledEther,
                                     uint256 _timeElapsed) external;
}
