// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IRobotRegistry.sol";

/**
 * @title RobotDashboard
 * @dev Contract quản lý analytics và thống kê hoạt động robot
 *
 * Lưu ý: Contract này CHỈ LƯU DỮ LIỆU, không tự động tính toán.
 * Backend sẽ gọi các function để cập nhật số liệu định kỳ.
 */
contract RobotDashboard {
    /* =======================
            ENUMS
    ======================= */
    enum InteractionType {
        CUSTOMER_SERVICE, // Phục vụ khách hàng
        GREETING, // Chào hỏi
        QUESTION_ANSWER, // Trả lời câu hỏi
        TASK_EXECUTION, // Thực hiện task
        ERROR_HANDLING // Xử lý lỗi
    }

    enum TrafficSource {
        WEBSITE, // Website
        APP, // Mobile App
        VOICE, // Voice call
        CHAT, // Chat
        OTHER // Khác
    }

    /* =======================
            STRUCTS
    ======================= */

    // Thống kê theo ngày
    struct DailyStats {
        uint256 date; // Timestamp ngày (00:00:00)
        uint256 totalInteractions; // Tổng số tương tác
        uint256 totalCustomers; // Tổng số khách hàng
        uint256 successfulRate; // Tỷ lệ thành công × 100 (vd: 9200 = 92%)
        uint256 errorCount; // Số lỗi
        uint256 satisfiedRate; //Khách hàng hài lòng
        uint256 updatedAt; // Lần cập nhật cuối
    }

    // Top câu hỏi
    struct TopQuestion {
        string question;
        uint256 count; // Số lần được hỏi
        uint256 successRate; // Tỷ lệ trả lời đúng × 100
        uint256 lastAsked; // Lần hỏi cuối
    }

    // Phân loại nguồn
    struct SourceStats {
        uint256 traffic; // Nguồn traffic
        uint256 robotInitiated; // Robot chủ động
        uint256 scheduled; // Theo lịch
        uint256 interactive; // Tương tác trực tiếp
    }

    // Sự cố giao tiếp
    struct CommunicationIssue {
        string issueType; // "Lỗi xử lý", "Lời chào", "Giao tiếp"
        uint256 count;
        uint256 lastOccurred;
    }

    // Thông báo chi tiết
    struct ActivityLog {
        uint256 logId;
        uint256 robotId;
        uint256 timestamp;
        string activity; // "Mất kết nối Wifi trong 30s"
        string details;
        bool isResolved;
    }

    /* =======================
            STORAGE
    ======================= */
    IRobotRegistry public robotRegistry;

    // robotId => date => DailyStats
    mapping(uint256 => mapping(uint256 => DailyStats)) public dailyStats;

    // robotId => question hash => TopQuestion
    mapping(uint256 => mapping(bytes32 => TopQuestion)) public topQuestions;

    // robotId => list of question hashes (for iteration)
    mapping(uint256 => bytes32[]) private questionHashes;

    // robotId => date => SourceStats
    mapping(uint256 => mapping(uint256 => SourceStats)) public sourceStats;

    // robotId => issue type => CommunicationIssue
    mapping(uint256 => mapping(string => CommunicationIssue)) public commIssues;

    // robotId => ActivityLog[]
    mapping(uint256 => ActivityLog[]) public activityLogs;

    uint256 private logCounter;

    /* =======================
            EVENTS
    ======================= */
    event DailyStatsUpdated(
        uint256 indexed robotId,
        uint256 indexed date,
        uint256 interactions,
        uint256 customers
    );

    event QuestionRecorded(
        uint256 indexed robotId,
        string question,
        uint256 count
    );

    event ActivityLogged(
        uint256 indexed robotId,
        uint256 indexed logId,
        string activity
    );

    event IssueReported(
        uint256 indexed robotId,
        string issueType,
        uint256 count
    );

    /* =======================
            CONSTRUCTOR
    ======================= */
    constructor(address _robotRegistry) {
        require(_robotRegistry != address(0), "Invalid registry");
        robotRegistry = IRobotRegistry(_robotRegistry);
    }

    /* =======================
        MODIFIERS
    ======================= */
    modifier robotExists(uint256 robotId) {
        require(
            robotRegistry.getRobotById(robotId).id != 0,
            "Robot not exists"
        );
        _;
    }

    /* =======================
        DATA RECORDING
    ======================= */

    /**
     * @dev Cập nhật thống kê ngày
     * @notice BE gọi function này để update số liệu hàng ngày
     */
    function updateDailyStats(
        uint256 robotId,
        uint256 date,
        uint256 totalInteractions,
        uint256 totalCustomers,
        uint256 successfulRate,
        uint256 satisfiedRate,
        uint256 errorCount
    ) external robotExists(robotId) {
        require(successfulRate <= 10000, "Invalid rate");

        dailyStats[robotId][date] = DailyStats({
            date: date,
            totalInteractions: totalInteractions,
            totalCustomers: totalCustomers,
            successfulRate: successfulRate,
            errorCount: errorCount,
            satisfiedRate: satisfiedRate,
            updatedAt: block.timestamp
        });

        emit DailyStatsUpdated(
            robotId,
            date,
            totalInteractions,
            totalCustomers
        );
    }

    /**
     * @dev Record câu hỏi
     */
    function recordQuestion(
        uint256 robotId,
        string memory question,
        bool wasSuccessful
    ) external robotExists(robotId) {
        bytes32 qHash = keccak256(abi.encodePacked(question));

        TopQuestion storage tq = topQuestions[robotId][qHash];

        if (tq.count == 0) {
            // First time
            tq.question = question;
            questionHashes[robotId].push(qHash);
        }

        tq.count++;
        tq.lastAsked = block.timestamp;

        // Update success rate
        if (wasSuccessful) {
            uint256 successCount = (tq.successRate * (tq.count - 1)) /
                10000 +
                1;
            tq.successRate = (successCount * 10000) / tq.count;
        } else {
            uint256 successCount = (tq.successRate * (tq.count - 1)) / 10000;
            tq.successRate = (successCount * 10000) / tq.count;
        }

        emit QuestionRecorded(robotId, question, tq.count);
    }

    /**
     * @dev Cập nhật source stats
     */
    function updateSourceStats(
        uint256 robotId,
        uint256 date,
        uint256 traffic,
        uint256 robotInitiated,
        uint256 scheduled,
        uint256 interactive
    ) external robotExists(robotId) {
        sourceStats[robotId][date] = SourceStats({
            traffic: traffic,
            robotInitiated: robotInitiated,
            scheduled: scheduled,
            interactive: interactive
        });
    }

    /**
     * @dev Report communication issue
     */
    function reportIssue(
        uint256 robotId,
        string memory issueType
    ) external robotExists(robotId) {
        CommunicationIssue storage issue = commIssues[robotId][issueType];

        if (issue.count == 0) {
            issue.issueType = issueType;
        }

        issue.count++;
        issue.lastOccurred = block.timestamp;

        emit IssueReported(robotId, issueType, issue.count);
    }

    /**
     * @dev Log activity
     */
    function logActivity(
        uint256 robotId,
        string memory activity,
        string memory details
    ) external robotExists(robotId) returns (uint256) {
        logCounter++;

        activityLogs[robotId].push(
            ActivityLog({
                logId: logCounter,
                robotId: robotId,
                timestamp: block.timestamp,
                activity: activity,
                details: details,
                isResolved: false
            })
        );

        emit ActivityLogged(robotId, logCounter, activity);
        return logCounter;
    }

    /**
     * @dev Resolve activity log
     */
    function resolveActivity(uint256 robotId, uint256 logIndex) external {
        require(logIndex < activityLogs[robotId].length, "Invalid index");
        activityLogs[robotId][logIndex].isResolved = true;
    }

    /* =======================
            GETTERS
    ======================= */

    /**
     * @dev Lấy stats theo ngày
     */
    function getDailyStats(
        uint256 robotId,
        uint256 date
    ) external view returns (DailyStats memory) {
        return dailyStats[robotId][date];
    }

    /**
     * @dev Lấy stats nhiều ngày
     */
    function getStatsDateRange(
        uint256 robotId,
        uint256 startDate,
        uint256 endDate
    ) external view returns (DailyStats[] memory) {
        require(startDate <= endDate, "Invalid range");

        uint256 numDays = (endDate - startDate) / 1 days + 1;
        DailyStats[] memory stats = new DailyStats[](numDays);

        for (uint256 i = 0; i < numDays; i++) {
            uint256 date = startDate + (i * 1 days);
            stats[i] = dailyStats[robotId][date];
        }

        return stats;
    }

    /**
     * @dev Lấy top N questions
     */
    function getTopQuestions(
        uint256 robotId,
        uint256 limit
    ) external view returns (TopQuestion[] memory) {
        bytes32[] memory hashes = questionHashes[robotId];
        uint256 total = hashes.length;

        if (total == 0) {
            return new TopQuestion[](0);
        }

        // Simple sort (bubble sort for small datasets)
        TopQuestion[] memory allQuestions = new TopQuestion[](total);
        for (uint256 i = 0; i < total; i++) {
            allQuestions[i] = topQuestions[robotId][hashes[i]];
        }

        // Sort by count (descending)
        for (uint256 i = 0; i < total - 1; i++) {
            for (uint256 j = 0; j < total - i - 1; j++) {
                if (allQuestions[j].count < allQuestions[j + 1].count) {
                    TopQuestion memory temp = allQuestions[j];
                    allQuestions[j] = allQuestions[j + 1];
                    allQuestions[j + 1] = temp;
                }
            }
        }

        // Return top N
        uint256 resultSize = limit > total ? total : limit;
        TopQuestion[] memory result = new TopQuestion[](resultSize);
        for (uint256 i = 0; i < resultSize; i++) {
            result[i] = allQuestions[i];
        }

        return result;
    }

    /**
     * @dev Lấy source stats
     */
    function getSourceStats(
        uint256 robotId,
        uint256 date
    ) external view returns (SourceStats memory) {
        return sourceStats[robotId][date];
    }

    /**
     * @dev Lấy communication issues
     */
    function getIssue(
        uint256 robotId,
        string memory issueType
    ) external view returns (CommunicationIssue memory) {
        return commIssues[robotId][issueType];
    }

    /**
     * @dev Lấy activity logs
     */
    function getActivityLogs(
        uint256 robotId,
        uint256 limit
    ) external view returns (ActivityLog[] memory) {
        ActivityLog[] memory allLogs = activityLogs[robotId];
        uint256 total = allLogs.length;

        if (total == 0) {
            return new ActivityLog[](0);
        }

        uint256 resultSize = limit > total ? total : limit;
        ActivityLog[] memory result = new ActivityLog[](resultSize);

        // Get latest logs (reverse order)
        for (uint256 i = 0; i < resultSize; i++) {
            result[i] = allLogs[total - 1 - i];
        }

        return result;
    }

    /**
     * @dev Lấy logs chưa resolve
     */
    function getUnresolvedLogs(
        uint256 robotId
    ) external view returns (ActivityLog[] memory) {
        ActivityLog[] memory allLogs = activityLogs[robotId];

        // Count unresolved
        uint256 count = 0;
        for (uint256 i = 0; i < allLogs.length; i++) {
            if (!allLogs[i].isResolved) {
                count++;
            }
        }

        ActivityLog[] memory result = new ActivityLog[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allLogs.length; i++) {
            if (!allLogs[i].isResolved) {
                result[index] = allLogs[i];
                index++;
            }
        }

        return result;
    }

    /**
     * @dev Tính tổng trong khoảng thời gian
     */
    function getTotalStats(
        uint256 robotId,
        uint256 startDate,
        uint256 endDate
    )
        external
        view
        returns (
            uint256 totalInteractions,
            uint256 totalCustomers,
            uint256 avgSuccessRate,
            uint256 totalErrors
        )
    {
        uint256 numDays = (endDate - startDate) / 1 days + 1;
        uint256 rateSum = 0;
        uint256 rateCount = 0;

        for (uint256 i = 0; i < numDays; i++) {
            uint256 date = startDate + (i * 1 days);
            DailyStats memory stats = dailyStats[robotId][date];

            totalInteractions += stats.totalInteractions;
            totalCustomers += stats.totalCustomers;
            totalErrors += stats.errorCount;

            if (stats.successfulRate > 0) {
                rateSum += stats.successfulRate;
                rateCount++;
            }
        }

        avgSuccessRate = rateCount > 0 ? rateSum / rateCount : 0;
    }
}
