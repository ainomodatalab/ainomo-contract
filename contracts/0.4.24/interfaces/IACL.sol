/*
 * SPDX-License-Identifier:    MIT
 */

pragma solidity ^0.4.24;


interface IACL {
    function initialize(address permissionsCreator) external;

    // TODO: this should be external
    function hasPermission(address who, address where, bytes32 what, bytes how) public view returns (bool);
}
