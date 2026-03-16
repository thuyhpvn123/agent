// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IRobotRegistryV2.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RobotObservationTrainingV2 is UUPSUpgradeable {
    enum TrainingStatus {
        ONGOING,
        COMPLETED,
        CANCELLED,
        FAILED
    }

    struct ObservationSession {
        uint256 sessionId;
        uint256 robotId;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 trainingDuration;
        TrainingStatus status;
        address trainer;
        bool isActive;
        uint256 createdAt;
        uint256 lastModified;
        string cameraSource;
        string modelVersion;
        uint256 accuracy;
        string trainingResultUrl;
    }

    struct ObservationRecord {
        uint256 sessionId;
        string dataUrl;
        uint256 recordedAt;
        uint256 dataSize;
        string dataType;
        string notes;
    }

    IRobotRegistryV2 public robotRegistry;

    mapping(uint256 => ObservationSession[]) private robotSessions;
    mapping(uint256 => ObservationRecord) private sessionData;
    mapping(uint256 => uint256) private sessionToRobot;

    mapping(uint256 => bool) public hasActiveSession;
    mapping(uint256 => uint256) public activeSessionIndex;

    uint256 private sessionCounter;

    event ObservationSessionStarted(
        uint256 indexed sessionId,
        uint256 indexed robotId,
        string cameraSource
    );

    event ObservationRecorded(
        uint256 indexed sessionId,
        uint256 indexed robotId,
        string dataUrl
    );

    event TrainingCompleted(
        uint256 indexed sessionId,
        uint256 indexed robotId,
        uint256 accuracy
    );

    event TrainingFailed(
        uint256 indexed sessionId,
        uint256 indexed robotId,
        string reason
    );

    event ObservationSessionEnded(
        uint256 indexed sessionId,
        uint256 indexed robotId,
        TrainingStatus finalStatus
    );

    event ObservationSessionCancelled(
        uint256 indexed sessionId,
        uint256 indexed robotId
    );

    event SessionToggled(uint256 indexed sessionId, bool isActive);

    function initialize(address _robotRegistry) external initializer {
        __UUPSUpgradeable_init();
        require(_robotRegistry != address(0), "Invalid registry");
        robotRegistry = IRobotRegistryV2(_robotRegistry);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override {}

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

    function startObservationSession(
        uint256 robotId,
        string memory title,
        string memory description,
        string memory cameraSource
    ) external robotExists(robotId) returns (uint256) {
        require(!hasActiveSession[robotId], "Active session exists");
        require(bytes(title).length > 0, "Empty title");

        sessionCounter++;

        robotSessions[robotId].push(
            ObservationSession({
                sessionId: sessionCounter,
                robotId: robotId,
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
                trainingResultUrl: ""
            })
        );

        hasActiveSession[robotId] = true;
        activeSessionIndex[robotId] = robotSessions[robotId].length - 1;

        sessionToRobot[sessionCounter] = robotId;

        emit ObservationSessionStarted(sessionCounter, robotId, cameraSource);
        return sessionCounter;
    }

    function recordObservation(
        uint256 sessionId,
        string memory dataUrl,
        uint256 dataSize,
        string memory dataType,
        string memory notes
    ) external {
        uint256 robotId = sessionToRobot[sessionId];
        require(robotId != 0, "Session not found");
        require(
            robotRegistry.getRobotById(robotId).id != 0,
            "Robot not exists"
        );

        bool found = false;
        uint256 sessionIndex = 0;
        for (uint256 i = 0; i < robotSessions[robotId].length; i++) {
            if (robotSessions[robotId][i].sessionId == sessionId) {
                sessionIndex = i;
                found = true;
                break;
            }
        }
        require(found, "Session not found in robot");

        ObservationSession storage session = robotSessions[robotId][
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

        emit ObservationRecorded(sessionId, robotId, dataUrl);
    }

    function updateTrainingResult(
        uint256 robotId,
        uint256 sessionId,
        string memory modelVersion,
        uint256 accuracy,
        string memory resultUrl
    ) external robotExists(robotId) onlyActiveSession(robotId) {
        require(accuracy <= 100, "Invalid accuracy");

        ObservationSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];

        require(session.sessionId == sessionId, "Invalid session");

        session.modelVersion = modelVersion;
        session.accuracy = accuracy;
        session.trainingResultUrl = resultUrl;
        session.lastModified = block.timestamp;

        emit TrainingCompleted(sessionId, robotId, accuracy);
    }

    function endObservationSession(
        uint256 robotId
    ) external robotExists(robotId) onlyActiveSession(robotId) {
        ObservationSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];

        session.endTime = block.timestamp;
        session.trainingDuration = session.endTime - session.startTime;
        session.status = TrainingStatus.COMPLETED;
        session.isActive = false;

        hasActiveSession[robotId] = false;
        activeSessionIndex[robotId] = 0;

        emit ObservationSessionEnded(
            session.sessionId,
            robotId,
            TrainingStatus.COMPLETED
        );
    }

    function markTrainingFailed(
        uint256 robotId,
        string memory reason
    ) external robotExists(robotId) onlyActiveSession(robotId) {
        ObservationSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];

        session.endTime = block.timestamp;
        session.trainingDuration = session.endTime - session.startTime;
        session.status = TrainingStatus.FAILED;
        session.isActive = false;

        hasActiveSession[robotId] = false;
        activeSessionIndex[robotId] = 0;

        emit TrainingFailed(session.sessionId, robotId, reason);
    }

    function cancelObservationSession(
        uint256 robotId
    ) external robotExists(robotId) onlyActiveSession(robotId) {
        ObservationSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];

        session.endTime = block.timestamp;
        session.status = TrainingStatus.CANCELLED;
        session.isActive = false;

        hasActiveSession[robotId] = false;
        activeSessionIndex[robotId] = 0;

        emit ObservationSessionCancelled(session.sessionId, robotId);
    }

    function toggleSessionActive(
        uint256 robotId,
        uint256 sessionIndex
    ) external robotExists(robotId) {
        require(sessionIndex < robotSessions[robotId].length, "Invalid index");

        ObservationSession storage session = robotSessions[robotId][
            sessionIndex
        ];
        session.isActive = !session.isActive;
        session.lastModified = block.timestamp;

        emit SessionToggled(session.sessionId, session.isActive);
    }

    function updateSessionInfo(
        uint256 robotId,
        uint256 sessionIndex,
        string memory newTitle,
        string memory newDescription
    ) external robotExists(robotId) {
        require(sessionIndex < robotSessions[robotId].length, "Invalid index");

        ObservationSession storage session = robotSessions[robotId][
            sessionIndex
        ];
        session.title = newTitle;
        session.description = newDescription;
        session.lastModified = block.timestamp;
    }

    function deleteSession(
        uint256 robotId,
        uint256 sessionIndex
    ) external robotExists(robotId) {
        require(sessionIndex < robotSessions[robotId].length, "Invalid index");

        ObservationSession storage session = robotSessions[robotId][
            sessionIndex
        ];

        delete sessionData[session.sessionId];

        uint256 last = robotSessions[robotId].length - 1;
        if (sessionIndex != last) {
            robotSessions[robotId][sessionIndex] = robotSessions[robotId][last];
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

    function getSessionData(
        uint256 sessionId
    ) external view returns (ObservationRecord memory) {
        return sessionData[sessionId];
    }

    function getSessionsByRobot(
        uint256 robotId
    ) external view returns (ObservationSession[] memory) {
        ObservationSession[] storage all = robotSessions[robotId];
        uint256 len = all.length;

        ObservationSession[] memory result = new ObservationSession[](len);

        for (uint256 i = 0; i < len; i++) {
            result[i] = all[len - 1 - i];
        }

        return result;
    }

    function getCurrentSession(
        uint256 robotId
    ) external view returns (ObservationSession memory) {
        require(hasActiveSession[robotId], "No active session");
        return robotSessions[robotId][activeSessionIndex[robotId]];
    }

    function getSessionByIndex(
        uint256 robotId,
        uint256 sessionIndex
    ) external view returns (ObservationSession memory) {
        require(sessionIndex < robotSessions[robotId].length, "Invalid index");
        return robotSessions[robotId][sessionIndex];
    }

    function isTraining(uint256 robotId) external view returns (bool) {
        return hasActiveSession[robotId];
    }

    function getSessionCount(uint256 robotId) external view returns (uint256) {
        return robotSessions[robotId].length;
    }

    function getSessionsPaginated(
        uint256 robotId,
        TrainingStatus status,
        uint256 page,
        uint256 limit
    )
        external
        view
        returns (ObservationSession[] memory sessions, uint256 total)
    {
        require(limit > 0, "Limit must be > 0");
        require(page > 0, "Page must be > 0");

        ObservationSession[] storage all = robotSessions[robotId];
        uint256 len = all.length;

        for (uint256 i = 0; i < len; i++) {
            if (all[i].status == status) {
                total++;
            }
        }

        if (total == 0) {
            return (new ObservationSession[](0), 0);
        }

        uint256 start = (page - 1) * limit;
        if (start >= total) {
            return (new ObservationSession[](0), total);
        }

        uint256 end = start + limit;
        if (end > total) {
            end = total;
        }

        uint256 size = end - start;
        sessions = new ObservationSession[](size);

        uint256 matchedIndex = 0;
        uint256 resultIndex = 0;

        for (uint256 i = len; i > 0 && resultIndex < size; i--) {
            if (all[i - 1].status == status) {
                if (matchedIndex >= start && matchedIndex < end) {
                    sessions[resultIndex] = all[i - 1];
                    resultIndex++;
                }
                matchedIndex++;
            }
        }

        return (sessions, total);
    }

    function getCompletedSessions(
        uint256 robotId
    ) external view returns (ObservationSession[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < robotSessions[robotId].length; i++) {
            if (robotSessions[robotId][i].status == TrainingStatus.COMPLETED) {
                count++;
            }
        }

        ObservationSession[] memory result = new ObservationSession[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < robotSessions[robotId].length; i++) {
            if (robotSessions[robotId][i].status == TrainingStatus.COMPLETED) {
                result[index] = robotSessions[robotId][i];
                index++;
            }
        }
        return result;
    }

    function getFailedSessions(
        uint256 robotId
    ) external view returns (ObservationSession[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < robotSessions[robotId].length; i++) {
            if (robotSessions[robotId][i].status == TrainingStatus.FAILED) {
                count++;
            }
        }

        ObservationSession[] memory result = new ObservationSession[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < robotSessions[robotId].length; i++) {
            if (robotSessions[robotId][i].status == TrainingStatus.FAILED) {
                result[index] = robotSessions[robotId][i];
                index++;
            }
        }
        return result;
    }

    function getTrainingStats(
        uint256 robotId
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
        totalSessions = robotSessions[robotId].length;

        uint256 totalAccuracy = 0;
        uint256 countWithAccuracy = 0;

        for (uint256 i = 0; i < totalSessions; i++) {
            if (robotSessions[robotId][i].status == TrainingStatus.COMPLETED) {
                completedSessions++;
                if (robotSessions[robotId][i].accuracy > 0) {
                    totalAccuracy += robotSessions[robotId][i].accuracy;
                    countWithAccuracy++;
                }
            } else if (
                robotSessions[robotId][i].status == TrainingStatus.FAILED
            ) {
                failedSessions++;
            }
        }

        averageAccuracy = countWithAccuracy > 0
            ? totalAccuracy / countWithAccuracy
            : 0;
    }
}
