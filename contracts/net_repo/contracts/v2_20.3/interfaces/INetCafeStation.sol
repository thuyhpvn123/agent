// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface INetCafeStationV2 {
    function isStationOnline(bytes32 pcId) external view returns (bool);
    function isStationMaintenance(bytes32 pcId) external view returns (bool);
}
