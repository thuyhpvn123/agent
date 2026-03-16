// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface INetCafeManagementV2 {
    function getStationPrice(bytes32 pcId) external view returns (uint256);

    function getStationMeta(
        bytes32 pcId
    ) external view returns (string memory name, bytes32 groupId, bool exists);

    function getStationIdsPaged(
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory);

    function getGroupIdsPaged(
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory);

    function getPricePolicyIdsPaged(
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory);
}
