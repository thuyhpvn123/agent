// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {NetCafeStaffUpgradeable} from "./NetCafeStaffUpgradeable.sol";
import {INetCafeManagementV2} from "./interfaces/INetCafeManagementV2.sol";
import {INetCafeUserV2} from "./interfaces/INetCafeUserV2.sol";
import {INetCafeSessionV2} from "./interfaces/INetCafeSessionV2.sol";

contract NetCafeStationV2 is OwnableUpgradeable, UUPSUpgradeable, NetCafeStaffUpgradeable {
    struct Station {
        bytes32 pcId;
        string name;
        bytes32 groupId;
        uint256 balanceVND;
        address currentUserAddress;
        address currentSession;
        string currentUserName;
        bool online;
        uint256 lastActiveAt;
        bool maintenance;
    }

    mapping(bytes32 => Station) public stations;

    INetCafeUserV2 public userContract;
    INetCafeSessionV2 public sessionContract;
    INetCafeManagementV2 public managementContract;

    event StationStatusChanged(address sessionWallet, bytes32 pcId);
    event StationAssigned(bytes32 pcId, address user, address sessionWallet);
    event StationReleased(bytes32 pcId);
    event StationMaintenanceSet(bytes32 pcId, bool maintenance);

    function initialize(
        address _staffContract,
        address _userContract,
        address _sessionContract,
        address _managementContract
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __NetCafeStaff_init(_staffContract);
        require(_userContract != address(0), "Invalid user contract");
        require(_sessionContract != address(0), "Invalid session contract");
        require(_managementContract != address(0), "Invalid management contract");
        userContract = INetCafeUserV2(_userContract);
        sessionContract = INetCafeSessionV2(_sessionContract);
        managementContract = INetCafeManagementV2(_managementContract);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setStatus(address sessionWallet, bytes32 pcId) external {
        (string memory stationName, bytes32 groupId, bool exists) =
            managementContract.getStationMeta(pcId);
        require(exists, "Station not found");
        INetCafeSessionV2.Session memory s = sessionContract.getSession(sessionWallet);
        require(s.active, "Session inactive");
        require(s.pcId == pcId, "Invalid PC");

        (bool online, uint256 lastLoginAt, uint256 balanceVND, string memory displayName) =
            userContract.getUserStationData(s.user);

        require(online, "User not online");

        stations[pcId].pcId = pcId;
        stations[pcId].name = stationName;
        stations[pcId].groupId = groupId;
        stations[pcId].online = online;
        stations[pcId].currentUserName = displayName;
        stations[pcId].currentUserAddress = s.user;
        stations[pcId].currentSession = sessionWallet;
        stations[pcId].lastActiveAt = lastLoginAt;
        stations[pcId].balanceVND = balanceVND;
        emit StationStatusChanged(sessionWallet, pcId);
    }

    function setMaintenance(bytes32 pcId, bool maintenance) external onlyFinanceStaff {
        (, , bool exists) = managementContract.getStationMeta(pcId);
        require(exists, "Station not found");
        stations[pcId].maintenance = maintenance;
        emit StationMaintenanceSet(pcId, maintenance);
    }

    function clearStationStatus(bytes32 pcId) external {
        (, , bool exists) = managementContract.getStationMeta(pcId);
        if (!exists) return;

        stations[pcId].online = false;
        stations[pcId].currentUserAddress = address(0);
        stations[pcId].currentSession = address(0);
        stations[pcId].currentUserName = "";
        stations[pcId].lastActiveAt = 0;
        stations[pcId].balanceVND = 0;

        emit StationReleased(pcId);
    }

    function getStationsPaged(
        uint256 offset,
        uint256 limit
    ) external view returns (Station[] memory) {
        bytes32[] memory ids = managementContract.getStationIdsPaged(offset, limit);
        Station[] memory list = new Station[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            bytes32 pcId = ids[i];
            (string memory name, bytes32 groupId, bool exists) =
                managementContract.getStationMeta(pcId);
            if (!exists) {
                continue;
            }
            Station storage stored = stations[pcId];
            list[i] = Station({
                pcId: pcId,
                name: name,
                groupId: groupId,
                balanceVND: stored.balanceVND,
                currentUserAddress: stored.currentUserAddress,
                currentSession: stored.currentSession,
                currentUserName: stored.currentUserName,
                online: stored.online,
                lastActiveAt: stored.lastActiveAt,
                maintenance: stored.maintenance
            });
        }
        return list;
    }

    uint256[50] private __gap;
}

