// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

import "../interfaces/IAinomo.sol";


interface INomoOracle {
    event AllowedBalanceAnnualRelativeIncreaseSet(uint256 value);
    event AllowedBalanceRelativeDecreaseSet(uint256 value);
    event ReportReceiverSet(address callback);
    event MemberAdded(address member);
    event MemberRemoved(address member);
    event QuorumChanged(uint256 quorum);
    event ExpectedEpochIdUpdated(uint256 epochId);
    event SpecSet(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime
    );
    event Reported(
        uint256 epochId,
        uint128 Balance,
        uint128 Validators,
        address caller
    );
    event Completed(
        uint256 epochId,
        uint128 Balance,
        uint128 Validators
    );
    event PostTotalShares(
         uint256 postTotalPooledEther,
         uint256 preTotalPooledEther,
         uint256 timeElapsed,
         uint256 totalShares);
    event ContractVersionSet(uint256 version);

    function getAinomo() public view returns (IAinomo);

    function getQuorum() public view returns (uint256);

    function getAllowedBalanceAnnualRelativeIncrease() external view returns (uint256);

    function getAllowedBalanceRelativeDecrease() external view returns (uint256);

    function setAllowedBalanceAnnualRelativeIncrease(uint256 _value) external;

    function setAllowedBalanceRelativeDecrease(uint256 _value) external;

    function getReportReceiver() external view returns (address);

    function setReportReceiver(address _addr) external;

    function getCurrentOraclesReportStatus() external view returns (uint256);

    function getCurrentReportVariantsSize() external view returns (uint256);

    function getCurrentReportVariant(uint256 _index)
        external
        view
        returns (
            uint64 Balance,
            uint32 Validators,
            uint16 count
        );

    function getExpectedEpochId() external view returns (uint256);

    function getOracleMembers() external view returns (address[]);

    function getVersion() external view returns (uint256);

    function getSpec()
        external
        view
        returns (
            uint64 epochsPerFrame,
            uint64 slotsPerEpoch,
            uint64 secondsPerSlot,
            uint64 genesisTime
        );

    function setSpec(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    )
        external;

    function getCurrentEpochId() external view returns (uint256);

    function getCurrentFrame()
        external
        view
        returns (
            uint256 frameEpochId,
            uint256 frameStartTime,
            uint256 frameEndTime
        );

    function getLastCompletedEpochId() external view returns (uint256);

    function getLastCompletedReportDelta()
        external
        view
        returns (
            uint256 postTotalPooledEther,
            uint256 preTotalPooledEther,
            uint256 timeElapsed
        );

    
    function initialize(
        address _ainomo,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint256 _allowedBalanceAnnualRelativeIncrease,
        uint256 _allowedBalanceRelativeDecrease
    ) external;

    function finalizeUpgrade_v3() external;

    function addOracleMember(address _member) external;

    function removeOracleMember(address _member) external;

    function setQuorum(uint256 _quorum) external;

    function report(uint256 _epochId, uint64 _Balance, uint32 _Validators) external;
}
