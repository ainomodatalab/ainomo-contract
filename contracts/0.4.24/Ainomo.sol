// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

import "solidity-bytes-utils/contracts/BytesLib.sol";

import "./interfaces/IAinomo.sol";
import "./interfaces/INodeOperatorsRegistry.sol";
import "./interfaces/IDepositContract.sol";
import "./interfaces/IAinomoExecutionLayerRewardsVault.sol";

import "./StETH.sol";

import "./lib/StakeLimitUtils.sol";


interface IERC721 {
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
}


contract Ainomo is IAinomo, StETH, AragonApp {
    using SafeMath for uint256;
    using UnstructuredStorage for bytes32;
    using StakeLimitUnstructuredStorage for bytes32;
    using StakeLimitUtils for StakeLimitState.Data;

    /// ACL
    bytes32 constant public PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 constant public RESUME_ROLE = keccak256("RESUME_ROLE");
    bytes32 constant public STAKING_PAUSE_ROLE = keccak256("STAKING_PAUSE_ROLE");
    bytes32 constant public STAKING_CONTROL_ROLE = keccak256("STAKING_CONTROL_ROLE");
    bytes32 constant public MANAGE_FEE = keccak256("MANAGE_FEE");
    bytes32 constant public MANAGE_WITHDRAWAL_KEY = keccak256("MANAGE_WITHDRAWAL_KEY");
    bytes32 constant public MANAGE_PROTOCOL_CONTRACTS_ROLE = keccak256("MANAGE_PROTOCOL_CONTRACTS_ROLE");
    bytes32 constant public BURN_ROLE = keccak256("BURN_ROLE");
    bytes32 constant public DEPOSIT_ROLE = keccak256("DEPOSIT_ROLE");
    bytes32 constant public SET_EL_REWARDS_VAULT_ROLE = keccak256("SET_EL_REWARDS_VAULT_ROLE");
    bytes32 constant public SET_EL_REWARDS_WITHDRAWAL_LIMIT_ROLE = keccak256(
        "SET_EL_REWARDS_WITHDRAWAL_LIMIT_ROLE"
    );

    uint256 constant public PUBKEY_LENGTH = 48;
    uint256 constant public WITHDRAWAL_CREDENTIALS_LENGTH = 32;
    uint256 constant public SIGNATURE_LENGTH = 96;

    uint256 constant public DEPOSIT_SIZE = 32 ether;

    uint256 internal constant DEPOSIT_AMOUNT_UNIT = 1000000000 wei;
    uint256 internal constant TOTAL_BASIS_POINTS = 10000;

    uint256 internal constant DEFAULT_MAX_DEPOSITS_PER_CALL = 150;

    bytes32 internal constant FEE_POSITION = keccak256("nomo.Ainomo.fee");
    bytes32 internal constant TREASURY_FEE_POSITION = keccak256("nomo.Ainomo.treasuryFee");
    bytes32 internal constant INSURANCE_FEE_POSITION = keccak256("nomo.Ainomo.insuranceFee");
    bytes32 internal constant NODE_OPERATORS_FEE_POSITION = keccak256("nomo.Ainomo.nodeOperatorsFee");

    bytes32 internal constant DEPOSIT_CONTRACT_POSITION = keccak256("nomo.Ainomo.depositContract");
    bytes32 internal constant ORACLE_POSITION = keccak256("nomo.Ainomo.oracle");
    bytes32 internal constant NODE_OPERATORS_REGISTRY_POSITION = keccak256("nomo.Ainomo.nodeOperatorsRegistry");
    bytes32 internal constant TREASURY_POSITION = keccak256("nomo.Ainomo.treasury");
    bytes32 internal constant INSURANCE_FUND_POSITION = keccak256("nomo.Ainomo.insuranceFund");
    bytes32 internal constant EL_REWARDS_VAULT_POSITION = keccak256("nomo.Ainomo.executionLayerRewardsVault");

    bytes32 internal constant STAKING_STATE_POSITION = keccak256("nomo.Ainomo.stakeLimit");
    bytes32 internal constant BUFFERED_ETHER_POSITION = keccak256("nomo.Ainomo.bufferedEther");
    bytes32 internal constant DEPOSITED_VALIDATORS_POSITION = keccak256("nomo.Ainomo.depositedValidators");
    bytes32 internal constant BEACON_BALANCE_POSITION = keccak256("nomo.Ainomo.Balance");
    bytes32 internal constant BEACON_VALIDATORS_POSITION = keccak256("nomo.Ainomo.Validators");

    bytes32 internal constant EL_REWARDS_WITHDRAWAL_LIMIT_POSITION = keccak256("nomo.Ainomo.ELRewardsWithdrawalLimit");

    bytes32 internal constant TOTAL_EL_REWARDS_COLLECTED_POSITION = keccak256("nomo.Ainomo.totalELRewardsCollected");

    bytes32 internal constant WITHDRAWAL_CREDENTIALS_POSITION = keccak256("nomo.Ainomo.withdrawalCredentials");

    function initialize(
        IDepositContract _depositContract,
        address _oracle,
        INodeOperatorsRegistry _operators,
        address _treasury,
        address _insuranceFund
    )
        public onlyInit
    {
        NODE_OPERATORS_REGISTRY_POSITION.setStorageAddress(address(_operators));
        DEPOSIT_CONTRACT_POSITION.setStorageAddress(address(_depositContract));

        _setProtocolContracts(_oracle, _treasury, _insuranceFund);

        initialized();
    }

    function pauseStaking() external {
        _auth(STAKING_PAUSE_ROLE);

        _pauseStaking();
    }

    function resumeStaking() external {
        _auth(STAKING_CONTROL_ROLE);

        _resumeStaking();
    }

    function setStakingLimit(uint256 _maxStakeLimit, uint256 _stakeLimitIncreasePerBlock) external {
        _auth(STAKING_CONTROL_ROLE);

        STAKING_STATE_POSITION.setStorageStakeLimitStruct(
            STAKING_STATE_POSITION.getStorageStakeLimitStruct().setStakingLimit(
                _maxStakeLimit,
                _stakeLimitIncreasePerBlock
            )
        );

        emit StakingLimitSet(_maxStakeLimit, _stakeLimitIncreasePerBlock);
    }

    function removeStakingLimit() external {
        _auth(STAKING_CONTROL_ROLE);

        STAKING_STATE_POSITION.setStorageStakeLimitStruct(
            STAKING_STATE_POSITION.getStorageStakeLimitStruct().removeStakingLimit()
        );

        emit StakingLimitRemoved();
    }

    function isStakingPaused() external view returns (bool) {
        return STAKING_STATE_POSITION.getStorageStakeLimitStruct().isStakingPaused();
    }

    function getCurrentStakeLimit() public view returns (uint256) {
        return _getCurrentStakeLimit(STAKING_STATE_POSITION.getStorageStakeLimitStruct());
    }

    function getStakeLimitFullInfo() external view returns (
        bool isStakingPaused,
        bool isStakingLimitSet,
        uint256 currentStakeLimit,
        uint256 maxStakeLimit,
        uint256 maxStakeLimitGrowthBlocks,
        uint256 prevStakeLimit,
        uint256 prevStakeBlockNumber
    ) {
        StakeLimitState.Data memory stakeLimitData = STAKING_STATE_POSITION.getStorageStakeLimitStruct();

        isStakingPaused = stakeLimitData.isStakingPaused();
        isStakingLimitSet = stakeLimitData.isStakingLimitSet();

        currentStakeLimit = _getCurrentStakeLimit(stakeLimitData);

        maxStakeLimit = stakeLimitData.maxStakeLimit;
        maxStakeLimitGrowthBlocks = stakeLimitData.maxStakeLimitGrowthBlocks;
        prevStakeLimit = stakeLimitData.prevStakeLimit;
        prevStakeBlockNumber = stakeLimitData.prevStakeBlockNumber;
    }

    function() external payable {
        require(msg.data.length == 0, "NON_EMPTY_DATA");
        _submit(0);
    }

    function submit(address _referral) external payable returns (uint256) {
        return _submit(_referral);
    }

    function receiveELRewards() external payable {
        require(msg.sender == EL_REWARDS_VAULT_POSITION.getStorageAddress());

        TOTAL_EL_REWARDS_COLLECTED_POSITION.setStorageUint256(
            TOTAL_EL_REWARDS_COLLECTED_POSITION.getStorageUint256().add(msg.value));

        emit ELRewardsReceived(msg.value);
    }

    function depositBufferedEther() external {
        _auth(DEPOSIT_ROLE);

        return _depositBufferedEther(DEFAULT_MAX_DEPOSITS_PER_CALL);
    }

    function depositBufferedEther(uint256 _maxDeposits) external {
        _auth(DEPOSIT_ROLE);

        return _depositBufferedEther(_maxDeposits);
    }

    function burnShares(address _account, uint256 _sharesAmount)
        external
        authP(BURN_ROLE, arr(_account, _sharesAmount))
        returns (uint256 newTotalShares)
    {
        return _burnShares(_account, _sharesAmount);
    }

    function stop() external {
        _auth(PAUSE_ROLE);

        _stop();
        _pauseStaking();
    }

    function resume() external {
        _auth(RESUME_ROLE);

        _resume();
        _resumeStaking();
    }

    function setFee(uint16 _feeBasisPoints) external {
        _auth(MANAGE_FEE);

        _setBPValue(FEE_POSITION, _feeBasisPoints);
        emit FeeSet(_feeBasisPoints);
    }

    function setFeeDistribution(
        uint16 _treasuryFeeBasisPoints,
        uint16 _insuranceFeeBasisPoints,
        uint16 _operatorsFeeBasisPoints
    )
        external
    {
        _auth(MANAGE_FEE);

        require(
            TOTAL_BASIS_POINTS == uint256(_treasuryFeeBasisPoints)
            .add(uint256(_insuranceFeeBasisPoints))
            .add(uint256(_operatorsFeeBasisPoints)),
            "FEES_DONT_ADD_UP"
        );

        _setBPValue(TREASURY_FEE_POSITION, _treasuryFeeBasisPoints);
        _setBPValue(INSURANCE_FEE_POSITION, _insuranceFeeBasisPoints);
        _setBPValue(NODE_OPERATORS_FEE_POSITION, _operatorsFeeBasisPoints);

        emit FeeDistributionSet(_treasuryFeeBasisPoints, _insuranceFeeBasisPoints, _operatorsFeeBasisPoints);
    }

    function setProtocolContracts(
        address _oracle,
        address _treasury,
        address _insuranceFund
    ) external {
        _auth(MANAGE_PROTOCOL_CONTRACTS_ROLE);

        _setProtocolContracts(_oracle, _treasury, _insuranceFund);
    }

    function setWithdrawalCredentials(bytes32 _withdrawalCredentials) external {
        _auth(MANAGE_WITHDRAWAL_KEY);

        WITHDRAWAL_CREDENTIALS_POSITION.setStorageBytes32(_withdrawalCredentials);
        getOperators().trimUnusedKeys();

        emit WithdrawalCredentialsSet(_withdrawalCredentials);
    }

    function setELRewardsVault(address _executionLayerRewardsVault) external {
        _auth(SET_EL_REWARDS_VAULT_ROLE);

        EL_REWARDS_VAULT_POSITION.setStorageAddress(_executionLayerRewardsVault);

        emit ELRewardsVaultSet(_executionLayerRewardsVault);
    }

    function setELRewardsWithdrawalLimit(uint16 _limitPoints) external {
        _auth(SET_EL_REWARDS_WITHDRAWAL_LIMIT_ROLE);

        _setBPValue(EL_REWARDS_WITHDRAWAL_LIMIT_POSITION, _limitPoints);
        emit ELRewardsWithdrawalLimitSet(_limitPoints);
    }

    function handleOracleReport(uint256 _Validators, uint256 _Balance) external whenNotStopped {
        require(msg.sender == getOracle(), "APP_AUTH_FAILED");

        uint256 depositedValidators = DEPOSITED_VALIDATORS_POSITION.getStorageUint256();
        require(_Validators <= depositedValidators, "REPORTED_MORE_DEPOSITED");

        uint256 Validators = BEACON_VALIDATORS_POSITION.getStorageUint256();
        require(_Validators >= Validators, "REPORTED_LESS_VALIDATORS");
        uint256 appearedValidators = _Validators.sub(Validators);

        uint256 rewardBase = (appearedValidators.mul(DEPOSIT_SIZE)).add(BEACON_BALANCE_POSITION.getStorageUint256());

        BEACON_BALANCE_POSITION.setStorageUint256(_Balance);
        BEACON_VALIDATORS_POSITION.setStorageUint256(_Validators);


        uint256 executionLayerRewards;
        address executionLayerRewardsVaultAddress = getELRewardsVault();

        if (executionLayerRewardsVaultAddress != address(0)) {
            executionLayerRewards = IAinomoExecutionLayerRewardsVault(executionLayerRewardsVaultAddress).withdrawRewards(
                (_getTotalPooledEther() * EL_REWARDS_WITHDRAWAL_LIMIT_POSITION.getStorageUint256()) / TOTAL_BASIS_POINTS
            );

            if (executionLayerRewards != 0) {
                BUFFERED_ETHER_POSITION.setStorageUint256(_getBufferedEther().add(executionLayerRewards));
            }
        }

        if (_Balance > rewardBase) {
            uint256 rewards = _Balance.sub(rewardBase);
            distributeFee(rewards.add(executionLayerRewards));
        }
    }

    function transferToVault(address _token) external {
        require(allowRecoverability(_token), "RECOVER_DISALLOWED");
        address vault = getRecoveryVault();
        require(vault != address(0), "RECOVER_VAULT_ZERO");

        uint256 balance;
        if (_token == ETH) {
            balance = _getUnaccountedEther();
            require(vault.call.value(balance)(), "RECOVER_TRANSFER_FAILED");
        } else {
            ERC20 token = ERC20(_token);
            balance = token.staticBalanceOf(this);
            require(token.safeTransfer(vault, balance), "RECOVER_TOKEN_TRANSFER_FAILED");
        }

        emit RecoverToVault(vault, _token, balance);
    }

    function getFee() public view returns (uint16 feeBasisPoints) {
        return uint16(FEE_POSITION.getStorageUint256());
    }

    function getFeeDistribution()
        public
        view
        returns (
            uint16 treasuryFeeBasisPoints,
            uint16 insuranceFeeBasisPoints,
            uint16 operatorsFeeBasisPoints
        )
    {
        treasuryFeeBasisPoints = uint16(TREASURY_FEE_POSITION.getStorageUint256());
        insuranceFeeBasisPoints = uint16(INSURANCE_FEE_POSITION.getStorageUint256());
        operatorsFeeBasisPoints = uint16(NODE_OPERATORS_FEE_POSITION.getStorageUint256());
    }

    function getWithdrawalCredentials() public view returns (bytes32) {
        return WITHDRAWAL_CREDENTIALS_POSITION.getStorageBytes32();
    }

    function getBufferedEther() external view returns (uint256) {
        return _getBufferedEther();
    }

    function getTotalELRewardsCollected() external view returns (uint256) {
        return TOTAL_EL_REWARDS_COLLECTED_POSITION.getStorageUint256();
    }

    function getELRewardsWithdrawalLimit() external view returns (uint256) {
        return EL_REWARDS_WITHDRAWAL_LIMIT_POSITION.getStorageUint256();
    }

    function getDepositContract() public view returns (IDepositContract) {
        return IDepositContract(DEPOSIT_CONTRACT_POSITION.getStorageAddress());
    }

    function getOracle() public view returns (address) {
        return ORACLE_POSITION.getStorageAddress();
    }

    function getOperators() public view returns (INodeOperatorsRegistry) {
        return INodeOperatorsRegistry(NODE_OPERATORS_REGISTRY_POSITION.getStorageAddress());
    }

    function getTreasury() public view returns (address) {
        return TREASURY_POSITION.getStorageAddress();
    }

    function getInsuranceFund() public view returns (address) {
        return INSURANCE_FUND_POSITION.getStorageAddress();
    }

    function getBeaconStat() public view returns (uint256 depositedValidators, uint256 Validators, uint256 Balance) {
        depositedValidators = DEPOSITED_VALIDATORS_POSITION.getStorageUint256();
        Validators = BEACON_VALIDATORS_POSITION.getStorageUint256();
        Balance = BEACON_BALANCE_POSITION.getStorageUint256();
    }

    function getELRewardsVault() public view returns (address) {
        return EL_REWARDS_VAULT_POSITION.getStorageAddress();
    }

    function _setProtocolContracts(address _oracle, address _treasury, address _insuranceFund) internal {
        require(_oracle != address(0), "ORACLE_ZERO_ADDRESS");
        require(_treasury != address(0), "TREASURY_ZERO_ADDRESS");
        require(_insuranceFund != address(0), "INSURANCE_FUND_ZERO_ADDRESS");

        ORACLE_POSITION.setStorageAddress(_oracle);
        TREASURY_POSITION.setStorageAddress(_treasury);
        INSURANCE_FUND_POSITION.setStorageAddress(_insuranceFund);

        emit ProtocolContactsSet(_oracle, _treasury, _insuranceFund);
    }

    function _submit(address _referral) internal returns (uint256) {
        require(msg.value != 0, "ZERO_DEPOSIT");

        StakeLimitState.Data memory stakeLimitData = STAKING_STATE_POSITION.getStorageStakeLimitStruct();
        require(!stakeLimitData.isStakingPaused(), "STAKING_PAUSED");

        if (stakeLimitData.isStakingLimitSet()) {
            uint256 currentStakeLimit = stakeLimitData.calculateCurrentStakeLimit();

            require(msg.value <= currentStakeLimit, "STAKE_LIMIT");

            STAKING_STATE_POSITION.setStorageStakeLimitStruct(
                stakeLimitData.updatePrevStakeLimit(currentStakeLimit - msg.value)
            );
        }

        uint256 sharesAmount = getSharesByPooledEth(msg.value);
        if (sharesAmount == 0) {
            sharesAmount = msg.value;
        }

        _mintShares(msg.sender, sharesAmount);

        BUFFERED_ETHER_POSITION.setStorageUint256(_getBufferedEther().add(msg.value));
        emit Submitted(msg.sender, msg.value, _referral);

        _emitTransferAfterMintingShares(msg.sender, sharesAmount);
        return sharesAmount;
    }

    function _emitTransferAfterMintingShares(address _to, uint256 _sharesAmount) internal {
        emit Transfer(address(0), _to, getPooledEthByShares(_sharesAmount));
        emit TransferShares(address(0), _to, _sharesAmount);
    }

    function _depositBufferedEther(uint256 _maxDeposits) internal whenNotStopped {
        uint256 buffered = _getBufferedEther();
        if (buffered >= DEPOSIT_SIZE) {
            uint256 unaccounted = _getUnaccountedEther();
            uint256 numDeposits = buffered.div(DEPOSIT_SIZE);
            _markAsUnbuffered(_ETH2Deposit(numDeposits < _maxDeposits ? numDeposits : _maxDeposits));
            assert(_getUnaccountedEther() == unaccounted);
        }
    }

    function _ETH2Deposit(uint256 _numDeposits) internal returns (uint256) {
        (bytes memory pubkeys, bytes memory signatures) = getOperators().assignNextSigningKeys(_numDeposits);

        if (pubkeys.length == 0) {
            return 0;
        }

        require(pubkeys.length.mod(PUBKEY_LENGTH) == 0, "REGISTRY_INCONSISTENT_PUBKEYS_LEN");
        require(signatures.length.mod(SIGNATURE_LENGTH) == 0, "REGISTRY_INCONSISTENT_SIG_LEN");

        uint256 numKeys = pubkeys.length.div(PUBKEY_LENGTH);
        require(numKeys == signatures.length.div(SIGNATURE_LENGTH), "REGISTRY_INCONSISTENT_SIG_COUNT");

        for (uint256 i = 0; i < numKeys; ++i) {
            bytes memory pubkey = BytesLib.slice(pubkeys, i * PUBKEY_LENGTH, PUBKEY_LENGTH);
            bytes memory signature = BytesLib.slice(signatures, i * SIGNATURE_LENGTH, SIGNATURE_LENGTH);
            _stake(pubkey, signature);
        }

        DEPOSITED_VALIDATORS_POSITION.setStorageUint256(
            DEPOSITED_VALIDATORS_POSITION.getStorageUint256().add(numKeys)
        );

        return numKeys.mul(DEPOSIT_SIZE);
    }

    function _stake(bytes memory _pubkey, bytes memory _signature) internal {
        bytes32 withdrawalCredentials = getWithdrawalCredentials();
        require(withdrawalCredentials != 0, "EMPTY_WITHDRAWAL_CREDENTIALS");

        uint256 value = DEPOSIT_SIZE;

        uint256 depositAmount = value.div(DEPOSIT_AMOUNT_UNIT);
        assert(depositAmount.mul(DEPOSIT_AMOUNT_UNIT) == value);    // properly rounded

        bytes32 pubkeyRoot = sha256(_pad64(_pubkey));
        bytes32 signatureRoot = sha256(
            abi.encodePacked(
                sha256(BytesLib.slice(_signature, 0, 64)),
                sha256(_pad64(BytesLib.slice(_signature, 64, SIGNATURE_LENGTH.sub(64))))
            )
        );

        bytes32 depositDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, withdrawalCredentials)),
                sha256(abi.encodePacked(_toLittleEndian64(depositAmount), signatureRoot))
            )
        );

        uint256 targetBalance = address(this).balance.sub(value);

        getDepositContract().deposit.value(value)(
            _pubkey, abi.encodePacked(withdrawalCredentials), _signature, depositDataRoot);
        require(address(this).balance == targetBalance, "EXPECTING_DEPOSIT_TO_HAPPEN");
    }

        uint256 feeBasis = getFee();
        uint256 shares2mint = (
            _totalRewards.mul(feeBasis).mul(_getTotalShares())
            .div(
                _getTotalPooledEther().mul(TOTAL_BASIS_POINTS)
                .sub(feeBasis.mul(_totalRewards))
            )
        );

        _mintShares(address(this), shares2mint);

        (,uint16 insuranceFeeBasisPoints, uint16 operatorsFeeBasisPoints) = getFeeDistribution();

        uint256 toInsuranceFund = shares2mint.mul(insuranceFeeBasisPoints).div(TOTAL_BASIS_POINTS);
        address insuranceFund = getInsuranceFund();
        _transferShares(address(this), insuranceFund, toInsuranceFund);
        _emitTransferAfterMintingShares(insuranceFund, toInsuranceFund);

        uint256 distributedToOperatorsShares = _distributeNodeOperatorsReward(
            shares2mint.mul(operatorsFeeBasisPoints).div(TOTAL_BASIS_POINTS)
        );

        uint256 toTreasury = shares2mint.sub(toInsuranceFund).sub(distributedToOperatorsShares);

        address treasury = getTreasury();
        _transferShares(address(this), treasury, toTreasury);
        _emitTransferAfterMintingShares(treasury, toTreasury);
    }

    function _distributeNodeOperatorsReward(uint256 _sharesToDistribute) internal returns (uint256 distributed) {
        (address[] memory recipients, uint256[] memory shares) = getOperators().getRewardsDistribution(_sharesToDistribute);

        assert(recipients.length == shares.length);

        distributed = 0;
        for (uint256 idx = 0; idx < recipients.length; ++idx) {
            _transferShares(
                address(this),
                recipients[idx],
                shares[idx]
            );
            _emitTransferAfterMintingShares(recipients[idx], shares[idx]);
            distributed = distributed.add(shares[idx]);
        }
    }

    function _markAsUnbuffered(uint256 _amount) internal {
        BUFFERED_ETHER_POSITION.setStorageUint256(
            BUFFERED_ETHER_POSITION.getStorageUint256().sub(_amount));

        emit Unbuffered(_amount);
    }

    function _setBPValue(bytes32 _slot, uint16 _value) internal {
        require(_value <= TOTAL_BASIS_POINTS, "VALUE_OVER_100_PERCENT");
        _slot.setStorageUint256(uint256(_value));
    }

    function _getBufferedEther() internal view returns (uint256) {
        uint256 buffered = BUFFERED_ETHER_POSITION.getStorageUint256();
        assert(address(this).balance >= buffered);

        return buffered;
    }

    function _getUnaccountedEther() internal view returns (uint256) {
        return address(this).balance.sub(_getBufferedEther());
    }

    function _getTransientBalance() internal view returns (uint256) {
        uint256 depositedValidators = DEPOSITED_VALIDATORS_POSITION.getStorageUint256();
        uint256 Validators = BEACON_VALIDATORS_POSITION.getStorageUint256();
        assert(depositedValidators >= Validators);
        return depositedValidators.sub(Validators).mul(DEPOSIT_SIZE);
    }

    function _getTotalPooledEther() internal view returns (uint256) {
        return _getBufferedEther().add(
            BEACON_BALANCE_POSITION.getStorageUint256()
        ).add(_getTransientBalance());
    }

    function _pad64(bytes memory _b) internal pure returns (bytes memory) {
        assert(_b.length >= 32 && _b.length <= 64);
        if (64 == _b.length)
            return _b;

        bytes memory zero32 = new bytes(32);
        assembly { mstore(add(zero32, 0x20), 0) }

        if (32 == _b.length)
            return BytesLib.concat(_b, zero32);
        else
            return BytesLib.concat(_b, BytesLib.slice(zero32, 0, uint256(64).sub(_b.length)));
    }

    function _toLittleEndian64(uint256 _value) internal pure returns (uint256 result) {
        result = 0;
        uint256 temp_value = _value;
        for (uint256 i = 0; i < 8; ++i) {
            result = (result << 8) | (temp_value & 0xFF);
            temp_value >>= 8;
        }

        assert(0 == temp_value);    // fully converted
        result <<= (24 * 8);
    }

    function _pauseStaking() internal {
        STAKING_STATE_POSITION.setStorageStakeLimitStruct(
            STAKING_STATE_POSITION.getStorageStakeLimitStruct().setStakeLimitPauseState(true)
        );

        emit StakingPaused();
    }

    function _resumeStaking() internal {
        STAKING_STATE_POSITION.setStorageStakeLimitStruct(
            STAKING_STATE_POSITION.getStorageStakeLimitStruct().setStakeLimitPauseState(false)
        );

        emit StakingResumed();
    }

    function _getCurrentStakeLimit(StakeLimitState.Data memory _stakeLimitData) internal view returns(uint256) {
        if (_stakeLimitData.isStakingPaused()) {
            return 0;
        }
        if (!_stakeLimitData.isStakingLimitSet()) {
            return uint256(-1);
        }

        return _stakeLimitData.calculateCurrentStakeLimit();
    }

    function _auth(bytes32 _role) internal view auth(_role) {
        // no-op
    }