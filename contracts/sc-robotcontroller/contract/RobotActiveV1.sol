// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RobotStaffUpgradeable} from "./RobotStaffUpgradeable.sol";
import "./interfaces/IRobotRegistry.sol";

contract RobotActive is
    OwnableUpgradeable,
    // UUPSUpgradeable,
    RobotStaffUpgradeable
{
    enum ActivityStatus {
        ONGOING, // Đang hoạt động
        COMPLETED, // Đã hoàn thành
        CANCELLED // Đã hủy
    }

    struct RobotActiveInfo {
        uint256 activityId;
        address robotAddress;
        uint256 startTime;
        uint256 endTime;
        uint256 totalActiveTime;
        uint256 createdAt;
        string action; // Hành động của robot (vd: "Sao kê pin", "Đang hỗ trợ khách hàng")
        ActivityStatus status;
    }

    IRobotRegistry public robotRegistry;

    // robotAddress → array of activities
    mapping(address => RobotActiveInfo[]) public robotActivities;

    // Track activity đang chạy của robot
    mapping(address => uint256) public activeActivityIndex;
    mapping(address => bool) public hasActiveActivity;

    uint256 private activityCounter;

    event ActivityStarted(
        address indexed robotAddress,
        uint256 indexed activityId,
        uint256 activityIndex,
        string action,
        uint256 startTime
    );
    event ActivityEnded(
        address indexed robotAddress,
        uint256 indexed activityId,
        uint256 duration,
        string action,
        ActivityStatus status
    );
    event ActivityCancelled(
        address indexed robotAddress,
        uint256 indexed activityId,
        string action
    );

    // constructor(address _robotRegistryAddress) {
    //     require(
    //         _robotRegistryAddress != address(0),
    //         "Invalid registry address"
    //     );
    //     robotRegistry = IRobotRegistry(_robotRegistryAddress);
    // }
    function initialize(
        address _staffContract,
        address _robotRegistry
    ) public initializer {
        __Ownable_init(msg.sender);
        // __UUPSUpgradeable_init();
        __RobotStaffUpgradeable_init(_staffContract);

        robotRegistry = IRobotRegistry(_robotRegistry);
    }
    // function _authorizeUpgrade(
    //     address newImplemation
    // ) internal override onlyOwner {}

    // Modifier kiểm tra robot tồn tại
    modifier robotExists(address _robotAddress) {
        IRobotRegistry.Robot memory robot = robotRegistry.getRobotByAddress(
            _robotAddress
        );
        require(robot.robotAddress != address(0), "Robot not exists");
        _;
    }

    // Bắt đầu hoạt động
    function startActivity(
        address _robotAddress,
        string memory _action
    ) public robotExists(_robotAddress) onlyMerchantOwner returns (uint256) {
        require(bytes(_action).length > 0, "Action cannot be empty");
        require(
            !hasActiveActivity[_robotAddress],
            "Robot already has an active activity"
        );

        activityCounter++;
        uint256 newActivityId = activityCounter;

        robotActivities[_robotAddress].push(
            RobotActiveInfo({
                activityId: newActivityId,
                robotAddress: _robotAddress,
                startTime: block.timestamp,
                endTime: 0,
                totalActiveTime: 0,
                createdAt: block.timestamp,
                action: _action,
                status: ActivityStatus.ONGOING
            })
        );

        uint256 activityIndex = robotActivities[_robotAddress].length - 1;

        hasActiveActivity[_robotAddress] = true;
        activeActivityIndex[_robotAddress] = activityIndex;

        emit ActivityStarted(
            _robotAddress,
            newActivityId,
            activityIndex,
            _action,
            block.timestamp
        );
        return newActivityId;
    }

    // Kết thúc hoạt động hiện tại
    function endCurrentActivity(
        address _robotAddress
    ) public robotExists(_robotAddress) onlyMerchantOwner {
        require(
            hasActiveActivity[_robotAddress],
            "No active activity for this robot"
        );

        uint256 activityIndex = activeActivityIndex[_robotAddress];
        RobotActiveInfo storage activity = robotActivities[_robotAddress][
            activityIndex
        ];

        require(
            activity.status == ActivityStatus.ONGOING,
            "Activity is not ongoing"
        );

        activity.endTime = block.timestamp;
        activity.totalActiveTime = activity.endTime - activity.startTime;
        activity.status = ActivityStatus.COMPLETED;

        hasActiveActivity[_robotAddress] = false;
        activeActivityIndex[_robotAddress] = 0;

        emit ActivityEnded(
            _robotAddress,
            activity.activityId,
            activity.totalActiveTime,
            activity.action,
            ActivityStatus.COMPLETED
        );
    }

    // Hủy hoạt động hiện tại
    function cancelCurrentActivity(
        address _robotAddress
    ) public robotExists(_robotAddress) onlyMerchantOwner {
        require(
            hasActiveActivity[_robotAddress],
            "No active activity for this robot"
        );

        uint256 activityIndex = activeActivityIndex[_robotAddress];
        RobotActiveInfo storage activity = robotActivities[_robotAddress][
            activityIndex
        ];

        require(
            activity.status == ActivityStatus.ONGOING,
            "Activity is not ongoing"
        );

        activity.endTime = block.timestamp;
        activity.totalActiveTime = activity.endTime - activity.startTime;
        activity.status = ActivityStatus.CANCELLED;

        hasActiveActivity[_robotAddress] = false;
        activeActivityIndex[_robotAddress] = 0;

        emit ActivityCancelled(
            _robotAddress,
            activity.activityId,
            activity.action
        );
    }

    // Kết thúc hoạt động theo index (nếu cần kết thúc activity cũ)
    function endActivity(
        address _robotAddress,
        uint256 _activityIndex
    ) public robotExists(_robotAddress) onlyMerchantOwner onlyManager {
        require(
            _activityIndex < robotActivities[_robotAddress].length,
            "Activity not exists"
        );

        RobotActiveInfo storage activity = robotActivities[_robotAddress][
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
            hasActiveActivity[_robotAddress] &&
            activeActivityIndex[_robotAddress] == _activityIndex
        ) {
            hasActiveActivity[_robotAddress] = false;
            activeActivityIndex[_robotAddress] = 0;
        }

        emit ActivityEnded(
            _robotAddress,
            activity.activityId,
            activity.totalActiveTime,
            activity.action,
            ActivityStatus.COMPLETED
        );
    }

    // Lấy thông tin robot từ registry
    function getRobotInfo(
        address _robotAddress
    ) public view returns (IRobotRegistry.Robot memory) {
        return robotRegistry.getRobotByAddress(_robotAddress);
    }

    // Lấy tất cả activities của robot
    function getActivitiesByRobot(
        address _robotAddress
    ) public view returns (RobotActiveInfo[] memory) {
        return robotActivities[_robotAddress];
    }

    // Pagination (page bắt đầu từ 1)
    function getActivitiesPaginated(
        address _robotAddress,
        uint256 page,
        uint256 limit
    ) public view returns (RobotActiveInfo[] memory activities, uint256 total) {
        require(limit > 0, "Limit must be > 0");

        total = robotActivities[_robotAddress].length;

        if (page == 0 || total == 0) {
            return (new RobotActiveInfo[](0), total);
        }

        uint256 start = (page - 1) * limit;
        if (start >= total) {
            return (new RobotActiveInfo[](0), total);
        }

        uint256 end = start + limit;
        if (end > total) end = total;

        uint256 size = end - start;
        activities = new RobotActiveInfo[](size);

        for (uint256 i = 0; i < size; i++) {
            activities[i] = robotActivities[_robotAddress][start + i];
        }

        return (activities, total);
    }

    // Lấy activity theo index
    function getActivity(
        address _robotAddress,
        uint256 _activityIndex
    ) public view returns (RobotActiveInfo memory) {
        require(
            _activityIndex < robotActivities[_robotAddress].length,
            "Activity not exists"
        );
        return robotActivities[_robotAddress][_activityIndex];
    }

    // Lấy activity theo activityId (duyệt tuyến tính)
    function getActivityById(
        address _robotAddress,
        uint256 _activityId
    ) public view returns (RobotActiveInfo memory) {
        for (uint256 i = 0; i < robotActivities[_robotAddress].length; i++) {
            if (robotActivities[_robotAddress][i].activityId == _activityId) {
                return robotActivities[_robotAddress][i];
            }
        }
        revert("Activity not found");
    }

    // Lấy activity đang chạy
    function getCurrentActivity(
        address _robotAddress
    ) public view returns (RobotActiveInfo memory) {
        require(hasActiveActivity[_robotAddress], "No active activity");
        return
            robotActivities[_robotAddress][activeActivityIndex[_robotAddress]];
    }

    // Tổng thời gian active
    function getTotalActiveTime(
        address _robotAddress
    ) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < robotActivities[_robotAddress].length; i++) {
            total += robotActivities[_robotAddress][i].totalActiveTime;
        }
        return total;
    }

    // Số lượng activity
    function getActivityCount(
        address _robotAddress
    ) public view returns (uint256) {
        return robotActivities[_robotAddress].length;
    }

    // Tổng số activity toàn hệ thống
    function getTotalActivityCount() public view returns (uint256) {
        return activityCounter;
    }

    // Activities đã hoàn thành
    function getCompletedActivities(
        address _robotAddress
    ) public view returns (RobotActiveInfo[] memory) {
        RobotActiveInfo[] memory all = robotActivities[_robotAddress];
        uint256 count = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].status == ActivityStatus.COMPLETED) count++;
        }

        RobotActiveInfo[] memory result = new RobotActiveInfo[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].status == ActivityStatus.COMPLETED) {
                result[idx++] = all[i];
            }
        }
        return result;
    }

    // Activities đang ongoing
    function getOngoingActivities(
        address _robotAddress
    ) public view returns (RobotActiveInfo[] memory) {
        RobotActiveInfo[] memory all = robotActivities[_robotAddress];
        uint256 count = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].status == ActivityStatus.ONGOING) count++;
        }

        RobotActiveInfo[] memory result = new RobotActiveInfo[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].status == ActivityStatus.ONGOING) {
                result[idx++] = all[i];
            }
        }
        return result;
    }

    // Activities đã hủy
    function getCancelledActivities(
        address _robotAddress
    ) public view returns (RobotActiveInfo[] memory) {
        RobotActiveInfo[] memory all = robotActivities[_robotAddress];
        uint256 count = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].status == ActivityStatus.CANCELLED) count++;
        }

        RobotActiveInfo[] memory result = new RobotActiveInfo[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].status == ActivityStatus.CANCELLED) {
                result[idx++] = all[i];
            }
        }
        return result;
    }

    // Activities trong khoảng thời gian
    function getActivitiesByTimeRange(
        address _robotAddress,
        uint256 _startTime,
        uint256 _endTime
    ) public view returns (RobotActiveInfo[] memory) {
        require(_startTime < _endTime, "Invalid time range");

        RobotActiveInfo[] memory all = robotActivities[_robotAddress];
        uint256 count = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (
                all[i].startTime >= _startTime && all[i].startTime <= _endTime
            ) {
                count++;
            }
        }

        RobotActiveInfo[] memory result = new RobotActiveInfo[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (
                all[i].startTime >= _startTime && all[i].startTime <= _endTime
            ) {
                result[idx++] = all[i];
            }
        }
        return result;
    }

    // Kiểm tra robot đang active không
    function isRobotActive(address _robotAddress) public view returns (bool) {
        return hasActiveActivity[_robotAddress];
    }

    // Thời gian hoạt động trung bình
    function getAverageActivityTime(
        address _robotAddress
    ) public view returns (uint256) {
        uint256 count = 0;
        uint256 total = 0;

        for (uint256 i = 0; i < robotActivities[_robotAddress].length; i++) {
            if (robotActivities[_robotAddress][i].totalActiveTime > 0) {
                total += robotActivities[_robotAddress][i].totalActiveTime;
                count++;
            }
        }

        if (count == 0) return 0;
        return total / count;
    }
}
