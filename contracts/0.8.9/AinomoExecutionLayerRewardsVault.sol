// SPDX-FileCopyrightText: 2023 Ainomo 

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "@openzeppelin/contracts-v4.4/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-v4.4/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-v4.4/token/ERC20/utils/SafeERC20.sol";

interface IAinomo {
    function receiveELRewards() external payable;
}


contract AinomoExecutionLayerRewardsVault {
    using SafeERC20 for IERC20;

    address public immutable AINOMO;
    address public immutable TREASURY;

    event ERC20Recovered(
        address indexed requestedBy,
        address indexed token,
        uint256 amount
    );

    event ERC721Recovered(
        address indexed requestedBy,
        address indexed token,
        uint256 tokenId
    );

    event ETHReceived(
        uint256 amount
    );

    constructor(address _ainomo, address _treasury) {
        require(_ainomo != address(0), "AINOMO_ZERO_ADDRESS");
        require(_treasury != address(0), "TREASURY_ZERO_ADDRESS");

        AINOMO = _ainomo;
        TREASURY = _treasury;
    }

    receive() external payable {
        emit ETHReceived(msg.value);
    }

    function withdrawRewards(uint256 _maxAmount) external returns (uint256 amount) {
        require(msg.sender == AINOMO, "ONLY_OWNER_CAN_WITHDRAW");

        uint256 balance = address(this).balance;
        amount = (balance > _maxAmount) ? _maxAmount : balance;
        if (amount > 0) {
            IAinomo(AINOMO).receiveELRewards{value: amount}();
        }
        return amount;
    }

    function recoverERC20(address _token, uint256 _amount) external {
        require(_amount > 0, "ZERO_RECOVERY_AMOUNT");

        emit ERC20Recovered(msg.sender, _token, _amount);

        IERC20(_token).safeTransfer(TREASURY, _amount);
    }

    function recoverERC721(address _token, uint256 _tokenId) external {
        emit ERC721Recovered(msg.sender, _token, _tokenId);

        IERC721(_token).transferFrom(address(this), TREASURY, _tokenId);
    }
}
