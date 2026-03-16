// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IRobotRegistry {
    enum RobotStatus {
        ACTIVE,
        INACTIVE,
        DISCONNECTED,
        CHARGING,
        MAINTENANCE
    }

    struct Robot {
        address robotAddress;
        string name;
        RobotStatus status;
        uint256 batteryLevel;
        uint256 createdAt;
        uint256 groupId;
        string image;
        address chat_address;
    }

    function getRobotByAddress(
        address _robotAddress
    ) external view returns (Robot memory);
    function robots(
        uint256
    )
        external
        view
        returns (
            address robotAddress,
            string memory name,
            RobotStatus status,
            uint256 batteryLevel,
            uint256 createdAt,
            uint256 groupId,
            string memory image,
            address chat_address
        );
    function getRobotCountByStatus(
        RobotStatus _status
    ) external view returns (uint256);
    function getRobotCountByStatusInGroup(
        uint256 _groupId,
        RobotStatus _status
    ) external view returns (uint256);
    function getRobotCount() external view returns (uint256);
}
