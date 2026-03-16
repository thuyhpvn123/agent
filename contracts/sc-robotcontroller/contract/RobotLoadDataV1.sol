// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRobotRegistry.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RobotStaffUpgradeable} from "./RobotStaffUpgradeable.sol";

contract RobotDataUploadTraining is
    OwnableUpgradeable,
    // UUPSUpgradeable,
    RobotStaffUpgradeable
{
    /* =======================
            ENUMS
    ======================= */
    enum TrainingStatus {
        ONGOING,
        COMPLETED,
        CANCELLED
    }

    /* =======================
            STRUCTS
    ======================= */
    struct UploadSession {
        uint256 sessionId;
        address robotAddress;
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
        string fileKey;
        string fileType;
        uint256 fileSize;
        uint256 uploadedAt;
        uint256 progress; // 0 → 100
        bool uploaded;
    }

    /* =======================
            STORAGE
    ======================= */
    IRobotRegistry public robotRegistry;

    // robotAddress => upload sessions
    mapping(address => UploadSession[]) private robotSessions;

    // sessionId => files
    mapping(uint256 => TrainingFile[]) private sessionFiles;
    mapping(uint256 => address) private sessionToRobot;
    mapping(uint256 => uint256) private sessionIndexById;

    mapping(address => bool) public hasActiveSession;
    mapping(address => uint256) public activeSessionIndex;

    uint256 private sessionCounter;

    /* =======================                               
            EVENTS
    ======================= */
    event UploadSessionStarted(
        uint256 indexed sessionId,
        address indexed robotAddress
    );
    event FileAdded(uint256 indexed sessionId, string fileName, string fileKey);
    event FileProgressUpdated(
        uint256 indexed sessionId,
        uint256 fileIndex,
        uint256 progress
    );
    event FileRemoved(uint256 indexed sessionId, uint256 fileIndex);
    event UploadSessionUpdated(uint256 indexed sessionId);
    event UploadSessionEnded(
        uint256 indexed sessionId,
        address indexed robotAddress
    );
    event UploadSessionCancelled(
        uint256 indexed sessionId,
        address indexed robotAddress
    );

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

    // modifier onlyTrainer(address robotAddress) {
    //     UploadSession storage session = robotSessions[robotAddress][
    //         activeSessionIndex[robotAddress]
    //     ];
    //     require(session.trainer == msg.sender, "Not trainer");
    //     _;
    // }

    /* =======================
        SESSION MANAGEMENT
    ======================= */

    function startUploadSession(
        address robotAddress,
        string memory title,
        string memory description
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
            UploadSession({
                sessionId: sessionCounter,
                robotAddress: robotAddress,
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

        hasActiveSession[robotAddress] = true;
        activeSessionIndex[robotAddress] =
            robotSessions[robotAddress].length -
            1;

        sessionToRobot[sessionCounter] = robotAddress;
        sessionIndexById[sessionCounter] = robotSessions[robotAddress].length;

        emit UploadSessionStarted(sessionCounter, robotAddress);
        return sessionCounter;
    }

    /* =======================
            FILE HANDLING
    ======================= */

    function addFile(
        address robotAddress,
        uint256 sessionId,
        string memory fileName,
        string memory fileKey,
        string memory fileType,
        uint256 fileSize
    )
        external
        robotExists(robotAddress)
        onlyActiveSession(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
    {
        UploadSession storage session = robotSessions[robotAddress][
            activeSessionIndex[robotAddress]
        ];

        require(session.sessionId == sessionId, "Invalid session");
        require(session.status == TrainingStatus.ONGOING, "Session ended");

        sessionFiles[sessionId].push(
            TrainingFile({
                fileName: fileName,
                fileKey: fileKey,
                fileType: fileType,
                fileSize: fileSize,
                uploadedAt: block.timestamp,
                progress: 0,
                uploaded: false
            })
        );

        emit FileAdded(sessionId, fileName, fileKey);
    }

    function updateFileProgress(
        address robotAddress,
        uint256 sessionId,
        uint256 fileIndex,
        uint256 progress
    )
        external
        robotExists(robotAddress)
        onlyActiveSession(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
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
        address robotAddress,
        uint256 sessionId,
        uint256 fileIndex
    )
        external
        robotExists(robotAddress)
        onlyActiveSession(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
    {
        require(fileIndex < sessionFiles[sessionId].length, "Invalid index");

        uint256 last = sessionFiles[sessionId].length - 1;
        if (fileIndex != last) {
            sessionFiles[sessionId][fileIndex] = sessionFiles[sessionId][last];
        }
        sessionFiles[sessionId].pop();

        emit FileRemoved(sessionId, fileIndex);
    }

    /* =======================
        UPDATE / CONFIRM
    ======================= */

    function updateSessionInfo(
        address robotAddress,
        string memory newTitle,
        string memory newDescription
    )
        external
        robotExists(robotAddress)
        onlyActiveSession(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
    {
        UploadSession storage session = robotSessions[robotAddress][
            activeSessionIndex[robotAddress]
        ];

        session.title = newTitle;
        session.description = newDescription;
        session.lastModified = block.timestamp;

        emit UploadSessionUpdated(session.sessionId);
    }

    function endUploadSession(
        address robotAddress
    )
        external
        robotExists(robotAddress)
        onlyActiveSession(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
    {
        UploadSession storage session = robotSessions[robotAddress][
            activeSessionIndex[robotAddress]
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

        hasActiveSession[robotAddress] = false;
        // không reset activeSessionIndex về 0 vì có thể dùng lại sau (tùy logic UI)

        emit UploadSessionEnded(session.sessionId, robotAddress);
    }

    function cancelUploadSession(
        address robotAddress
    )
        external
        robotExists(robotAddress)
        onlyActiveSession(robotAddress)
        onlyMerchantOwner
        onlyManager
        onlyStaff
    {
        UploadSession storage session = robotSessions[robotAddress][
            activeSessionIndex[robotAddress]
        ];

        session.endTime = block.timestamp;
        session.status = TrainingStatus.CANCELLED;
        session.isActive = false;

        hasActiveSession[robotAddress] = false;
        // không reset activeSessionIndex về 0 vì có thể dùng lại sau

        emit UploadSessionCancelled(session.sessionId, robotAddress);
    }

    /* =======================
            READ
    ======================= */

    function getSessionFiles(
        uint256 sessionId
    ) external view returns (TrainingFile[] memory) {
        TrainingFile[] storage all = sessionFiles[sessionId];
        uint256 len = all.length;

        TrainingFile[] memory result = new TrainingFile[](len);

        // duyệt ngược → file mới nhất trước
        for (uint256 i = 0; i < len; i++) {
            result[i] = all[len - 1 - i];
        }

        return result;
    }

    function getSessionsByRobot(
        address robotAddress
    ) external view returns (UploadSession[] memory) {
        UploadSession[] storage all = robotSessions[robotAddress];
        uint256 len = all.length;

        UploadSession[] memory result = new UploadSession[](len);

        for (uint256 i = 0; i < len; i++) {
            result[i] = all[len - 1 - i];
        }

        return result;
    }

    function getCurrentSession(
        address robotAddress
    ) external view returns (UploadSession memory) {
        require(hasActiveSession[robotAddress], "No active session");
        return robotSessions[robotAddress][activeSessionIndex[robotAddress]];
    }

    function getSessionsByRobotPagedAndStatus(
        address robotAddress,
        TrainingStatus status,
        uint256 offset,
        uint256 limit
    ) external view returns (UploadSession[] memory sessions, uint256 total) {
        UploadSession[] storage all = robotSessions[robotAddress];

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

        UploadSession storage session = robotSessions[robotAddress][
            sessionIndex
        ];

        require(session.trainer == msg.sender, "Not trainer");
        require(!session.isActive, "Session is active");
        require(
            session.status == TrainingStatus.COMPLETED ||
                session.status == TrainingStatus.CANCELLED,
            "Session not ended"
        );

        delete sessionFiles[sessionId];
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
            // Cập nhật lại activeSessionIndex nếu cần
            if (
                hasActiveSession[robotAddress] &&
                activeSessionIndex[robotAddress] == last
            ) {
                activeSessionIndex[robotAddress] = sessionIndex;
            }
        }
        robotSessions[robotAddress].pop();
    }

    function toggleSessionActive(
        address robotAddress,
        uint256 sessionId
    ) external robotExists(robotAddress) onlyMerchantOwner {
        require(sessionToRobot[sessionId] == robotAddress, "Invalid session");
        uint256 sessionIndexPlus1 = sessionIndexById[sessionId];
        require(sessionIndexPlus1 > 0, "Session not found");
        uint256 sessionIndex = sessionIndexPlus1 - 1;

        UploadSession storage session = robotSessions[robotAddress][
            sessionIndex
        ];

        require(session.trainer == msg.sender, "Not trainer");
        require(
            session.status == TrainingStatus.COMPLETED,
            "Session not completed"
        );

        session.isActive = !session.isActive;
        session.lastModified = block.timestamp;
    }
    uint256[50] private __gap;
}
