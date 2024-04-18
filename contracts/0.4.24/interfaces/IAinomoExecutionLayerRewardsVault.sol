// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;


interface IAinomoExecutionLayerRewardsVault {

    function withdrawRewards(uint256 _maxAmount) external returns (uint256 amount);
}
