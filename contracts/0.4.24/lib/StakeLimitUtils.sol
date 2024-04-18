// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

library StakeLimitState {
    struct Data {
        uint32 prevStakeBlockNumber;
        uint96 prevStakeLimit;
        uint32 maxStakeLimitGrowthBlocks;
        uint96 maxStakeLimit;
    }
}

library StakeLimitUnstructuredStorage {
    using UnstructuredStorage for bytes32;

    /// @dev Storage offset for `maxStakeLimit` (bits)
    uint256 internal constant MAX_STAKE_LIMIT_OFFSET = 160;
    /// @dev Storage offset for `maxStakeLimitGrowthBlocks` (bits)
    uint256 internal constant MAX_STAKE_LIMIT_GROWTH_BLOCKS_OFFSET = 128;
    /// @dev Storage offset for `prevStakeLimit` (bits)
    uint256 internal constant PREV_STAKE_LIMIT_OFFSET = 32;
    /// @dev Storage offset for `prevStakeBlockNumber` (bits)
    uint256 internal constant PREV_STAKE_BLOCK_NUMBER_OFFSET = 0;

    function getStorageStakeLimitStruct(bytes32 _position) internal view returns (StakeLimitState.Data memory stakeLimit) {
        uint256 slotValue = _position.getStorageUint256();

        stakeLimit.prevStakeBlockNumber = uint32(slotValue >> PREV_STAKE_BLOCK_NUMBER_OFFSET);
        stakeLimit.prevStakeLimit = uint96(slotValue >> PREV_STAKE_LIMIT_OFFSET);
        stakeLimit.maxStakeLimitGrowthBlocks = uint32(slotValue >> MAX_STAKE_LIMIT_GROWTH_BLOCKS_OFFSET);
        stakeLimit.maxStakeLimit = uint96(slotValue >> MAX_STAKE_LIMIT_OFFSET);
    }

    function setStorageStakeLimitStruct(bytes32 _position, StakeLimitState.Data memory _data) internal {
        _position.setStorageUint256(
            uint256(_data.prevStakeBlockNumber) << PREV_STAKE_BLOCK_NUMBER_OFFSET
                | uint256(_data.prevStakeLimit) << PREV_STAKE_LIMIT_OFFSET
                | uint256(_data.maxStakeLimitGrowthBlocks) << MAX_STAKE_LIMIT_GROWTH_BLOCKS_OFFSET
                | uint256(_data.maxStakeLimit) << MAX_STAKE_LIMIT_OFFSET
        );
    }
}

library StakeLimitUtils {
    function calculateCurrentStakeLimit(StakeLimitState.Data memory _data) internal view returns(uint256 limit) {
        uint256 stakeLimitIncPerBlock;
        if (_data.maxStakeLimitGrowthBlocks != 0) {
            stakeLimitIncPerBlock = _data.maxStakeLimit / _data.maxStakeLimitGrowthBlocks;
        }

        limit = _data.prevStakeLimit + ((block.number - _data.prevStakeBlockNumber) * stakeLimitIncPerBlock);
        if (limit > _data.maxStakeLimit) {
            limit = _data.maxStakeLimit;
        }
    }

    function isStakingPaused(StakeLimitState.Data memory _data) internal pure returns(bool) {
        return _data.prevStakeBlockNumber == 0;
    }

    function isStakingLimitSet(StakeLimitState.Data memory _data) internal pure returns(bool) {
        return _data.maxStakeLimit != 0;
    }

    function setStakingLimit(
        StakeLimitState.Data memory _data,
        uint256 _maxStakeLimit,
        uint256 _stakeLimitIncreasePerBlock
    ) internal view returns (StakeLimitState.Data memory) {
        require(_maxStakeLimit != 0, "ZERO_MAX_STAKE_LIMIT");
        require(_maxStakeLimit <= uint96(-1), "TOO_LARGE_MAX_STAKE_LIMIT");
        require(_maxStakeLimit >= _stakeLimitIncreasePerBlock, "TOO_LARGE_LIMIT_INCREASE");
        require(
            (_stakeLimitIncreasePerBlock == 0)
            || (_maxStakeLimit / _stakeLimitIncreasePerBlock <= uint32(-1)),
            "TOO_SMALL_LIMIT_INCREASE"
        );

        if ((_data.maxStakeLimit == 0) || (_maxStakeLimit < _data.prevStakeLimit)) {
            _data.prevStakeLimit = uint96(_maxStakeLimit);
        }
        _data.maxStakeLimitGrowthBlocks = _stakeLimitIncreasePerBlock != 0 ? uint32(_maxStakeLimit / _stakeLimitIncreasePerBlock) : 0;

        _data.maxStakeLimit = uint96(_maxStakeLimit);

        if (_data.prevStakeBlockNumber != 0) {
            _data.prevStakeBlockNumber = uint32(block.number);
        }

        return _data;
    }

    function removeStakingLimit(
        StakeLimitState.Data memory _data
    ) internal view returns (StakeLimitState.Data memory) {
        _data.maxStakeLimit = 0;

        return _data;
    }

    function updatePrevStakeLimit(
        StakeLimitState.Data memory _data,
        uint256 _newPrevStakeLimit
    ) internal view returns (StakeLimitState.Data memory) {
        assert(_newPrevStakeLimit <= uint96(-1));
        assert(_data.prevStakeBlockNumber != 0);

        _data.prevStakeLimit = uint96(_newPrevStakeLimit);
        _data.prevStakeBlockNumber = uint32(block.number);

        return _data;
    }

    function setStakeLimitPauseState(
        StakeLimitState.Data memory _data,
        bool _isPaused
    ) internal view returns (StakeLimitState.Data memory) {
        _data.prevStakeBlockNumber = uint32(_isPaused ? 0 : block.number);

        return _data;
    }
}
