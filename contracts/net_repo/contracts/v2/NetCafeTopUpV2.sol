// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {NetCafeStaffUpgradeable} from "./NetCafeStaffUpgradeable.sol";
import {INetCafeUserV2} from "./interfaces/INetCafeUserV2.sol";
import {INetCafeSessionV2} from "./interfaces/INetCafeSessionV2.sol";

// interface IAuditLog {
//     function writeLog(
//         uint256 branchId,
//         address actor,
//         string calldata actorName,
//         string calldata action,
//         bytes32 targetId,
//         string calldata detail
//     ) external returns (uint256);
// }

contract NetCafeTopUpV2 is
    OwnableUpgradeable,
    UUPSUpgradeable,
    NetCafeStaffUpgradeable
{
    enum PaymentMethod {
        CASH, // Tiền mặt
        BANK // Chuyển khoản ngân hàng / QR
    }

    enum TopUpStatus {
        PENDING,
        APPROVED,
        REJECTED
    }

    // ─────────────────────────────────────────────
    //  Structs
    // ─────────────────────────────────────────────

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

    struct PaymentConfig {
        bool allowCash; // Cho phép tiền mặt
        bool allowBank; // Cho phép chuyển khoản / QR
    }

    // ─────────────────────────────────────────────
    //  State
    // ─────────────────────────────────────────────

    INetCafeUserV2 public userContract;
    INetCafeSessionV2 public sessionContract;
    PaymentConfig public paymentConfig;

    uint256 private topUpCounter;
    mapping(uint256 => TopUpRequest) public topUpRequests;
    uint256[] public pendingTopUps;
    mapping(address => uint256[]) public topUpHistory;
    uint256[] public handledTopUpIds;

    // ─────────────────────────────────────────────
    //  Events
    // ─────────────────────────────────────────────

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
    event PaymentConfigUpdated(bool allowCash, bool allowBank);

    /* =======================
           INIT
    ======================= */
    function initialize(
        address _staffContract,
        address _userContract
        // address _auditLogContract
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __NetCafeStaff_init(_staffContract);
        require(_userContract != address(0), "Invalid user contract");
        userContract = INetCafeUserV2(_userContract);
        // auditLog = IAuditLog(_auditLogContract);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setSessionContract(address _session) external onlyOwner {
        require(_session != address(0), "Invalid session contract");
        sessionContract = INetCafeSessionV2(_session);
    }

    modifier onlyAllowedMethod(PaymentMethod method) {
        if (method == PaymentMethod.CASH) {
            require(paymentConfig.allowCash, "Cash payment not allowed");
        } else if (method == PaymentMethod.BANK) {
            require(paymentConfig.allowBank, "Bank payment not allowed");
        }
        _;
    }
    modifier onlyValidSession(
        address sessionWallet,
        bytes32 sessionKeyHash,
        bytes32 pcId
    ) {
        require(
            address(sessionContract) != address(0),
            "Session contract not set"
        );
        require(
            sessionContract.validateSession(
                sessionWallet,
                sessionKeyHash,
                pcId
            ),
            "Invalid or expired session"
        );
        _;
    }

    // ─────────────────────────────────────────────
    //  Config
    // ─────────────────────────────────────────────

    /**
     * @notice Bật/tắt phương thức thanh toán
     * @param allowCash Cho phép tiền mặt
     * @param allowBank Cho phép chuyển khoản / QR
     */
    function setPaymentConfig(bool allowCash, bool allowBank) external {
        require(allowCash || allowBank, "At least one method must be enabled");
        paymentConfig = PaymentConfig({
            allowCash: allowCash,
            allowBank: allowBank
        });
        emit PaymentConfigUpdated(allowCash, allowBank);
    }

    /**
     * @notice Kiểm tra phương thức thanh toán có được phép không
     */
    function isMethodAllowed(
        PaymentMethod method
    ) external view returns (bool) {
        if (method == PaymentMethod.CASH) return paymentConfig.allowCash;
        if (method == PaymentMethod.BANK) return paymentConfig.allowBank;
        return false;
    }

    // ─────────────────────────────────────────────
    //  Deposit (staff trực tiếp, không cần duyệt)
    // ─────────────────────────────────────────────

    function depositVND(
        address wallet,
        uint256 amountVND,
        PaymentMethod method
    ) external onlyFinanceStaff onlyAllowedMethod(method) {
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

    // ─────────────────────────────────────────────
    //  Request → Approve / Reject
    // ─────────────────────────────────────────────

    function requestTopUp(
        address userWallet,
        uint256 amountVND,
        PaymentMethod method,
        address sessionWallet, // thêm param
        bytes32 sessionKeyHash,
        bytes32 pcId
    )
        external
        onlyAllowedMethod(method)
        onlyValidSession(sessionWallet, sessionKeyHash, pcId)
    {
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
        require(req.status == TopUpStatus.PENDING, "Already handled");

        req.status = TopUpStatus.APPROVED;
        req.handledAt = block.timestamp;

        userContract.increaseBalance(req.userWallet, req.amountVND);
        topUpHistory[req.userWallet].push(id);
        handledTopUpIds.push(id);
        _removePending(id);

        emit TopUpApproved(id, req.userWallet, req.amountVND);
    }

    function rejectTopUp(uint256 id) external onlyFinanceStaff {
        TopUpRequest storage req = topUpRequests[id];
        require(req.status == TopUpStatus.PENDING, "Already handled");

        req.status = TopUpStatus.REJECTED;
        req.handledAt = block.timestamp;
        handledTopUpIds.push(id);
        _removePending(id);

        emit TopUpRejected(id, req.userWallet);
    }

    // ─────────────────────────────────────────────
    //  Validate helper
    // ─────────────────────────────────────────────

    function _isValidAmountDeposit(
        uint256 paymentId,
        uint256 amount
    ) external view returns (bool isValid, string memory message) {
        if (topUpRequests[paymentId].id == 0) {
            return (false, "TopUp request not found");
        }
        TopUpRequest storage req = topUpRequests[paymentId];
        if (req.amountVND != amount) {
            return (false, "Amount does not match");
        }
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

    // ─────────────────────────────────────────────
    //  Query / Pagination
    // ─────────────────────────────────────────────

    function getPendingTopUps() external view returns (uint256[] memory) {
        return pendingTopUps;
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

    function getTopUpHistory(
        address wallet,
        uint256 offset,
        uint256 limit
    ) external view returns (TopUpRequest[] memory, uint256 total) {
        uint256[] storage history = topUpHistory[wallet];
        total = history.length;
        if (offset >= total) return (new TopUpRequest[](0), total);
        uint256 end = offset + limit;
        if (end > total) end = total;
        TopUpRequest[] memory list = new TopUpRequest[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            list[i - offset] = topUpRequests[history[i]];
        }
        return (list, total);
    }

    // ─────────────────────────────────────────────
    //  Internal
    // ─────────────────────────────────────────────

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

    uint256[48] private __gap;
}
