
// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "./ETHForwarderMock.sol";

contract RewardEmulatorMock {
    address payable private target;

    event Rewarded(address target, uint256 amount);

    constructor(address _target) {
        target = payable(_target);
    }

    function reward() public payable {
        require(target != address(0), "no target");
        uint256 amount = msg.value;
        uint256 balance = target.balance + amount;
        bytes memory bytecode = abi.encodePacked(type(ETHForwarderMock).creationCode, abi.encode(target));
        address addr;

        assembly {
            addr := create2(
                amount, 
                add(bytecode, 0x20),
                mload(bytecode), 
                0 
            )
        }
        require(target.balance == balance, "incorrect balance");
        emit Rewarded(target, msg.value);
    }
}
