// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IRobotRegistryV2.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RobotDataUploadTrainingV2 is UUPSUpgradeable {
    enum TrainingStatus {
        ONGOING,
        COMPLETED,
        CANCELLED
    }

    struct UploadSession {
        uint256 sessionId;
        uint256 robotId;
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 totalFiles;
        uint256 totalDataSize;
        TrainingStatus status;
        address trainer;
        bool isActive;
        uint256 createdAt;
        uint256 lastModified;
    }

    struct TrainingFile {
        string fileName;
        string fileUrl;
        string fileType;
        uint256 fileSize;
        uint256 uploadedAt;
        uint256 progress;
        bool uploaded;
    }

    IRobotRegistryV2 public robotRegistry;

    mapping(uint256 => UploadSession[]) private robotSessions;
    mapping(uint256 => TrainingFile[]) private sessionFiles;

    mapping(uint256 => bool) public hasActiveSession;
    mapping(uint256 => uint256) public activeSessionIndex;

    uint256 private sessionCounter;

    event UploadSessionStarted(
        uint256 indexed sessionId,
        uint256 indexed robotId
    );
    event FileAdded(uint256 indexed sessionId, string fileName);
    event FileProgressUpdated(
        uint256 indexed sessionId,
        uint256 fileIndex,
        uint256 progress
    );
    event FileRemoved(uint256 indexed sessionId, uint256 fileIndex);
    event UploadSessionUpdated(uint256 indexed sessionId);
    event UploadSessionEnded(
        uint256 indexed sessionId,
        uint256 indexed robotId
    );
    event UploadSessionCancelled(
        uint256 indexed sessionId,
        uint256 indexed robotId
    );

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

    modifier onlyTrainer(uint256 robotId) {
        UploadSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];
        require(session.trainer == msg.sender, "Not trainer");
        _;
    }

    function startUploadSession(
        uint256 robotId,
        string memory title,
        string memory description
    ) external robotExists(robotId) returns (uint256) {
        require(!hasActiveSession[robotId], "Active session exists");
        require(bytes(title).length > 0, "Empty title");

        sessionCounter++;

        robotSessions[robotId].push(
            UploadSession({
                sessionId: sessionCounter,
                robotId: robotId,
                title: title,
                description: description,
                startTime: block.timestamp,
                endTime: 0,
                totalFiles: 0,
                totalDataSize: 0,
                status: TrainingStatus.ONGOING,
                trainer: msg.sender,
                isActive: true,
                createdAt: block.timestamp,
                lastModified: block.timestamp
            })
        );

        hasActiveSession[robotId] = true;
        activeSessionIndex[robotId] = robotSessions[robotId].length - 1;

        emit UploadSessionStarted(sessionCounter, robotId);
        return sessionCounter;
    }

    function addFile(
        uint256 robotId,
        uint256 sessionId,
        string memory fileName,
        string memory fileUrl,
        string memory fileType,
        uint256 fileSize
    )
        external
        robotExists(robotId)
        onlyActiveSession(robotId)
        onlyTrainer(robotId)
    {
        UploadSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];

        require(session.sessionId == sessionId, "Invalid session");
        require(session.status == TrainingStatus.ONGOING, "Session ended");

        sessionFiles[sessionId].push(
            TrainingFile({
                fileName: fileName,
                fileUrl: fileUrl,
                fileType: fileType,
                fileSize: fileSize,
                uploadedAt: block.timestamp,
                progress: 0,
                uploaded: false
            })
        );

        emit FileAdded(sessionId, fileName);
    }

    function updateFileProgress(
        uint256 robotId,
        uint256 sessionId,
        uint256 fileIndex,
        uint256 progress
    )
        external
        robotExists(robotId)
        onlyActiveSession(robotId)
        onlyTrainer(robotId)
    {
        require(progress <= 100, "Invalid progress");
        require(fileIndex < sessionFiles[sessionId].length, "Invalid index");

        TrainingFile storage file = sessionFiles[sessionId][fileIndex];
        file.progress = progress;

        if (progress == 100) {
            file.uploaded = true;
        }

        emit FileProgressUpdated(sessionId, fileIndex, progress);
    }

    function removeFile(
        uint256 robotId,
        uint256 sessionId,
        uint256 fileIndex
    )
        external
        robotExists(robotId)
        onlyActiveSession(robotId)
        onlyTrainer(robotId)
    {
        require(fileIndex < sessionFiles[sessionId].length, "Invalid index");

        uint256 last = sessionFiles[sessionId].length - 1;
        if (fileIndex != last) {
            sessionFiles[sessionId][fileIndex] = sessionFiles[sessionId][last];
        }
        sessionFiles[sessionId].pop();

        emit FileRemoved(sessionId, fileIndex);
    }

    function updateSessionInfo(
        uint256 robotId,
        string memory newTitle,
        string memory newDescription
    )
        external
        robotExists(robotId)
        onlyActiveSession(robotId)
        onlyTrainer(robotId)
    {
        UploadSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];

        session.title = newTitle;
        session.description = newDescription;
        session.lastModified = block.timestamp;

        emit UploadSessionUpdated(session.sessionId);
    }

    function endUploadSession(
        uint256 robotId
    )
        external
        robotExists(robotId)
        onlyActiveSession(robotId)
        onlyTrainer(robotId)
    {
        UploadSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];

        session.endTime = block.timestamp;
        session.status = TrainingStatus.COMPLETED;
        session.isActive = false;

        session.totalFiles = sessionFiles[session.sessionId].length;

        uint256 totalSize;
        for (uint256 i = 0; i < sessionFiles[session.sessionId].length; i++) {
            totalSize += sessionFiles[session.sessionId][i].fileSize;
        }
        session.totalDataSize = totalSize;

        hasActiveSession[robotId] = false;
        activeSessionIndex[robotId] = 0;

        emit UploadSessionEnded(session.sessionId, robotId);
    }

    function cancelUploadSession(
        uint256 robotId
    )
        external
        robotExists(robotId)
        onlyActiveSession(robotId)
        onlyTrainer(robotId)
    {
        UploadSession storage session = robotSessions[robotId][
            activeSessionIndex[robotId]
        ];

        session.endTime = block.timestamp;
        session.status = TrainingStatus.CANCELLED;
        session.isActive = false;

        hasActiveSession[robotId] = false;
        activeSessionIndex[robotId] = 0;

        emit UploadSessionCancelled(session.sessionId, robotId);
    }

    function getSessionFiles(
        uint256 sessionId
    ) external view returns (TrainingFile[] memory) {
        TrainingFile[] storage all = sessionFiles[sessionId];
        uint256 len = all.length;

        TrainingFile[] memory result = new TrainingFile[](len);

        for (uint256 i = 0; i < len; i++) {
            result[i] = all[len - 1 - i];
        }

        return result;
    }

    function getSessionsByRobot(
        uint256 robotId
    ) external view returns (UploadSession[] memory) {
        UploadSession[] storage all = robotSessions[robotId];
        uint256 len = all.length;

        UploadSession[] memory result = new UploadSession[](len);

        for (uint256 i = 0; i < len; i++) {
            result[i] = all[len - 1 - i];
        }

        return result;
    }

    function getCurrentSession(
        uint256 robotId
    ) external view returns (UploadSession memory) {
        require(hasActiveSession[robotId], "No active session");
        return robotSessions[robotId][activeSessionIndex[robotId]];
    }

    function getSessionsByRobotPagedAndStatus(
        uint256 robotId,
        TrainingStatus status,
        uint256 offset,
        uint256 limit
    ) external view returns (UploadSession[] memory sessions, uint256 total) {
        UploadSession[] storage all = robotSessions[robotId];

        uint256 count;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].status == status) count++;
        }

        total = count;
        if (offset >= total) {
            return (new UploadSession[](0), total);
        }

        uint256 end = offset + limit;
        if (end > total) end = total;

        sessions = new UploadSession[](end - offset);

        uint256 matched;
        uint256 idx;

        for (uint256 i = all.length; i > 0 && idx < sessions.length; i--) {
            UploadSession storage s = all[i - 1];
            if (s.status == status) {
                if (matched >= offset) {
                    sessions[idx++] = s;
                }
                matched++;
            }
        }
    }

    function deleteSession(
        uint256 robotId,
        uint256 sessionIndex
    ) external robotExists(robotId) {
        require(sessionIndex < robotSessions[robotId].length, "Invalid index");

        UploadSession storage session = robotSessions[robotId][sessionIndex];

        require(session.trainer == msg.sender, "Not trainer");
        require(!session.isActive, "Session is active");
        require(
            session.status == TrainingStatus.COMPLETED ||
                session.status == TrainingStatus.CANCELLED,
            "Session not ended"
        );

        uint256 sessionId = session.sessionId;

        delete sessionFiles[sessionId];

        uint256 last = robotSessions[robotId].length - 1;
        if (sessionIndex != last) {
            robotSessions[robotId][sessionIndex] = robotSessions[robotId][last];
        }
        robotSessions[robotId].pop();
    }

    function toggleSessionActive(
        uint256 robotId,
        uint256 sessionIndex
    ) external robotExists(robotId) {
        require(sessionIndex < robotSessions[robotId].length, "Invalid index");

        UploadSession storage session = robotSessions[robotId][sessionIndex];

        require(session.trainer == msg.sender, "Not trainer");
        require(
            session.status == TrainingStatus.COMPLETED,
            "Session not completed"
        );

        session.isActive = !session.isActive;
        session.lastModified = block.timestamp;
    }
}
