// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts-v4.4/utils/introspection/ERC165.sol";
import "../interfaces/IReportReceiver.sol";

contract ReceiverMock is IReportReceiver, ERC165 {
    uint256 public immutable id;
    uint256 public processedCounter;

    constructor(uint256 _id) {
        id = _id;
    }

    function processNomoOracleReport(uint256, uint256, uint256) external virtual override {
        processedCounter++;
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return (
            _interfaceId == type(IReportReceiver).interfaceId
            || super.supportsInterface(_interfaceId)
        );
    }
}

contract ReceiverMockWithoutERC165 is IReportReceiver {
    function processNomoOracleReport(uint256, uint256, uint256) external virtual override {

    }
}
