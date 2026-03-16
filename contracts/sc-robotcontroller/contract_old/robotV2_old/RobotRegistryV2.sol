// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RobotRegistryV2 is UUPSUpgradeable {
    enum RobotStatus {
        ACTIVE,
        INACTIVE,
        DISCONNECTED,
        CHARGING,
        MAINTENANCE
    }

    struct Robot {
        uint256 id;
        string name;
        RobotStatus status;
        uint256 batteryLevel;
        uint256 createdAt;
        uint256 groupId;
        string image;
    }

    struct GroupRobot {
        uint256 groupId;
        uint256[] robotIds;
        string name;
    }

    uint256 private robotCounter;
    uint256 private groupCounter;

    mapping(uint256 => Robot) public robots;
    mapping(uint256 => GroupRobot) public groupRobots;

    event RobotRegistered(
        uint256 indexed robotId,
        string name,
        uint256 groupId,
        string image
    );
    event GroupRegistered(uint256 indexed groupId, string name);
    event UpdateBattery(uint256 indexed id, uint256 battery);
    event UpdateStatus(uint256 indexed id, RobotStatus status);

    function initialize() external initializer {
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override {}

    function registerGroupRobot(string memory _name) public returns (uint256) {
        groupCounter++;
        uint256 newGroupId = groupCounter;

        groupRobots[newGroupId] = GroupRobot({
            groupId: newGroupId,
            name: _name,
            robotIds: new uint256[](0)
        });

        emit GroupRegistered(newGroupId, _name);
        return newGroupId;
    }

    function registerRobot(
        string memory _name,
        uint256 _groupId,
        uint256 _batteryLevel,
        string memory _image
    ) public returns (uint256) {
        require(
            groupRobots[_groupId].groupId != 0,
            "Group with this ID does not exist"
        );
        require(_batteryLevel <= 100, "Battery must be <= 100");

        robotCounter++;
        uint256 newRobotId = robotCounter;

        robots[newRobotId] = Robot({
            id: newRobotId,
            name: _name,
            status: RobotStatus.ACTIVE,
            batteryLevel: _batteryLevel,
            createdAt: block.timestamp,
            groupId: _groupId,
            image: _image
        });

        groupRobots[_groupId].robotIds.push(newRobotId);
        emit RobotRegistered(newRobotId, _name, _groupId, _image);

        return newRobotId;
    }

    function getRobotsByGroup(
        uint256 _groupId
    ) public view returns (Robot[] memory) {
        GroupRobot storage group = groupRobots[_groupId];
        require(group.groupId != 0, "Group does not exist");

        uint256 len = group.robotIds.length;
        Robot[] memory result = new Robot[](len);

        for (uint256 i = 0; i < len; i++) {
            result[i] = robots[group.robotIds[i]];
        }

        return result;
    }

    function getGroupRobotById(
        uint256 _groupId
    ) public view returns (GroupRobot memory) {
        require(groupRobots[_groupId].groupId != 0, "GroupRobot not exists");
        return groupRobots[_groupId];
    }

    function getRobotById(uint256 _id) public view returns (Robot memory) {
        require(robots[_id].id != 0, "Robot not exists");
        return robots[_id];
    }

    function updateStatus(uint256 _id, RobotStatus _status) public {
        require(robots[_id].id != 0, "Robot not exists");

        Robot storage robot = robots[_id];
        robot.status = _status;

        emit UpdateStatus(_id, _status);
    }

    function updateBattery(uint256 _id, uint256 _battery) public {
        require(robots[_id].id != 0, "Robot not exists");
        require(_battery <= 100, "Battery must be <= 100");

        Robot storage robot = robots[_id];
        require(robot.status == RobotStatus.CHARGING, "Robot is not charging");

        robot.batteryLevel = _battery;
        emit UpdateBattery(_id, _battery);

        if (_battery == 100) {
            robot.status = RobotStatus.ACTIVE;
            emit UpdateStatus(_id, RobotStatus.ACTIVE);
        }
    }

    function getRobotCount() public view returns (uint256) {
        return robotCounter;
    }

    function getGroupCount() public view returns (uint256) {
        return groupCounter;
    }

    function getGroupsPaginated(
        uint256 page,
        uint256 limit
    ) public view returns (GroupRobot[] memory groups, uint256 total) {
        require(limit > 0, "Limit must be > 0");

        total = groupCounter;

        uint256 start = (page - 1) * limit + 1;
        if (start > total) {
            return (new GroupRobot[](0), total);
        }

        uint256 end = start + limit - 1;
        if (end > total) {
            end = total;
        }

        uint256 size = end - start + 1;
        groups = new GroupRobot[](size);

        uint256 index = 0;
        for (uint256 i = start; i <= end; i++) {
            groups[index] = groupRobots[i];
            index++;
        }

        return (groups, total);
    }

    function getRobotsPaginated(
        uint256 page,
        uint256 limit
    ) public view returns (Robot[] memory robotsPage, uint256 total) {
        require(limit > 0, "Limit must be > 0");
        total = robotCounter;

        if (page == 0 || total == 0) {
            return (new Robot[](0), total);
        }

        uint256 start = (page - 1) * limit + 1;
        if (start > total) {
            return (new Robot[](0), total);
        }

        uint256 end = start + limit - 1;
        if (end > total) {
            end = total;
        }

        uint256 size = end - start + 1;
        robotsPage = new Robot[](size);

        uint256 index = 0;
        for (uint256 i = start; i <= end; i++) {
            robotsPage[index] = robots[i];
            index++;
        }

        return (robotsPage, total);
    }

    function getRobotCountByStatus(
        RobotStatus _status
    ) public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 1; i <= robotCounter; i++) {
            if (robots[i].status == _status) {
                count++;
            }
        }
        return count;
    }

    function getRobotsByStatus(
        RobotStatus _status
    ) public view returns (Robot[] memory) {
        uint256 count = getRobotCountByStatus(_status);

        Robot[] memory result = new Robot[](count);
        uint256 index = 0;

        for (uint256 i = 1; i <= robotCounter; i++) {
            if (robots[i].status == _status) {
                result[index] = robots[i];
                index++;
            }
        }

        return result;
    }

    function getRobotsByStatusPaginated(
        RobotStatus _status,
        uint256 page,
        uint256 limit
    ) public view returns (Robot[] memory robotsPage, uint256 total) {
        require(limit > 0, "Limit must be > 0");
        require(page > 0, "Page must be > 0");

        total = getRobotCountByStatus(_status);

        if (total == 0) {
            return (new Robot[](0), 0);
        }

        uint256 start = (page - 1) * limit;
        if (start >= total) {
            return (new Robot[](0), total);
        }

        uint256 end = start + limit;
        if (end > total) {
            end = total;
        }

        uint256 size = end - start;
        robotsPage = new Robot[](size);

        uint256 currentIndex = 0;
        uint256 resultIndex = 0;

        for (uint256 i = 1; i <= robotCounter && resultIndex < size; i++) {
            if (robots[i].status == _status) {
                if (currentIndex >= start && currentIndex < end) {
                    robotsPage[resultIndex] = robots[i];
                    resultIndex++;
                }
                currentIndex++;
            }
        }

        return (robotsPage, total);
    }

    function getRobotsByStatusInGroup(
        uint256 _groupId,
        RobotStatus _status
    ) public view returns (Robot[] memory) {
        GroupRobot storage group = groupRobots[_groupId];
        require(group.groupId != 0, "Group does not exist");

        uint256 count = 0;
        for (uint256 i = 0; i < group.robotIds.length; i++) {
            if (robots[group.robotIds[i]].status == _status) {
                count++;
            }
        }

        Robot[] memory result = new Robot[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < group.robotIds.length; i++) {
            uint256 robotId = group.robotIds[i];
            if (robots[robotId].status == _status) {
                result[index] = robots[robotId];
                index++;
            }
        }

        return result;
    }

    function getRobotCountByStatusInGroup(
        uint256 _groupId,
        RobotStatus _status
    ) public view returns (uint256) {
        GroupRobot storage group = groupRobots[_groupId];
        require(group.groupId != 0, "Group does not exist");

        uint256 count = 0;
        for (uint256 i = 0; i < group.robotIds.length; i++) {
            if (robots[group.robotIds[i]].status == _status) {
                count++;
            }
        }
        return count;
    }

    function getRobotStatusStatistics()
        public
        view
        returns (
            uint256 activeCount,
            uint256 inactiveCount,
            uint256 disconnectedCount,
            uint256 chargingCount,
            uint256 maintenanceCount
        )
    {
        for (uint256 i = 1; i <= robotCounter; i++) {
            if (robots[i].status == RobotStatus.ACTIVE) {
                activeCount++;
            } else if (robots[i].status == RobotStatus.INACTIVE) {
                inactiveCount++;
            } else if (robots[i].status == RobotStatus.DISCONNECTED) {
                disconnectedCount++;
            } else if (robots[i].status == RobotStatus.CHARGING) {
                chargingCount++;
            } else if (robots[i].status == RobotStatus.MAINTENANCE) {
                maintenanceCount++;
            }
        }
        return (
            activeCount,
            inactiveCount,
            disconnectedCount,
            chargingCount,
            maintenanceCount
        );
    }

    function getGroupStatusStatistics(
        uint256 _groupId
    )
        public
        view
        returns (
            uint256 activeCount,
            uint256 inactiveCount,
            uint256 disconnectedCount,
            uint256 chargingCount,
            uint256 maintenanceCount
        )
    {
        GroupRobot storage group = groupRobots[_groupId];
        require(group.groupId != 0, "Group does not exist");

        for (uint256 i = 0; i < group.robotIds.length; i++) {
            uint256 robotId = group.robotIds[i];
            if (robots[robotId].status == RobotStatus.ACTIVE) {
                activeCount++;
            } else if (robots[robotId].status == RobotStatus.INACTIVE) {
                inactiveCount++;
            } else if (robots[robotId].status == RobotStatus.DISCONNECTED) {
                disconnectedCount++;
            } else if (robots[robotId].status == RobotStatus.CHARGING) {
                chargingCount++;
            } else if (robots[robotId].status == RobotStatus.MAINTENANCE) {
                maintenanceCount++;
            }
        }
        return (
            activeCount,
            inactiveCount,
            disconnectedCount,
            chargingCount,
            maintenanceCount
        );
    }
}
