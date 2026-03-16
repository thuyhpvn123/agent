// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {NetCafeStaffUpgradeable} from "./NetCafeStaffUpgradeable.sol";
import {INetCafeUserV2} from "./interfaces/INetCafeUserV2.sol";
import {INetCafeSessionV2} from "./interfaces/INetCafeSessionV2.sol";

contract NetCafeSpendV2 is OwnableUpgradeable, UUPSUpgradeable, NetCafeStaffUpgradeable {
    enum SpendType {
        PLAY_TIME
    }

    struct SpendHistory {
        uint256 id;
        address userWallet;
        uint256 amountVND;
        SpendType spendType;
        uint256 fromTime;
        uint256 toTime;
        uint256 createdAt;
    }

    INetCafeUserV2 public userContract;
    INetCafeSessionV2 public sessionContract;

    uint256 private spendCounter;
    mapping(uint256 => SpendHistory) public spendHistories;
    mapping(address => uint256[]) public spendHistoryOfUser;

    event SpendRecorded(
        uint256 indexed id,
        address indexed user,
        uint256 amountVND,
        SpendType spendType
    );

    function initialize(
        address _staffContract,
        address _userContract,
        address _sessionContract
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __NetCafeStaff_init(_staffContract);
        require(_userContract != address(0), "Invalid user contract");
        require(_sessionContract != address(0), "Invalid session contract");
        userContract = INetCafeUserV2(_userContract);
        sessionContract = INetCafeSessionV2(_sessionContract);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function spendVND(address wallet, uint256 amountVND) external {
        require(userContract.isActive(wallet), "User not found");
        userContract.decreaseBalance(wallet, amountVND);
    }

    function chargePlayTime(
        address sessionWallet,
        bytes32 sessionKeyHash,
        bytes32 pcId,
        uint256 pricePerMinute
    ) external onlyFinanceStaff {
        INetCafeSessionV2.Session memory s = sessionContract.getSession(sessionWallet);

        require(s.active, "Session inactive");
        require(s.sessionKeyHash == sessionKeyHash, "Invalid session key");
        require(s.pcId == pcId, "Invalid PC");

        (bool active, bool online, uint256 lastLoginAt, uint256 balanceVND) =
            userContract.getUserStatus(s.user);

        require(active, "User not found");
        require(online, "User not online");

        uint256 endTime = block.timestamp > s.expiresAt
            ? s.expiresAt
            : block.timestamp;

        require(endTime > lastLoginAt, "Invalid play time");

        uint256 playedSeconds = endTime - lastLoginAt;
        require(playedSeconds >= 20, "Too short session");

        uint256 minutesPlayed = playedSeconds / 60;
        uint256 cost = minutesPlayed * pricePerMinute;

        require(balanceVND >= cost, "Insufficient balance");

        userContract.decreaseBalance(s.user, cost);

        spendCounter++;
        spendHistories[spendCounter] = SpendHistory({
            id: spendCounter,
            userWallet: s.user,
            amountVND: cost,
            spendType: SpendType.PLAY_TIME,
            fromTime: lastLoginAt,
            toTime: endTime,
            createdAt: block.timestamp
        });

        spendHistoryOfUser[s.user].push(spendCounter);

        sessionContract.closeSessionByModule(sessionWallet);
        userContract.forceLogout(s.user);

        emit SpendRecorded(spendCounter, s.user, cost, SpendType.PLAY_TIME);
    }

    function getSpendHistoryPaged(
        address wallet,
        uint256 offset,
        uint256 limit
    ) external view onlyFinanceStaff returns (SpendHistory[] memory) {
        uint256 total = spendHistoryOfUser[wallet].length;
        if (offset >= total) return new SpendHistory[](0);

        uint256 end = offset + limit;
        if (end > total) end = total;

        SpendHistory[] memory list = new SpendHistory[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            list[i - offset] = spendHistories[spendHistoryOfUser[wallet][i]];
        }
        return list;
    }

    uint256[50] private __gap;
}

