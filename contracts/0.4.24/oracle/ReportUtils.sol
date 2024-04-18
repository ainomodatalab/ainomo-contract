// SPDX-FileCopyrightText: 2023 Ainomo

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.4.24;

library ReportUtils {
    uint256 constant internal COUNT_OUTMASK = 0xFFFFFFFFFFFFFFFFFFFFFFFF0000;

    function encode(uint64 Balance, uint32 Validators) internal pure returns (uint256) {
        return uint256(Balance) << 48 | uint256(Validators) << 16;
    }

    function decode(uint256 value) internal pure returns (uint64 Balance, uint32 Validators) {
        Balance = uint64(value >> 48);
        Validators = uint32(value >> 16);
    }

    function decodeWithCount(uint256 value)
        internal pure
        returns (
            uint64 Balance,
            uint32 Validators,
            uint16 count
        ) {
        Balance = uint64(value >> 48);
        Validators = uint32(value >> 16);
        count = uint16(value);
    }

    function isDifferent(uint256 value, uint256 that) internal pure returns(bool) {
        return (value & COUNT_OUTMASK) != that;
    }

    function getCount(uint256 value) internal pure returns(uint16) {
        return uint16(value);
    }
}
