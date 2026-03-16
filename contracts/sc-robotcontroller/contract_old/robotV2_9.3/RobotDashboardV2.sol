// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title RobotCheckpoint
 * @dev Luu checkpoint robot + thong ke FAQ theo ngay / thang / nam
 */
contract RobotCheckpointV2 is UUPSUpgradeable {
    enum IncidentCategory {
        Move, // 0
        Communication, // 1
        Technique // 2
    }
    enum IncidentDetail {
        Stuck,
        Collision,
        CannotReach,
        UnclearHearing,
        NotUnderstoodQuestion,
        AskedRepeatedly,
        ConnectionError,
        SoftwareError,
        SensorError
    }

    /* ===================== STRUCTS ===================== */

    struct Checkpoint {
        string robotId;
        uint256 timestamp;
        uint8 satisfaction;
        uint256 customerCount;
        uint256 correctAnswer;
        uint256 successful; // so luong thanh cong
        uint256 unsuccesfull;
        uint256 incorrectAnswer;
    }

    struct FAQ {
        string question;
        uint256 count;
    }
    struct RobotTypeStat {
        string robotType; // MiniBoss, MiniStaff, Syra...
        uint256 count; // so luong loai do
    }

    struct RobotSummary {
        uint256 totalRobots; // tong robot
        uint256 totalActiveTime; // tong thoi gian hoat dong (giay)
        uint256 totalInteractions; // tong luot tuong tac
    }
    struct ActivityStat {
        uint256 active; // dang hoat dong
        uint256 inactive; // khong hoat dong
        uint256 charging; // dang sac pin
    }
    struct Incident {
        string robotId; // Robot A, Robot B
        IncidentCategory category; // loai loi chinh
        IncidentDetail detail;
        uint256 timestamp; // thoi diem xay ra
        string decription;
    }

    /* ===================== STORAGE ===================== */

    Incident[] public incidents;
    Checkpoint[] public checkpoints;

    mapping(uint256 => FAQ[]) public dailyFAQs; // key = dayTimestamp (00:00:00)
    mapping(uint256 => FAQ[]) public monthlyFAQs; // key = YYYYMM (202611)
    mapping(uint256 => FAQ[]) public yearlyFAQs; // key = YYYY (2026)

    mapping(uint256 => RobotTypeStat[]) public dailyRobotTypes;
    mapping(uint256 => RobotSummary) public dailyRobotSummary;

    mapping(uint256 => RobotTypeStat[]) public monthlyRobotTypes;
    mapping(uint256 => RobotSummary) public monthlyRobotSummary;

    mapping(uint256 => RobotTypeStat[]) public yearlyRobotTypes;
    mapping(uint256 => RobotSummary) public yearlyRobotSummary;

    mapping(uint256 => ActivityStat) public dailyActivity;
    mapping(uint256 => ActivityStat) public monthlyActivity;
    mapping(uint256 => ActivityStat) public yearlyActivity;

    address public owner;

    /* ===================== EVENTS ===================== */

    event CheckpointAdded(
        uint256 indexed id,
        string robotId,
        uint256 timestamp
    );
    event DailyFAQAdded(uint256 indexed dayTimestamp, uint256 totalQuestions);
    event MonthlyFAQAdded(uint256 indexed monthId, uint256 totalQuestions);
    event YearlyFAQAdded(uint256 indexed year, uint256 totalQuestions);

    /* ===================== INITIALIZER ===================== */

    function initialize() external initializer {
        __UUPSUpgradeable_init();
        owner = msg.sender;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /* ===================== MODIFIERS ===================== */

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function addDailyActivityStat(
        uint256 dayTs,
        uint256 active,
        uint256 inactive,
        uint256 charging
    ) external onlyOwner {
        dailyActivity[dayTs] = ActivityStat(active, inactive, charging);
    }
    function addMonthlyActivityStat(
        uint256 monthId,
        uint256 active,
        uint256 inactive,
        uint256 charging
    ) external onlyOwner {
        monthlyActivity[monthId] = ActivityStat(active, inactive, charging);
    }
    function addYearlyActivityStat(
        uint256 year,
        uint256 active,
        uint256 inactive,
        uint256 charging
    ) external onlyOwner {
        yearlyActivity[year] = ActivityStat(active, inactive, charging);
    }

    /* ===================== CHECKPOINT ===================== */

    function addCheckpoint(
        string memory _robotId,
        uint256 _timestamp,
        uint8 _satisfaction,
        uint256 _customerCount,
        uint256 _correctAnswer,
        uint256 _successful,
        uint256 _unsuccesfull,
        uint256 _incorrectAnswer
    ) external onlyOwner {
        checkpoints.push(
            Checkpoint(
                _robotId,
                _timestamp,
                _satisfaction,
                _customerCount,
                _correctAnswer,
                _successful,
                _unsuccesfull,
                _incorrectAnswer
            )
        );

        emit CheckpointAdded(checkpoints.length - 1, _robotId, _timestamp);
    }

    function addIncident(
        string memory robotId,
        IncidentCategory category,
        IncidentDetail detail,
        uint256 timestamp,
        string memory description
    ) external onlyOwner {
        if (category == IncidentCategory.Move) {
            require(
                detail == IncidentDetail.Stuck ||
                    detail == IncidentDetail.Collision ||
                    detail == IncidentDetail.CannotReach,
                "Invalid detail for Move category"
            );
        } else if (category == IncidentCategory.Communication) {
            require(
                detail == IncidentDetail.UnclearHearing ||
                    detail == IncidentDetail.NotUnderstoodQuestion ||
                    detail == IncidentDetail.AskedRepeatedly,
                "Invalid detail for Communication category"
            );
        } else if (category == IncidentCategory.Technique) {
            require(
                detail == IncidentDetail.ConnectionError ||
                    detail == IncidentDetail.SoftwareError ||
                    detail == IncidentDetail.SensorError,
                "Invalid detail for Technique category"
            );
        }

        incidents.push(
            Incident(robotId, category, detail, timestamp, description)
        );
    }
    function addDailyRobotStat(
        uint256 dayTs,
        string[] memory robotTypes,
        uint256[] memory counts,
        uint256 totalRobots,
        uint256 totalActiveTime,
        uint256 totalInteractions
    ) external onlyOwner {
        require(robotTypes.length == counts.length, "Length mismatch");

        delete dailyRobotTypes[dayTs];

        for (uint256 i = 0; i < robotTypes.length; i++) {
            dailyRobotTypes[dayTs].push(
                RobotTypeStat(robotTypes[i], counts[i])
            );
        }

        dailyRobotSummary[dayTs] = RobotSummary(
            totalRobots,
            totalActiveTime,
            totalInteractions
        );
    }
    function addMonthlyRobotStat(
        uint256 monthId,
        string[] memory robotTypes,
        uint256[] memory counts,
        uint256 totalRobots,
        uint256 totalActiveTime,
        uint256 totalInteractions
    ) external onlyOwner {
        require(robotTypes.length == counts.length, "Length mismatch");

        delete monthlyRobotTypes[monthId];

        for (uint256 i = 0; i < robotTypes.length; i++) {
            monthlyRobotTypes[monthId].push(
                RobotTypeStat(robotTypes[i], counts[i])
            );
        }

        monthlyRobotSummary[monthId] = RobotSummary(
            totalRobots,
            totalActiveTime,
            totalInteractions
        );
    }
    function addYearlyRobotStat(
        uint256 year,
        string[] memory robotTypes,
        uint256[] memory counts,
        uint256 totalRobots,
        uint256 totalActiveTime,
        uint256 totalInteractions
    ) external onlyOwner {
        require(robotTypes.length == counts.length, "Length mismatch");

        delete yearlyRobotTypes[year];

        for (uint256 i = 0; i < robotTypes.length; i++) {
            yearlyRobotTypes[year].push(
                RobotTypeStat(robotTypes[i], counts[i])
            );
        }

        yearlyRobotSummary[year] = RobotSummary(
            totalRobots,
            totalActiveTime,
            totalInteractions
        );
    }

    /* ===================== DAILY FAQ ===================== */

    function addDailyFAQ(
        uint256 _dayTimestamp,
        string[] memory _questions,
        uint256[] memory _counts
    ) external onlyOwner {
        require(_questions.length == _counts.length, "Length mismatch");

        delete dailyFAQs[_dayTimestamp];

        for (uint256 i = 0; i < _questions.length; i++) {
            dailyFAQs[_dayTimestamp].push(FAQ(_questions[i], _counts[i]));
        }

        emit DailyFAQAdded(_dayTimestamp, _questions.length);
    }

    function getGlobalTopQuestionsTimeRange(
        uint256 _dayTimestamp
    )
        external
        view
        returns (string[] memory questions, uint256[] memory counts)
    {
        return _getFAQ(dailyFAQs[_dayTimestamp]);
    }

    /* ===================== MONTHLY FAQ ===================== */

    function addMonthlyFAQ(
        uint256 _monthId,
        string[] memory _questions,
        uint256[] memory _counts
    ) external onlyOwner {
        require(_questions.length == _counts.length, "Length mismatch");

        delete monthlyFAQs[_monthId];

        for (uint256 i = 0; i < _questions.length; i++) {
            monthlyFAQs[_monthId].push(FAQ(_questions[i], _counts[i]));
        }

        emit MonthlyFAQAdded(_monthId, _questions.length);
    }

    function getMonthlyFAQ(
        uint256 _monthId
    )
        external
        view
        returns (string[] memory questions, uint256[] memory counts)
    {
        return _getFAQ(monthlyFAQs[_monthId]);
    }

    /* ===================== YEARLY FAQ ===================== */

    function addYearlyFAQ(
        uint256 _year,
        string[] memory _questions,
        uint256[] memory _counts
    ) external onlyOwner {
        require(_questions.length == _counts.length, "Length mismatch");

        delete yearlyFAQs[_year];

        for (uint256 i = 0; i < _questions.length; i++) {
            yearlyFAQs[_year].push(FAQ(_questions[i], _counts[i]));
        }

        emit YearlyFAQAdded(_year, _questions.length);
    }

    function getYearlyFAQ(
        uint256 _year
    )
        external
        view
        returns (string[] memory questions, uint256[] memory counts)
    {
        return _getFAQ(yearlyFAQs[_year]);
    }

    /* ===================== HELPERS ===================== */

    function getDayTimestamp(uint256 _timestamp) public pure returns (uint256) {
        return (_timestamp / 1 days) * 1 days;
    }

    function _getFAQ(
        FAQ[] storage faqs
    )
        internal
        view
        returns (string[] memory questions, uint256[] memory counts)
    {
        questions = new string[](faqs.length);
        counts = new uint256[](faqs.length);

        for (uint256 i = 0; i < faqs.length; i++) {
            questions[i] = faqs[i].question;
            counts[i] = faqs[i].count;
        }
    }

    /* ===================== CHECKPOINT QUERY ===================== */

    function getGlobalStatsByTimeRange(
        uint256 _fromTime,
        uint256 _toTime
    )
        external
        view
        returns (
            string[] memory robotIds,
            uint256[] memory timestamps,
            uint8[] memory satisfactions,
            uint256[] memory counts,
            uint256[] memory correctAnswers,
            uint256[] memory successful,
            uint256[] memory unsuccesfull,
            uint256[] memory incorrectAnswer
        )
    {
        uint256 total = 0;

        for (uint256 i = 0; i < checkpoints.length; i++) {
            if (
                checkpoints[i].timestamp >= _fromTime &&
                checkpoints[i].timestamp <= _toTime
            ) {
                total++;
            }
        }

        robotIds = new string[](total);
        timestamps = new uint256[](total);
        satisfactions = new uint8[](total);
        counts = new uint256[](total);
        correctAnswers = new uint256[](total);
        successful = new uint256[](total);
        unsuccesfull = new uint256[](total);
        incorrectAnswer = new uint256[](total);

        uint256 idx = 0;
        for (uint256 i = 0; i < checkpoints.length; i++) {
            if (
                checkpoints[i].timestamp >= _fromTime &&
                checkpoints[i].timestamp <= _toTime
            ) {
                Checkpoint memory cp = checkpoints[i];
                robotIds[idx] = cp.robotId;
                timestamps[idx] = cp.timestamp;
                satisfactions[idx] = cp.satisfaction;
                counts[idx] = cp.customerCount;
                correctAnswers[idx] = cp.correctAnswer;
                successful[idx] = cp.successful;
                unsuccesfull[idx] = cp.unsuccesfull;
                incorrectAnswer[idx] = cp.incorrectAnswer;
                idx++;
            }
        }
    }

    function getTotalCheckpoints() external view returns (uint256) {
        return checkpoints.length;
    }

    function getDailyRobotStat(
        uint256 dayTs
    )
        external
        view
        returns (
            string[] memory robotTypes,
            uint256[] memory counts,
            uint256 totalRobots,
            uint256 totalActiveTime,
            uint256 totalInteractions
        )
    {
        RobotTypeStat[] storage stats = dailyRobotTypes[dayTs];

        robotTypes = new string[](stats.length);
        counts = new uint256[](stats.length);

        for (uint256 i = 0; i < stats.length; i++) {
            robotTypes[i] = stats[i].robotType;
            counts[i] = stats[i].count;
        }

        RobotSummary memory s = dailyRobotSummary[dayTs];
        return (
            robotTypes,
            counts,
            s.totalRobots,
            s.totalActiveTime,
            s.totalInteractions
        );
    }
    function getMonthlyRobotStat(
        uint256 monthId
    )
        external
        view
        returns (
            string[] memory robotTypes,
            uint256[] memory counts,
            uint256 totalRobots,
            uint256 totalActiveTime,
            uint256 totalInteractions
        )
    {
        RobotTypeStat[] storage stats = monthlyRobotTypes[monthId];

        robotTypes = new string[](stats.length);
        counts = new uint256[](stats.length);

        for (uint256 i = 0; i < stats.length; i++) {
            robotTypes[i] = stats[i].robotType;
            counts[i] = stats[i].count;
        }

        RobotSummary memory s = monthlyRobotSummary[monthId];
        return (
            robotTypes,
            counts,
            s.totalRobots,
            s.totalActiveTime,
            s.totalInteractions
        );
    }
    function getYearlyRobotStat(
        uint256 year
    )
        external
        view
        returns (
            string[] memory robotTypes,
            uint256[] memory counts,
            uint256 totalRobots,
            uint256 totalActiveTime,
            uint256 totalInteractions
        )
    {
        RobotTypeStat[] storage stats = yearlyRobotTypes[year];

        robotTypes = new string[](stats.length);
        counts = new uint256[](stats.length);

        for (uint256 i = 0; i < stats.length; i++) {
            robotTypes[i] = stats[i].robotType;
            counts[i] = stats[i].count;
        }

        RobotSummary memory s = yearlyRobotSummary[year];
        return (
            robotTypes,
            counts,
            s.totalRobots,
            s.totalActiveTime,
            s.totalInteractions
        );
    }

    function getDailyActivityStat(
        uint256 dayTs
    )
        external
        view
        returns (uint256 active, uint256 inactive, uint256 charging)
    {
        ActivityStat memory s = dailyActivity[dayTs];
        return (s.active, s.inactive, s.charging);
    }
    function getMonthlyActivityStat(
        uint256 monthId
    )
        external
        view
        returns (uint256 active, uint256 inactive, uint256 charging)
    {
        ActivityStat memory s = monthlyActivity[monthId];
        return (s.active, s.inactive, s.charging);
    }
    function getYearlyActivityStat(
        uint256 year
    )
        external
        view
        returns (uint256 active, uint256 inactive, uint256 charging)
    {
        ActivityStat memory s = yearlyActivity[year];
        return (s.active, s.inactive, s.charging);
    }

    /* ===================== INCIDENTS WITH PAGINATION (LIFO) ===================== */

    function getTotalIssuesByTimeRange(
        uint256 fromTime,
        uint256 toTime
    ) external view returns (uint256 total) {
        for (uint256 i = 0; i < incidents.length; i++) {
            if (
                incidents[i].timestamp >= fromTime &&
                incidents[i].timestamp <= toTime
            ) {
                total++;
            }
        }
    }

    function getIssuesCountsByTimeRange(
        IncidentCategory category,
        uint256 fromTime,
        uint256 toTime,
        uint256 limit,
        uint256 offset
    )
        external
        view
        returns (
            string[] memory robotIds,
            IncidentCategory[] memory categories,
            IncidentDetail[] memory details,
            uint256[] memory timestamps,
            uint256 totalCount,
            string[] memory descriptions
        )
    {
        require(limit > 0 && limit <= 100, "Limit must be 1-100");

        totalCount = 0;
        for (uint256 i = 0; i < incidents.length; i++) {
            if (
                incidents[i].category == category &&
                incidents[i].timestamp >= fromTime &&
                incidents[i].timestamp <= toTime
            ) {
                totalCount++;
            }
        }

        if (totalCount == 0 || offset >= totalCount) {
            return (
                new string[](0),
                new IncidentCategory[](0),
                new IncidentDetail[](0),
                new uint256[](0),
                totalCount,
                new string[](0)
            );
        }

        uint256 remaining = totalCount - offset;
        uint256 resultSize = remaining < limit ? remaining : limit;

        robotIds = new string[](resultSize);
        categories = new IncidentCategory[](resultSize);
        details = new IncidentDetail[](resultSize);
        timestamps = new uint256[](resultSize);
        descriptions = new string[](resultSize);

        uint256 matchCount = 0;
        uint256 resultIndex = 0;

        for (uint256 i = incidents.length; i > 0; i--) {
            uint256 idx = i - 1;

            if (
                incidents[idx].category == category &&
                incidents[idx].timestamp >= fromTime &&
                incidents[idx].timestamp <= toTime
            ) {
                if (matchCount >= offset && resultIndex < resultSize) {
                    Incident memory inc = incidents[idx];
                    robotIds[resultIndex] = inc.robotId;
                    categories[resultIndex] = inc.category;
                    details[resultIndex] = inc.detail;
                    timestamps[resultIndex] = inc.timestamp;
                    descriptions[resultIndex] = inc.decription;
                    resultIndex++;
                }
                matchCount++;

                if (resultIndex >= resultSize) {
                    break;
                }
            }
        }

        return (
            robotIds,
            categories,
            details,
            timestamps,
            totalCount,
            descriptions
        );
    }
}
