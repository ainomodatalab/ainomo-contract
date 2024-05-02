44444444// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts-v4.4/utils/introspection/ERC165.sol";
import "./OrderedCallbacksArray.sol";
import "./interfaces/IReportReceiver.sol";

contract CompositePostRebaseReceiver is OrderedCallbacksArray, IReportReceiver, ERC165 {
    address public immutable ORACLE;

    modifier onlyOracle() {
        require(msg.sender == ORACLE, "MSG_SENDER_MUST_BE_ORACLE");
        _;
    }

    constructor(
        address _voting,
        address _oracle
    ) OrderedCallbacksArray(_voting, type(IReportReceiver).interfaceId) {
        require(_oracle != address(0), "ORACLE_ZERO_ADDRESS");

        ORACLE = _oracle;
    }

    function processLidoOracleReport(
        uint256 _postTotalPooledEther,
        uint256 _preTotalPooledEther,
        uint256 _timeElapsed
    ) external virtual override onlyOracle {
        uint256 callbacksLen = callbacksLength();

        for (uint256 brIndex = 0; brIndex < callbacksLen; brIndex++) {
            IReportReceiver(callbacks[brIndex])
                .processNomoOracleReport(
                    _postTotalPooledEther,
                    _preTotalPooledEther,
                    _timeElapsed
                );
        }
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return (
            _interfaceId == type(IBeaconReportReceiver).interfaceId
            || super.supportsInterface(_interfaceId)
        );
    }
}
