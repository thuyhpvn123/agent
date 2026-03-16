// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {NetCafeStaffUpgradeable} from "./NetCafeStaffUpgradeable.sol";
import {INetCafeUserV2} from "./interfaces/INetCafeUserV2.sol";

contract NetCafeTopUpV2 is
    OwnableUpgradeable,
    UUPSUpgradeable,
    NetCafeStaffUpgradeable
{
    enum PaymentMethod {
        CASH,
        BANK
    }

    enum TopUpStatus {
        PENDING,
        APPROVED,
        REJECTED
    }

    struct TopUpRequest {
        uint256 id;
        address userWallet;
        string userName;
        uint256 amountVND;
        PaymentMethod method;
        TopUpStatus status;
        uint256 createdAt;
        uint256 handledAt;
    }

    INetCafeUserV2 public userContract;

    uint256 private topUpCounter;
    mapping(uint256 => TopUpRequest) public topUpRequests;
    uint256[] public pendingTopUps;
    mapping(address => uint256[]) public topUpHistory;
    uint256[] public handledTopUpIds;

    event TopUpRequested(
        uint256 indexed id,
        address indexed user,
        uint256 amountVND,
        PaymentMethod method
    );
    event TopUpApproved(
        uint256 indexed id,
        address indexed user,
        uint256 amountVND
    );
    event TopUpRejected(uint256 indexed id, address indexed user);

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

    function depositVND(
        address wallet,
        uint256 amountVND,
        PaymentMethod method
    ) external onlyFinanceStaff {
        require(userContract.isActive(wallet), "User not found");
        require(amountVND > 0, "Invalid amount");

        topUpCounter++;

        topUpRequests[topUpCounter] = TopUpRequest({
            id: topUpCounter,
            userWallet: wallet,
            userName: userContract.getDisplayName(wallet),
            amountVND: amountVND,
            method: method,
            status: TopUpStatus.APPROVED,
            createdAt: block.timestamp,
            handledAt: block.timestamp
        });

        userContract.increaseBalance(wallet, amountVND);

        topUpHistory[wallet].push(topUpCounter);
        handledTopUpIds.push(topUpCounter);

        emit TopUpApproved(topUpCounter, wallet, amountVND);
    }
    function _isValidAmountDeposit(
        uint256 paymentId,
        uint256 amount
    ) external view returns (bool isValid, string memory message) {
        // Kiểm tra topup request có tồn tại không
        if (topUpRequests[paymentId].id == 0) {
            return (false, "TopUp request not found");
        }

        TopUpRequest storage req = topUpRequests[paymentId];

        // Kiểm tra amount có khớp không
        if (req.amountVND != amount) {
            return (false, "Amount does not match");
        }

        // Kiểm tra trạng thái
        if (req.status == TopUpStatus.APPROVED) {
            return (true, "TopUp already approved");
        }

        if (req.status == TopUpStatus.REJECTED) {
            return (false, "TopUp was rejected");
        }

        if (req.status == TopUpStatus.PENDING) {
            return (false, "TopUp is still pending");
        }

        return (false, "Unknown status");
    }
    function requestTopUp(
        address userWallet,
        uint256 amountVND,
        PaymentMethod method
    ) external {
        require(userWallet != address(0), "Invalid user wallet");
        require(userContract.isActive(userWallet), "User not registered");
        require(amountVND > 0, "Invalid amount");

        topUpCounter++;

        topUpRequests[topUpCounter] = TopUpRequest({
            id: topUpCounter,
            userWallet: userWallet,
            userName: userContract.getDisplayName(userWallet),
            amountVND: amountVND,
            method: method,
            status: TopUpStatus.PENDING,
            createdAt: block.timestamp,
            handledAt: 0
        });

        pendingTopUps.push(topUpCounter);

        emit TopUpRequested(topUpCounter, userWallet, amountVND, method);
    }

    function approveTopUp(uint256 id) external onlyFinanceStaff {
        TopUpRequest storage req = topUpRequests[id];
        require(req.status == TopUpStatus.PENDING, "Handled");

        req.status = TopUpStatus.APPROVED;
        req.handledAt = block.timestamp;

        userContract.increaseBalance(req.userWallet, req.amountVND);
        topUpHistory[req.userWallet].push(id);
        handledTopUpIds.push(id);

        emit TopUpApproved(id, req.userWallet, req.amountVND);

        _removePending(id);
    }

    function rejectTopUp(uint256 id) external onlyFinanceStaff {
        TopUpRequest storage req = topUpRequests[id];
        require(req.status == TopUpStatus.PENDING, "Handled");

        req.status = TopUpStatus.REJECTED;
        req.handledAt = block.timestamp;
        handledTopUpIds.push(id);
        emit TopUpRejected(id, req.userWallet);
        _removePending(id);
    }

    function getPendingTopUps() external view returns (uint256[] memory) {
        return pendingTopUps;
    }

    function getTopUpHistory(
        address wallet
    ) external view returns (uint256[] memory) {
        return topUpHistory[wallet];
    }

    function getPendingTopUpsPaged(
        uint256 offset,
        uint256 limit
    ) external view returns (TopUpRequest[] memory) {
        uint256 total = pendingTopUps.length;
        if (offset >= total) return new TopUpRequest[](0);

        uint256 end = offset + limit;
        if (end > total) end = total;

        TopUpRequest[] memory list = new TopUpRequest[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            list[i - offset] = topUpRequests[pendingTopUps[i]];
        }
        return list;
    }

    function getHandledTopUpsPaged(
        uint256 offset,
        uint256 limit
    ) external view returns (TopUpRequest[] memory) {
        uint256 total = handledTopUpIds.length;
        if (offset >= total) return new TopUpRequest[](0);

        uint256 end = offset + limit;
        if (end > total) end = total;

        TopUpRequest[] memory list = new TopUpRequest[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            list[i - offset] = topUpRequests[handledTopUpIds[i]];
        }

        return list;
    }

    function _removePending(uint256 id) internal {
        uint256 len = pendingTopUps.length;
        for (uint256 i = 0; i < len; i++) {
            if (pendingTopUps[i] == id) {
                pendingTopUps[i] = pendingTopUps[len - 1];
                pendingTopUps.pop();
                break;
            }
        }
    }

    uint256[50] private __gap;
}
