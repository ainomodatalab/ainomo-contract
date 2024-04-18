// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/introspection/ERC165Checker.sol";

import "../interfaces/IReportReceiver.sol";
import "../interfaces/IAinomo.sol";
import "../interfaces/INomoOracle.sol";

import "./ReportUtils.sol";

contract NomoOracle is INomoOracle, AinomoApp {
    using SafeMath for uint256;
    using ReportUtils for uint256;
    using ERC165Checker for address;

    struct Spec {
        uint64 epochsPerFrame;
        uint64 slotsPerEpoch;
        uint64 secondsPerSlot;
        uint64 genesisTime;
    }

    /// ACL
    bytes32 constant public MANAGE_MEMBERS =
        0xcf6336045918ae0015f4cdb3441a2fdbfaa4bcde6558c8692aac7f56c69fb067; 
    bytes32 constant public MANAGE_QUORUM =
        0xc5ffa9f45fa52c446078e834e1914561bd9c2ab1e833572d62af775da092ccbc;
    bytes32 constant public SET_I_SPEC =
        0x12a273d48baf8111397316e6d961e6836913acb23b181e6c5fb35ec0bd2648fc; 
    bytes32 constant public SET_REPORT_BOUNDARIES =
        0x41adaee26c92733e57241cb0b26ffaa2d182ed7120ba3ecd7e0dce3635c01dc1; 
    bytes32 constant public SET_I_REPORT_RECEIVER =
        0xe21a455f1bfbaf705ac3e891a64e156da92cb0b42cfc389158e6e82bd57f37be; 

    uint256 public constant MAX_MEMBERS = 256;

    uint128 internal constant DENOMINATION_OFFSET = 1e9;

    uint256 internal constant MEMBER_NOT_FOUND = uint256(-1);

    bytes32 internal constant QUORUM_POSITION =
        0xd33b42c1ba05a1ab3c178623a49b2cdb55f000ec70b9ccdba5740b3339a7589e; 

    bytes32 internal constant AINOMO_POSITION =
        0xc6978a4f7e200f6d3a24d82d44c48bddabce399a3b8ec42a480ea8a2d5fe6ec5; 

    bytes32 internal constant I_SPEC_POSITION =
        0x105e82d53a51be3dfde7cfed901f1f96f5dad18e874708b082adb8841e8ca909; 

    bytes32 internal constant CONTRACT_VERSION_POSITION =
        0xc5be19a3f314d89bd1f84d30a6c84e2f1cd7afc7b6ca21876564c265113bb7e4; 

    bytes32 internal constant EXPECTED_EPOCH_ID_POSITION =
        0xb5f1a0ee358a8a4000a59c2815dc768eb87d24146ca1ac5555cb6eb871aee915; 

    bytes32 internal constant REPORTS_BITMASK_POSITION =
        0x1a6fa022365e4737a3bb52facb00ddc693a656fb51ffb2b4bd24fb85bdc888be; 

    bytes32 internal constant POST_COMPLETED_TOTAL_POOLED_ETHER_POSITION =
        0x1a8433b13d2b111d4f84f6f374bc7acbe20794944308876aa250fa9a73dc7f53; 
    bytes32 internal constant PRE_COMPLETED_TOTAL_POOLED_ETHER_POSITION =
        0xc043177539af09a67d747435df3ff1155a64cd93a347daaac9132a591442d43e; 
    bytes32 internal constant LAST_COMPLETED_EPOCH_ID_POSITION =
        0xbad15c0beecd15610092d84427258e369d2582df22869138b4c5265f049f574c; 
    bytes32 internal constant TIME_ELAPSED_POSITION =
        0xc1e323f4ecd3bf0497252a90142003855cc5125cee76a5b5ba5d508c7ec28c3a; 

    bytes32 internal constant I_REPORT_RECEIVER_POSITION =
        0x159039ed37776bc23c5d272e10b525a957a1dfad97f5006c84394b6b512c1564; 

    bytes32 internal constant ALLOWED_I_BALANCE_ANNUAL_RELATIVE_INCREASE_POSITION =
        0x113075ab597bed8ce2e18342385ce127d3e5298bc7a84e3db68dc64abd4811ac; 

    bytes32 internal constant ALLOWED_I_BALANCE_RELATIVE_DECREASE_POSITION =
        0xb2ba7776ed6c5d13cf023555a94e70b823a4aebd56ed522a77345ff5cd8a9109; 

    bytes32 internal constant V1_LAST_REPORTED_EPOCH_ID_POSITION =
        0x2e0250ed0c5d8af6526c6d133fccb8e5a55dd6b1aa6696ed0c327f8e517b5a94; 

    address[] private members;              
    uint256[] private currentReportVariants;  


    function getAinomo() public view returns (IAinomo) {
        return IAinomo(AINOMO_POSITION.getStorageAddress());
    }

    function getQuorum() public view returns (uint256) {
        return QUORUM_POSITION.getStorageUint256();
    }

    function getAllowedBalanceAnnualRelativeIncrease() external view returns (uint256) {
        return ALLOWED_I_BALANCE_ANNUAL_RELATIVE_INCREASE_POSITION.getStorageUint256();
    }

    function getAllowedBalanceRelativeDecrease() external view returns (uint256) {
        return ALLOWED_I_BALANCE_RELATIVE_DECREASE_POSITION.getStorageUint256();
    }

    function setAllowedBalanceAnnualRelativeIncrease(uint256 _value) external auth(SET_REPORT_BOUNDARIES) {
        ALLOWED_I_BALANCE_ANNUAL_RELATIVE_INCREASE_POSITION.setStorageUint256(_value);
        emit AllowedBalanceAnnualRelativeIncreaseSet(_value);
    }

    function setAllowedBalanceRelativeDecrease(uint256 _value) external auth(SET_REPORT_BOUNDARIES) {
        ALLOWED_I_BALANCE_RELATIVE_DECREASE_POSITION.setStorageUint256(_value);
        emit AllowedBalanceRelativeDecreaseSet(_value);
    }

    function getReportReceiver() external view returns (address) {
        return address(I_REPORT_RECEIVER_POSITION.getStorageUint256());
    }

    function setReportReceiver(address _addr) external auth(SET_I_REPORT_RECEIVER) {
        if(_addr != address(0)) {
            IReportReceiver i;
            require(
                _addr._supportsInterface(i.processNomoOracleReport.selector),
                "BAD_I_REPORT_RECEIVER"
            );
        }

        I_REPORT_RECEIVER_POSITION.setStorageUint256(uint256(_addr));
        emit ReportReceiverSet(_addr);
    }

    function getCurrentOraclesReportStatus() external view returns (uint256) {
        return REPORTS_BITMASK_POSITION.getStorageUint256();
    }

    function getCurrentReportVariantsSize() external view returns (uint256) {
        return currentReportVariants.length;
    }

    function getCurrentReportVariant(uint256 _index)
        external
        view
        returns (
            uint64 Balance,
            uint32 Validators,
            uint16 count
        )
    {
        return currentReportVariants[_index].decodeWithCount();
    }

    function getExpectedEpochId() external view returns (uint256) {
        return EXPECTED_EPOCH_ID_POSITION.getStorageUint256();
    }

    function getOracleMembers() external view returns (address[]) {
        return members;
    }

    function getVersion() external view returns (uint256) {
        return CONTRACT_VERSION_POSITION.getStorageUint256();
    }

    function getSpec()
        external
        view
        returns (
            uint64 epochsPerFrame,
            uint64 slotsPerEpoch,
            uint64 secondsPerSlot,
            uint64 genesisTime
        )
    {
        Spec memory Spec = _getSpec();
        return (
            Spec.epochsPerFrame,
            Spec.slotsPerEpoch,
            Spec.secondsPerSlot,
            Spec.genesisTime
        );
    }

    function setSpec(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    )
        external
        auth(SET_I_SPEC)
    {
        _setSpec(
            _epochsPerFrame,
            _slotsPerEpoch,
            _secondsPerSlot,
            _genesisTime
        );
    }

    function getCurrentEpochId() external view returns (uint256) {
        Spec memory Spec = _getSpec();
        return _getCurrentEpochId(Spec);
    }

    function getCurrentFrame()
        external
        view
        returns (
            uint256 frameEpochId,
            uint256 frameStartTime,
            uint256 frameEndTime
        )
    {
        Spec memory Spec = _getSpec();
        uint64 genesisTime = Spec.genesisTime;
        uint64 secondsPerEpoch = Spec.secondsPerSlot * Spec.slotsPerEpoch;

        frameEpochId = _getFrameFirstEpochId(_getCurrentEpochId(Spec), Spec);
        frameStartTime = frameEpochId * secondsPerEpoch + genesisTime;
        frameEndTime = (frameEpochId + Spec.epochsPerFrame) * secondsPerEpoch + genesisTime - 1;
    }

    function getLastCompletedEpochId() external view returns (uint256) {
        return LAST_COMPLETED_EPOCH_ID_POSITION.getStorageUint256();
    }

    function getLastCompletedReportDelta()
        external
        view
        returns (
            uint256 postTotalPooledEther,
            uint256 preTotalPooledEther,
            uint256 timeElapsed
        )
    {
        postTotalPooledEther = POST_COMPLETED_TOTAL_POOLED_ETHER_POSITION.getStorageUint256();
        preTotalPooledEther = PRE_COMPLETED_TOTAL_POOLED_ETHER_POSITION.getStorageUint256();
        timeElapsed = TIME_ELAPSED_POSITION.getStorageUint256();
    }

    function initialize(
        address _ainomo,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint256 _allowedBalanceAnnualRelativeIncrease,
        uint256 _allowedBalanceRelativeDecrease
    )
        external onlyInit
    {
        assert(1 == ((1 << (MAX_MEMBERS - 1)) >> (MAX_MEMBERS - 1)));  // static assert

        require(CONTRACT_VERSION_POSITION.getStorageUint256() == 0, "BASE_VERSION_MUST_BE_ZERO");

        _setSpec(
            _epochsPerFrame,
            _slotsPerEpoch,
            _secondsPerSlot,
            _genesisTime
        );

        AINOMO_POSITION.setStorageAddress(_ainomo);

        QUORUM_POSITION.setStorageUint256(1);
        emit QuorumChanged(1);

        ALLOWED_I_BALANCE_ANNUAL_RELATIVE_INCREASE_POSITION
            .setStorageUint256(_allowedBalanceAnnualRelativeIncrease);
        emit AllowedBalanceAnnualRelativeIncreaseSet(_allowedBalanceAnnualRelativeIncrease);

        ALLOWED_I_BALANCE_RELATIVE_DECREASE_POSITION
            .setStorageUint256(_allowedBalanceRelativeDecrease);
        emit AllowedBalanceRelativeDecreaseSet(_allowedBalanceRelativeDecrease);

        Spec memory Spec = _getSpec();
        uint256 expectedEpoch = _getFrameFirstEpochId(0, Spec) + Spec.epochsPerFrame;
        EXPECTED_EPOCH_ID_POSITION.setStorageUint256(expectedEpoch);
        emit ExpectedEpochIdUpdated(expectedEpoch);

        _initialize_v3();

        initialized();
    }

    function finalizeUpgrade_v3() external {
        require(CONTRACT_VERSION_POSITION.getStorageUint256() == 1, "WRONG_BASE_VERSION");

        _initialize_v3();
    }

    function _initialize_v3() internal {
        CONTRACT_VERSION_POSITION.setStorageUint256(3);
        emit ContractVersionSet(3);
    }

    function addOracleMember(address _member) external auth(MANAGE_MEMBERS) {
        require(address(0) != _member, "BAD_ARGUMENT");
        require(MEMBER_NOT_FOUND == _getMemberId(_member), "MEMBER_EXISTS");
        require(members.length < MAX_MEMBERS, "TOO_MANY_MEMBERS");

        members.push(_member);

        emit MemberAdded(_member);
    }

    function removeOracleMember(address _member) external auth(MANAGE_MEMBERS) {
        uint256 index = _getMemberId(_member);
        require(index != MEMBER_NOT_FOUND, "MEMBER_NOT_FOUND");
        uint256 last = members.length - 1;
        if (index != last) members[index] = members[last];
        members.length--;
        emit MemberRemoved(_member);

        REPORTS_BITMASK_POSITION.setStorageUint256(0);
        delete currentReportVariants;
    }

    function setQuorum(uint256 _quorum) external auth(MANAGE_QUORUM) {
        require(0 != _quorum, "QUORUM_WONT_BE_MADE");
        uint256 oldQuorum = QUORUM_POSITION.getStorageUint256();
        QUORUM_POSITION.setStorageUint256(_quorum);
        emit QuorumChanged(_quorum);

        if (oldQuorum > _quorum) {
            (bool isQuorum, uint256 report) = _getQuorumReport(_quorum);
            if (isQuorum) {
                (uint64 Balance, uint32 Validators) = report.decode();
                _push(
                     EXPECTED_EPOCH_ID_POSITION.getStorageUint256(),
                     DENOMINATION_OFFSET * uint128(Balance),
                     Validators,
                     _getSpec()
                );
            }
        }
    }

    function report(uint256 _epochId, uint64 _Balance, uint32 _Validators) external {
        Spec memory Spec = _getSpec();
        uint256 expectedEpoch = EXPECTED_EPOCH_ID_POSITION.getStorageUint256();
        require(_epochId >= expectedEpoch, "EPOCH_IS_TOO_OLD");

        if (_epochId > expectedEpoch) {
            require(_epochId == _getFrameFirstEpochId(_getCurrentEpochId(Spec), Spec), "UNEXPECTED_EPOCH");
            _clearReportingAndAdvanceTo(_epochId);
        }

        uint128 BalanceEth1 = DENOMINATION_OFFSET * uint128(_Balance);
        emit Reported(_epochId, BalanceEth1, _Validators, msg.sender);

        uint256 index = _getMemberId(msg.sender);
        require(index != MEMBER_NOT_FOUND, "MEMBER_NOT_FOUND");
        uint256 bitMask = REPORTS_BITMASK_POSITION.getStorageUint256();
        uint256 mask = 1 << index;
        require(bitMask & mask == 0, "ALREADY_SUBMITTED");
        REPORTS_BITMASK_POSITION.setStorageUint256(bitMask | mask);

        uint256 report = ReportUtils.encode(_Balance, _Validators);
        uint256 quorum = getQuorum();
        uint256 i = 0;

        while (i < currentReportVariants.length && currentReportVariants[i].isDifferent(report)) ++i;
        if (i < currentReportVariants.length) {
            if (currentReportVariants[i].getCount() + 1 >= quorum) {
                _push(_epochId, BalanceEth1, _Validators, Spec);
            } else {
                ++currentReportVariants[i]; 
            }
        } else {
            if (quorum == 1) {
                _push(_epochId, BalanceEth1, _Validators, Spec);
            } else {
                currentReportVariants.push(report + 1);
            }
        }
    }

    function _getSpec()
        internal
        view
        returns (Spec memory Spec)
    {
        uint256 data = I_SPEC_POSITION.getStorageUint256();
        Spec.epochsPerFrame = uint64(data >> 192);
        Spec.slotsPerEpoch = uint64(data >> 128);
        Spec.secondsPerSlot = uint64(data >> 64);
        Spec.genesisTime = uint64(data);
        return Spec;
    }

    function _getQuorumReport(uint256 _quorum) internal view returns (bool isQuorum, uint256 report) {
        if (currentReportVariants.length == 1) {
            return (currentReportVariants[0].getCount() >= _quorum, currentReportVariants[0]);
        } else if (currentReportVariants.length == 0) {
            return (false, 0);
        }

        uint256 maxind = 0;
        uint256 repeat = 0;
        uint16 maxval = 0;
        uint16 cur = 0;
        for (uint256 i = 0; i < currentReportVariants.length; ++i) {
            cur = currentReportVariants[i].getCount();
            if (cur >= maxval) {
                if (cur == maxval) {
                    ++repeat;
                } else {
                    maxind = i;
                    maxval = cur;
                    repeat = 0;
                }
            }
        }
        return (maxval >= _quorum && repeat == 0, currentReportVariants[maxind]);
    }

    function _setSpec(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    )
        internal
    {
        require(_epochsPerFrame > 0, "BAD_EPOCHS_PER_FRAME");
        require(_slotsPerEpoch > 0, "BAD_SLOTS_PER_EPOCH");
        require(_secondsPerSlot > 0, "BAD_SECONDS_PER_SLOT");
        require(_genesisTime > 0, "BAD_GENESIS_TIME");

        uint256 data = (
            uint256(_epochsPerFrame) << 192 |
            uint256(_slotsPerEpoch) << 128 |
            uint256(_secondsPerSlot) << 64 |
            uint256(_genesisTime)
        );
        I_SPEC_POSITION.setStorageUint256(data);
        emit SpecSet(
            _epochsPerFrame,
            _slotsPerEpoch,
            _secondsPerSlot,
            _genesisTime);
    }

    function _push(
        uint256 _epochId,
        uint128 _BalanceEth1,
        uint128 _Validators,
        Spec memory _Spec
    )
        internal
    {
        emit Completed(_epochId, _BalanceEth1, _Validators);

        _clearReportingAndAdvanceTo(_epochId + _Spec.epochsPerFrame);

        IAinomo ainomo = getAinomo();
        uint256 prevTotalPooledEther = ainomo.totalSupply();
        ainomo.handleOracleReport(_Validators, _BalanceEth1);
        uint256 postTotalPooledEther = ainomo.totalSupply();

        PRE_COMPLETED_TOTAL_POOLED_ETHER_POSITION.setStorageUint256(prevTotalPooledEther);
        POST_COMPLETED_TOTAL_POOLED_ETHER_POSITION.setStorageUint256(postTotalPooledEther);
        uint256 timeElapsed = (_epochId - LAST_COMPLETED_EPOCH_ID_POSITION.getStorageUint256()) *
            _Spec.slotsPerEpoch * _Spec.secondsPerSlot;
        TIME_ELAPSED_POSITION.setStorageUint256(timeElapsed);
        LAST_COMPLETED_EPOCH_ID_POSITION.setStorageUint256(_epochId);

        _reportSanityChecks(postTotalPooledEther, prevTotalPooledEther, timeElapsed);

        emit PostTotalShares(postTotalPooledEther, prevTotalPooledEther, timeElapsed, ainomo.getTotalShares());
        IReportReceiver receiver = IReportReceiver(I_REPORT_RECEIVER_POSITION.getStorageUint256());
        if (address(receiver) != address(0)) {
            receiver.processNomoOracleReport(postTotalPooledEther, prevTotalPooledEther, timeElapsed);
        }
    }

    function _clearReportingAndAdvanceTo(uint256 _epochId) internal {
        REPORTS_BITMASK_POSITION.setStorageUint256(0);
        EXPECTED_EPOCH_ID_POSITION.setStorageUint256(_epochId);
        delete currentReportVariants;
        emit ExpectedEpochIdUpdated(_epochId);
    }

    function _reportSanityChecks(
        uint256 _postTotalPooledEther,
        uint256 _preTotalPooledEther,
        uint256 _timeElapsed)
        internal
        view
    {
        if (_postTotalPooledEther >= _preTotalPooledEther) {
            uint256 allowedAnnualRelativeIncreaseBp =
                ALLOWED_I_BALANCE_ANNUAL_RELATIVE_INCREASE_POSITION.getStorageUint256();
            require(uint256(10000 * 365 days).mul(_postTotalPooledEther - _preTotalPooledEther) <=
                    allowedAnnualRelativeIncreaseBp.mul(_preTotalPooledEther).mul(_timeElapsed),
                    "ALLOWED_I_BALANCE_INCREASE");
        } else {
            uint256 allowedRelativeDecreaseBp =
                ALLOWED_I_BALANCE_RELATIVE_DECREASE_POSITION.getStorageUint256();
            require(uint256(10000).mul(_preTotalPooledEther - _postTotalPooledEther) <=
                    allowedRelativeDecreaseBp.mul(_preTotalPooledEther),
                    "ALLOWED_I_BALANCE_DECREASE");
        }
    }

    function _getMemberId(address _member) internal view returns (uint256) {
        uint256 length = members.length;
        for (uint256 i = 0; i < length; ++i) {
            if (members[i] == _member) {
                return i;
            }
        }
        return MEMBER_NOT_FOUND;
    }

    function _getCurrentEpochId(Spec memory _Spec) internal view returns (uint256) {
        return (_getTime() - _Spec.genesisTime) / (_Spec.slotsPerEpoch * _Spec.secondsPerSlot);
    }

    function _getFrameFirstEpochId(uint256 _epochId, Spec memory _Spec) internal view returns (uint256) {
        return _epochId / _Spec.epochsPerFrame * _Spec.epochsPerFrame;
    }

    function _getTime() internal view returns (uint256) {
        return block.timestamp; // solhint-disable
    }
}
