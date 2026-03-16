// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IRobotRegistryV2.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title RobotTesting - Optimized Version
 * @dev Contract quan ly kiem thu Robot (Testing/Exam system)
 */
contract RobotTestingV2 is UUPSUpgradeable {
    /* =======================
                ENUMS
        ======================= */
    enum TestStatus {
        ONGOING, // Dang test
        PASSED, // Dat (>50%)
        FAILED, // Khong dat (<=50%)
        CANCELLED // Da huy
    }

    /* =======================
                STRUCTS
        ======================= */
    struct TestSession {
        uint256 sessionId;
        uint256 robotId;
        string title;
        uint256 startTime;
        uint256 endTime;
        uint256 testDuration; // Thoi gian lam bai (seconds)
        TestStatus status;
        address tester;
        bool isActive;
        uint256 createdAt;
        uint256 lastModified;
        uint256 totalQuestions; // Tong so cau hoi
        uint256 correctAnswers; // So cau dung
        uint256 averageScore; // Diem trung binh * 100
        uint256 passRate; // Ty le thanh cong * 100
        string[] testFileUrls; // Danh sach file de thi
        string resultUrl; // URL ket qua chi tiet
    }

    struct TestFile {
        string fileUrl;
        string fileName;
        uint256 uploadedAt;
    }

    /* =======================
                STORAGE
        ======================= */
    IRobotRegistryV2 public robotRegistry;

    mapping(uint256 => TestSession[]) private robotSessions;
    mapping(uint256 => TestFile[]) private sessionFiles;
    mapping(uint256 => uint256) private sessionToRobot;
    mapping(uint256 => uint256) private sessionIndexById;

    mapping(uint256 => bool) public hasActiveSession;
    mapping(uint256 => uint256) public activeSessionIndex;

    uint256 private sessionCounter;
    address public owner;

    uint256 public constant PASSING_SCORE = 500; // 5.0 diem

    /* =======================
                EVENTS
        ======================= */
    event TestSessionStarted(
        uint256 indexed sessionId,
        uint256 indexed robotId,
        string title
    );

    event TestFileAdded(
        uint256 indexed sessionId,
        string fileUrl,
        string fileName
    );

    event TestFileRemoved(
        uint256 indexed sessionId,
        uint256 fileIndex,
        string fileUrl
    );

    event TestResultSubmitted(
        uint256 indexed sessionId,
        uint256 indexed robotId,
        uint256 totalQuestions,
        uint256 correctAnswers,
        uint256 averageScore,
        uint256 passRate,
        TestStatus status
    );

    event TestSessionEnded(
        uint256 indexed sessionId,
        uint256 indexed robotId,
        TestStatus finalStatus
    );

    event TestSessionCancelled(
        uint256 indexed sessionId,
        uint256 indexed robotId
    );

    event SessionToggled(uint256 indexed sessionId, bool isActive);

    /* =======================
                INITIALIZER
        ======================= */
    function initialize(address _robotRegistry) external initializer {
        __UUPSUpgradeable_init();
        require(_robotRegistry != address(0), "Invalid registry");
        robotRegistry = IRobotRegistryV2(_robotRegistry);
        owner = msg.sender;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
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

    modifier onlyActiveSession(uint256 robotId) {
        require(hasActiveSession[robotId], "No active session");
        _;
    }

    /* =======================
            SESSION MANAGEMENT
        ======================= */

    function startTestSession(
        uint256 robotId,
        string memory title
    ) external robotExists(robotId) returns (uint256) {
        require(!hasActiveSession[robotId], "Active session exists");
        require(bytes(title).length > 0, "Empty title");

        sessionCounter++;

        robotSessions[robotId].push(
            TestSession({
                sessionId: sessionCounter,
                robotId: robotId,
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
                testFileUrls: new string[](0),
                resultUrl: ""
            })
        );

        hasActiveSession[robotId] = true;
        activeSessionIndex[robotId] = robotSessions[robotId].length - 1;
        sessionToRobot[sessionCounter] = robotId;
        sessionIndexById[sessionCounter] = robotSessions[robotId].length;

        emit TestSessionStarted(sessionCounter, robotId, title);
        return sessionCounter;
    }

    function addTestFile(
        uint256 sessionId,
        string memory fileUrl,
        string memory fileName
    ) external {
        uint256 robotId = sessionToRobot[sessionId];
        require(robotId != 0, "Session not found");
        require(bytes(fileUrl).length > 0, "Empty file URL");
        require(bytes(fileName).length > 0, "Empty file name");

        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;
        require(
            sessionIndex < robotSessions[robotId].length,
            "Session index out of range"
        );

        TestSession storage session = robotSessions[robotId][sessionIndex];
        require(session.status == TestStatus.ONGOING, "Session not ongoing");

        sessionFiles[sessionId].push(
            TestFile({
                fileUrl: fileUrl,
                fileName: fileName,
                uploadedAt: block.timestamp
            })
        );

        session.testFileUrls.push(fileUrl);
        session.lastModified = block.timestamp;

        emit TestFileAdded(sessionId, fileUrl, fileName);
    }

    function removeTestFile(uint256 sessionId, uint256 fileIndex) external {
        uint256 robotId = sessionToRobot[sessionId];
        require(robotId != 0, "Session not found");

        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;
        require(
            sessionIndex < robotSessions[robotId].length,
            "Session index out of range"
        );

        TestSession storage session = robotSessions[robotId][sessionIndex];
        require(session.status == TestStatus.ONGOING, "Session not ongoing");
        require(fileIndex < sessionFiles[sessionId].length, "Invalid index");

        TestFile memory removed = sessionFiles[sessionId][fileIndex];

        uint256 last = sessionFiles[sessionId].length - 1;
        if (fileIndex != last) {
            sessionFiles[sessionId][fileIndex] = sessionFiles[sessionId][last];
            session.testFileUrls[fileIndex] = session.testFileUrls[last];
        }
        sessionFiles[sessionId].pop();
        session.testFileUrls.pop();

        session.lastModified = block.timestamp;

        emit TestFileRemoved(sessionId, fileIndex, removed.fileUrl);
    }

    function submitTestResult(
        uint256 sessionId,
        uint256 totalQuestions,
        uint256 correctAnswers,
        uint256 averageScore,
        uint256 passRate,
        bool isPassed,
        string memory resultUrl
    ) external {
        uint256 robotId = sessionToRobot[sessionId];
        require(robotId != 0, "Session not found");

        bool found = false;
        for (uint256 i = 0; i < robotSessions[robotId].length; i++) {
            if (robotSessions[robotId][i].sessionId == sessionId) {
                TestSession storage session = robotSessions[robotId][i];

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
                session.resultUrl = resultUrl;
                session.lastModified = block.timestamp;

                session.status = isPassed
                    ? TestStatus.PASSED
                    : TestStatus.FAILED;

                emit TestResultSubmitted(
                    sessionId,
                    robotId,
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
        uint256 robotId
    ) external robotExists(robotId) onlyActiveSession(robotId) {
        TestSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];

        require(
            session.status == TestStatus.PASSED ||
                session.status == TestStatus.FAILED,
            "Test result not submitted"
        );

        session.endTime = block.timestamp;
        session.testDuration = session.endTime - session.startTime;
        session.isActive = false;

        hasActiveSession[robotId] = false;
        activeSessionIndex[robotId] = 0;

        emit TestSessionEnded(session.sessionId, robotId, session.status);
    }

    function cancelTestSession(
        uint256 robotId
    ) external robotExists(robotId) onlyActiveSession(robotId) {
        TestSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];

        session.endTime = block.timestamp;
        session.status = TestStatus.CANCELLED;
        session.isActive = false;

        hasActiveSession[robotId] = false;
        activeSessionIndex[robotId] = 0;

        emit TestSessionCancelled(session.sessionId, robotId);
    }

    /* =======================
            UI MANAGEMENT
    ======================= */

    function toggleSessionActive(
        uint256 robotId,
        uint256 sessionId
    ) external robotExists(robotId) {
        require(sessionToRobot[sessionId] == robotId, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;

        TestSession storage session = robotSessions[robotId][sessionIndex];
        session.isActive = !session.isActive;
        session.lastModified = block.timestamp;

        emit SessionToggled(session.sessionId, session.isActive);
    }

    function updateSessionInfo(
        uint256 robotId,
        uint256 sessionId,
        string memory newTitle
    ) external robotExists(robotId) {
        require(sessionToRobot[sessionId] == robotId, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;

        TestSession storage session = robotSessions[robotId][sessionIndex];
        session.title = newTitle;
        session.lastModified = block.timestamp;
    }

    function deleteSession(
        uint256 robotId,
        uint256 sessionId
    ) external robotExists(robotId) {
        require(sessionToRobot[sessionId] == robotId, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;

        TestSession storage session = robotSessions[robotId][sessionIndex];

        delete sessionFiles[session.sessionId];
        delete sessionToRobot[sessionId];
        delete sessionIndexById[sessionId];

        uint256 last = robotSessions[robotId].length - 1;
        if (sessionIndex != last) {
            robotSessions[robotId][sessionIndex] = robotSessions[robotId][last];
            uint256 movedSessionId = robotSessions[robotId][sessionIndex]
                .sessionId;
            sessionIndexById[movedSessionId] = sessionIndex + 1;
            if (
                hasActiveSession[robotId] &&
                activeSessionIndex[robotId] == last
            ) {
                activeSessionIndex[robotId] = sessionIndex;
            }
        }
        robotSessions[robotId].pop();

        if (
            hasActiveSession[robotId] &&
            activeSessionIndex[robotId] == sessionIndex
        ) {
            hasActiveSession[robotId] = false;
            activeSessionIndex[robotId] = 0;
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
        uint256 robotId
    ) external view returns (TestSession[] memory) {
        TestSession[] storage all = robotSessions[robotId];
        uint256 total = all.length;

        TestSession[] memory result = new TestSession[](total);

        for (uint256 i = 0; i < total; i++) {
            result[i] = all[total - 1 - i];
        }

        return result;
    }

    function getCurrentSession(
        uint256 robotId
    ) external view returns (TestSession memory) {
        require(hasActiveSession[robotId], "No active session");
        return robotSessions[robotId][activeSessionIndex[robotId]];
    }

    function getSessionById(
        uint256 robotId,
        uint256 sessionId
    ) external view returns (TestSession memory) {
        require(sessionToRobot[sessionId] == robotId, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;
        return robotSessions[robotId][sessionIndex];
    }

    function getSessionCount(uint256 robotId) external view returns (uint256) {
        return robotSessions[robotId].length;
    }

    function getPassedSessions(
        uint256 robotId
    ) external view returns (TestSession[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < robotSessions[robotId].length; i++) {
            if (robotSessions[robotId][i].status == TestStatus.PASSED) {
                count++;
            }
        }

        TestSession[] memory result = new TestSession[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < robotSessions[robotId].length; i++) {
            if (robotSessions[robotId][i].status == TestStatus.PASSED) {
                result[index] = robotSessions[robotId][i];
                index++;
            }
        }
        return result;
    }

    function getFailedSessions(
        uint256 robotId
    ) external view returns (TestSession[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < robotSessions[robotId].length; i++) {
            if (robotSessions[robotId][i].status == TestStatus.FAILED) {
                count++;
            }
        }

        TestSession[] memory result = new TestSession[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < robotSessions[robotId].length; i++) {
            if (robotSessions[robotId][i].status == TestStatus.FAILED) {
                result[index] = robotSessions[robotId][i];
                index++;
            }
        }
        return result;
    }

    function getTestStats(
        uint256 robotId
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
        totalTests = robotSessions[robotId].length;

        uint256 totalScore = 0;
        uint256 totalPassRate = 0;
        uint256 countWithScore = 0;

        for (uint256 i = 0; i < totalTests; i++) {
            if (robotSessions[robotId][i].status == TestStatus.PASSED) {
                passedTests++;
            } else if (robotSessions[robotId][i].status == TestStatus.FAILED) {
                failedTests++;
            }

            if (robotSessions[robotId][i].averageScore > 0) {
                totalScore += robotSessions[robotId][i].averageScore;
                totalPassRate += robotSessions[robotId][i].passRate;
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
        uint256 robotId,
        uint256 page,
        uint256 limit
    ) external view returns (TestSession[] memory sessions, uint256 total) {
        require(limit > 0, "Limit must be > 0");
        require(page > 0, "Page must be > 0");

        TestSession[] storage all = robotSessions[robotId];
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

        uint256 start = (page - 1) * limit;
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
}
