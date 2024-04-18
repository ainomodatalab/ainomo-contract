// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

import "../oracle/NomoOracle.sol";


contract NomoOracleMock is NomoOracle {
    uint256 private time;

    function setV1LastReportedEpochForTest(uint256 _epoch) public {
        V1_LAST_REPORTED_EPOCH_ID_POSITION.setStorageUint256(_epoch);
    }

    function setTime(uint256 _time) public {
        time = _time;
    }

    function _getTime() internal view returns (uint256) {
        return time;
    }
}
