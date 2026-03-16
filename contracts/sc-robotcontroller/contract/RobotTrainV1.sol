// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRobotRegistry.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RobotStaffUpgradeable} from "./RobotStaffUpgradeable.sol";

/**
 * @title RobotObservationTraining
 * @dev Contract quản lý phiên huấn luyện qua quan sát
 *
 * FLOW:
 * 1. FE: User click "Bắt đầu" → BE gọi startObservationSession()
 * 2. BE: Gọi recordObservation() (chỉ 1 lần duy nhất cho mỗi session)
 * 3. BE: Tiến hành training (off-chain, AI processing)
 * 4. BE: Training xong → Báo FE
 * 5. FE: User click "Hoàn thành" → BE gọi endObservationSession()
 */
contract RobotObservationTraining is
    OwnableUpgradeable,
    // UUPSUpgradeable,
    RobotStaffUpgradeable
{
    /* =======================
            ENUMS
    ======================= */
    enum TrainingStatus {
        ONGOING, // Đang training
        COMPLETED, // Đã hoàn thành
        CANCELLED, // Đã hủy
        FAILED // Training thất bại
    }

    /* =======================
            STRUCTS
    ======================= */
    struct ObservationSession {
        uint256 sessionId;
        address robotAddress;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 trainingDuration; // Thời gian training (seconds)
        TrainingStatus status;
        address trainer;
        bool isActive; // Toggle on/off trong UI
        uint256 createdAt;
        uint256 lastModified;
        bool isDeleted;
        // Training info
        string cameraSource; // Camera ID
        string modelVersion; // Version model AI đã train
        uint256 accuracy; // Độ chính xác (0-100)
        string trainingResultUrl; // URL kết quả training (logs, metrics...)
    }

    struct ObservationRecord {
        uint256 sessionId;
        string dataUrl; // URL dữ liệu quan sát (video/images)
        uint256 recordedAt;
        uint256 dataSize; // Kích thước data (bytes)
        string dataType; // "video", "images", "mixed"
        string notes; // Ghi chú từ backend
    }

    /* =======================
            STORAGE
    ======================= */
    IRobotRegistry public robotRegistry;

    // robotAddress => observation sessions
    mapping(address => ObservationSession[]) private robotSessions;

    // sessionId => observation record (CHỈ 1 record cho mỗi session)
    mapping(uint256 => ObservationRecord) private sessionData;

    // sessionId => robotAddress
    mapping(uint256 => address) private sessionToRobot;
    mapping(uint256 => uint256) private sessionIndexById;

    mapping(address => bool) public hasActiveSession;
    mapping(address => uint256) public activeSessionIndex;

    uint256 private sessionCounter;

    /* =======================
            EVENTS
    ======================= */
    event ObservationSessionStarted(
        uint256 indexed sessionId,
        address indexed robotAddress,
        string cameraSource
    );

    event ObservationRecorded(
        uint256 indexed sessionId,
        address indexed robotAddress,
        string dataUrl
    );

    event TrainingCompleted(
        uint256 indexed sessionId,
        address indexed robotAddress,
        uint256 accuracy
    );

    event TrainingFailed(
        uint256 indexed sessionId,
        address indexed robotAddress,
        string reason
    );

    event ObservationSessionEnded(
        uint256 indexed sessionId,
        address indexed robotAddress,
        TrainingStatus finalStatus
    );

    event ObservationSessionCancelled(
        uint256 indexed sessionId,
        address indexed robotAddress
    );

    event SessionToggled(uint256 indexed sessionId, bool isActive);

    /* =======================
            CONSTRUCTOR
    ======================= */
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

    function startObservationSession(
        address robotAddress,
        string memory title,
        string memory description,
        string memory cameraSource
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
            ObservationSession({
                sessionId: sessionCounter,
                robotAddress: robotAddress,
                title: title,
                description: description,
                startTime: block.timestamp,
                endTime: 0,
                trainingDuration: 0,
                status: TrainingStatus.ONGOING,
                trainer: msg.sender,
                isActive: true,
                createdAt: block.timestamp,
                lastModified: block.timestamp,
                cameraSource: cameraSource,
                modelVersion: "",
                accuracy: 0,
                isDeleted: false,
                trainingResultUrl: ""
            })
        );

        hasActiveSession[robotAddress] = true;
        activeSessionIndex[robotAddress] =
            robotSessions[robotAddress].length -
            1;

        sessionToRobot[sessionCounter] = robotAddress;
        sessionIndexById[sessionCounter] = robotSessions[robotAddress].length;

        emit ObservationSessionStarted(
            sessionCounter,
            robotAddress,
            cameraSource
        );
        return sessionCounter;
    }

    function recordObservation(
        uint256 sessionId,
        string memory dataUrl,
        uint256 dataSize,
        string memory dataType,
        string memory notes
    ) external {
        address robotAddress = sessionToRobot[sessionId];
        require(robotAddress != address(0), "Session not found");
        require(
            robotRegistry.getRobotByAddress(robotAddress).robotAddress !=
                address(0),
            "Robot not exists"
        );

        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found in robot");
        uint256 sessionIndex = sessionIndexPlus1 - 1;
        require(
            sessionIndex < robotSessions[robotAddress].length,
            "Session index out of range"
        );

        ObservationSession storage session = robotSessions[robotAddress][
            sessionIndex
        ];
        require(
            session.status == TrainingStatus.ONGOING,
            "Session not ongoing"
        );
        require(
            bytes(sessionData[sessionId].dataUrl).length == 0,
            "Data already recorded"
        );

        sessionData[sessionId] = ObservationRecord({
            sessionId: sessionId,
            dataUrl: dataUrl,
            recordedAt: block.timestamp,
            dataSize: dataSize,
            dataType: dataType,
            notes: notes
        });

        emit ObservationRecorded(sessionId, robotAddress, dataUrl);
    }

    function updateTrainingResult(
        address robotAddress,
        uint256 sessionId,
        string memory modelVersion,
        uint256 accuracy,
        string memory resultUrl
    ) external robotExists(robotAddress) onlyActiveSession(robotAddress) {
        require(accuracy <= 100, "Invalid accuracy");

        ObservationSession storage session = robotSessions[robotAddress][
            activeSessionIndex[robotAddress]
        ];

        require(session.sessionId == sessionId, "Invalid session");

        session.modelVersion = modelVersion;
        session.accuracy = accuracy;
        session.trainingResultUrl = resultUrl;
        session.lastModified = block.timestamp;

        emit TrainingCompleted(sessionId, robotAddress, accuracy);
    }

    function endObservationSession(
        address robotAddress
    )
        external
        robotExists(robotAddress)
        onlyActiveSession(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
    {
        ObservationSession storage session = robotSessions[robotAddress][
            activeSessionIndex[robotAddress]
        ];

        session.endTime = block.timestamp;
        session.trainingDuration = session.endTime - session.startTime;
        session.status = TrainingStatus.COMPLETED;
        session.isActive = false;

        hasActiveSession[robotAddress] = false;
        activeSessionIndex[robotAddress] = 0;

        emit ObservationSessionEnded(
            session.sessionId,
            robotAddress,
            TrainingStatus.COMPLETED
        );
    }

    function markTrainingFailed(
        address robotAddress,
        string memory reason
    ) external robotExists(robotAddress) onlyActiveSession(robotAddress) {
        ObservationSession storage session = robotSessions[robotAddress][
            activeSessionIndex[robotAddress]
        ];

        session.endTime = block.timestamp;
        session.trainingDuration = session.endTime - session.startTime;
        session.status = TrainingStatus.FAILED;
        session.isActive = false;

        hasActiveSession[robotAddress] = false;
        activeSessionIndex[robotAddress] = 0;

        emit TrainingFailed(session.sessionId, robotAddress, reason);
    }

    function cancelObservationSession(
        address robotAddress
    )
        external
        robotExists(robotAddress)
        onlyActiveSession(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
    {
        ObservationSession storage session = robotSessions[robotAddress][
            activeSessionIndex[robotAddress]
        ];

        session.endTime = block.timestamp;
        session.status = TrainingStatus.CANCELLED;
        session.isActive = false;

        hasActiveSession[robotAddress] = false;
        activeSessionIndex[robotAddress] = 0;

        emit ObservationSessionCancelled(session.sessionId, robotAddress);
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

        ObservationSession storage session = robotSessions[robotAddress][
            sessionIndex
        ];
        session.isActive = !session.isActive;
        session.lastModified = block.timestamp;

        emit SessionToggled(session.sessionId, session.isActive);
    }

    function updateSessionInfo(
        address robotAddress,
        uint256 sessionId,
        string memory newTitle,
        string memory newDescription
    ) external robotExists(robotAddress) {
        require(sessionToRobot[sessionId] == robotAddress, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;

        ObservationSession storage session = robotSessions[robotAddress][
            sessionIndex
        ];
        session.title = newTitle;
        session.description = newDescription;
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

        ObservationSession storage session = robotSessions[robotAddress][
            sessionIndex
        ];

        require(!session.isDeleted, "Already deleted");

        session.isDeleted = true;
        session.isActive = false;
        session.lastModified = block.timestamp;

        if (
            hasActiveSession[robotAddress] &&
            activeSessionIndex[robotAddress] == sessionIndex
        ) {
            hasActiveSession[robotAddress] = false;
            activeSessionIndex[robotAddress] = 0;
        }

        delete sessionData[session.sessionId];
    }

    /* =======================
            GETTERS
    ======================= */

    function getSessionData(
        uint256 sessionId
    ) external view returns (ObservationRecord memory) {
        return sessionData[sessionId];
    }

    function getSessionsByRobot(
        address robotAddress
    ) external view returns (ObservationSession[] memory) {
        ObservationSession[] storage all = robotSessions[robotAddress];

        uint256 count = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (!all[i].isDeleted) count++;
        }

        ObservationSession[] memory result = new ObservationSession[](count);

        uint256 idx = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (!all[i].isDeleted) {
                result[idx++] = all[i];
            }
        }

        return result;
    }

    function getCurrentSession(
        address robotAddress
    ) external view returns (ObservationSession memory) {
        require(hasActiveSession[robotAddress], "No active session");
        return robotSessions[robotAddress][activeSessionIndex[robotAddress]];
    }

    function getSessionById(
        address robotAddress,
        uint256 sessionId
    ) external view returns (ObservationSession memory) {
        require(sessionToRobot[sessionId] == robotAddress, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;
        return robotSessions[robotAddress][sessionIndex];
    }

    function isTraining(address robotAddress) external view returns (bool) {
        return hasActiveSession[robotAddress];
    }

    function getSessionCount(
        address robotAddress
    ) external view returns (uint256) {
        return robotSessions[robotAddress].length;
    }

    function getSessionsPaginated(
        address robotAddress,
        TrainingStatus status,
        uint256 page,
        uint256 limit
    )
        external
        view
        returns (ObservationSession[] memory sessions, uint256 total)
    {
        require(limit > 0, "Limit must be > 0");

        ObservationSession[] storage all = robotSessions[robotAddress];
        uint256 len = all.length;

        total = 0;
        for (uint256 i = 0; i < len; i++) {
            if (all[i].status == status && !all[i].isDeleted) {
                total++;
            }
        }

        if (total == 0) {
            return (new ObservationSession[](0), 0);
        }

        uint256 start = page * limit;
        if (start >= total) {
            return (new ObservationSession[](0), total);
        }

        uint256 end = start + limit;
        if (end > total) end = total;

        uint256 size = end - start;
        sessions = new ObservationSession[](size);

        uint256 matchedIndex = 0;
        uint256 resultIndex = 0;

        for (uint256 i = len; i > 0 && resultIndex < size; i--) {
            ObservationSession storage s = all[i - 1];
            if (s.status == status && !s.isDeleted) {
                if (matchedIndex >= start && matchedIndex < end) {
                    sessions[resultIndex] = s;
                    resultIndex++;
                }
                matchedIndex++;
            }
        }

        return (sessions, total);
    }

    function getCompletedSessions(
        address robotAddress
    ) external view returns (ObservationSession[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < robotSessions[robotAddress].length; i++) {
            if (
                robotSessions[robotAddress][i].status ==
                TrainingStatus.COMPLETED &&
                !robotSessions[robotAddress][i].isDeleted
            ) {
                count++;
            }
        }

        ObservationSession[] memory result = new ObservationSession[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < robotSessions[robotAddress].length; i++) {
            if (
                robotSessions[robotAddress][i].status ==
                TrainingStatus.COMPLETED &&
                !robotSessions[robotAddress][i].isDeleted
            ) {
                result[index++] = robotSessions[robotAddress][i];
            }
        }
        return result;
    }

    function getFailedSessions(
        address robotAddress
    ) external view returns (ObservationSession[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < robotSessions[robotAddress].length; i++) {
            if (
                robotSessions[robotAddress][i].status ==
                TrainingStatus.FAILED &&
                !robotSessions[robotAddress][i].isDeleted
            ) {
                count++;
            }
        }

        ObservationSession[] memory result = new ObservationSession[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < robotSessions[robotAddress].length; i++) {
            if (
                robotSessions[robotAddress][i].status ==
                TrainingStatus.FAILED &&
                !robotSessions[robotAddress][i].isDeleted
            ) {
                result[index++] = robotSessions[robotAddress][i];
            }
        }
        return result;
    }

    function getTrainingStats(
        address robotAddress
    )
        external
        view
        returns (
            uint256 totalSessions,
            uint256 completedSessions,
            uint256 failedSessions,
            uint256 averageAccuracy
        )
    {
        totalSessions = 0;
        completedSessions = 0;
        failedSessions = 0;
        uint256 totalAccuracy = 0;
        uint256 countWithAccuracy = 0;

        for (uint256 i = 0; i < robotSessions[robotAddress].length; i++) {
            ObservationSession storage s = robotSessions[robotAddress][i];
            if (s.isDeleted) continue;

            totalSessions++;

            if (s.status == TrainingStatus.COMPLETED) {
                completedSessions++;
                if (s.accuracy > 0) {
                    totalAccuracy += s.accuracy;
                    countWithAccuracy++;
                }
            } else if (s.status == TrainingStatus.FAILED) {
                failedSessions++;
            }
        }

        averageAccuracy = countWithAccuracy > 0
            ? totalAccuracy / countWithAccuracy
            : 0;
    }
    uint256[50] private __gap;
}
