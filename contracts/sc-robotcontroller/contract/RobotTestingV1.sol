// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRobotRegistry.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RobotStaffUpgradeable} from "./RobotStaffUpgradeable.sol";

/**
 * @title RobotTesting - Optimized Version
 * @dev Contract quản lý kiểm thử Robot (Testing/Exam system)
 *
 * FLOW (Tối ưu):
 * 1. FE: Upload file đề thi → BE gọi startTestSession()
 * 2. BE: Thêm file đề → Gọi addTestFile() (không cần questionCount)
 * 3. BE: Robot làm bài test (off-chain)
 * 4. BE: Tổng hợp kết quả → Gọi submitTestResult() với đầy đủ thông tin
 * 5. FE: Click "Hoàn tất" → BE gọi endTestSession()
 */
contract RobotTesting is
    OwnableUpgradeable,
    // UUPSUpgradeable,
    RobotStaffUpgradeable
{
    enum TestStatus {
        ONGOING, // Đang test
        PASSED, // Đạt (>50%)
        FAILED, // Không đạt (≤50%)
        CANCELLED // Đã hủy
    }

    /* =======================
                STRUCTS
    ======================= */
    struct TestSession {
        uint256 sessionId;
        address robotAddress;
        string title;
        uint256 startTime;
        uint256 endTime;
        uint256 testDuration; // Thời gian làm bài (seconds)
        TestStatus status;
        address tester;
        bool isActive;
        uint256 createdAt;
        uint256 lastModified;
        // Test results (Backend tổng hợp)
        uint256 totalQuestions; // Tổng số câu hỏi
        uint256 correctAnswers; // Số câu đúng (câu đạt ≥ 7 điểm)
        uint256 averageScore; // Điểm trung bình × 100 (vd: 820 = 8.2 điểm)
        uint256 passRate; // Tỷ lệ thành công × 100 (vd: 8667 = 86.67%)
        // Test data
        string[] testFileKeys; // Danh sách file key đề thi
        string resultKey; // File key kết quả chi tiết
    }

    struct TestFile {
        string fileKey;
        string fileName;
        uint256 uploadedAt;
    }

    /* =======================
                STORAGE
    ======================= */
    IRobotRegistry public robotRegistry;

    // robotAddress => test sessions
    mapping(address => TestSession[]) private robotSessions;

    // sessionId => test files
    mapping(uint256 => TestFile[]) private sessionFiles;

    // sessionId => robotAddress
    mapping(uint256 => address) private sessionToRobot;
    mapping(uint256 => uint256) private sessionIndexById;

    mapping(address => bool) public hasActiveSession;
    mapping(address => uint256) public activeSessionIndex;

    uint256 private sessionCounter;

    // Minimum score to pass (5.0 out of 10 = 500 when multiplied by 100)
    uint256 public constant PASSING_SCORE = 500; // 5.0 điểm

    /* =======================
                EVENTS
    ======================= */
    event TestSessionStarted(
        uint256 indexed sessionId,
        address indexed robotAddress,
        string title
    );

    event TestFileAdded(
        uint256 indexed sessionId,
        string fileKey,
        string fileName
    );

    event TestFileRemoved(
        uint256 indexed sessionId,
        uint256 fileIndex,
        string fileKey
    );

    event TestResultSubmitted(
        uint256 indexed sessionId,
        address indexed robotAddress,
        uint256 totalQuestions,
        uint256 correctAnswers,
        uint256 averageScore,
        uint256 passRate,
        TestStatus status
    );

    event TestSessionEnded(
        uint256 indexed sessionId,
        address indexed robotAddress,
        TestStatus finalStatus
    );

    event TestSessionCancelled(
        uint256 indexed sessionId,
        address indexed robotAddress
    );

    event SessionToggled(uint256 indexed sessionId, bool isActive);

    function initialize(
        address _staffContract,
        address _robotRegistry
    ) public initializer {
        require(_robotRegistry != address(0), "Invalid registry");

        __Ownable_init(msg.sender);
        // __UUPSUpgradeable_init();
        __RobotStaffUpgradeable_init(_staffContract);

        robotRegistry = IRobotRegistry(_robotRegistry);
    }
    // function _authorizeUpgrade(
    //     address newImplemation
    // ) internal override onlyOwner {}

    /* =======================
                MODIFIERS
        ======================= */
    modifier robotExists(address robotAddress) {
        require(
            robotRegistry.getRobotByAddress(robotAddress).robotAddress !=
                address(0),
            "Robot not exists"
        );
        _;
    }

    modifier onlyActiveSession(address robotAddress) {
        require(hasActiveSession[robotAddress], "No active session");
        _;
    }

    /* =======================
            SESSION MANAGEMENT
    ======================= */

    function startTestSession(
        address robotAddress,
        string memory title
    )
        external
        robotExists(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
        returns (uint256)
    {
        require(!hasActiveSession[robotAddress], "Active session exists");
        require(bytes(title).length > 0, "Empty title");

        sessionCounter++;

        robotSessions[robotAddress].push(
            TestSession({
                sessionId: sessionCounter,
                robotAddress: robotAddress,
                title: title,
                startTime: block.timestamp,
                endTime: 0,
                testDuration: 0,
                status: TestStatus.ONGOING,
                tester: msg.sender,
                isActive: true,
                createdAt: block.timestamp,
                lastModified: block.timestamp,
                totalQuestions: 0,
                correctAnswers: 0,
                averageScore: 0,
                passRate: 0,
                testFileKeys: new string[](0),
                resultKey: ""
            })
        );

        hasActiveSession[robotAddress] = true;
        activeSessionIndex[robotAddress] =
            robotSessions[robotAddress].length -
            1;
        sessionToRobot[sessionCounter] = robotAddress;
        sessionIndexById[sessionCounter] = robotSessions[robotAddress].length;

        emit TestSessionStarted(sessionCounter, robotAddress, title);
        return sessionCounter;
    }

    function addTestFile(
        uint256 sessionId,
        string memory fileKey,
        string memory fileName
    ) external onlyMerchantOwner onlyManager onlyStaff {
        address robotAddress = sessionToRobot[sessionId];
        require(robotAddress != address(0), "Session not found");
        require(bytes(fileKey).length > 0, "Empty file key");
        require(bytes(fileName).length > 0, "Empty file name");

        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;
        require(
            sessionIndex < robotSessions[robotAddress].length,
            "Session index out of range"
        );

        TestSession storage session = robotSessions[robotAddress][sessionIndex];
        require(session.status == TestStatus.ONGOING, "Session not ongoing");

        sessionFiles[sessionId].push(
            TestFile({
                fileKey: fileKey,
                fileName: fileName,
                uploadedAt: block.timestamp
            })
        );

        session.testFileKeys.push(fileKey);
        session.lastModified = block.timestamp;

        emit TestFileAdded(sessionId, fileKey, fileName);
    }

    function removeTestFile(
        uint256 sessionId,
        uint256 fileIndex
    ) external onlyMerchantOwner onlyManager onlyStaff {
        address robotAddress = sessionToRobot[sessionId];
        require(robotAddress != address(0), "Session not found");

        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;
        require(
            sessionIndex < robotSessions[robotAddress].length,
            "Session index out of range"
        );

        TestSession storage session = robotSessions[robotAddress][sessionIndex];
        require(session.status == TestStatus.ONGOING, "Session not ongoing");
        require(fileIndex < sessionFiles[sessionId].length, "Invalid index");

        TestFile memory removed = sessionFiles[sessionId][fileIndex];

        uint256 last = sessionFiles[sessionId].length - 1;
        if (fileIndex != last) {
            sessionFiles[sessionId][fileIndex] = sessionFiles[sessionId][last];
            session.testFileKeys[fileIndex] = session.testFileKeys[last];
        }
        sessionFiles[sessionId].pop();
        session.testFileKeys.pop();

        session.lastModified = block.timestamp;

        emit TestFileRemoved(sessionId, fileIndex, removed.fileKey);
    }

    function submitTestResult(
        uint256 sessionId,
        uint256 totalQuestions,
        uint256 correctAnswers,
        uint256 averageScore,
        uint256 passRate,
        bool isPassed,
        string memory resultKey
    ) external onlyMerchantOwner onlyManager onlyStaff {
        address robotAddress = sessionToRobot[sessionId];
        require(robotAddress != address(0), "Session not found");

        bool found = false;
        for (uint256 i = 0; i < robotSessions[robotAddress].length; i++) {
            if (robotSessions[robotAddress][i].sessionId == sessionId) {
                TestSession storage session = robotSessions[robotAddress][i];

                require(
                    session.status == TestStatus.ONGOING,
                    "Session not ongoing"
                );
                require(totalQuestions > 0, "Invalid total questions");
                require(
                    correctAnswers <= totalQuestions,
                    "Invalid correct answers"
                );
                require(averageScore <= 1000, "Invalid average score");
                require(passRate <= 10000, "Invalid pass rate");

                session.totalQuestions = totalQuestions;
                session.correctAnswers = correctAnswers;
                session.averageScore = averageScore;
                session.passRate = passRate;
                session.resultKey = resultKey;
                session.lastModified = block.timestamp;

                session.status = isPassed
                    ? TestStatus.PASSED
                    : TestStatus.FAILED;

                emit TestResultSubmitted(
                    sessionId,
                    robotAddress,
                    totalQuestions,
                    correctAnswers,
                    averageScore,
                    passRate,
                    session.status
                );
                found = true;
                break;
            }
        }

        require(found, "Session not found");
    }

    function endTestSession(
        address robotAddress
    )
        external
        robotExists(robotAddress)
        onlyActiveSession(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
    {
        TestSession storage session = robotSessions[robotAddress][
            activeSessionIndex[robotAddress]
        ];

        require(
            session.status == TestStatus.PASSED ||
                session.status == TestStatus.FAILED,
            "Test result not submitted"
        );

        session.endTime = block.timestamp;
        session.testDuration = session.endTime - session.startTime;
        session.isActive = false;

        hasActiveSession[robotAddress] = false;
        activeSessionIndex[robotAddress] = 0;

        emit TestSessionEnded(session.sessionId, robotAddress, session.status);
    }

    function cancelTestSession(
        address robotAddress
    )
        external
        robotExists(robotAddress)
        onlyActiveSession(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
    {
        TestSession storage session = robotSessions[robotAddress][
            activeSessionIndex[robotAddress]
        ];

        session.endTime = block.timestamp;
        session.status = TestStatus.CANCELLED;
        session.isActive = false;

        hasActiveSession[robotAddress] = false;
        activeSessionIndex[robotAddress] = 0;

        emit TestSessionCancelled(session.sessionId, robotAddress);
    }

    /* =======================
            UI MANAGEMENT
    ======================= */

    function toggleSessionActive(
        address robotAddress,
        uint256 sessionId
    ) external robotExists(robotAddress) onlyMerchantOwner {
        require(sessionToRobot[sessionId] == robotAddress, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;

        TestSession storage session = robotSessions[robotAddress][sessionIndex];
        session.isActive = !session.isActive;
        session.lastModified = block.timestamp;

        emit SessionToggled(session.sessionId, session.isActive);
    }

    function updateSessionInfo(
        address robotAddress,
        uint256 sessionId,
        string memory newTitle
    ) external robotExists(robotAddress) {
        require(sessionToRobot[sessionId] == robotAddress, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;

        TestSession storage session = robotSessions[robotAddress][sessionIndex];
        session.title = newTitle;
        session.lastModified = block.timestamp;
    }

    function deleteSession(
        address robotAddress,
        uint256 sessionId
    )
        external
        robotExists(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
    {
        require(sessionToRobot[sessionId] == robotAddress, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;

        TestSession storage session = robotSessions[robotAddress][sessionIndex];

        delete sessionFiles[session.sessionId];
        delete sessionToRobot[sessionId];
        delete sessionIndexById[sessionId];

        uint256 last = robotSessions[robotAddress].length - 1;
        if (sessionIndex != last) {
            robotSessions[robotAddress][sessionIndex] = robotSessions[
                robotAddress
            ][last];
            uint256 movedSessionId = robotSessions[robotAddress][sessionIndex]
                .sessionId;
            sessionIndexById[movedSessionId] = sessionIndex + 1;
            if (
                hasActiveSession[robotAddress] &&
                activeSessionIndex[robotAddress] == last
            ) {
                activeSessionIndex[robotAddress] = sessionIndex;
            }
        }
        robotSessions[robotAddress].pop();

        if (
            hasActiveSession[robotAddress] &&
            activeSessionIndex[robotAddress] == sessionIndex
        ) {
            hasActiveSession[robotAddress] = false;
            activeSessionIndex[robotAddress] = 0;
        }
    }

    /* =======================
                GETTERS
    ======================= */

    function getSessionFiles(
        uint256 sessionId
    ) external view returns (TestFile[] memory) {
        return sessionFiles[sessionId];
    }

    function getSessionsByRobot(
        address robotAddress
    ) external view returns (TestSession[] memory) {
        TestSession[] storage all = robotSessions[robotAddress];
        uint256 total = all.length;

        TestSession[] memory result = new TestSession[](total);

        for (uint256 i = 0; i < total; i++) {
            result[i] = all[total - 1 - i];
        }

        return result;
    }

    function getCurrentSession(
        address robotAddress
    ) external view returns (TestSession memory) {
        require(hasActiveSession[robotAddress], "No active session");
        return robotSessions[robotAddress][activeSessionIndex[robotAddress]];
    }

    function getSessionById(
        address robotAddress,
        uint256 sessionId
    ) external view returns (TestSession memory) {
        require(sessionToRobot[sessionId] == robotAddress, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;
        return robotSessions[robotAddress][sessionIndex];
    }

    function getSessionCount(
        address robotAddress
    ) external view returns (uint256) {
        return robotSessions[robotAddress].length;
    }

    function getPassedSessions(
        address robotAddress
    ) external view returns (TestSession[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < robotSessions[robotAddress].length; i++) {
            if (robotSessions[robotAddress][i].status == TestStatus.PASSED) {
                count++;
            }
        }

        TestSession[] memory result = new TestSession[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < robotSessions[robotAddress].length; i++) {
            if (robotSessions[robotAddress][i].status == TestStatus.PASSED) {
                result[index] = robotSessions[robotAddress][i];
                index++;
            }
        }
        return result;
    }

    function getFailedSessions(
        address robotAddress
    ) external view returns (TestSession[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < robotSessions[robotAddress].length; i++) {
            if (robotSessions[robotAddress][i].status == TestStatus.FAILED) {
                count++;
            }
        }

        TestSession[] memory result = new TestSession[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < robotSessions[robotAddress].length; i++) {
            if (robotSessions[robotAddress][i].status == TestStatus.FAILED) {
                result[index] = robotSessions[robotAddress][i];
                index++;
            }
        }
        return result;
    }

    function getTestStats(
        address robotAddress
    )
        external
        view
        returns (
            uint256 totalTests,
            uint256 passedTests,
            uint256 failedTests,
            uint256 overallAverageScore,
            uint256 overallPassRate
        )
    {
        totalTests = robotSessions[robotAddress].length;

        uint256 totalScore = 0;
        uint256 totalPassRate = 0;
        uint256 countWithScore = 0;

        for (uint256 i = 0; i < totalTests; i++) {
            if (robotSessions[robotAddress][i].status == TestStatus.PASSED) {
                passedTests++;
            } else if (
                robotSessions[robotAddress][i].status == TestStatus.FAILED
            ) {
                failedTests++;
            }

            if (robotSessions[robotAddress][i].averageScore > 0) {
                totalScore += robotSessions[robotAddress][i].averageScore;
                totalPassRate += robotSessions[robotAddress][i].passRate;
                countWithScore++;
            }
        }

        overallAverageScore = countWithScore > 0
            ? totalScore / countWithScore
            : 0;
        overallPassRate = countWithScore > 0
            ? totalPassRate / countWithScore
            : 0;
    }

    function getSessionsPaginated(
        address robotAddress,
        uint256 page,
        uint256 limit
    ) external view returns (TestSession[] memory sessions, uint256 total) {
        require(limit > 0, "Limit must be > 0");

        TestSession[] storage all = robotSessions[robotAddress];
        uint256 validCount = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].status != TestStatus.CANCELLED) {
                validCount++;
            }
        }

        total = validCount;

        if (total == 0) {
            return (new TestSession[](0), 0);
        }

        uint256 start = page * limit;
        if (start >= total) {
            return (new TestSession[](0), total);
        }

        uint256 end = start + limit;
        if (end > total) {
            end = total;
        }

        TestSession[] memory validSessions = new TestSession[](total);
        uint256 validIndex = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[all.length - 1 - i].status != TestStatus.CANCELLED) {
                validSessions[validIndex] = all[all.length - 1 - i];
                validIndex++;
            }
        }

        uint256 size = end - start;
        sessions = new TestSession[](size);
        for (uint256 i = 0; i < size; i++) {
            sessions[i] = validSessions[start + i];
        }

        return (sessions, total);
    }
    uint256[50] private __gap;
}
