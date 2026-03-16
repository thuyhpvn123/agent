// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IRobotRegistryV2.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RobotActiveV2 is UUPSUpgradeable {
    enum ActivityStatus {
        ONGOING,
        COMPLETED,
        CANCELLED
    }

    struct RobotActiveInfo {
        uint256 activityId;
        uint256 robotId;
        uint256 startTime;
        uint256 endTime;
        uint256 totalActiveTime;
        uint256 createdAt;
        string action;
        ActivityStatus status;
    }

    IRobotRegistryV2 public robotRegistry;

    mapping(uint256 => RobotActiveInfo[]) public robotActivities;
    mapping(uint256 => uint256) public activeActivityIndex;
    mapping(uint256 => bool) public hasActiveActivity;

    uint256 private activityCounter;
    address public owner;

    event ActivityStarted(
        uint256 indexed robotId,
        uint256 indexed activityId,
        uint256 activityIndex,
        string action,
        uint256 startTime
    );
    event ActivityEnded(
        uint256 indexed robotId,
        uint256 indexed activityId,
        uint256 duration,
        string action,
        ActivityStatus status
    );
    event ActivityCancelled(
        uint256 indexed robotId,
        uint256 indexed activityId,
        string action
    );

    function initialize(address _robotRegistryAddress) external initializer {
        __UUPSUpgradeable_init();
        require(_robotRegistryAddress != address(0), "Invalid registry address");
        robotRegistry = IRobotRegistryV2(_robotRegistryAddress);
        owner = msg.sender;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier robotExists(uint256 _robotId) {
        IRobotRegistryV2.Robot memory robot = robotRegistry.getRobotById(
            _robotId
        );
        require(robot.id != 0, "Robot not exists");
        _;
    }

    function startActivity(
        uint256 _robotId,
        string memory _action
    ) public robotExists(_robotId) returns (uint256) {
        require(bytes(_action).length > 0, "Action cannot be empty");
        require(
            !hasActiveActivity[_robotId],
            "Robot already has an active activity"
        );

        activityCounter++;
        uint256 newActivityId = activityCounter;

        robotActivities[_robotId].push(
            RobotActiveInfo({
                activityId: newActivityId,
                robotId: _robotId,
                startTime: block.timestamp,
                endTime: 0,
                totalActiveTime: 0,
                createdAt: block.timestamp,
                action: _action,
                status: ActivityStatus.ONGOING
            })
        );

        uint256 activityIndex = robotActivities[_robotId].length - 1;

        hasActiveActivity[_robotId] = true;
        activeActivityIndex[_robotId] = activityIndex;

        emit ActivityStarted(
            _robotId,
            newActivityId,
            activityIndex,
            _action,
            block.timestamp
        );
        return newActivityId;
    }

    function endCurrentActivity(uint256 _robotId) public robotExists(_robotId) {
        require(
            hasActiveActivity[_robotId],
            "No active activity for this robot"
        );

        uint256 activityIndex = activeActivityIndex[_robotId];
        RobotActiveInfo storage activity = robotActivities[_robotId][
            activityIndex
        ];

        require(
            activity.status == ActivityStatus.ONGOING,
            "Activity is not ongoing"
        );

        activity.endTime = block.timestamp;
        activity.totalActiveTime = activity.endTime - activity.startTime;
        activity.status = ActivityStatus.COMPLETED;

        hasActiveActivity[_robotId] = false;
        activeActivityIndex[_robotId] = 0;

        emit ActivityEnded(
            _robotId,
            activity.activityId,
            activity.totalActiveTime,
            activity.action,
            ActivityStatus.COMPLETED
        );
    }

    function cancelCurrentActivity(
        uint256 _robotId
    ) public robotExists(_robotId) {
        require(
            hasActiveActivity[_robotId],
            "No active activity for this robot"
        );

        uint256 activityIndex = activeActivityIndex[_robotId];
        RobotActiveInfo storage activity = robotActivities[_robotId][
            activityIndex
        ];

        require(
            activity.status == ActivityStatus.ONGOING,
            "Activity is not ongoing"
        );

        activity.endTime = block.timestamp;
        activity.totalActiveTime = activity.endTime - activity.startTime;
        activity.status = ActivityStatus.CANCELLED;

        hasActiveActivity[_robotId] = false;
        activeActivityIndex[_robotId] = 0;

        emit ActivityCancelled(_robotId, activity.activityId, activity.action);
    }

    function endActivity(
        uint256 _robotId,
        uint256 _activityIndex
    ) public robotExists(_robotId) {
        require(
            _activityIndex < robotActivities[_robotId].length,
            "Activity not exists"
        );

        RobotActiveInfo storage activity = robotActivities[_robotId][
            _activityIndex
        ];
        require(
            activity.status == ActivityStatus.ONGOING,
            "Activity is not ongoing"
        );

        activity.endTime = block.timestamp;
        activity.totalActiveTime = activity.endTime - activity.startTime;
        activity.status = ActivityStatus.COMPLETED;

        if (
            hasActiveActivity[_robotId] &&
            activeActivityIndex[_robotId] == _activityIndex
        ) {
            hasActiveActivity[_robotId] = false;
            activeActivityIndex[_robotId] = 0;
        }

        emit ActivityEnded(
            _robotId,
            activity.activityId,
            activity.totalActiveTime,
            activity.action,
            ActivityStatus.COMPLETED
        );
    }

    function getRobotInfo(
        uint256 _robotId
    ) public view returns (IRobotRegistryV2.Robot memory) {
        return robotRegistry.getRobotById(_robotId);
    }

    function getActivitiesByRobot(
        uint256 _robotId
    ) public view returns (RobotActiveInfo[] memory) {
        return robotActivities[_robotId];
    }

    function getActivitiesPaginated(
        uint256 _robotId,
        uint256 page,
        uint256 limit
    ) public view returns (RobotActiveInfo[] memory activities, uint256 total) {
        require(limit > 0, "Limit must be > 0");

        total = robotActivities[_robotId].length;

        if (page == 0 || total == 0) {
            return (new RobotActiveInfo[](0), total);
        }

        uint256 start = (page - 1) * limit;
        if (start >= total) {
            return (new RobotActiveInfo[](0), total);
        }

        uint256 end = start + limit;
        if (end > total) {
            end = total;
        }

        uint256 size = end - start;
        activities = new RobotActiveInfo[](size);

        for (uint256 i = 0; i < size; i++) {
            activities[i] = robotActivities[_robotId][start + i];
        }

        return (activities, total);
    }

    function getActivity(
        uint256 _robotId,
        uint256 _activityIndex
    ) public view returns (RobotActiveInfo memory) {
        require(
            _activityIndex < robotActivities[_robotId].length,
            "Activity not exists"
        );
        return robotActivities[_robotId][_activityIndex];
    }

    function getActivityById(
        uint256 _robotId,
        uint256 _activityId
    ) public view returns (RobotActiveInfo memory) {
        for (uint256 i = 0; i < robotActivities[_robotId].length; i++) {
            if (robotActivities[_robotId][i].activityId == _activityId) {
                return robotActivities[_robotId][i];
            }
        }
        revert("Activity not found");
    }

    function getCurrentActivity(
        uint256 _robotId
    ) public view returns (RobotActiveInfo memory) {
        require(hasActiveActivity[_robotId], "No active activity");
        return robotActivities[_robotId][activeActivityIndex[_robotId]];
    }

    function getTotalActiveTime(
        uint256 _robotId
    ) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < robotActivities[_robotId].length; i++) {
            total += robotActivities[_robotId][i].totalActiveTime;
        }
        return total;
    }

    function getActivityCount(uint256 _robotId) public view returns (uint256) {
        return robotActivities[_robotId].length;
    }

    function getTotalActivityCount() public view returns (uint256) {
        return activityCounter;
    }

    function getCompletedActivities(
        uint256 _robotId
    ) public view returns (RobotActiveInfo[] memory) {
        RobotActiveInfo[] memory allActivities = robotActivities[_robotId];

        uint256 count = 0;
        for (uint256 i = 0; i < allActivities.length; i++) {
            if (allActivities[i].status == ActivityStatus.COMPLETED) {
                count++;
            }
        }

        RobotActiveInfo[] memory result = new RobotActiveInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allActivities.length; i++) {
            if (allActivities[i].status == ActivityStatus.COMPLETED) {
                result[index] = allActivities[i];
                index++;
            }
        }

        return result;
    }

    function getOngoingActivities(
        uint256 _robotId
    ) public view returns (RobotActiveInfo[] memory) {
        RobotActiveInfo[] memory allActivities = robotActivities[_robotId];

        uint256 count = 0;
        for (uint256 i = 0; i < allActivities.length; i++) {
            if (allActivities[i].status == ActivityStatus.ONGOING) {
                count++;
            }
        }

        RobotActiveInfo[] memory result = new RobotActiveInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allActivities.length; i++) {
            if (allActivities[i].status == ActivityStatus.ONGOING) {
                result[index] = allActivities[i];
                index++;
            }
        }

        return result;
    }

    function getCancelledActivities(
        uint256 _robotId
    ) public view returns (RobotActiveInfo[] memory) {
        RobotActiveInfo[] memory allActivities = robotActivities[_robotId];

        uint256 count = 0;
        for (uint256 i = 0; i < allActivities.length; i++) {
            if (allActivities[i].status == ActivityStatus.CANCELLED) {
                count++;
            }
        }

        RobotActiveInfo[] memory result = new RobotActiveInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allActivities.length; i++) {
            if (allActivities[i].status == ActivityStatus.CANCELLED) {
                result[index] = allActivities[i];
                index++;
            }
        }

        return result;
    }

    function getActivitiesByTimeRange(
        uint256 _robotId,
        uint256 _startTime,
        uint256 _endTime
    ) public view returns (RobotActiveInfo[] memory) {
        require(_startTime < _endTime, "Invalid time range");

        RobotActiveInfo[] memory allActivities = robotActivities[_robotId];

        uint256 count = 0;
        for (uint256 i = 0; i < allActivities.length; i++) {
            if (
                allActivities[i].startTime >= _startTime &&
                allActivities[i].startTime <= _endTime
            ) {
                count++;
            }
        }

        RobotActiveInfo[] memory result = new RobotActiveInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allActivities.length; i++) {
            if (
                allActivities[i].startTime >= _startTime &&
                allActivities[i].startTime <= _endTime
            ) {
                result[index] = allActivities[i];
                index++;
            }
        }

        return result;
    }

    function isRobotActive(uint256 _robotId) public view returns (bool) {
        return hasActiveActivity[_robotId];
    }

    function getAverageActivityTime(
        uint256 _robotId
    ) public view returns (uint256) {
        uint256 count = 0;
        uint256 total = 0;

        for (uint256 i = 0; i < robotActivities[_robotId].length; i++) {
            if (robotActivities[_robotId][i].totalActiveTime > 0) {
                total += robotActivities[_robotId][i].totalActiveTime;
                count++;
            }
        }

        if (count == 0) return 0;
        return total / count;
    }
}
