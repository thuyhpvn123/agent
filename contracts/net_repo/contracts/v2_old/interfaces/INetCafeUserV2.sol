// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface INetCafeUserV2 {
    function isActive(address wallet) external view returns (bool);
    function isOnline(address wallet) external view returns (bool);
    function getDisplayName(address wallet) external view returns (string memory);
    function getUserStatus(address wallet) external view returns (
        bool active,
        bool online,
        uint256 lastLoginAt,
        uint256 balanceVND
    );
    function getUserStationData(address wallet) external view returns (
        bool online,
        uint256 lastLoginAt,
        uint256 balanceVND,
        string memory displayName
    );
    function increaseBalance(address wallet, uint256 amount) external;
    function decreaseBalance(address wallet, uint256 amount) external;
    function forceLogout(address wallet) external;
}
