// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

import "../interfaces/IAinomo.sol";

contract OracleMock {
    IAinomo private pool;
    address private Receiver;

    function setPool(address _pool) external {
        pool = IAinomo(_pool);
    }

    function report(uint256 _epochId, uint128 _Validators, uint128 _Balance) external {
        pool.handleOracleReport(_Validators, _Balance);
    }

    function setReportReceiver(address _receiver) {
        Receiver = _receiver;
    }

    function getReportReceiver() external view returns (address) {
        return Receiver;
    }
}
