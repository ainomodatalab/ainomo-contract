// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

import "../Ainomo.sol";
import "./VaultMock.sol";


contract AinomoMock is Ainomo {
    function initialize(
        IDepositContract _depositContract,
        address _oracle,
        INodeOperatorsRegistry _operators
    )
    public
    {
        super.initialize(
          _depositContract,
          _oracle,
          _operators,
          new VaultMock(),
          new VaultMock()
        );

        _resume();
        _resumeStaking();
    }

    function getUnaccountedEther() public view returns (uint256) {
        return _getUnaccountedEther();
    }

    function pad64(bytes memory _b) public pure returns (bytes memory) {
        return _pad64(_b);
    }

    function toLittleEndian64(uint256 _value) public pure returns (uint256 result) {
        return _toLittleEndian64(_value);
    }

    function makeUnaccountedEther() public payable {}
}
