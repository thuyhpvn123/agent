// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {NetCafeStaffUpgradeable} from "./NetCafeStaffUpgradeable.sol";
import {INetCafeUserV2} from "./interfaces/INetCafeUserV2.sol";
import {INetCafeManagementV2} from "./interfaces/INetCafeManagementV2.sol";
contract NetCafeSessionV2 is
    OwnableUpgradeable,
    UUPSUpgradeable,
    NetCafeStaffUpgradeable
{
    struct Session {
        address user;
        address sessionWallet;
        bytes32 sessionKeyHash;
        bytes32 pcId;
        uint64 expiresAt;
        bool active;
    }
    mapping(address => Session) public sessions;
    mapping(address => bool) public modules;
    // mapping(address => bool) public userHasActiveSession;
    mapping(address => address) public activeSessionOfUser;
    mapping(bytes32 => bool) public pcHasActiveSession;
    mapping(bytes32 => address) public machineSession; // pcId => sessionWallet

    // mapping(address => address) public userActiveSession; // user => sessionWallet
    // mapping(bytes32 => address) public pcActiveSession; // pcId => sessionWallet

    INetCafeUserV2 public userContract;
    INetCafeManagementV2 public managementContract;
    event ModuleUpdated(address indexed module, bool allowed);
    event SessionOpened(
        address indexed user,
        address indexed sessionWallet,
        bytes32 pcId,
        uint64 expiresAt
    );
    event SessionClosed(address indexed sessionWallet);

    function initialize(
        address _staffContract,
        address _userContract,
        address _managementContract
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __NetCafeStaff_init(_staffContract);
        require(_userContract != address(0), "Invalid user contract");
        userContract = INetCafeUserV2(_userContract);
        managementContract = INetCafeManagementV2(_managementContract);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    modifier onlyModule() {
        require(modules[msg.sender], "Not module");
        _;
    }

    function setModule(address module, bool allowed) external onlyOwner {
        require(module != address(0), "Invalid module");
        modules[module] = allowed;
        emit ModuleUpdated(module, allowed);
    }

    function openSession(
        address sessionWallet,
        bytes32 sessionKeyHash,
        bytes32 pcId,
        uint64 interval
    ) external {
        require(userContract.isActive(msg.sender), "User not registered");
        require(sessionWallet != address(0), "Invalid session wallet");
        require(
            interval == 60 || interval == 120 || interval == 180,
            "Invalid interval: must be 60, 120, or 180"
        );
        // Auto clear nếu session của user cũ đã expired
        address oldUserSession = activeSessionOfUser[msg.sender];
        if (
            oldUserSession != address(0) &&
            block.timestamp >= sessions[oldUserSession].expiresAt
        ) {
            _clearSession(oldUserSession);
        }
        address oldPcSession = machineSession[pcId];
        if (
            oldPcSession != address(0) &&
            block.timestamp >= sessions[oldPcSession].expiresAt
        ) {
            _clearSession(oldPcSession);
        }
        require(!sessions[sessionWallet].active, "Session already active");
        require(
            activeSessionOfUser[msg.sender] == address(0),
            "User already has active session"
        );
        require(!pcHasActiveSession[pcId], "PC already has active session");

        uint64 expiresAt = uint64(block.timestamp) + interval;

        sessions[sessionWallet] = Session({
            user: msg.sender,
            sessionWallet: sessionWallet,
            sessionKeyHash: sessionKeyHash,
            pcId: pcId,
            expiresAt: expiresAt,
            active: true
        });

        activeSessionOfUser[msg.sender] = sessionWallet;
        pcHasActiveSession[pcId] = true;
        machineSession[pcId] = sessionWallet;
        _deductMoney(sessionWallet, pcId, interval);
        if (!sessions[sessionWallet].active) return;
        emit SessionOpened(msg.sender, sessionWallet, pcId, expiresAt);
    }

    // function validateSession(
    //     address sessionWallet,
    //     bytes32 sessionKeyHash,
    //     bytes32 pcId
    // ) external returns (bool) {
    //     Session memory s = sessions[sessionWallet];

    //     if (!s.active) return false;
    //     if (block.timestamp >= s.expiresAt) return false;
    //     if (s.sessionKeyHash != sessionKeyHash) return false;
    //     if (s.pcId != pcId) return false;
    //     emit SessionOpened(s.user, s.sessionWallet, s.pcId, s.expiresAt);
    //     return true;
    // }
    function validateSession(
        address sessionWallet,
        bytes32 sessionKeyHash,
        bytes32 pcId
    ) external view returns (bool) {
        Session memory s = sessions[sessionWallet];
        if (!s.active) return false;
        if (block.timestamp >= s.expiresAt) return false;
        if (s.sessionKeyHash != sessionKeyHash) return false;
        if (s.pcId != pcId) return false;
        return true;
    }

    function closeSession(address sessionWallet) external {
        Session storage s = sessions[sessionWallet];
        require(s.active, "Session not active");
        require(
            msg.sender == s.user || msg.sender == s.sessionWallet,
            "Not authorized"
        );
        _clearSession(sessionWallet);
        // emit SessionClosed(sessionWallet);
    }

    function closeSessionByModule(address sessionWallet) external onlyModule {
        if (!sessions[sessionWallet].active) return;
        _clearSession(sessionWallet);
        // emit SessionClosed(sessionWallet);
    }

    function isSessionActive(
        address sessionWallet
    ) external view returns (bool) {
        return sessions[sessionWallet].active;
    }

    function getSession(
        address sessionWallet
    ) external view returns (Session memory) {
        return sessions[sessionWallet];
    }
    function _clearSession(address sessionWallet) internal {
        Session storage s = sessions[sessionWallet];
        activeSessionOfUser[s.user] = address(0);
        pcHasActiveSession[s.pcId] = false;
        machineSession[s.pcId] = address(0);
        s.active = false;
        emit SessionClosed(sessionWallet);
    }
    // Lấy session từ user, không cần biết sessionWallet
    function getSessionByUser(
        address user
    ) external view returns (Session memory) {
        address sessionWallet = activeSessionOfUser[user];
        require(sessionWallet != address(0), "No active session");
        return sessions[sessionWallet];
    }
    //heartbeat
    function heartbeat(address sessionWallet, uint64 interval) external {
        require(msg.sender == sessionWallet, "Not session wallet");
        require(sessions[sessionWallet].active, "No active session"); // bỏ !
        require(
            interval == 60 || interval == 120 || interval == 180,
            "Invalid interval"
        );
        require(
            block.timestamp < sessions[sessionWallet].expiresAt,
            "Session expired"
        );
        bytes32 pcId = sessions[sessionWallet].pcId;
        _deductMoney(sessionWallet, pcId, interval);
        if (!sessions[sessionWallet].active) return;
        uint64 expiresAt = sessions[sessionWallet].expiresAt;
        if (block.timestamp > expiresAt) {
            expiresAt = uint64(block.timestamp) + interval;
        } else {
            expiresAt += interval;
        }
        sessions[sessionWallet].expiresAt = expiresAt;
    }

    function _deductMoney(
        address sessionWallet,
        bytes32 pcId,
        uint64 interval
    ) internal {
        Session memory s = sessions[sessionWallet];
        (
            bool active,
            bool online,
            uint256 lastLoginAt,
            uint256 balanceVND
        ) = userContract.getUserBalance(s.user);

        (uint256 pricePerMinute) = managementContract.getStationPrice(pcId);

        uint256 cost = (pricePerMinute * uint256(interval)) / 60;

        // require(balanceVND > cost, "Your account has run out of money.");
        if (balanceVND >= cost) {
            userContract.decreaseBalance(s.user, cost);
        } else {
            _clearSession(sessionWallet);
        }
    }

    uint256[50] private __gap;
}
