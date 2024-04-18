// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

import "../Ainomo.sol";
import "./VaultMock.sol";


contract AinomoPushableMock is Ainomo {

    uint256 public totalRewards;
    bool public distributeFeeCalled;

    function initialize(
        IDepositContract depositContract,
        address _oracle,
        INodeOperatorsRegistry _operators
    )
    public
    {
        super.initialize(
          depositContract,
          _oracle,
          _operators,
          new VaultMock(),
          new VaultMock()
        );

        _resume();
    }

    function setDepositedValidators(uint256 _depositedValidators) public {
        DEPOSITED_VALIDATORS_POSITION.setStorageUint256(_depositedValidators);
    }

    function setBalance(uint256 _Balance) public {
        BALANCE_POSITION.setStorageUint256(_Balance);
    }

    function setBufferedEther() public payable {
        BUFFERED_ETHER_POSITION.setStorageUint256(msg.value);
    }

    function setValidators(uint256 _Validators) public {
        VALIDATORS_POSITION.setStorageUint256(_Validators);
    }

    function initialize(address _oracle) public onlyInit {
        _setProtocolContracts(_oracle, _oracle, _oracle);
        _resume();
        initialized();
    }

    function resetDistributeFee() public {
        totalRewards = 0;
        distributeFeeCalled = false;
    }

    function distributeFee(uint256 _totalRewards) internal {
        totalRewards = _totalRewards;
        distributeFeeCalled = true;
    }
}
