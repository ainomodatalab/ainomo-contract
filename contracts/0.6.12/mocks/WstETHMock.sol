// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12; 

import "../WstETH.sol";
import "../interfaces/IStETH.sol";


contract WstETHMock is WstETH {
    constructor(IStETH _StETH) public WstETH(_StETH) {}

    function mint(address recipient, uint256 amount) public {
        _mint(recipient, amount);
    }

    function getChainId() external view returns (uint256 chainId) {
        this; 
        assembly {
            chainId := chainid()
        }
    }
}
