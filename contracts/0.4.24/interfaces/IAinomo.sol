// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

interface IAinomo {
    function totalSupply() external view returns (uint256);
    function getTotalShares() external view returns (uint256);

    function stop() external;

    function resume() external;

    function pauseStaking() external;

    function resumeStaking() external;

    function setStakingLimit(uint256 _maxStakeLimit, uint256 _stakeLimitIncreasePerBlock) external;

    function removeStakingLimit() external;

    function isStakingPaused() external view returns (bool);

    function getCurrentStakeLimit() external view returns (uint256);

    function getStakeLimitFullInfo() external view returns (
        bool isStakingPaused,
        bool isStakingLimitSet,
        uint256 currentStakeLimit,
        uint256 maxStakeLimit,
        uint256 maxStakeLimitGrowthBlocks,
        uint256 prevStakeLimit,
        uint256 prevStakeBlockNumber
    );

    event Stopped();
    event Resumed();

    event StakingPaused();
    event StakingResumed();
    event StakingLimitSet(uint256 maxStakeLimit, uint256 stakeLimitIncreasePerBlock);
    event StakingLimitRemoved();

    function setProtocolContracts(
        address _oracle,
        address _treasury,
        address _insuranceFund
    ) external;

    event ProtocolContactsSet(address oracle, address treasury, address insuranceFund);

    function setFee(uint16 _feeBasisPoints) external;

    function setFeeDistribution(
        uint16 _treasuryFeeBasisPoints,
        uint16 _insuranceFeeBasisPoints,
        uint16 _operatorsFeeBasisPoints
    ) external;

    /**
      * @notice Returns staking rewards fee rate
      */
    function getFee() external view returns (uint16 feeBasisPoints);

    /**
      * @notice Returns fee distribution proportion
      */
    function getFeeDistribution() external view returns (
        uint16 treasuryFeeBasisPoints,
        uint16 insuranceFeeBasisPoints,
        uint16 operatorsFeeBasisPoints
    );

    event FeeSet(uint16 feeBasisPoints);

    event FeeDistributionSet(uint16 treasuryFeeBasisPoints, uint16 insuranceFeeBasisPoints, uint16 operatorsFeeBasisPoints);

    function receiveELRewards() external payable;

    event ELRewardsReceived(uint256 amount);

    function setELRewardsWithdrawalLimit(uint16 _limitPoints) external;

    event ELRewardsWithdrawalLimitSet(uint256 limitPoints);

    function setWithdrawalCredentials(bytes32 _withdrawalCredentials) external;

    function getWithdrawalCredentials() external view returns (bytes);

    event WithdrawalCredentialsSet(bytes32 withdrawalCredentials);

    function setELRewardsVault(address _executionLayerRewardsVault) external;

    event ELRewardsVaultSet(address executionLayerRewardsVault);

    function handleOracleReport(uint256 _epoch, uint256 _eth2balance) external;


    function submit(address _referral) external payable returns (uint256 StETH);

    // Records a deposit made by a user
    event Submitted(address indexed sender, uint256 amount, address referral);

    // The `amount` of ether was sent to the deposit_contract.deposit function
    event Unbuffered(uint256 amount);

    event Withdrawal(address indexed sender, uint256 tokenAmount, uint256 sentFromBuffer,
                     bytes32 indexed pubkeyHash, uint256 etherAmount);


    // Info functions

    function getTotalPooledEther() external view returns (uint256);

    function getBufferedEther() external view returns (uint256);

    function getStat() external view returns (uint256 depositedValidators, uint256 Validators, uint256 Balance);
}
