// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

interface ISelfOwnedStETHBurner {
    function getCoverSharesBurnt() external view returns (uint256);

    function getNonCoverSharesBurnt() external view returns (uint256);
}
