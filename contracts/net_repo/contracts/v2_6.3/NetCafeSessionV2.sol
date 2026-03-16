// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {NetCafeStaffUpgradeable} from "./NetCafeStaffUpgradeable.sol";
import {INetCafeUserV2} from "./interfaces/INetCafeUserV2.sol";

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

    INetCafeUserV2 public userContract;

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
        address _userContract
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __NetCafeStaff_init(_staffContract);
        require(_userContract != address(0), "Invalid user contract");
        userContract = INetCafeUserV2(_userContract);
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
        uint64 expiresAt
    ) external {
        require(userContract.isActive(msg.sender), "User not registered");
        require(sessionWallet != address(0), "Invalid session wallet");
        require(!sessions[sessionWallet].active, "Session already active");
        require(expiresAt > block.timestamp, "Invalid expiry");

        sessions[sessionWallet] = Session({
            user: msg.sender,
            sessionWallet: sessionWallet,
            sessionKeyHash: sessionKeyHash,
            pcId: pcId,
            expiresAt: expiresAt,
            active: true
        });

        emit SessionOpened(msg.sender, sessionWallet, pcId, expiresAt);
    }

    function validateSession(
        address sessionWallet,
        bytes32 sessionKeyHash,
        bytes32 pcId
    ) external returns (bool) {
        Session memory s = sessions[sessionWallet];

        if (!s.active) return false;
        if (block.timestamp >= s.expiresAt) return false;
        if (s.sessionKeyHash != sessionKeyHash) return false;
        if (s.pcId != pcId) return false;
        emit SessionOpened(s.user, s.sessionWallet, s.pcId, s.expiresAt);
        return true;
    }

    function closeSession(address sessionWallet) external {
        Session storage s = sessions[sessionWallet];

        require(s.active, "Session not active");
        require(
            msg.sender == s.user || msg.sender == s.sessionWallet,
            "Not authorized"
        );

        s.active = false;
        emit SessionClosed(sessionWallet);
    }

    function closeSessionByModule(address sessionWallet) external onlyModule {
        Session storage s = sessions[sessionWallet];
        if (!s.active) {
            return;
        }
        s.active = false;
        emit SessionClosed(sessionWallet);
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

    uint256[50] private __gap;
}
