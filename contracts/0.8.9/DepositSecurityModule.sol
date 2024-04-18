// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import {ECDSA} from "./lib/ECDSA.sol";


interface IDepositContract {
    function get_deposit_root() external view returns (bytes32 rootHash);
}


interface IAinomo {
    function depositBufferedEther(uint256 maxDeposits) external;
}


interface INodeOperatorsRegistry {
    function getKeysOpIndex() external view returns (uint256 index);
}


contract DepositSecurityModule {
    struct Signature {
        bytes32 r;
        bytes32 vs;
    }

    event OwnerChanged(address newValue);
    event NodeOperatorsRegistryChanged(address newValue);
    event PauseIntentValidityPeriodBlocksChanged(uint256 newValue);
    event MaxDepositsChanged(uint256 newValue);
    event MinDepositBlockDistanceChanged(uint256 newValue);
    event GuardianQuorumChanged(uint256 newValue);
    event GuardianAdded(address guardian);
    event GuardianRemoved(address guardian);
    event DepositsPaused(address guardian);
    event DepositsUnpaused();


    bytes32 public immutable ATTEST_MESSAGE_PREFIX;
    bytes32 public immutable PAUSE_MESSAGE_PREFIX;

    address public immutable AINOMO;
    address public immutable DEPOSIT_CONTRACT;

    address internal nodeOperatorsRegistry;
    uint256 internal maxDepositsPerBlock;
    uint256 internal minDepositBlockDistance;
    uint256 internal pauseIntentValidityPeriodBlocks;

    address internal owner;

    address[] internal guardians;
    mapping(address => uint256) internal guardianIndicesOneBased; // 1-based
    uint256 internal quorum;

    bool internal paused;
    uint256 internal lastDepositBlock;


    constructor(
        address _ainomo,
        address _depositContract,
        address _nodeOperatorsRegistry,
        uint256 _networkId,
        uint256 _maxDepositsPerBlock,
        uint256 _minDepositBlockDistance,
        uint256 _pauseIntentValidityPeriodBlocks
    ) {
        require(_ainomo != address(0), "AINOMO_ZERO_ADDRESS");
        require(_depositContract != address(0), "DEPOSIT_CONTRACT_ZERO_ADDRESS");
        AINOMO = _ainomo;
        DEPOSIT_CONTRACT = _depositContract;

        ATTEST_MESSAGE_PREFIX = keccak256(abi.encodePacked(
            bytes32(0xc085395a994e25b1b3d0ea7937b7395495fb405b31c7d22dbc3976a6bd01f2bf),
            _networkId
        ));

        PAUSE_MESSAGE_PREFIX = keccak256(abi.encodePacked(
            bytes32(0x1c4c40205558f12027f21204d6218b8006985b7a6359bcab15404bcc3e3fa122),
            _networkId
        ));

        _setOwner(msg.sender);
        _setNodeOperatorsRegistry(_nodeOperatorsRegistry);
        _setMaxDeposits(_maxDepositsPerBlock);
        _setMinDepositBlockDistance(_minDepositBlockDistance);
        _setPauseIntentValidityPeriodBlocks(_pauseIntentValidityPeriodBlocks);
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "not an owner");
        _;
    }

    function setOwner(address newValue) external onlyOwner {
        _setOwner(newValue);
    }

    function _setOwner(address newValue) internal {
        require(newValue != address(0), "invalid value for owner: must be different from zero address");
        owner = newValue;
        emit OwnerChanged(newValue);
    }


    function getNodeOperatorsRegistry() external view returns (address) {
        return nodeOperatorsRegistry;
    }

    function setNodeOperatorsRegistry(address newValue) external onlyOwner {
        _setNodeOperatorsRegistry(newValue);
    }

    function _setNodeOperatorsRegistry(address newValue) internal {
        nodeOperatorsRegistry = newValue;
        emit NodeOperatorsRegistryChanged(newValue);
    }


    function getPauseIntentValidityPeriodBlocks() external view returns (uint256) {
        return pauseIntentValidityPeriodBlocks;
    }

    function setPauseIntentValidityPeriodBlocks(uint256 newValue) external onlyOwner {
        _setPauseIntentValidityPeriodBlocks(newValue);
    }

    function _setPauseIntentValidityPeriodBlocks(uint256 newValue) internal {
        require(newValue > 0, "invalid value for pauseIntentValidityPeriodBlocks: must be greater then 0");
        pauseIntentValidityPeriodBlocks = newValue;
        emit PauseIntentValidityPeriodBlocksChanged(newValue);
    }


    function getMaxDeposits() external view returns (uint256) {
        return maxDepositsPerBlock;
    }

    function setMaxDeposits(uint256 newValue) external onlyOwner {
        _setMaxDeposits(newValue);
    }

    function _setMaxDeposits(uint256 newValue) internal {
        maxDepositsPerBlock = newValue;
        emit MaxDepositsChanged(newValue);
    }


    function getMinDepositBlockDistance() external view returns (uint256) {
        return minDepositBlockDistance;
    }

    function setMinDepositBlockDistance(uint256 newValue) external onlyOwner {
        _setMinDepositBlockDistance(newValue);
    }

    function _setMinDepositBlockDistance(uint256 newValue) internal {
        require(newValue > 0, "invalid value for minDepositBlockDistance: must be greater then 0");
        if (newValue != minDepositBlockDistance) {
            minDepositBlockDistance = newValue;
            emit MinDepositBlockDistanceChanged(newValue);
        }
    }


    function getGuardianQuorum() external view returns (uint256) {
        return quorum;
    }

    function setGuardianQuorum(uint256 newValue) external onlyOwner {
        _setGuardianQuorum(newValue);
    }

    function _setGuardianQuorum(uint256 newValue) internal {
        quorum = newValue;
        emit GuardianQuorumChanged(newValue);
    }


    function getGuardians() external view returns (address[] memory) {
        return guardians;
    }

    function isGuardian(address addr) external view returns (bool) {
        return _isGuardian(addr);
    }

    function _isGuardian(address addr) internal view returns (bool) {
        return guardianIndicesOneBased[addr] > 0;
    }

    function getGuardianIndex(address addr) external view returns (int256) {
        return _getGuardianIndex(addr);
    }

    function _getGuardianIndex(address addr) internal view returns (int256) {
        return int256(guardianIndicesOneBased[addr]) - 1;
    }

    function addGuardian(address addr, uint256 newQuorum) external onlyOwner {
        _addGuardian(addr);
        _setGuardianQuorum(newQuorum);
    }

    function addGuardians(address[] memory addresses, uint256 newQuorum) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; ++i) {
            _addGuardian(addresses[i]);
        }
        _setGuardianQuorum(newQuorum);
    }

    function _addGuardian(address addr) internal {
        require(addr != address(0), "guardian zero address");
        require(!_isGuardian(addr), "duplicate address");
        guardians.push(addr);
        guardianIndicesOneBased[addr] = guardians.length;
        emit GuardianAdded(addr);
    }

    function removeGuardian(address addr, uint256 newQuorum) external onlyOwner {
        uint256 indexOneBased = guardianIndicesOneBased[addr];
        require(indexOneBased != 0, "not a guardian");

        uint256 totalGuardians = guardians.length;
        assert(indexOneBased <= totalGuardians);

        if (indexOneBased != totalGuardians) {
            address addrToMove = guardians[totalGuardians - 1];
            guardians[indexOneBased - 1] = addrToMove;
            guardianIndicesOneBased[addrToMove] = indexOneBased;
        }

        guardianIndicesOneBased[addr] = 0;
        guardians.pop();

        _setGuardianQuorum(newQuorum);

        emit GuardianRemoved(addr);
    }


    function isPaused() external view returns (bool) {
        return paused;
    }

    function pauseDeposits(uint256 blockNumber, Signature memory sig) external {
        if (paused) {
            return;
        }

        address guardianAddr = msg.sender;
        int256 guardianIndex = _getGuardianIndex(msg.sender);

        if (guardianIndex == -1) {
            bytes32 msgHash = keccak256(abi.encodePacked(PAUSE_MESSAGE_PREFIX, blockNumber));
            guardianAddr = ECDSA.recover(msgHash, sig.r, sig.vs);
            guardianIndex = _getGuardianIndex(guardianAddr);
            require(guardianIndex != -1, "invalid signature");
        }

        require(
            block.number - blockNumber <= pauseIntentValidityPeriodBlocks,
            "pause intent expired"
        );

        paused = true;
        emit DepositsPaused(guardianAddr);
    }

    function unpauseDeposits() external onlyOwner {
        if (paused) {
            paused = false;
            emit DepositsUnpaused();
        }
    }


    function getLastDepositBlock() external view returns (uint256) {
        return lastDepositBlock;
    }


    function setLastDepositBlock(uint256 newLastDepositBlock) external onlyOwner {
        lastDepositBlock = newLastDepositBlock;
    }


    function canDeposit() external view returns (bool) {
        return !paused && quorum > 0 && block.number - lastDepositBlock >= minDepositBlockDistance;
    }


    function depositBufferedEther(
        bytes32 depositRoot,
        uint256 keysOpIndex,
        uint256 blockNumber,
        bytes32 blockHash,
        Signature[] memory sortedGuardianSignatures
    ) external {
        bytes32 onchainDepositRoot = IDepositContract(DEPOSIT_CONTRACT).get_deposit_root();
        require(depositRoot == onchainDepositRoot, "deposit root changed");

        require(!paused, "deposits are paused");
        require(quorum > 0 && sortedGuardianSignatures.length >= quorum, "no guardian quorum");

        require(block.number - lastDepositBlock >= minDepositBlockDistance, "too frequent deposits");
        require(blockHash != bytes32(0) && blockhash(blockNumber) == blockHash, "unexpected block hash");

        uint256 onchainKeysOpIndex = INodeOperatorsRegistry(nodeOperatorsRegistry).getKeysOpIndex();
        require(keysOpIndex == onchainKeysOpIndex, "keys op index changed");

        _verifySignatures(
            depositRoot,
            keysOpIndex,
            blockNumber,
            blockHash,
            sortedGuardianSignatures
        );

        IAinomo(AINOMO).depositBufferedEther(maxDepositsPerBlock);
        lastDepositBlock = block.number;
    }


    function _verifySignatures(
        bytes32 depositRoot,
        uint256 keysOpIndex,
        uint256 blockNumber,
        bytes32 blockHash,
        Signature[] memory sigs
    )
        internal view
    {
        bytes32 msgHash = keccak256(abi.encodePacked(
            ATTEST_MESSAGE_PREFIX,
            depositRoot,
            keysOpIndex,
            blockNumber,
            blockHash
        ));

        address prevSignerAddr = address(0);

        for (uint256 i = 0; i < sigs.length; ++i) {
            address signerAddr = ECDSA.recover(msgHash, sigs[i].r, sigs[i].vs);
            require(_isGuardian(signerAddr), "invalid signature");
            require(signerAddr > prevSignerAddr, "signatures not sorted");
            prevSignerAddr = signerAddr;
        }
    }
}
