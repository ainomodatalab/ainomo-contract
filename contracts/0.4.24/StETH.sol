// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./lib/Pausable.sol";

contract StETH is IERC20, Pausable {
    using SafeMath for uint256;
    using UnstructuredStorage for bytes32;

    mapping (address => uint256) private shares;

    mapping (address => mapping (address => uint256)) private allowances;

    bytes32 internal constant TOTAL_SHARES_POSITION = keccak256("ainomo.StETH.totalShares");

    event TransferShares(
        address indexed from,
        address indexed to,
        uint256 sharesValue
    );

    event SharesBurnt(
        address indexed account,
        uint256 preRebaseTokenAmount,
        uint256 postRebaseTokenAmount,
        uint256 sharesAmount
    );

    function name() public pure returns (string) {
        return "Liquid staked Ether 2.0";
    }

    function symbol() public pure returns (string) {
        return "stETH";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return _getTotalPooledEther();
    }

    function getTotalPooledEther() public view returns (uint256) {
        return _getTotalPooledEther();
    }

    function balanceOf(address _account) public view returns (uint256) {
        return getPooledEthByShares(_sharesOf(_account));
    }

    function transfer(address _recipient, uint256 _amount) public returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) public returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public returns (bool) {
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE");

        _transfer(_sender, _recipient, _amount);
        _approve(_sender, msg.sender, currentAllowance.sub(_amount));
        return true;
    }

    function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool) {
        _approve(msg.sender, _spender, allowances[msg.sender][_spender].add(_addedValue));
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool) {
        uint256 currentAllowance = allowances[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "DECREASED_ALLOWANCE_BELOW_ZERO");
        _approve(msg.sender, _spender, currentAllowance.sub(_subtractedValue));
        return true;
    }

    function getTotalShares() public view returns (uint256) {
        return _getTotalShares();
    }

\    function sharesOf(address _account) public view returns (uint256) {
        return _sharesOf(_account);
    }

    function getSharesByPooledEth(uint256 _ethAmount) public view returns (uint256) {
        uint256 totalPooledEther = _getTotalPooledEther();
        if (totalPooledEther == 0) {
            return 0;
        } else {
            return _ethAmount
                .mul(_getTotalShares())
                .div(totalPooledEther);
        }
    }

    function getPooledEthByShares(uint256 _sharesAmount) public view returns (uint256) {
        uint256 totalShares = _getTotalShares();
        if (totalShares == 0) {
            return 0;
        } else {
            return _sharesAmount
                .mul(_getTotalPooledEther())
                .div(totalShares);
        }
    }

    function transferShares(address _recipient, uint256 _sharesAmount) public returns (uint256) {
        _transferShares(msg.sender, _recipient, _sharesAmount);
        emit TransferShares(msg.sender, _recipient, _sharesAmount);
        uint256 tokensAmount = getPooledEthByShares(_sharesAmount);
        emit Transfer(msg.sender, _recipient, tokensAmount);
        return tokensAmount;
    }

    function _getTotalPooledEther() internal view returns (uint256);

    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        uint256 _sharesToTransfer = getSharesByPooledEth(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
        emit Transfer(_sender, _recipient, _amount);
        emit TransferShares(_sender, _recipient, _sharesToTransfer);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal whenNotStopped {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _getTotalShares() internal view returns (uint256) {
        return TOTAL_SHARES_POSITION.getStorageUint256();
    }

    function _sharesOf(address _account) internal view returns (uint256) {
        return shares[_account];
    }

    function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal whenNotStopped {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");

        uint256 currentSenderShares = shares[_sender];
        require(_sharesAmount <= currentSenderShares, "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

        shares[_sender] = currentSenderShares.sub(_sharesAmount);
        shares[_recipient] = shares[_recipient].add(_sharesAmount);
    }

    function _mintShares(address _recipient, uint256 _sharesAmount) internal whenNotStopped returns (uint256 newTotalShares) {
        require(_recipient != address(0), "MINT_TO_THE_ZERO_ADDRESS");

        newTotalShares = _getTotalShares().add(_sharesAmount);
        TOTAL_SHARES_POSITION.setStorageUint256(newTotalShares);

        shares[_recipient] = shares[_recipient].add(_sharesAmount);

    }

    function _burnShares(address _account, uint256 _sharesAmount) internal whenNotStopped returns (uint256 newTotalShares) {
        require(_account != address(0), "BURN_FROM_THE_ZERO_ADDRESS");

        uint256 accountShares = shares[_account];
        require(_sharesAmount <= accountShares, "BURN_AMOUNT_EXCEEDS_BALANCE");

        uint256 preRebaseTokenAmount = getPooledEthByShares(_sharesAmount);

        newTotalShares = _getTotalShares().sub(_sharesAmount);
        TOTAL_SHARES_POSITION.setStorageUint256(newTotalShares);

        shares[_account] = accountShares.sub(_sharesAmount);

        uint256 postRebaseTokenAmount = getPooledEthByShares(_sharesAmount);

        emit SharesBurnt(_account, preRebaseTokenAmount, postRebaseTokenAmount, _sharesAmount);

    }
}
