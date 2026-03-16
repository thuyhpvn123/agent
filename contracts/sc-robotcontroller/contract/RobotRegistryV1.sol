// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RobotStaffUpgradeable} from "./RobotStaffUpgradeable.sol";

contract RobotRegistry is
    OwnableUpgradeable,
    // UUPSUpgradeable,
    RobotStaffUpgradeable
{
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

    struct GroupRobot {
        uint256 groupId;
        address[] robotAddresses;
        string name;
    }

    uint256 private groupCounter;

    // robotAddress => Robot
    mapping(address => Robot) public robots;
    // groupId => GroupRobot
    mapping(uint256 => GroupRobot) public groupRobots;
    // track all registered robot addresses for iteration
    address[] private allRobotAddresses;

    // Events
    event RobotRegistered(
        address indexed robotAddress,
        string name,
        uint256 groupId,
        string image
    );
    event GroupRegistered(uint256 indexed groupId, string name);
    event UpdateBattery(address indexed robotAddress, uint256 battery);
    event UpdateStatus(address indexed robotAddress, RobotStatus status);

    function initialize(address _staffContract) public initializer {
        __Ownable_init(msg.sender);
        // __UUPSUpgradeable_init();
        __RobotStaffUpgradeable_init(_staffContract);
    }
    // function _authorizeUpgrade(
    //     address newImplemation
    // ) internal override onlyOwner {}

    function registerGroupRobot(string memory _name) public returns (uint256) {
        groupCounter++;
        uint256 newGroupId = groupCounter;

        groupRobots[newGroupId] = GroupRobot({
            groupId: newGroupId,
            name: _name,
            robotAddresses: new address[](0)
        });

        emit GroupRegistered(newGroupId, _name);
        return newGroupId;
    }

    // ============ ROBOT FUNCTIONS ============

    function registerRobot(
        address _robotAddress,
        string memory _name,
        uint256 _groupId,
        uint256 _batteryLevel,
        string memory _image,
        address _chat_address
    ) public onlyMerchantOwner onlyManager {
        require(_robotAddress != address(0), "Invalid robot address");
        require(
            robots[_robotAddress].robotAddress == address(0),
            "Robot already registered"
        );
        require(groupRobots[_groupId].groupId != 0, "Group does not exist");
        require(_batteryLevel <= 100, "Battery must be <= 100");

        robots[_robotAddress] = Robot({
            robotAddress: _robotAddress,
            name: _name,
            status: RobotStatus.ACTIVE,
            batteryLevel: _batteryLevel,
            createdAt: block.timestamp,
            groupId: _groupId,
            image: _image,
            chat_address: _chat_address
        });

        groupRobots[_groupId].robotAddresses.push(_robotAddress);
        allRobotAddresses.push(_robotAddress);

        emit RobotRegistered(_robotAddress, _name, _groupId, _image);
    }

    function getRobotByAddress(
        address _robotAddress
    ) public view onlyMerchantOwner onlyManager returns (Robot memory) {
        require(
            robots[_robotAddress].robotAddress != address(0),
            "Robot not exists"
        );
        return robots[_robotAddress];
    }

    function updateStatus(RobotStatus _status) public {
        Robot storage robot = robots[msg.sender];

        require(robot.robotAddress != address(0), "Robot not exists");

        robot.status = _status;

        emit UpdateStatus(msg.sender, _status);
    }

    function updateBattery(uint256 _battery) public {
        Robot storage robot = robots[msg.sender];

        require(robot.robotAddress != address(0), "Robot not exists");
        require(_battery <= 100, "Battery must be <= 100");
        require(robot.status == RobotStatus.CHARGING, "Robot is not charging");

        robot.batteryLevel = _battery;

        emit UpdateBattery(msg.sender, _battery);

        if (_battery == 100) {
            robot.status = RobotStatus.ACTIVE;
            emit UpdateStatus(msg.sender, RobotStatus.ACTIVE);
        }
    }

    // ============ GROUP QUERY FUNCTIONS ============

    function getGroupRobotById(
        uint256 _groupId
    ) public view returns (GroupRobot memory) {
        require(groupRobots[_groupId].groupId != 0, "Group not exists");
        return groupRobots[_groupId];
    }

    function getRobotsByGroup(
        uint256 _groupId
    ) public view returns (Robot[] memory) {
        GroupRobot storage group = groupRobots[_groupId];
        require(group.groupId != 0, "Group does not exist");

        uint256 len = group.robotAddresses.length;
        Robot[] memory result = new Robot[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = robots[group.robotAddresses[i]];
        }
        return result;
    }

    // ============ HELPER FUNCTIONS ============

    function getRobotCount() public view returns (uint256) {
        return allRobotAddresses.length;
    }

    function getGroupCount() public view returns (uint256) {
        return groupCounter;
    }

    // ============ PAGINATED FUNCTIONS ============

    function getGroupsPaginated(
        uint256 page,
        uint256 limit
    )
        public
        view
        onlyMerchantOwner
        onlyManager
        returns (GroupRobot[] memory groups, uint256 total)
    {
        require(limit > 0, "Limit must be > 0");
        require(page > 0, "Page must be > 0");

        total = groupCounter;

        uint256 start = (page - 1) * limit + 1;
        if (start > total) return (new GroupRobot[](0), total);

        uint256 end = start + limit - 1;
        if (end > total) end = total;

        uint256 size = end - start + 1;
        groups = new GroupRobot[](size);

        for (uint256 i = 0; i < size; i++) {
            groups[i] = groupRobots[start + i];
        }

        return (groups, total);
    }

    function getRobotsPaginated(
        uint256 page,
        uint256 limit
    )
        public
        view
        onlyMerchantOwner
        onlyManager
        returns (Robot[] memory robotsPage, uint256 total)
    {
        require(limit > 0, "Limit must be > 0");
        require(page > 0, "Page must be > 0");

        total = allRobotAddresses.length;
        if (total == 0) return (new Robot[](0), total);

        uint256 start = (page - 1) * limit;
        if (start >= total) return (new Robot[](0), total);

        uint256 end = start + limit;
        if (end > total) end = total;

        uint256 size = end - start;
        robotsPage = new Robot[](size);

        for (uint256 i = 0; i < size; i++) {
            robotsPage[i] = robots[allRobotAddresses[start + i]];
        }

        return (robotsPage, total);
    }

    // ============ FILTER BY STATUS ============

    function getRobotCountByStatus(
        RobotStatus _status
    ) public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < allRobotAddresses.length; i++) {
            if (robots[allRobotAddresses[i]].status == _status) count++;
        }
        return count;
    }

    function getRobotsByStatus(
        RobotStatus _status
    ) public view returns (Robot[] memory) {
        uint256 count = getRobotCountByStatus(_status);
        Robot[] memory result = new Robot[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < allRobotAddresses.length; i++) {
            Robot storage r = robots[allRobotAddresses[i]];
            if (r.status == _status) {
                result[index] = r;
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
        if (total == 0) return (new Robot[](0), 0);

        uint256 start = (page - 1) * limit;
        if (start >= total) return (new Robot[](0), total);

        uint256 end = start + limit;
        if (end > total) end = total;

        uint256 size = end - start;
        robotsPage = new Robot[](size);

        uint256 currentIndex = 0;
        uint256 resultIndex = 0;

        for (
            uint256 i = 0;
            i < allRobotAddresses.length && resultIndex < size;
            i++
        ) {
            Robot storage r = robots[allRobotAddresses[i]];
            if (r.status == _status) {
                if (currentIndex >= start && currentIndex < end) {
                    robotsPage[resultIndex] = r;
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
        for (uint256 i = 0; i < group.robotAddresses.length; i++) {
            if (robots[group.robotAddresses[i]].status == _status) count++;
        }

        Robot[] memory result = new Robot[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < group.robotAddresses.length; i++) {
            address addr = group.robotAddresses[i];
            if (robots[addr].status == _status) {
                result[index] = robots[addr];
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
        for (uint256 i = 0; i < group.robotAddresses.length; i++) {
            if (robots[group.robotAddresses[i]].status == _status) count++;
        }
        return count;
    }

    // ============ STATISTICS ============

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
        for (uint256 i = 0; i < allRobotAddresses.length; i++) {
            RobotStatus s = robots[allRobotAddresses[i]].status;
            if (s == RobotStatus.ACTIVE) activeCount++;
            else if (s == RobotStatus.INACTIVE) inactiveCount++;
            else if (s == RobotStatus.DISCONNECTED) disconnectedCount++;
            else if (s == RobotStatus.CHARGING) chargingCount++;
            else if (s == RobotStatus.MAINTENANCE) maintenanceCount++;
        }
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

        for (uint256 i = 0; i < group.robotAddresses.length; i++) {
            RobotStatus s = robots[group.robotAddresses[i]].status;
            if (s == RobotStatus.ACTIVE) activeCount++;
            else if (s == RobotStatus.INACTIVE) inactiveCount++;
            else if (s == RobotStatus.DISCONNECTED) disconnectedCount++;
            else if (s == RobotStatus.CHARGING) chargingCount++;
            else if (s == RobotStatus.MAINTENANCE) maintenanceCount++;
        }
    }
    uint256[50] private __gap;
}
