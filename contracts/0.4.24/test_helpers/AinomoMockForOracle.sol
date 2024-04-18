// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;


contract AinomoMockForOracle {
    uint256 private totalPooledEther;

    function totalSupply() external view returns (uint256) {
        return totalPooledEther;
    }

    function handleOracleReport(uint256, uint256 _beaconBalance) external {
        totalPooledEther = _beaconBalance;
    }

    function getTotalShares() public view returns (uint256) {
        return 42;
    }

    function pretendTotalPooledEtherGweiForTest(uint256 _val) public {
        totalPooledEther = _val * 1e9; 
    }
}
