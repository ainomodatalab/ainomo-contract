// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;


interface INodeOperatorsRegistry {
    function addNodeOperator(string _name, address _rewardAddress) external returns (uint256 id);

    function setNodeOperatorActive(uint256 _id, bool _active) external;

    function setNodeOperatorName(uint256 _id, string _name) external;

    function setNodeOperatorRewardAddress(uint256 _id, address _rewardAddress) external;

    function setNodeOperatorStakingLimit(uint256 _id, uint64 _stakingLimit) external;

    function reportStoppedValidators(uint256 _id, uint64 _stoppedIncrement) external;

    function trimUnusedKeys() external;

    function getNodeOperatorsCount() external view returns (uint256);

    function getActiveNodeOperatorsCount() external view returns (uint256);

    function getNodeOperator(uint256 _id, bool _fullInfo) external view returns (
        bool active,
        string name,
        address rewardAddress,
        uint64 stakingLimit,
        uint64 stoppedValidators,
        uint64 totalSigningKeys,
        uint64 usedSigningKeys);

    function getRewardsDistribution(uint256 _totalRewardShares) external view returns (
        address[] memory recipients,
        uint256[] memory shares
    );

    event NodeOperatorAdded(uint256 id, string name, address rewardAddress, uint64 stakingLimit);
    event NodeOperatorActiveSet(uint256 indexed id, bool active);
    event NodeOperatorNameSet(uint256 indexed id, string name);
    event NodeOperatorRewardAddressSet(uint256 indexed id, address rewardAddress);
    event NodeOperatorStakingLimitSet(uint256 indexed id, uint64 stakingLimit);
    event NodeOperatorTotalStoppedValidatorsReported(uint256 indexed id, uint64 totalStopped);
    event NodeOperatorTotalKeysTrimmed(uint256 indexed id, uint64 totalKeysTrimmed);

    function assignNextSigningKeys(uint256 _numKeys) external returns (bytes memory pubkeys, bytes memory signatures);

    function addSigningKeys(uint256 _operator_id, uint256 _quantity, bytes _pubkeys, bytes _signatures) external;

    function addSigningKeysOperatorBH(uint256 _operator_id, uint256 _quantity, bytes _pubkeys, bytes _signatures) external;

    function removeSigningKey(uint256 _operator_id, uint256 _index) external;

    function removeSigningKeyOperatorBH(uint256 _operator_id, uint256 _index) external;

    function removeSigningKeys(uint256 _operator_id, uint256 _index, uint256 _amount) external;

    function removeSigningKeysOperatorBH(uint256 _operator_id, uint256 _index, uint256 _amount) external;

    function getTotalSigningKeyCount(uint256 _operator_id) external view returns (uint256);

    function getUnusedSigningKeyCount(uint256 _operator_id) external view returns (uint256);

    function getSigningKey(uint256 _operator_id, uint256 _index) external view returns
            (bytes key, bytes depositSignature, bool used);


    function getKeysOpIndex() external view returns (uint256);

    event SigningKeyAdded(uint256 indexed operatorId, bytes pubkey);
    event SigningKeyRemoved(uint256 indexed operatorId, bytes pubkey);
    event KeysOpIndexSet(uint256 keysOpIndex);
}
