// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./EconomyTypes.sol";
import "./interfaces/IPoint.sol";
import "./interfaces/IManagement.sol";
import "./interfaces/IMeos.sol";

import "./lib/DateTimeTZ.sol";
import "forge-std/console.sol";

import {PublicfullDB} from "./loyaltyDB.sol";
/**
 * Token model:
 *   Token A (Vault Xu)  — earn từ topup/hóa đơn → spend
 *   Token B (Reward Xu) — earn từ tier bonus + campaign → spend
 *   lifetimeTokenA      — chỉ tăng, dùng owner biết mức tier để gán
 */
contract RestaurantLoyaltySystem is
    Initializable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using Strings for uint256;

    // ================================================================
    // ROLES
    // ================================================================
    bytes32 public constant NET_MODULE   = keccak256("NET_MODULE");
    bytes32 public constant FOOD_MODULE  = keccak256("FOOD_MODULE");
    bytes32 public constant FINANCE  = keccak256("FINANCE");
    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");

    // ================================================================
    // STATE — MEMBER
    // ================================================================
    mapping(address => Member)        public members;
    mapping(string  => address)       public memberIdToAddress;
    mapping(address => uint256[])     public memberTxIds;
    mapping(address => bytes32[])     public memberToGroups;
    mapping(bytes32 => MemberGroup)   public memberGroups;
    mapping(bytes32 => address[])     public groupMembers;
    mapping(uint256 => ManualRequest) public manualRequests;
    mapping(bytes32 => bool)          public processedInvoices;
    mapping(address => uint256)       public lastRequestDate;
    mapping(address => uint256)       public staffDailyRequests;
    mapping(address => bool)          public isTokenHolder;

    Member[]      public allMembers;
    MemberGroup[] public allMemberGroups;
    bytes32[]     public allGroupIds;
    Transaction[]    public allTransactions;
    address[]     public tokenHolders;

    uint256 private _txCounter;
    uint256 private _requestCounter;

    // ================================================================
    // STATE — TOKEN A (Vault Xu)
    // ================================================================
    mapping(address => uint256) private _balanceA;
    mapping(bytes32 => bool)    private _processedTopups;

    struct LedgerEntryA {
        address customer;
        int256  delta;
        bytes32 actionType;
        bytes32 refId;
        bytes32 idempotencyKey;
        uint256 timestamp;
    }
    LedgerEntryA[]                private _ledgerA;
    mapping(address => uint256[]) private _ledgerAIdx;

    uint256 public totalACredited;
    uint256 public totalADebited;

    // ================================================================
    // STATE — TOKEN B (Reward Xu)
    // ================================================================
    struct RewardBatch {
        uint256 id;
        uint256 amount;
        uint256 expiresAt;
        uint256 campaignId;
        bytes32 sourceEventId;
        bool    active;
    }

    mapping(address => RewardBatch[]) private _rewardBatches;
    mapping(address => uint256)       private _balanceB;
    mapping(bytes32 => bool)          private _processedGrants;

    struct LedgerEntryB {
        address customer;
        int256  delta;
        bytes32 actionType;
        bytes32 refId;
        uint256 timestamp;
        string  note;
    }
    LedgerEntryB[]                private _ledgerB;
    mapping(address => uint256[]) private _ledgerBIdx;

    uint256 public totalBGranted;
    uint256 public totalBDebited;
    uint256 public totalBExpired;
    uint256 private _batchCounter;

    mapping(bytes32 => bool) public allowedActionTypes;
    bytes32[] public allowedActionTypeList;

    // ================================================================
    // STATE — POLICY
    // ================================================================
    uint256 public topupRate;           // inputAmount / topupRate = Token A
    uint256 public topupMin;
    uint256 public topupMax;            // 0 = unlimited
    EconomyTypes.SpendPriority public spendPriority;
    uint256 public rewardMaxPercent;    // base % cap Token B (0-100)
    uint256 public rewardMaxAbsolute;   // 0 = unlimited
    uint256 public defaultExpiryDays;   // 0 = no expiry

    // ================================================================
    // STATE — TIER
    // ================================================================
    bool public tierEnabled;
    mapping(address => bytes32)                 public customerTier;
    mapping(address => uint256)                 public lifetimeTokenA;
    mapping(bytes32 => EconomyTypes.TierConfig) public tierConfigs;
    EconomyTypes.TierConfig[]                   public allTiers;
    mapping(string => bytes32)                  public tierIdByName;

    // ================================================================
    // STATE — CAMPAIGN
    // ================================================================
    uint256 private _campaignCounter;
    mapping(uint256 => EconomyTypes.Campaign) public campaigns;
    uint256[]                                 public campaignIds;
    mapping(bytes32 => bool)                  public campaignExecutionLog;
    address public TopUp;
    address public agent;
    address public MANAGEMENT;
    mapping(uint256 => address) public mOrder;
    mapping(uint256 => address) public mTopUp;
    mapping(address => bool) public isOrder;
    mapping(address => bool) public isTopUp;
    uint256 public exchangeRate;          // Tỷ giá: X VND = 1 token
    address public enhancedAgentSC;
    uint256 public maxPercentPerInvoice;  // % tối đa dùng token thanh toán
    uint256 private transactionCounter;
    mapping(uint256 => Transaction) public transactions;
    mapping(address => uint256[]) public memberTransactions;
    mapping(address => PaymentTransaction[]) public memberPaymentHistory;
    bool public manualGrantEnabled;
    // ================================================================
    // [FIX-7] STATE — DEBIT BREAKDOWN
    // ================================================================
    mapping(bytes32 => DebitRecord) public debitByRefId;
    mapping(bytes32 => bool)        public debitRefExists;
    mapping(address => bytes32[])   private customerDebitRefs;
    // ================================================================
    // NEW: STATE — DASHBOARD AGGREGATE
    // Lưu theo key = keccak256(abi.encodePacked(dayBucket, branchId))
    // dayBucket = block.timestamp / 1 days  (số nguyên ngày Unix)
    // ================================================================
      // branchId => dayBucket => DailyStats
    mapping(uint256 => mapping(uint256 => DailyStats)) public dailyStatsByBranch;
    // dayBucket[] đã có data (để liệt kê)
    uint256[] public recordedDays;
    mapping(uint256 => bool) private _dayRecorded;
    uint256 private _execLogCounter;
    mapping(uint256 => CampaignExecRecord) public campaignExecRecords;  // logId => record
    mapping(uint256 => uint256[]) public campaignExecIds;               // campaignId => []logId
    mapping(address => uint256[]) public customerExecIds;               // customer => []logId
    uint256[] public allExecIds;
    uint256 private _changeCounter;
    ChangeRecord[] public changeHistory;
    mapping(uint8 => uint256[]) public changeIdsByType;   // ChangeType(uint8) => []id
    address public searchIndex;
        // ================================================================
    // LOCK POINT
    // Added 09/03/2026 thêm mới cho logic khóa point khi thanh toán trc
    mapping(address => uint256) public lockedBalanceOf;



    struct LockedBatch {
        uint256 batchId;
        uint256 amountTaken;
    }

    struct LockedPoint {
        uint256 amount;
        uint256 amountA;
        uint256 amountB;
        LockedBatch[] lockedBatches; // Ghi nhớ chi tiết từng batch đã trừ
        bytes32 referenceId;
        uint256 lockTimestamp;
        bool active;
    }

    mapping(bytes32 => LockedPoint) public lockedPoints; 

    // ================================================================
    // EVENTS
    // ================================================================
    // Member
    event MemberRegistered(address indexed wallet, string memberId, uint256 timestamp);
    event MemberUpdated(address indexed wallet, string memberId, uint256 timestamp);
    event MemberDeleted(address indexed wallet, uint256 timestamp);
    event MemberLocked(address indexed member, address indexed actor, string reason, uint256 timestamp);
    event MemberUnlocked(address indexed member, address indexed actor, uint256 timestamp);
    event MemberGroupCreated(bytes32 indexed groupId, string name, uint256 timestamp);
    event MemberGroupUpdated(bytes32 indexed groupId, string name, uint256 timestamp);
    event MemberGroupDeleted(bytes32 indexed groupId, uint256 timestamp);
    event MemberAssignedToGroup(address indexed member, bytes32 indexed groupId, uint256 timestamp);
    event MemberRemovedFromGroup(address indexed member, bytes32 indexed groupId, uint256 timestamp);
    event ManualRequestCreated(uint256 indexed requestId, address indexed member, address indexed staff, uint256 timestamp);
    event ManualRequestProcessed(uint256 indexed requestId, bool approved, address indexed admin, uint256 timestamp);
    event ManualGrantEnabledSet(bool enabled, address indexed actor, uint256 timestamp);
    // Token A
    event TokenACredited(
        uint256 indexed branchId,
        address indexed customer,
        uint256 amount,
        bytes32 source,
        bytes32 refId,
        bytes32 idempotencyKey,
        uint256 timestamp
    );
        event TokenADebited(uint256 indexed branchId, address indexed customer, uint256 amount, bytes32 actionType, bytes32 refId, uint256 timestamp);

    // Token B
    event TokenBGranted(address indexed customer, uint256 amount, uint256 campaignId, bytes32 sourceEventId, uint256 expiresAt, uint256 timestamp);
    event TokenBDebited(
        uint256 indexed branchId,
        address indexed customer,
        uint256 amount,
        bytes32 actionType,
        bytes32 refId,
        uint256 timestamp
    );
    event TokenBExpired(address indexed customer, uint256 amount, uint256 timestamp);

    // Earn / Debit flow
    event TokenAEarned(address indexed customer, uint256 inputAmount, uint256 tokenAEarned, uint256 tokenBFromTier, bytes32 idempotencyKey, bytes32 refId, bytes32 eventType);
    event DebitCompleted(address indexed customer, uint256 totalAmount, uint256 spentA, uint256 spentB, bytes32 actionType, bytes32 refId);

    // Policy
    event TopupPolicyUpdated(uint256 rate, uint256 minTopup, uint256 maxTopup);
    event SpendPolicyUpdated(uint8 priority, uint256 maxPercent, uint256 maxAbsolute, uint256 expiryDays);
    event AllowedActionUpdated(bytes32 actionType, bool allowed);

    // Tier
    event TierEnabledSet(address indexed actor, bool enabled, uint256 timestamp);
    event TierDefined(bytes32 indexed tierId, string name, uint256 pointsRequired, uint256 tokenBBonusPercent, uint256 campaignMultiplier, uint256 rewardCapPercentBonus, uint256 rewardCapAbsoluteBonus, address indexed actor, uint256 timestamp);
    event TierDeleted(bytes32 indexed tierId, address indexed actor, uint256 timestamp);
    event CustomerTierChanged(address indexed customer, bytes32 oldTier, bytes32 newTier, address indexed actor, bytes32 refId, uint256 timestamp);

    // Campaign
    event CampaignCreated(uint256 indexed campaignId, string name, bytes32 eventType, uint256 rewardAmount, bool isPercent, bytes32 minTierID);
    event CampaignUpdated(uint256 indexed campaignId, uint256 rewardAmount, bool isPercent, uint256 expiresAt, bytes32 minTierID);
    event CampaignPaused(uint256 indexed campaignId);
    event CampaignResumed(uint256 indexed campaignId);
    event CampaignExecuted(uint256 indexed campaignId, address indexed customer, bytes32 sourceEventId, uint256 baseAmount, uint256 finalAmount, uint256 timestamp);

    event TransactionCreated(uint256 indexed txId, address indexed member, TransactionType txType, int256 points);
    event PointsUsedForPayment(address indexed member, bytes32 indexed paymentId, uint256 pointsUsed, uint256 orderAmount, uint256 timestamp);
    // Added 09/03/2026 - Sự kiện cho logic Lock/Unlock
    event PointsLocked(address indexed member, uint256 amount, bytes32 indexed referenceId);
    event PointsUnlocked(address indexed member, uint256 amount, bytes32 indexed referenceId);
    event PointsBurnConfirmed(address indexed member, uint256 amount, bytes32 indexed referenceId);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // ================================================================
    // MODIFIERS
    // ================================================================
    modifier onlyAdmin() {
        require(IManagement(MANAGEMENT).hasRole(ROLE_ADMIN, msg.sender), "Only admin");
        _;
    }
    modifier onlyStaffOrAdmin() {
        require(IManagement(MANAGEMENT).hasRole(ROLE_ADMIN, msg.sender) ||IManagement(MANAGEMENT).isStaff(msg.sender), "Only staff or admin");
        _;
    }
    modifier onlyStaffWithRoleOrAdmin(STAFF_ROLE role) {
        require(IManagement(MANAGEMENT).checkRole(role, msg.sender), "Only staff with role or admin");
        _;
    }

    modifier onlyOrder() {
        require(isOrder[msg.sender], "Only Order can call");
        _;
    }

    modifier memberExists(address _member) {
        require(members[_member].isActive, "Member not found");
        _;
    }

    modifier notLocked(address _member) {
        require(!members[_member].isLocked, "Account is locked");
        _;
    }

    // ================================================================
    // INIT
    // ================================================================
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    /**
     * @dev Chỉ cần owner — không truyền địa chỉ contract nào.
     */
    function initialize(address _agent,address _enhancedAgentSC) public initializer {
        __Ownable_init(msg.sender);
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ROLE_ADMIN, msg.sender);

        _grantRole(DEFAULT_ADMIN_ROLE, _agent);
        _grantRole(ROLE_ADMIN, _agent);
        exchangeRate = 1000; // 1 _agent unit = 10000 Token A
        topupRate          = exchangeRate;
        topupMin           = 0;
        topupMax           = 0;
        spendPriority      = EconomyTypes.SpendPriority.B_FIRST;
        rewardMaxPercent   = 100;
        rewardMaxAbsolute  = 0;
        defaultExpiryDays  = 0;
        tierEnabled        = false;
        maxPercentPerInvoice = 100; // 100%
        manualGrantEnabled   = false;
        allowedActionTypes[keccak256("ALL")] = true;
        allowedActionTypeList.push(keccak256("ALL"));
        agent = _agent;
        enhancedAgentSC = _enhancedAgentSC;

    }
    function setSearchIndex(address _idx) external onlyOwner {
        searchIndex = _idx;
    }
    function updatemaxPercentPerInvoice(uint256 _maxPercentPerInvoice) external onlyOwner {
        require(_maxPercentPerInvoice > 0, "Invalid maxPercentPerInvoice");
        maxPercentPerInvoice = _maxPercentPerInvoice;
    }
    function setManagementSC(address _management) external onlyOwner {
        MANAGEMENT = _management;
    }
        /**
     * @dev Cập nhật tỷ giá quy đổi
     */
    function updateExchangeRate(uint256 _newRate) external onlyStaffOrAdmin {
        require(_newRate > 0, "Invalid rate");
        exchangeRate = _newRate;
    }

    function setOrder(address _order,uint256 branchId) external onlyOwner {
        mOrder[branchId] = _order;
        isOrder[_order] = true;
        
    }
    function setTopUp(address _topup,uint256 branchId) external onlyOwner {
        mTopUp[branchId] = _topup;
        isTopUp[_topup] = true;
    }
    function setManualGrantEnabled(bool _enabled) external onlyAdmin {
        manualGrantEnabled = _enabled;
        emit ManualGrantEnabledSet(_enabled, msg.sender, block.timestamp);
    }

    // ================================================================
    // MEMBER — SELF REGISTRATION
    // ================================================================

    /**
     * @dev Khách tự đăng ký bằng wallet của mình.
     */
    function registerMember(RegisterInPut calldata input) external {
        require(bytes(input._memberId).length >= 8 && bytes(input._memberId).length <= 12, "Invalid memberId length");
        require(!members[msg.sender].isActive, "Already registered");
        require(memberIdToAddress[input._memberId] == address(0), "MemberId already exists");

        members[msg.sender] = Member({
            memberId:          input._memberId,
            walletAddress:     msg.sender,
            totalPoints:       0,
            lifetimePoints:    0,
            totalSpent:        0,
            tierID:            bytes32(0),
            lastBuyActivityAt: 0,
            isActive:          true,
            isLocked:          false,
            phoneNumber:       input._phoneNumber,
            firstName:         input._firstName,
            lastName:          input._lastName,
            whatsapp:          input._whatsapp,
            email:             input._email,
            avatar:            input._avatar
        });

        memberIdToAddress[input._memberId] = msg.sender;
        allMembers.push(members[msg.sender]);

        if (!isTokenHolder[msg.sender]) {
            tokenHolders.push(msg.sender);
            isTokenHolder[msg.sender] = true;
        }
        _recordDailyStatNewMember(0);
        emit MemberRegistered(msg.sender, input._memberId, block.timestamp);
    }

    /**
     * @dev Khách tự cập nhật thông tin của mình.
     */
    function updateMember(UpdateMemberInput calldata input) external memberExists(msg.sender) notLocked(msg.sender) {
        require(bytes(input._memberId).length >= 8 && bytes(input._memberId).length <= 12, "Invalid memberId length");

        Member storage m = members[msg.sender];
        bool sameId = keccak256(bytes(m.memberId)) == keccak256(bytes(input._memberId));
        require(sameId || memberIdToAddress[input._memberId] == address(0), "MemberId already exists");

        if (!sameId) {
            delete memberIdToAddress[m.memberId];
            m.memberId = input._memberId;
            memberIdToAddress[input._memberId] = msg.sender;
        }

        m.phoneNumber = input._phoneNumber;
        m.firstName   = input._firstName;
        m.lastName    = input._lastName;
        m.whatsapp    = input._whatsapp;
        m.email       = input._email;
        m.avatar      = input._avatar;

        _syncAllMembersEntry(msg.sender);
        emit MemberUpdated(msg.sender, m.memberId, block.timestamp);
    }

    /**
     * @dev Owner/CoOwner xóa member (ví dụ: vi phạm).
     */
    function deleteMember(address _member) external onlyAdmin {
        require(members[_member].walletAddress != address(0), "Member not found");

        bytes32[] memory groups = memberToGroups[_member];
        for (uint256 i = 0; i < groups.length; i++) {
            _removeMemberFromGroupArray(groups[i], _member);
        }
        delete memberToGroups[_member];
        delete memberIdToAddress[members[_member].memberId];
        delete members[_member];

        for (uint256 i = 0; i < allMembers.length; i++) {
            if (allMembers[i].walletAddress == _member) {
                allMembers[i] = allMembers[allMembers.length - 1];
                allMembers.pop();
                break;
            }
        }
        emit MemberDeleted(_member, block.timestamp);
    }

    function lockMember(address _member, string calldata reason) external onlyAdmin memberExists(_member) {
        members[_member].isLocked = true;
        _syncAllMembersEntry(_member);
        emit MemberLocked(_member, msg.sender, reason, block.timestamp);
    }

    function unlockMember(address _member) external onlyAdmin memberExists(_member) {
        members[_member].isLocked = false;
        _syncAllMembersEntry(_member);
        emit MemberUnlocked(_member, msg.sender, block.timestamp);
    }

    /**
     * @dev Cập nhật lastBuyActivityAt — gọi bởi Order/Net/Food module.
     */
    function updateLastBuyActivityAt(address _member) external onlyOrder {
        if (members[_member].isActive) members[_member].lastBuyActivityAt = block.timestamp;
    }

    // ================================================================
    // MEMBER — GROUPS
    // ================================================================

    function createMemberGroup(string calldata _name) external onlyAdmin returns (bytes32) {
        require(bytes(_name).length > 0, "Name required");
        bytes32 groupId = keccak256(abi.encodePacked(_name, block.timestamp));
        require(memberGroups[groupId].id == bytes32(0), "Group exists");

        memberGroups[groupId] = MemberGroup({ id: groupId, name: _name, isActive: true, createdAt: block.timestamp });
        allMemberGroups.push(memberGroups[groupId]);
        allGroupIds.push(groupId);

        emit MemberGroupCreated(groupId, _name, block.timestamp);
        return groupId;
    }
    function getMemberToGroups(address _member) external view returns(bytes32[] memory){
        return memberToGroups[_member];
    }

    function isMemberPointSystem(address _user) external view returns (bool){
        return(members[_user].isActive);
    }
    function isMemberGroupId(bytes32 groupId) external view returns (bool) {
        return (memberGroups[groupId].id != bytes32(0));
    }

    function updateMemberGroup(bytes32 _groupId, string calldata _name, bool _isActive) external onlyAdmin {
        require(memberGroups[_groupId].id != bytes32(0), "Group not found");
        memberGroups[_groupId].name     = _name;
        memberGroups[_groupId].isActive = _isActive;
        for (uint256 i = 0; i < allMemberGroups.length; i++) {
            if (allMemberGroups[i].id == _groupId) { allMemberGroups[i] = memberGroups[_groupId]; break; }
        }
        emit MemberGroupUpdated(_groupId, _name, block.timestamp);
    }

    function deleteMemberGroup(bytes32 _groupId) external onlyAdmin {
        require(memberGroups[_groupId].id != bytes32(0), "Group not found");
        address[] memory gm = groupMembers[_groupId];
        for (uint256 i = 0; i < gm.length; i++) {
            _removeGroupFromMember(gm[i], _groupId);
        }
        delete groupMembers[_groupId];
        delete memberGroups[_groupId];
        for (uint256 i = 0; i < allMemberGroups.length; i++) {
            if (allMemberGroups[i].id == _groupId) {
                allMemberGroups[i] = allMemberGroups[allMemberGroups.length - 1];
                allMemberGroups.pop();
                break;
            }
        }
        for (uint256 i = 0; i < allGroupIds.length; i++) {
            if (allGroupIds[i] == _groupId) {
                allGroupIds[i] = allGroupIds[allGroupIds.length - 1];
                allGroupIds.pop();
                break;
            }
        }
        emit MemberGroupDeleted(_groupId, block.timestamp);
    }

    function assignMemberToGroup(address _member, bytes32 _groupId) external onlyAdmin memberExists(_member) {
        require(memberGroups[_groupId].id != bytes32(0), "Group not found");
        require(!_isMemberInGroup(_member, _groupId), "Already in group");
        memberToGroups[_member].push(_groupId);
        groupMembers[_groupId].push(_member);
        emit MemberAssignedToGroup(_member, _groupId, block.timestamp);
    }

    function batchAssignMemberToGroups(address _member, bytes32[] calldata _groupIds) external onlyAdmin memberExists(_member) {
        for (uint256 i = 0; i < _groupIds.length; i++) {
            bytes32 gid = _groupIds[i];
            if (memberGroups[gid].id == bytes32(0)) continue;
            if (_isMemberInGroup(_member, gid)) continue;
            memberToGroups[_member].push(gid);
            groupMembers[gid].push(_member);
            emit MemberAssignedToGroup(_member, gid, block.timestamp);
        }
    }

    function removeMemberFromGroup(address _member, bytes32 _groupId) external onlyAdmin {
        _removeMemberFromGroupArray(_groupId, _member);
        _removeGroupFromMember(_member, _groupId);
        emit MemberRemovedFromGroup(_member, _groupId, block.timestamp);
    }

    // ================================================================
    // MEMBER — MANUAL REQUEST (staff tạo, admin duyệt)
    // ================================================================

    /**
     * @dev Staff tạo manual request earn Token A cho customer.
     *      Admin duyệt → credit Token A.
     */
    function createManualRequest(
        string   calldata _memberID,
        bytes32  _invoiceId,
        uint256  _amount,
        RequestEarnPointType _typeRequest,
        string   calldata _img
    ) external onlyStaffOrAdmin returns (uint256) {
        address _member = memberIdToAddress[_memberID];
        require(members[_member].isActive, "Member not found");
        require(!processedInvoices[_invoiceId], "Invoice already processed");

        // Rate limit staff: max 50 requests/ngày
        if (block.timestamp / 1 days > lastRequestDate[msg.sender] / 1 days) {
            staffDailyRequests[msg.sender] = 0;
            lastRequestDate[msg.sender]    = block.timestamp;
        }
        require(staffDailyRequests[msg.sender] < 50, "Daily request limit reached");

        uint256 pointsToEarn = topupRate > 0 ? _amount / topupRate : 0;

        _requestCounter++;
        manualRequests[_requestCounter] = ManualRequest({
            id:           _requestCounter,
            member:       _member,
            invoiceId:    _invoiceId,
            amount:       _amount,
            pointsToEarn: pointsToEarn,
            requestedBy:  msg.sender,
            requestTime:  block.timestamp,
            status:       RequestStatus.Pending,
            approvedBy:   address(0),
            approvedTime: 0,
            rejectReason: "",
            typeRequest:  _typeRequest,
            img:          _img
        });

        staffDailyRequests[msg.sender]++;
        emit ManualRequestCreated(_requestCounter, _member, msg.sender, block.timestamp);
        return _requestCounter;
    }

    /**
     * @dev Admin duyệt manual request → credit Token A cho customer.
     */
    function approveManualRequest(uint256 _requestId,uint256 _branchId) external onlyAdmin {
        ManualRequest storage req = manualRequests[_requestId];
        require(req.id != 0, "Request not found");
        require(req.status == RequestStatus.Pending, "Not pending");
        require(!processedInvoices[req.invoiceId], "Invoice already processed");

        req.status      = RequestStatus.Approved;
        req.approvedBy  = msg.sender;
        req.approvedTime = block.timestamp;
        processedInvoices[req.invoiceId] = true;

        if (req.pointsToEarn > 0) {
            _creditA(req.member, req.pointsToEarn, req.invoiceId, req.invoiceId,FOOD_MODULE,_branchId);
            _createTransaction(req.member, TransactionType.Earn, int256(req.pointsToEarn), req.amount, req.invoiceId, "ManualRequest approved", 0,_branchId,FOOD_MODULE);
            _updateMemberPoints(req.member);
        }

        emit ManualRequestProcessed(_requestId, true, msg.sender, block.timestamp);
    }

    function rejectManualRequest(uint256 _requestId, string calldata _reason) external onlyAdmin {
        ManualRequest storage req = manualRequests[_requestId];
        require(req.id != 0, "Request not found");
        require(req.status == RequestStatus.Pending, "Not pending");
        req.status       = RequestStatus.Rejected;
        req.approvedBy   = msg.sender;
        req.approvedTime = block.timestamp;
        req.rejectReason = _reason;
        emit ManualRequestProcessed(_requestId, false, msg.sender, block.timestamp);
    }
    function _isValidAmount(bytes32 _paymentId,uint _amount, bool isTopup,uint256 _branchId)internal view returns(bool){
        if(isTopup){
            require(mTopUp[_branchId] != address(0),"TopUp address not set yet");
            return INetCafeTopUp(mTopUp[_branchId]).isValidAmount(_paymentId,_amount);
        }else{
            require(mOrder[_branchId] != address(0), "Order address not set yet");
            return IOrder(mOrder[_branchId]).isValidAmount(_paymentId,_amount);
        }
    } 

    // ================================================================
    // CORE — EARN TOKEN A (topup / hóa đơn)
    // ================================================================

    /**
     * @dev Entry point chính: earn Token A từ topup hoặc ghi nhận hóa đơn.
     *
     * @param customer       Khách hàng
     * @param inputAmount    Số tiền (VND) hoặc giá trị hóa đơn
     * @param idempotencyKey Key chống duplicate
     * @param refId          Reference ID
     * @param eventType      EVENT_TOPUP / EVENT_NET_SETTLED / EVENT_FOOD_PAID
     * @param branchId       Branch ID (uint256) để filter campaign scope
     */
    function earnTokenA(
        address customer,
        uint256 inputAmount,
        bytes32 idempotencyKey,
        bytes32 refId, //invoiceId cho event hóa đơn, topupId cho event topup
        bytes32 eventType,
        uint256 branchId,
        bool isTopup
    ) external  nonReentrant whenNotPaused {
        require(members[customer].isActive, "Customer is not a member");
        require(customer != address(0), "Invalid customer");
        require(inputAmount > 0, "Amount must be > 0");
        require(idempotencyKey != bytes32(0), "Idempotency key required");
        require(eventType != bytes32(0), "Event type required");
        require(_isValidAmount(refId,inputAmount,isTopup,branchId),"amount earnPoint not match invoiceId");
        require(!processedInvoices[refId], "Invoice already processed");

        uint256 tokenA = _calcTokenA(inputAmount);
        require(tokenA > 0, "Token A is 0 after conversion");
        bytes32 source = isTopup ? NET_MODULE : FOOD_MODULE;
        _creditA(customer, tokenA, idempotencyKey, refId, source, branchId);
        _createTransaction(customer, TransactionType.Earn, int256(tokenA), inputAmount, refId, isTopup ? "Topup earn" : "Invoice earn", 0,branchId, source);
        
        uint256 tokenBFromTier = 0;
        if (tierEnabled) {
            lifetimeTokenA[customer] += tokenA;
            tokenBFromTier = _calcTierTokenBBonus(customer, tokenA);
            if (tokenBFromTier > 0)
                _grantB(customer, tokenBFromTier, 0, idempotencyKey, _calcExpiresAt());
                _createTransaction(customer, TransactionType.Issue, int256(tokenBFromTier), 0, idempotencyKey, "Tier bonus grant", 0,branchId, source);
        }

        _updateMemberPoints(customer);
        emit TokenAEarned(customer, inputAmount, tokenA, tokenBFromTier, idempotencyKey, refId, eventType);
        _executeCampaigns(eventType, idempotencyKey, customer, inputAmount, branchId);
        processedInvoices[refId] = true;

    }

    /**
     * @dev Shortcut topup — eventType = EVENT_TOPUP.
     */
    function creditTopup(
        address customer,
        uint256 inputAmount,
        bytes32 idempotencyKey,
        bytes32 refId,
        uint256 branchId
    ) external onlyStaffWithRoleOrAdmin(STAFF_ROLE.FINANCE) nonReentrant whenNotPaused {
        require(customer != address(0), "Invalid customer");
        require(inputAmount > 0, "Amount must be > 0");
        require(idempotencyKey != bytes32(0), "Idempotency key required");
        require(members[customer].isActive, "Customer is not a member");
        uint256 tokenA = _calcTokenA(inputAmount);
        require(tokenA > 0, "Token A is 0");
        require(_isValidAmount(refId,inputAmount,true,branchId),"amount earnPoint not match invoiceId");
        require(!processedInvoices[refId], "Invoice already processed");

        _creditA(customer, tokenA, idempotencyKey, refId, NET_MODULE, branchId);
        _createTransaction(customer, TransactionType.Earn, int256(tokenA), inputAmount, refId, "Staff creditTopup", 0,branchId, NET_MODULE);

        uint256 tokenBFromTier = 0;
        if (tierEnabled) {
            lifetimeTokenA[customer] += tokenA;
            tokenBFromTier = _calcTierTokenBBonus(customer, tokenA);
            if (tokenBFromTier > 0)
                _grantB(customer, tokenBFromTier, 0, idempotencyKey, _calcExpiresAt());
                _createTransaction(customer, TransactionType.Issue, int256(tokenBFromTier), 0, idempotencyKey, "Tier bonus grant", 0,branchId, NET_MODULE);
        }

        _updateMemberPoints(customer);
        emit TokenAEarned(customer, inputAmount, tokenA, tokenBFromTier, idempotencyKey, refId, EconomyTypes.EVENT_TOPUP);
        _executeCampaigns(EconomyTypes.EVENT_TOPUP, idempotencyKey, customer, inputAmount, branchId);
        processedInvoices[refId] = true;
    }

    // ================================================================
    // CORE — DEBIT
    // ================================================================

    function debit(
        address customer,
        uint256 amount,
        bytes32 actionType,
        bytes32 refId,
        uint256 branchId,
        bytes32 source // NET_MODULE, FOOD_MODULE, hoặc custom source để phân loại giao dịch (ví dụ: EVENT_INVOICE_PAYMENT)
    ) external onlyStaffWithRoleOrAdmin(STAFF_ROLE.FINANCE) nonReentrant whenNotPaused returns (uint256 spentA, uint256 spentB) {
        require(customer != address(0), "Invalid customer");
        require(amount > 0, "Amount must be > 0");
        require(!members[customer].isLocked, "Account is locked");
        require(members[customer].isActive, "Customer is not a member");
        require(refId != bytes32(0), "refId required");
        require(!debitRefExists[refId], "Duplicate refId");

        bool    canUseB = _isActionAllowedForB(actionType);
        uint256 balA    = _balanceA[customer];
        uint256 maxB    = 0;

        if (canUseB) {
            _expireBatches(customer);
            uint256 balB        = _balanceB[customer];
            uint256 effectivePct = rewardMaxPercent;
            uint256 effectiveAbs = rewardMaxAbsolute;

            if (tierEnabled) {
                (uint256 capPct, uint256 capAbs) = _getSpendCapBonus(customer);
                effectivePct = effectivePct + capPct;
                if (effectivePct > 100) effectivePct = 100;
                if (effectiveAbs > 0) effectiveAbs = effectiveAbs + capAbs;
            }

            maxB = (amount * effectivePct) / 100;
            if (effectiveAbs > 0 && maxB > effectiveAbs) maxB = effectiveAbs;
            if (maxB > balB) maxB = balB;
        }

        (spentA, spentB) = _calcDebitSplit(amount, balA, maxB, spendPriority);
        require(spentA + spentB == amount, "Debit split mismatch");

        if (spentA > 0) _debitA(customer, spentA, actionType, refId,branchId);
        if (spentB > 0) _debitB(customer, spentB, actionType, refId,branchId);

        if (members[customer].isActive) {
            members[customer].totalSpent += amount;
            _syncAllMembersEntry(customer);
        }
        debitByRefId[refId] = DebitRecord({
            customer:   customer,
            actionType: actionType,
            refId:      refId,
            amount:     amount,
            spentA:     spentA,
            spentB:     spentB,
            timestamp:  block.timestamp
        });
        debitRefExists[refId] = true;
        customerDebitRefs[customer].push(refId);
        _createTransaction(customer, TransactionType.Redeem, -int256(amount), amount, refId,
            string(abi.encodePacked("Debit spentA:", spentA.toString(), " spentB:", spentB.toString())), 0,branchId, source);
        emit DebitCompleted(customer, amount, spentA, spentB, actionType, refId);
    }

    function grantTokenBManual(
        address customer,
        uint256 amount,
        bytes32 sourceEventId,
        uint256 _branchId,
        bytes32 source // NET_MODULE, FOOD_MODULE, hoặc custom source để phân loại giao dịch (ví dụ: EVENT_INVOICE_PAYMENT)
    ) onlyStaffWithRoleOrAdmin(STAFF_ROLE.FINANCE) external nonReentrant whenNotPaused {
        require(manualGrantEnabled, "Manual grant is disabled");
        
        require(customer != address(0), "Invalid customer");
        require(amount > 0, "Amount must be > 0");
        require(sourceEventId != bytes32(0), "sourceEventId required");
        require(members[customer].isActive, "Customer is not a member");
        _grantB(customer, amount, 0, sourceEventId, _calcExpiresAt());
        _createTransaction(customer, TransactionType.Issue, int256(amount), 0, sourceEventId, "Manual grant Token B", 0,_branchId, source);
    }

    // ================================================================
    // STAFF ASSIST
    // ================================================================

    function creditAssist(address customer, uint256 inputAmount, bytes32 idempotencyKey, bytes32 refId, uint256 _branchId, bytes32 source)
        external onlyStaffWithRoleOrAdmin(STAFF_ROLE.FINANCE) nonReentrant whenNotPaused
    {
        require(members[customer].isActive, "Customer is not a member");
        uint256 tokenA = _calcTokenA(inputAmount);
        require(tokenA > 0, "Token A is 0");
        _creditA(customer, tokenA, idempotencyKey, refId, NET_MODULE,_branchId);
        _createTransaction(customer, TransactionType.Earn, int256(tokenA), inputAmount, refId, "Staff creditAssist", 0,_branchId, source);
        _updateMemberPoints(customer);
        emit TokenAEarned(customer, inputAmount, tokenA, 0, idempotencyKey, refId, EconomyTypes.ACTION_MANUAL);
    }

    function debitAAssist(address customer, uint256 amount, bytes32 actionType, bytes32 refId, uint256 _branchId, bytes32 source)
        external onlyStaffWithRoleOrAdmin(STAFF_ROLE.FINANCE) nonReentrant whenNotPaused
    {
        require(members[customer].isActive, "Customer is not a member");
        _debitA(customer, amount, actionType, refId,_branchId);
        _createTransaction(customer, TransactionType.Redeem, -int256(amount), amount, refId, "Staff debitA assist", 0,_branchId, source);
        _updateMemberPoints(customer);
    }

    function debitBAssist(address customer, uint256 amount, bytes32 actionType, bytes32 refId, uint256 _branchId, bytes32 source)
        external onlyStaffWithRoleOrAdmin(STAFF_ROLE.FINANCE) nonReentrant whenNotPaused
    {
        require(members[customer].isActive, "Customer is not a member");
        _requireActionAllowedForB(actionType);
        _expireBatches(customer);
        _debitB(customer, amount, actionType, refId,_branchId);
        _createTransaction(customer, TransactionType.Redeem, -int256(amount), amount, refId, "Staff debitB assist", 0,_branchId, source);
        _updateMemberPoints(customer);
    }

    // ================================================================
    // POLICY CONFIG
    // ================================================================

    function setTopupPolicy(uint256 rate, uint256 minTopup, uint256 maxTopup) external onlyAdmin {
        require(rate > 0, "Invalid rate");
        if (maxTopup > 0) require(maxTopup >= minTopup, "Invalid range");
        topupRate = rate; topupMin = minTopup; topupMax = maxTopup;
        _recordChange(ChangeType.TopupPolicy, abi.encode(rate, minTopup, maxTopup));
        emit TopupPolicyUpdated(rate, minTopup, maxTopup);
    }

    function setSpendPolicy(uint8 priority, uint256 maxPercent, uint256 maxAbsolute, uint256 expiryDays)
        external onlyAdmin
    {
        require(priority <= 2, "Invalid priority");
        require(maxPercent <= 100, "Percent 0-100");
        spendPriority = EconomyTypes.SpendPriority(priority);
        rewardMaxPercent  = maxPercent;
        rewardMaxAbsolute = maxAbsolute;
        defaultExpiryDays = expiryDays;
        _recordChange(ChangeType.SpendPolicy, abi.encode(priority, maxPercent, maxAbsolute, expiryDays));
        emit SpendPolicyUpdated(priority, maxPercent, maxAbsolute, expiryDays);
    }

    function setAllowedActionTypes(bytes32[] calldata types, bool[] calldata allowed) external onlyAdmin {
        require(types.length == allowed.length, "Length mismatch");
        for (uint256 i = 0; i < allowedActionTypeList.length; i++)
            allowedActionTypes[allowedActionTypeList[i]] = false;
        delete allowedActionTypeList;
        for (uint256 i = 0; i < types.length; i++) {
            allowedActionTypes[types[i]] = allowed[i];
            if (allowed[i]) allowedActionTypeList.push(types[i]);
            emit AllowedActionUpdated(types[i], allowed[i]);
        }
    }

    // ================================================================
    // TIER CONFIG
    // ================================================================

    function setTierEnabled(bool _enabled) external onlyAdmin {
        tierEnabled = _enabled;
        emit TierEnabledSet(msg.sender, _enabled, block.timestamp);
    }

    function createTier(
        string  calldata _name,
        uint256 _pointsRequired,
        uint256 _tokenBBonusPercent,
        uint256 _campaignMultiplier,
        uint256 _rewardCapPercentBonus,
        uint256 _rewardCapAbsoluteBonus,
        string  calldata _colour
    ) external onlyAdmin {
        require(bytes(_name).length > 0, "Name required");
        require(_campaignMultiplier >= 100, "Multiplier min 100");
        require(tierIdByName[_name] == bytes32(0), "Name duplicate");
        require(_rewardCapPercentBonus <= 100, "Cap percent max 100");
        for (uint256 i = 0; i < allTiers.length; i++)
            require(allTiers[i].pointsRequired != _pointsRequired, "pointsRequired duplicate");

        bytes32 tierId = keccak256(abi.encodePacked(_name, block.timestamp));
        EconomyTypes.TierConfig memory t = EconomyTypes.TierConfig({
            id: tierId, 
            name: _name, 
            pointsRequired: _pointsRequired, 
            pointsMax: type(uint256).max,
            tokenBBonusPercent: _tokenBBonusPercent, 
            campaignMultiplier: _campaignMultiplier,
            rewardCapPercentBonus: _rewardCapPercentBonus, 
            rewardCapAbsoluteBonus: _rewardCapAbsoluteBonus,
            colour: _colour
        });
        tierConfigs[tierId] = t;
        allTiers.push(t);
        tierIdByName[_name] = tierId;
        _sortTierRanges();
        _recordChange(ChangeType.TierCreated, abi.encode(tierId, _name, _pointsRequired, _tokenBBonusPercent, _campaignMultiplier));
        emit TierDefined(tierId, _name, _pointsRequired, _tokenBBonusPercent, _campaignMultiplier, _rewardCapPercentBonus, _rewardCapAbsoluteBonus, msg.sender, block.timestamp);
    }

    function updateTier(
        bytes32 _tierId,
        string  calldata _name,
        uint256 _pointsRequired,
        uint256 _tokenBBonusPercent,
        uint256 _campaignMultiplier,
        uint256 _rewardCapPercentBonus,
        uint256 _rewardCapAbsoluteBonus,
        string  calldata _colour
    ) external onlyAdmin {
        require(tierConfigs[_tierId].id != bytes32(0), "Tier not found");
        require(_campaignMultiplier >= 100, "Multiplier min 100");
        require(_rewardCapPercentBonus <= 100, "Cap percent max 100");
        EconomyTypes.TierConfig storage tier = tierConfigs[_tierId];
        if (_pointsRequired > 0 && _pointsRequired != tier.pointsRequired) {
            for (uint256 i = 0; i < allTiers.length; i++)
                if (allTiers[i].id != _tierId) require(allTiers[i].pointsRequired != _pointsRequired, "pointsRequired duplicate");
            tier.pointsRequired = _pointsRequired;
        }
        if (bytes(_name).length > 0 && keccak256(bytes(_name)) != keccak256(bytes(tier.name))) {
            require(tierIdByName[_name] == bytes32(0), "Name duplicate");
            delete tierIdByName[tier.name];
            tier.name = _name;
            tierIdByName[_name] = _tierId;
        }
        tier.tokenBBonusPercent = _tokenBBonusPercent;
        tier.campaignMultiplier = _campaignMultiplier;
        tier.rewardCapPercentBonus  = _rewardCapPercentBonus;
        tier.rewardCapAbsoluteBonus = _rewardCapAbsoluteBonus;
        if (bytes(_colour).length > 0) tier.colour = _colour;
        for (uint256 i = 0; i < allTiers.length; i++)
            if (allTiers[i].id == _tierId) { allTiers[i] = tier; break; }
        _sortTierRanges();
        _recordChange(ChangeType.TierUpdated, abi.encode(_tierId, tier.name, tier.pointsRequired, _tokenBBonusPercent, _campaignMultiplier));
        emit TierDefined(_tierId, tier.name, tier.pointsRequired, _tokenBBonusPercent, _campaignMultiplier, _rewardCapPercentBonus, _rewardCapAbsoluteBonus, msg.sender, block.timestamp);
    }

    function deleteTier(bytes32 _tierId) external onlyAdmin {
        require(tierConfigs[_tierId].id != bytes32(0), "Tier not found");
        // NEW: lưu change history trước khi xoá
        _recordChange(ChangeType.TierDeleted, abi.encode(_tierId, tierConfigs[_tierId].name));
        delete tierIdByName[tierConfigs[_tierId].name];
        delete tierConfigs[_tierId];
        for (uint256 i = 0; i < allTiers.length; i++) {
            if (allTiers[i].id == _tierId) { allTiers[i] = allTiers[allTiers.length - 1]; allTiers.pop(); break; }
        }
        _sortTierRanges();
        emit TierDeleted(_tierId, msg.sender, block.timestamp);
    }

    // ================================================================
    // TIER ASSIGNMENT
    // ================================================================

    function setTier(address customer, bytes32 tierId, bytes32 refId) external onlyAdmin {
        require(customer != address(0), "Invalid customer");
        if (tierId != bytes32(0)) require(tierConfigs[tierId].id != bytes32(0), "Tier not found");
        bytes32 old = customerTier[customer];
        customerTier[customer] = tierId;
        if (members[customer].isActive) {
            members[customer].tierID = tierId;
            _syncAllMembersEntry(customer);
        }
        emit CustomerTierChanged(customer, old, tierId, msg.sender, refId, block.timestamp);
    }

    function setTierForBatch(address[] calldata customers, bytes32 tierId, bytes32 refId) external onlyAdmin {
        require(customers.length > 0, "Empty list");
        if (tierId != bytes32(0)) require(tierConfigs[tierId].id != bytes32(0), "Tier not found");
        for (uint256 i = 0; i < customers.length; i++) {
            address c = customers[i];
            if (c == address(0) || customerTier[c] == tierId) continue;
            bytes32 old = customerTier[c];
            customerTier[c] = tierId;
            if (members[c].isActive) { members[c].tierID = tierId; _syncAllMembersEntry(c); }
            emit CustomerTierChanged(c, old, tierId, msg.sender, refId, block.timestamp);
        }
    }

    // ================================================================
    // CAMPAIGN CRUD
    // ================================================================

   function createCampaign(
        string    calldata name,
        bytes32   eventType,
        uint256   minAmount,
        uint256   rewardAmount,
        bool      isPercent,
        uint256   branchScope,
        uint256   exclusiveGroup,
        uint256   priority,
        bool      stackable,
        uint256   expiresAt,
        bytes32   minTierID,
        bytes32[] calldata allowedTiers,
        uint256   rewardExpiryDaysOverride  // [FIX-5] 0 = dùng default
    ) external onlyAdmin returns (uint256 campaignId) {
        require(bytes(name).length > 0, "Name required");
        require(eventType != bytes32(0), "Event type required");
        require(rewardAmount > 0, "Reward must be > 0");
        if (isPercent) require(rewardAmount <= 100, "Percent max 100");

        // [FIX-10] Validate tier IDs
        _validateTierFilter(minTierID, allowedTiers);

        _campaignCounter++;
        campaignId = _campaignCounter;

        campaigns[campaignId] = EconomyTypes.Campaign({
            id: campaignId,
            name: name,
            eventType: eventType,
            minAmount: minAmount,
            rewardAmount: rewardAmount,
            isPercent: isPercent,
            branchScope: branchScope,
            exclusiveGroup: exclusiveGroup,
            priority: priority,
            stackable: stackable,
            active: true,
            expiresAt: expiresAt,
            minTierID: minTierID,
            allowedTiers: allowedTiers,
            rewardExpiryDaysOverride: rewardExpiryDaysOverride  // [FIX-5]
        });
        campaignIds.push(campaignId);
        _recordChange(ChangeType.CampaignCreated, abi.encode(campaignId, name, eventType, rewardAmount, isPercent, expiresAt));
        emit CampaignCreated(campaignId, name, eventType, rewardAmount, isPercent, minTierID);
    }

    function updateCampaign(
        uint256   campaignId,
        uint256   rewardAmount,
        bool      isPercent,
        uint256   expiresAt,
        bytes32   minTierID,
        bytes32[] calldata allowedTiers,
        uint256   rewardExpiryDaysOverride  // [FIX-5]
    ) external onlyAdmin {
        require(campaigns[campaignId].id != 0, "Campaign not found");
        require(rewardAmount > 0, "Reward must be > 0");
        if (isPercent) require(rewardAmount <= 100, "Percent max 100");

        // [FIX-10] Validate tier IDs
        _validateTierFilter(minTierID, allowedTiers);

        EconomyTypes.Campaign storage c = campaigns[campaignId];
        c.rewardAmount             = rewardAmount;
        c.isPercent                = isPercent;
        c.expiresAt                = expiresAt;
        c.minTierID                = minTierID;
        c.allowedTiers             = allowedTiers;
        c.rewardExpiryDaysOverride = rewardExpiryDaysOverride;  // [FIX-5]
        _recordChange(ChangeType.CampaignUpdated, abi.encode(campaignId, rewardAmount, isPercent, expiresAt, minTierID));
        emit CampaignUpdated(campaignId, rewardAmount, isPercent, expiresAt, minTierID);
    }
    function _validateTierFilter(bytes32 minTierID, bytes32[] calldata allowedTiers) internal view {
        // minTierID: nếu khác 0 và khác TIER_BASE thì phải tồn tại
        if (minTierID != bytes32(0) && minTierID != EconomyTypes.TIER_BASE) {
            require(tierConfigs[minTierID].id != bytes32(0), "minTierID does not exist");
        }
        // Nếu tierEnabled = false mà truyền filter khác BASE thì cảnh báo sớm
        if (!tierEnabled && minTierID != bytes32(0) && minTierID != EconomyTypes.TIER_BASE) {
            revert("Tier filter invalid: tierEnabled is false");
        }

        // allowedTiers: mỗi phần tử phải là TIER_BASE hoặc tồn tại, không trùng
        for (uint256 i = 0; i < allowedTiers.length; i++) {
            bytes32 tid = allowedTiers[i];
            if (tid != EconomyTypes.TIER_BASE && tid != bytes32(0)) {
                require(tierConfigs[tid].id != bytes32(0), "allowedTiers contains non-existent tier");
            }
            // Không cho duplicate
            for (uint256 j = i + 1; j < allowedTiers.length; j++) {
                require(allowedTiers[i] != allowedTiers[j], "allowedTiers has duplicate");
            }
        }
    }
    function pauseCampaign(uint256 campaignId)  external onlyAdmin { 
        require(campaigns[campaignId].id != 0, "Not found"); 
        campaigns[campaignId].active = false; 
        _recordChange(ChangeType.CampaignPaused, abi.encode(campaignId));
        emit CampaignPaused(campaignId);
    }
    function resumeCampaign(uint256 campaignId) external onlyAdmin { 
        require(campaigns[campaignId].id != 0, "Not found"); 
        campaigns[campaignId].active = true;  
        _recordChange(ChangeType.CampaignResumed, abi.encode(campaignId)); 
        emit CampaignResumed(campaignId);
    }

    // ================================================================
    // VIEW
    // ================================================================

    // function getMember(address _member) external onlyStaffOrAdmin view returns (Member memory) {
    function getMember(address _member) external  view returns (Member memory) {

        console.log("MANAGEMENT lafaaa:",address(MANAGEMENT));
        require(IManagement(MANAGEMENT).hasRole(ROLE_ADMIN, msg.sender) ||IManagement(MANAGEMENT).isStaff(msg.sender), "Only staff or admin");

        return members[_member];
    }
    function getPaymentConfig() external view returns (uint256 ,uint256 ) 
    {
        return (exchangeRate, maxPercentPerInvoice);
    }

    function getMemberByMemberId(string calldata _memberId) external view returns (Member memory) {
        address wallet = memberIdToAddress[_memberId];
        require(wallet != address(0), "Member not found");
        return members[wallet];
    }

    function isMember(address _user) external view returns (bool) {
        return members[_user].isActive;
    }

    function getAllMembersPagination(uint256 offset, uint256 limit)
        external onlyStaffOrAdmin view returns (Member[] memory result, uint256 totalCount)
    {
        uint256 len = allMembers.length;
        if (offset >= len) return (new Member[](0), len);
        uint256 size = (offset + limit > len ? len : offset + limit) - offset;
        result = new Member[](size);
        for (uint256 i = 0; i < size; i++) result[i] = allMembers[len - 1 - offset - i];
        return (result, len);
    }

    function getMemberGroups(address _member) external view returns (bytes32[] memory groupIds, MemberGroup[] memory details) {
        groupIds = memberToGroups[_member];
        details  = new MemberGroup[](groupIds.length);
        for (uint256 i = 0; i < groupIds.length; i++) details[i] = memberGroups[groupIds[i]];
    }

    function getAllGroups() external view returns (MemberGroup[] memory) { return allMemberGroups; }

    function getManualRequestsPagination(uint256 offset, uint256 limit)
        external view returns (ManualRequest[] memory result, uint256 totalCount)
    {
        uint256 total = _requestCounter;
        if (offset >= total) return (new ManualRequest[](0), total);
        uint256 size = (offset + limit > total ? total : offset + limit) - offset;
        result = new ManualRequest[](size);
        for (uint256 i = 0; i < size; i++) result[i] = manualRequests[total - offset - i];
        return (result, total);
    }

    function balanceA(address customer) external view returns (uint256) { 
        return _balanceA[customer]; 
    }

    function balanceB(address customer) external view returns (uint256) {
        uint256 bal = _balanceB[customer];
        RewardBatch[] storage batches = _rewardBatches[customer];
        for (uint256 i = 0; i < batches.length; i++) {
            if (batches[i].active && batches[i].expiresAt > 0 && block.timestamp > batches[i].expiresAt)
                bal = bal >= batches[i].amount ? bal - batches[i].amount : 0;
        }
        return bal;
    }

    function getBalances(address customer) external view returns (uint256, uint256) {
        return (_balanceA[customer], this.balanceB(customer));
    }
    function balanceOf(address customer) public view returns (uint256) {
        uint256 balA = _balanceA[customer];
        uint256 balB = this.balanceB(customer);
        return balA + balB;
    }
    function getTier(address customer) external view returns (bytes32) {
        if (!tierEnabled) return EconomyTypes.TIER_BASE;
        bytes32 tid = customerTier[customer];
        return tid == bytes32(0) ? EconomyTypes.TIER_BASE : tid;
    }

    function getCustomerInfo(address customer) external view returns (
        uint256 balA, uint256 balB,
        bytes32 effectiveTierId, string memory tierName,
        uint256 tokenBBonusPercent, uint256 campaignMultiplier,
        uint256 rewardCapPercentBonus, uint256 rewardCapAbsoluteBonus,
        uint256 lifetimeTokenATotal, uint256 pointsToNextTier
    ) {
        balA = _balanceA[customer];
        balB = this.balanceB(customer);
        lifetimeTokenATotal = lifetimeTokenA[customer];
        bytes32 tierId = tierEnabled ? customerTier[customer] : bytes32(0);
        effectiveTierId = tierId == bytes32(0) ? EconomyTypes.TIER_BASE : tierId;
        if (tierId != bytes32(0) && tierConfigs[tierId].id != bytes32(0)) {
            EconomyTypes.TierConfig storage cfg = tierConfigs[tierId];
            tierName = cfg.name; tokenBBonusPercent = cfg.tokenBBonusPercent;
            campaignMultiplier = cfg.campaignMultiplier; rewardCapPercentBonus = cfg.rewardCapPercentBonus;
            rewardCapAbsoluteBonus = cfg.rewardCapAbsoluteBonus;
            pointsToNextTier = cfg.pointsMax == type(uint256).max ? 0 : cfg.pointsMax + 1 - lifetimeTokenATotal;
        } else {
            tierName = "BASE"; campaignMultiplier = 100;
            pointsToNextTier = allTiers.length > 0 && lifetimeTokenATotal < allTiers[0].pointsRequired
                ? allTiers[0].pointsRequired - lifetimeTokenATotal : 0;
        }
    }

    function getAllTiers()        external view returns (EconomyTypes.TierConfig[] memory) { return allTiers; }
    function getActiveCampaigns() external view returns (EconomyTypes.Campaign[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < campaignIds.length; i++) {
            EconomyTypes.Campaign storage c = campaigns[campaignIds[i]];
            if (c.active && (c.expiresAt == 0 || block.timestamp <= c.expiresAt)) count++;
        }
        EconomyTypes.Campaign[] memory result = new EconomyTypes.Campaign[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < campaignIds.length; i++) {
            EconomyTypes.Campaign storage c = campaigns[campaignIds[i]];
            if (c.active && (c.expiresAt == 0 || block.timestamp <= c.expiresAt)) result[idx++] = c;
        }
        return result;
    }
    function getTopupPolicy()  external view returns (uint256 rate, uint256 minTop, uint256 maxTop) { return (topupRate, topupMin, topupMax); }
    function getSpendPolicy()  external view returns (uint8 priority, uint256 maxPercent, uint256 maxAbsolute, uint256 expiryDays) { return (uint8(spendPriority), rewardMaxPercent, rewardMaxAbsolute, defaultExpiryDays); }
    function expireBatches(address customer) external whenNotPaused { 
        _expireBatches(customer); 
    }

    // ================================================================
    // ADMIN
    // ================================================================
    function pause()   external onlyAdmin { _pause(); }
    function unpause() external onlyAdmin { _unpause(); }

    // ================================================================
    // INTERNAL — Token A
    // ================================================================
    function _calcTokenA(uint256 inputAmount) internal view returns (uint256) {
        require(topupRate > 0, "Topup rate not set");
        if (topupMin > 0) require(inputAmount >= topupMin, "Below min topup");
        if (topupMax > 0) require(inputAmount <= topupMax, "Exceeds max topup");
        return inputAmount / topupRate;
    }

    function _creditA(address customer, uint256 amount, bytes32 idempotencyKey, bytes32 refId, bytes32 source,uint256 branchId) internal {
        require(!_processedTopups[idempotencyKey], "Already processed");
        _processedTopups[idempotencyKey] = true;
        _balanceA[customer] += amount;
        totalACredited += amount;
        uint256 idx = _ledgerA.length;
        _ledgerA.push(LedgerEntryA(customer, int256(amount), source, refId, idempotencyKey, block.timestamp));
        _ledgerAIdx[customer].push(idx);
        emit TokenACredited( branchId, customer, amount, source, refId, idempotencyKey, block.timestamp);
        bool isTopup = (source == NET_MODULE);
        _recordStatCreditA(branchId, amount, isTopup);
        _indexCreditA(customer, amount, branchId, source, refId); 
    }

    function _debitA(address customer, uint256 amount, bytes32 actionType, bytes32 refId, uint256 branchId) internal {
        require(_balanceA[customer] >= amount, "Insufficient Token A");
        _balanceA[customer] -= amount;
        totalADebited += amount;
        uint256 idx = _ledgerA.length;
        _ledgerA.push(LedgerEntryA(customer, -int256(amount), actionType, refId, bytes32(0), block.timestamp));
        _ledgerAIdx[customer].push(idx);
        emit TokenADebited(branchId, customer, amount, actionType, refId, block.timestamp);
        _recordStatDebitA(branchId, amount);
        _indexDebitA(customer, amount, branchId, refId);
    }
    function getLedgerA(address customer) external view returns (LedgerEntryA[] memory entries) {
        uint256[] storage idxs = _ledgerAIdx[customer];
        entries = new LedgerEntryA[](idxs.length);
        for (uint256 i = 0; i < idxs.length; i++) entries[i] = _ledgerA[idxs[i]];
    }
    function getLedgerB(address customer) external view returns (LedgerEntryB[] memory entries) {
        uint256[] storage idxs = _ledgerBIdx[customer];
        entries = new LedgerEntryB[](idxs.length);
        for (uint256 i = 0; i < idxs.length; i++) entries[i] = _ledgerB[idxs[i]];
    }
    function getLedgerAByRefId(address customer, bytes32 refId) external view returns (LedgerEntryA[] memory entries) {
        uint256[] storage idxs = _ledgerAIdx[customer];
        uint256 count = 0;
        for (uint256 i = 0; i < idxs.length; i++) if (_ledgerA[idxs[i]].refId == refId) count++;
        entries = new LedgerEntryA[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < idxs.length; i++) if (_ledgerA[idxs[i]].refId == refId) entries[j++] = _ledgerA[idxs[i]];
    }
    function getLedgerBByRefId(address customer, bytes32 refId) external view returns (LedgerEntryB[] memory entries) {
        uint256[] storage idxs = _ledgerBIdx[customer];
        uint256 count = 0;
        for (uint256 i = 0; i < idxs.length; i++) if (_ledgerB[idxs[i]].refId == refId) count++;
        entries = new LedgerEntryB[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < idxs.length; i++) if (_ledgerB[idxs[i]].refId == refId) entries[j++] = _ledgerB[idxs[i]];
    }
    // ================================================================
    // INTERNAL — Token B
    // ================================================================
    function _grantB(address customer, uint256 amount, uint256 campaignId, bytes32 sourceEventId, uint256 expiresAt) internal {
        bytes32 grantKey = keccak256(abi.encodePacked(sourceEventId, campaignId, customer));
        if (_processedGrants[grantKey]) return;
        _processedGrants[grantKey] = true;
        _batchCounter++;
        _rewardBatches[customer].push(RewardBatch(_batchCounter, amount, expiresAt, campaignId, sourceEventId, true));
        _balanceB[customer] += amount;
        totalBGranted += amount;
        uint256 idx = _ledgerB.length;
        _ledgerB.push(LedgerEntryB(customer, int256(amount), keccak256("GRANT"), sourceEventId, block.timestamp, ""));
        _ledgerBIdx[customer].push(idx);
        emit TokenBGranted(customer, amount, campaignId, sourceEventId, expiresAt, block.timestamp);
        _recordStatGrantB(amount);
        _indexGrantB(customer, amount, sourceEventId);
    }

/**
     * [FIX-4] _debitB: consume nearest-expiry first.
     * expiresAt == 0 coi là vô hạn (ưu tiên tiêu sau cùng).
     */
    function _debitB(address customer, uint256 amount, bytes32 actionType, bytes32 refId,uint256 branchId) internal {
        require(_balanceB[customer] >= amount, "Insufficient Token B");
        uint256 remaining = amount;
        RewardBatch[] storage batches = _rewardBatches[customer];

        while (remaining > 0) {
            // Tìm batch active có expiresAt nhỏ nhất (0 = vô hạn = ưu tiên sau)
            uint256 minExpiry = type(uint256).max;
            uint256 minIdx    = type(uint256).max;
            for (uint256 i = 0; i < batches.length; i++) {
                if (!batches[i].active || batches[i].amount == 0) continue;
                uint256 eff = batches[i].expiresAt == 0 ? type(uint256).max : batches[i].expiresAt;
                if (eff < minExpiry) {
                    minExpiry = eff;
                    minIdx    = i;
                }
            }
            if (minIdx == type(uint256).max) break; // không còn batch nào

            uint256 take = batches[minIdx].amount >= remaining ? remaining : batches[minIdx].amount;
            batches[minIdx].amount -= take;
            if (batches[minIdx].amount == 0) batches[minIdx].active = false;
            remaining -= take;
        }

        uint256 actualSpent = amount - remaining;
        _balanceB[customer] -= actualSpent;
        totalBDebited += actualSpent;
        uint256 idx = _ledgerB.length;
        _ledgerB.push(LedgerEntryB(customer, -int256(actualSpent), actionType, refId, block.timestamp, ""));
        _ledgerBIdx[customer].push(idx);
        // [FIX-3] emit với merchant + branchId
        emit TokenBDebited( branchId, customer, actualSpent, actionType, refId, block.timestamp);
        _recordStatDebitB(branchId, actualSpent);
        _indexDebitB(customer, actualSpent, branchId, refId);
    }

    function _expireBatches(address customer) internal {
        RewardBatch[] storage batches = _rewardBatches[customer];
        for (uint256 i = 0; i < batches.length; i++) {
            if (batches[i].active && batches[i].expiresAt > 0 && block.timestamp > batches[i].expiresAt) {
                uint256 exp = batches[i].amount;
                batches[i].amount = 0; batches[i].active = false;
                _balanceB[customer] = _balanceB[customer] >= exp ? _balanceB[customer] - exp : 0;
                totalBExpired += exp;
                emit TokenBExpired(customer, exp, block.timestamp);
                _recordStatExpireB(exp);
                _indexExpireB(customer, exp);
            }
        }
    }

    function _isActionAllowedForB(bytes32 actionType) internal view returns (bool) {
        return allowedActionTypes[keccak256("ALL")] || allowedActionTypes[actionType];
    }

    function _requireActionAllowedForB(bytes32 actionType) internal view {
        require(_isActionAllowedForB(actionType), "Action not allowed for Token B");
    }

    function _calcExpiresAt() internal view returns (uint256) {
        return defaultExpiryDays == 0 ? 0 : block.timestamp + defaultExpiryDays * 1 days;
    }

    // ================================================================
    // INTERNAL — Member helpers
    // ================================================================

    /**
     * @dev Cập nhật totalPoints trong Member struct (Token A + Token B).
     */
    function _updateMemberPoints(address customer) internal {
        if (!members[customer].isActive) return;
        members[customer].totalPoints     = _balanceA[customer] + this.balanceB(customer);
        members[customer].lifetimePoints  = lifetimeTokenA[customer];
        _syncAllMembersEntry(customer);
    }

    function _syncAllMembersEntry(address customer) internal {
        for (uint256 i = 0; i < allMembers.length; i++) {
            if (allMembers[i].walletAddress == customer) {
                allMembers[i] = members[customer];
                break;
            }
        }
    }

    function _isMemberInGroup(address _member, bytes32 _groupId) internal view returns (bool) {
        bytes32[] storage gs = memberToGroups[_member];
        for (uint256 i = 0; i < gs.length; i++) if (gs[i] == _groupId) return true;
        return false;
    }

    function _removeMemberFromGroupArray(bytes32 _groupId, address _member) internal {
        address[] storage gm = groupMembers[_groupId];
        for (uint256 i = 0; i < gm.length; i++) {
            if (gm[i] == _member) { gm[i] = gm[gm.length - 1]; gm.pop(); break; }
        }
    }

    function _removeGroupFromMember(address _member, bytes32 _groupId) internal {
        bytes32[] storage gs = memberToGroups[_member];
        for (uint256 i = 0; i < gs.length; i++) {
            if (gs[i] == _groupId) { gs[i] = gs[gs.length - 1]; gs.pop(); break; }
        }
    }

    // ================================================================
    // INTERNAL — Tier helpers
    // ================================================================
    function _calcTierTokenBBonus(address customer, uint256 tokenAEarned) internal view returns (uint256) {
        bytes32 tierId = customerTier[customer];
        if (tierId == bytes32(0)) return 0;
        EconomyTypes.TierConfig storage cfg = tierConfigs[tierId];
        if (cfg.id == bytes32(0) || cfg.tokenBBonusPercent == 0) return 0;
        return (tokenAEarned * cfg.tokenBBonusPercent) / 100;
    }

    function _getSpendCapBonus(address customer) internal view returns (uint256 capPct, uint256 capAbs) {
        bytes32 tierId = customerTier[customer];
        if (tierId == bytes32(0)) return (0, 0);
        EconomyTypes.TierConfig storage cfg = tierConfigs[tierId];
        if (cfg.id == bytes32(0)) return (0, 0);
        return (cfg.rewardCapPercentBonus, cfg.rewardCapAbsoluteBonus);
    }

    function _getCampaignMultiplier(address customer) internal view returns (uint256) {
        if (!tierEnabled) return 100;
        bytes32 tierId = customerTier[customer];
        if (tierId == bytes32(0)) return 100;
        EconomyTypes.TierConfig storage cfg = tierConfigs[tierId];
        return cfg.id == bytes32(0) ? 100 : cfg.campaignMultiplier;
    }

    function _meetsMinTier(address customer, bytes32 minTierID) internal view returns (bool) {
        if (!tierEnabled || minTierID == bytes32(0) || minTierID == EconomyTypes.TIER_BASE) return true;
        return _getTierLevel(customerTier[customer]) >= _getTierLevel(minTierID);
    }

    function _isInAllowedTiers(address customer, bytes32[] memory allowed) internal view returns (bool) {
        if (!tierEnabled || allowed.length == 0) return true;
        bytes32 eff = customerTier[customer] == bytes32(0) ? EconomyTypes.TIER_BASE : customerTier[customer];
        for (uint256 i = 0; i < allowed.length; i++) if (allowed[i] == eff) return true;
        return false;
    }

    function _getTierLevel(bytes32 tierId) internal view returns (uint256) {
        if (tierId == bytes32(0) || tierId == EconomyTypes.TIER_BASE) return 0;
        for (uint256 i = 0; i < allTiers.length; i++) if (allTiers[i].id == tierId) return i + 1;
        return 0;
    }

    function _sortTierRanges() internal {
        if (allTiers.length == 0) return;
        for (uint256 i = 0; i < allTiers.length - 1; i++)
            for (uint256 j = 0; j < allTiers.length - i - 1; j++)
                if (allTiers[j].pointsRequired > allTiers[j + 1].pointsRequired) {
                    EconomyTypes.TierConfig memory tmp = allTiers[j];
                    allTiers[j] = allTiers[j + 1]; allTiers[j + 1] = tmp;
                }
        for (uint256 i = 0; i < allTiers.length; i++) {
            uint256 pMax = i < allTiers.length - 1 ? allTiers[i + 1].pointsRequired - 1 : type(uint256).max;
            allTiers[i].pointsMax = pMax;
            tierConfigs[allTiers[i].id].pointsMax = pMax;
        }
    }

    // ================================================================
    // INTERNAL — Campaign execution
    // ================================================================
    function _executeCampaigns(bytes32 eventType, bytes32 sourceEventId, address customer, uint256 amount, uint256 branchId) internal {
        uint256[] memory eligible = _getEligibleCampaigns(eventType, amount, branchId, customer);
        if (eligible.length == 0) return;
        uint256[] memory toExecute = _resolveStacking(eligible);
        for (uint256 i = 0; i < toExecute.length; i++) {
            uint256 cId = toExecute[i];
            if (cId == 0) continue;
            bytes32 execKey = keccak256(abi.encodePacked(cId, customer, sourceEventId));
            if (campaignExecutionLog[execKey]) continue;
            EconomyTypes.Campaign memory c = campaigns[cId];
            uint256 baseAmount  = c.isPercent ? (amount * c.rewardAmount) / 100 : c.rewardAmount;
            if (baseAmount == 0) continue;
            uint256 finalAmount = (baseAmount * _getCampaignMultiplier(customer)) / 100;
            uint256 expiresAt = _calcExpiresAtForCampaign(c.rewardExpiryDaysOverride);
            campaignExecutionLog[execKey] = true;
            _grantB(customer, finalAmount, cId, sourceEventId, expiresAt);
            emit CampaignExecuted(cId, customer, sourceEventId, baseAmount, finalAmount, block.timestamp);
        }
    }
    function _calcExpiresAtForCampaign(uint256 rewardExpiryDaysOverride) internal view returns (uint256) {
        if (rewardExpiryDaysOverride > 0) {
            return block.timestamp + rewardExpiryDaysOverride * 1 days;
        }
        return _calcExpiresAt();
    }
    function _getEligibleCampaigns(bytes32 eventType, uint256 amount, uint256 branchId, address customer)
        internal view returns (uint256[] memory)
    {
        uint256[] memory temp = new uint256[](campaignIds.length);
        uint256 count = 0;
        for (uint256 i = 0; i < campaignIds.length; i++) {
            uint256 cId = campaignIds[i];
            EconomyTypes.Campaign memory c = campaigns[cId];
            if (!c.active) continue;
            if (c.eventType != eventType) continue;
            if (c.minAmount > 0 && amount < c.minAmount) continue;
            if (c.expiresAt > 0 && block.timestamp > c.expiresAt) continue;
            if (c.branchScope != 0 && c.branchScope != branchId) continue;
            if (!_meetsMinTier(customer, c.minTierID)) continue;
            if (!_isInAllowedTiers(customer, c.allowedTiers)) continue;
            temp[count++] = cId;
        }
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) result[i] = temp[i];
        return result;
    }

    function _resolveStacking(uint256[] memory eligible) internal view returns (uint256[] memory) {
        uint256[] memory result          = new uint256[](eligible.length);
        uint256   resultCount            = 0;
        uint256[] memory processedGroups = new uint256[](eligible.length);
        uint256   processedCount         = 0;
        uint256   highestNonExcPriority  = 0;
        uint256   highestNonExcCampaign  = 0;
        bool      hasNonExcNonStack      = false;

        for (uint256 i = 0; i < eligible.length; i++) {
            EconomyTypes.Campaign memory c = campaigns[eligible[i]];
            if (c.exclusiveGroup != 0) continue;
            if (c.stackable) { result[resultCount++] = eligible[i]; }
            else {
                hasNonExcNonStack = true;
                if (c.priority > highestNonExcPriority) { highestNonExcPriority = c.priority; highestNonExcCampaign = eligible[i]; }
            }
        }
        if (hasNonExcNonStack && highestNonExcCampaign > 0) result[resultCount++] = highestNonExcCampaign;

        for (uint256 i = 0; i < eligible.length; i++) {
            EconomyTypes.Campaign memory c = campaigns[eligible[i]];
            if (c.exclusiveGroup == 0) continue;
            bool seen = false;
            for (uint256 j = 0; j < processedCount; j++) if (processedGroups[j] == c.exclusiveGroup) { seen = true; break; }
            if (seen) continue;
            uint256 bestPriority = 0; uint256 bestCampaign = 0;
            for (uint256 k = 0; k < eligible.length; k++) {
                EconomyTypes.Campaign memory ck = campaigns[eligible[k]];
                if (ck.exclusiveGroup == c.exclusiveGroup && ck.priority > bestPriority) { bestPriority = ck.priority; bestCampaign = eligible[k]; }
            }
            if (bestCampaign > 0) result[resultCount++] = bestCampaign;
            processedGroups[processedCount++] = c.exclusiveGroup;
        }

        uint256[] memory trimmed = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) trimmed[i] = result[i];
        return trimmed;
    }

    function _calcDebitSplit(uint256 amount, uint256 balA, uint256 maxB, EconomyTypes.SpendPriority prio)
        internal pure returns (uint256 spentA, uint256 spentB)
    {
        if (prio == EconomyTypes.SpendPriority.B_FIRST) {
            spentB = amount <= maxB ? amount : maxB;
            spentA = amount - spentB;
            require(spentA <= balA, "Insufficient Token A");
        } else if (prio == EconomyTypes.SpendPriority.A_FIRST) {
            spentA = amount <= balA ? amount : balA;
            uint256 rem = amount - spentA;
            spentB = rem <= maxB ? rem : maxB;
            require(spentA + spentB == amount, "Insufficient balance");
        } else {
            uint256 halfB = amount / 2;
            spentB = halfB <= maxB ? halfB : maxB;
            spentA = amount - spentB;
            require(spentA <= balA, "Insufficient Token A");
        }
    }
    function canPayWithPoints(
        address _member,
        uint256 _amount
    ) external view returns (
        bool canPay,
        uint256 pointsNeeded,
        uint256 currentPoints,
        uint256 maxPayableAmount
    ) {
        if (!members[_member].isActive) {
            return (false, 0, 0, 0);
        }
        
        Member storage member = members[_member];
        
        if (member.isLocked) {
            return (false, 0, balanceOf(_member), 0);
        }
        
        maxPayableAmount = (_amount * maxPercentPerInvoice) / 100;
        pointsNeeded = maxPayableAmount / exchangeRate;
        currentPoints = balanceOf(_member);
        
        canPay = (currentPoints >= pointsNeeded);
        
        return (canPay, pointsNeeded, currentPoints, maxPayableAmount);
    }
    function usePointsForPayment(
        address _member,
        uint256 _pointsToUse,
        uint256 _orderAmount,
        uint256 branchId
    ) external memberExists(_member) notLocked(_member) {
        require(isOrder[msg.sender]|| IManagement(MANAGEMENT).hasRole(ROLE_ADMIN, msg.sender), "Unauthorized");
        
        Member storage member = members[_member];
        require(balanceOf(_member) >= _pointsToUse, "Insufficient points");
        
        // Burn tokens
        bytes32 paymentId = keccak256(abi.encodePacked(_member, _pointsToUse, block.timestamp));

        if (_pointsToUse > 0) {
            uint256 fromA = _balanceA[_member] >= _pointsToUse ? _pointsToUse : _balanceA[_member];
            uint256 fromB = _pointsToUse - fromA;
            if (fromA > 0) _debitA(_member, fromA, keccak256("PAYMENT"), paymentId,branchId);
            if (fromB > 0) _debitB(_member, fromB, keccak256("PAYMENT"), paymentId,branchId);
        }        
        // Update member
        member.totalPoints = balanceOf(_member);
        member.lastBuyActivityAt = block.timestamp;
        
        
        _createTransaction(
            _member,
            TransactionType.Redeem,
            -int256(_pointsToUse),
            _orderAmount,
            paymentId,
            string(abi.encodePacked("Payment with points: ", _pointsToUse.toString())),
            0,
            branchId,
            FOOD_MODULE
        );
        
        memberPaymentHistory[_member].push(PaymentTransaction({
            paymentId: paymentId,
            pointsUsed: _pointsToUse,
            orderAmount: _orderAmount,
            timestamp: block.timestamp
        }));
        
        emit PointsUsedForPayment(_member, paymentId, _pointsToUse, _orderAmount, block.timestamp);
    }
    function _createTransaction(
        address _member,
        TransactionType _txType,
        int256 _points,
        uint256 _amount,
        bytes32 _invoiceId,
        string memory _note,
        uint256 _eventId,
        uint256 branchId,
        bytes32 source
    ) internal {
        transactionCounter++;
        transactions[transactionCounter] = Transaction({
            id: transactionCounter,
            member: _member,
            txType: _txType,
            points: _points,
            amount: _amount,
            invoiceId: _invoiceId,
            processedBy: msg.sender,
            timestamp: block.timestamp,
            note: _note,
            eventId: _eventId,
            status: PointTransactionStatus.Completed
        });
        
        memberTransactions[_member].push(transactionCounter);
        allTransactions.push(transactions[transactionCounter]);
        emit TransactionCreated(transactionCounter, _member, _txType, _points);
        require (searchIndex != address(0), "PublicfullDB not set");
        PublicfullDB(searchIndex).syncTransaction(
            agent,
            transactionCounter,
                _member,
            _txType == TransactionType.Earn   ? "Earn"   :
            _txType == TransactionType.Redeem ? "Redeem" :
            _txType == TransactionType.Issue  ? "Issue"  : "Expire",
            _points,
            _amount,
            _invoiceId,
            _note, 
            block.timestamp,
            branchId,
            source
        );     
    }
    function getMemberPaymentHistory(
        address _member,
        uint256 offset,
        uint256 limit
    ) external view returns (
        PaymentTransaction[] memory result,
        uint256 totalCount
    ) {
        PaymentTransaction[] memory history = memberPaymentHistory[_member];
        uint256 length = history.length;
        
        if (offset >= length) {
            return (new PaymentTransaction[](0), length);
        }
        
        uint256 end = offset + limit;
        if (end > length) {
            end = length;
        }
        
        uint256 size = end - offset;
        result = new PaymentTransaction[](size);
        
        // Lấy từ mới nhất (reverse order)
        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = length - 1 - offset - i;
            result[i] = history[reverseIndex];
        }
        
        return (result, length);
    }
// ================================================================
    // VIEW — SELF-ONLY (customer chỉ đọc dữ liệu của mình)
    // [FIX-2] Thêm self-only APIs
    // ================================================================

    /// @notice Customer đọc balance của chính mình
    function getMyBalances() external view returns (uint256 myBalA, uint256 myBalB) {
        return (_balanceA[msg.sender], this.balanceB(msg.sender));
    }

    /// @notice Customer đọc profile của chính mình
    function getMyMemberProfile() external view returns (Member memory) {
        require(members[msg.sender].isActive, "Not a member");
        return members[msg.sender];
    }

    /// @notice Customer đọc ledger A của chính mình (paginated)
    function getMyLedgerA(uint256 offset, uint256 limit)
        external view returns (LedgerEntryA[] memory result, uint256 total)
    {
        return _getLedgerAPaged(msg.sender, offset, limit);
    }

    /// @notice Customer đọc ledger B của chính mình (paginated)
    function getMyLedgerB(uint256 offset, uint256 limit)
        external view returns (LedgerEntryB[] memory result, uint256 total)
    {
        return _getLedgerBPaged(msg.sender, offset, limit);
    }

    /// @notice Customer đọc debit history của chính mình
    function getMyDebitRefs(uint256 offset, uint256 limit)
        external view returns (bytes32[] memory refs, uint256 total)
    {
        return getDebitRefsByCustomerPaging(msg.sender, offset, limit);
    }
     // Paginated ledger helpers (used by self-only APIs)
    function _getLedgerAPaged(address customer, uint256 offset, uint256 limit)
        internal view returns (LedgerEntryA[] memory result, uint256 total)
    {
        uint256[] storage idxs = _ledgerAIdx[customer];
        total = idxs.length;
        if (offset >= total) return (new LedgerEntryA[](0), total);
        uint256 end = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;
        result = new LedgerEntryA[](size);
        for (uint256 i = 0; i < size; i++) result[i] = _ledgerA[idxs[offset + i]];
    }

    function _getLedgerBPaged(address customer, uint256 offset, uint256 limit)
        internal view returns (LedgerEntryB[] memory result, uint256 total)
    {
        uint256[] storage idxs = _ledgerBIdx[customer];
        total = idxs.length;
        if (offset >= total) return (new LedgerEntryB[](0), total);
        uint256 end = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;
        result = new LedgerEntryB[](size);
        for (uint256 i = 0; i < size; i++) result[i] = _ledgerB[idxs[offset + i]];
    }
    // ================================================================
    // VIEW — DEBIT BREAKDOWN [FIX-7]
    // ================================================================
    function getDebitByRefId(bytes32 refId) external view returns (DebitRecord memory) {
        require(debitRefExists[refId], "refId not found");
        return debitByRefId[refId];
    }

    function getDebitRefsByCustomer(address customer) external view returns (bytes32[] memory) {
        require(
            msg.sender == customer ||
            IManagement(MANAGEMENT).hasRole(ROLE_ADMIN, msg.sender) ||
            IManagement(MANAGEMENT).isStaff(msg.sender),
            "Access denied"
        );
        return customerDebitRefs[customer];
    }

    function getDebitRefsByCustomerPaging(address customer, uint256 offset, uint256 limit)
        public view returns (bytes32[] memory refs, uint256 total)
    {
        require(
            msg.sender == customer ||
            IManagement(MANAGEMENT).hasRole(ROLE_ADMIN, msg.sender) ||
            IManagement(MANAGEMENT).isStaff(msg.sender),
            "Access denied"
        );
        bytes32[] storage arr = customerDebitRefs[customer];
        total = arr.length;
        if (offset >= total) return (new bytes32[](0), total);

        uint256 end  = offset + limit;
        if (end > total) end = total;
        uint256 size = end - offset;

        refs = new bytes32[](size);
        for (uint256 i = 0; i < size; i++) {
            refs[i] = arr[offset + i];
        }
    }
    function GetAllTransactionsPaginationByType(
        uint256 offset, 
        uint256 limit,
        TransactionType _txType
    )
        external
        view
        returns (Transaction[] memory result,uint totalCount)
    {
        uint count = 0;
        for(uint i; i< allTransactions.length;i++){
            Transaction memory transaction = allTransactions[i];
            if(transaction.txType == _txType){
                count++;
            }
        }
        totalCount = count;
        Transaction[] memory transactionArr= new Transaction[](count);
        uint index = 0;
        for(uint i; i< allTransactions.length;i++){
            Transaction memory transaction = allTransactions[i];
            if(transaction.txType == _txType){
                transactionArr[index] = transaction;
                index++;
            }
        }
        if(offset >= count) {
            return ( new Transaction[](0),count);
        }

        uint256 end = offset + limit;
        if (end > count) {
            end = count;
        }

        uint256 size = end - offset;
        result = new Transaction[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = count - 1 - offset - i;
            result[i] = transactionArr[reverseIndex];
        }

        return (result,count);
    }


    function GetAllTransactionsPagination(
        uint256 offset, 
        uint256 limit
    )
        external
        view
        returns (Transaction[] memory result,uint totalCount)
    {
        uint length = allTransactions.length;
        if(offset >= length) {
            return ( new Transaction[](0),length);
        }

        uint256 end = offset + limit;
        if (end > length) {
            end = length;
        }

        uint256 size = end - offset;
        result = new Transaction[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = length - 1 - offset - i;
            result[i] = allTransactions[reverseIndex];
        }

        return (result,length);
    }
/**
 * @dev Lấy transactions của member theo pagination
 */
function getMemberTransactionsPagination(
    address _member,
    uint256 offset,
    uint256 limit
) external view returns (
    Transaction[] memory result,
    uint256 totalCount
) {
    uint256[] memory txIds = memberTransactions[_member];
    uint256 length = txIds.length;
    
    if (offset >= length) {
        return (new Transaction[](0), length);
    }
    
    uint256 end = offset + limit;
    if (end > length) {
        end = length;
    }
    
    uint256 size = end - offset;
    result = new Transaction[](size);
    
    // Lấy transactions theo thứ tự đảo ngược (mới nhất trước)
    for (uint256 i = 0; i < size; i++) {
        uint256 reverseIndex = length - 1 - offset - i;
        uint256 txId = txIds[reverseIndex];
        result[i] = transactions[txId];
    }
    
    return (result, length);
}
    // ================================================================
    // INTERNAL — Dashboard helpers
    // ================================================================
    function _ensureDayRecorded(uint256 dayBucket) internal {
        if (!_dayRecorded[dayBucket]) { _dayRecorded[dayBucket] = true; recordedDays.push(dayBucket); }
    }

    function _recordDailyStatNewMember(uint256 _branchId) internal {
        uint256 dayBucket = block.timestamp / 1 days;
        _ensureDayRecorded(dayBucket);
        dailyStatsByBranch[_branchId][dayBucket].newMembers++;
        if (_branchId != 0) dailyStatsByBranch[0][dayBucket].newMembers++;
    }

    // ================================================================
    // INTERNAL — Change history
    // ================================================================
    function _recordChange(ChangeType changeType, bytes memory payload) internal {
        _changeCounter++;
        uint256 idx = changeHistory.length;
        changeHistory.push(ChangeRecord({ id: _changeCounter, changeType: changeType, actor: msg.sender, payload: payload, timestamp: block.timestamp }));
        changeIdsByType[uint8(changeType)].push(idx);
    }
    // ================================================================
    // NEW: VIEW — DASHBOARD AGGREGATE
    // ================================================================

    /**
     * @notice Lấy stats tổng hợp theo ngày và branchId.
     * @param dayBucket  block.timestamp / 1 days  (client tự tính hoặc dùng helper)
     * @param _branchId  0 = global (không phân chi nhánh)
     */
    function getDailyStats(uint256 dayBucket, uint256 _branchId) external view returns (DailyStats memory) {
        return dailyStatsByBranch[_branchId][dayBucket];
    }

    /**
     * @notice Lấy stats nhiều ngày liên tiếp (range).
     * @param fromDay  ngày bắt đầu (inclusive)
     * @param toDay    ngày kết thúc (inclusive)
     */
    function getDailyStatsRange(uint256 fromDay, uint256 toDay, uint256 _branchId)
        external view returns (DailyStats[] memory result, uint256[] memory daysNum)
    {
        require(toDay >= fromDay, "Invalid range");
        uint256 count = toDay - fromDay + 1;
        result = new DailyStats[](count);
        daysNum   = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            uint256 d = fromDay + i;
            result[i] = dailyStatsByBranch[_branchId][d];
            daysNum[i]   = d;
        }
    }

    /**
     * @notice Tổng hợp theo tuần (7 ngày) bắt đầu từ weekStartDay.
     */
    function getWeeklyStats(uint256 weekStartDay, uint256 _branchId) external view returns (DailyStats memory total) {
        for (uint256 i = 0; i < 7; i++) {
            DailyStats storage d = dailyStatsByBranch[_branchId][weekStartDay + i];
            total.totalTopup    += d.totalTopup;
            total.totalEarned   += d.totalEarned;
            total.totalSpend    += d.totalSpend;
            total.totalGrantB   += d.totalGrantB;
            total.totalDebitB   += d.totalDebitB;
            total.totalExpiredB += d.totalExpiredB;
            total.newMembers    += d.newMembers;
            total.txCount       += d.txCount;
        }
    }

    /**
     * @notice Tổng hợp theo tháng — truyền năm và tháng (1-12).
     * @dev Tính dayBucket của ngày đầu tháng và cộng dần đủ số ngày.
     *      Để đơn giản on-chain: lặp tối đa 31 ngày.
     */
    function getMonthlyStats(uint256 year, uint256 month, uint256 _branchId) external view returns (DailyStats memory total) {
        require(month >= 1 && month <= 12, "Invalid month");
        uint256 daysInMonth =  DateTimeTZ.getDaysInMonth(year, month);
        // Tính unix timestamp của ngày 1 tháng đó (UTC)
        int256 timeZone = 7;
        uint256 firstDay = DateTimeTZ.timestampFromDate(year, month, 1, timeZone) / 1 days;
        for (uint256 i = 0; i < daysInMonth; i++) {
            DailyStats storage d = dailyStatsByBranch[_branchId][firstDay + i];
            total.totalTopup    += d.totalTopup;
            total.totalEarned   += d.totalEarned;
            total.totalSpend    += d.totalSpend;
            total.totalGrantB   += d.totalGrantB;
            total.totalDebitB   += d.totalDebitB;
            total.totalExpiredB += d.totalExpiredB;
            total.newMembers    += d.newMembers;
            total.txCount       += d.txCount;
        }
    }

    // ================================================================
    // NEW: VIEW — CAMPAIGN EXECUTION LOG
    // ================================================================

    /**
     * @notice Lấy danh sách execution log theo campaignId (paginated).
     */
    function getCampaignExecLogByCampaign(uint256 campaignId, uint256 offset, uint256 limit)
        external view returns (CampaignExecRecord[] memory result, uint256 total)
    {
        uint256[] storage ids = campaignExecIds[campaignId];
        total = ids.length;
        if (offset >= total) return (new CampaignExecRecord[](0), total);
        uint256 end  = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;
        result = new CampaignExecRecord[](size);
        for (uint256 i = 0; i < size; i++) result[i] = campaignExecRecords[ids[total - 1 - offset - i]];
    }

    /**
     * @notice Lấy danh sách execution log theo customer (paginated).
     */
    function getCampaignExecLogByCustomer(address customer, uint256 offset, uint256 limit)
        external view returns (CampaignExecRecord[] memory result, uint256 total)
    {
        require(
            msg.sender == customer ||
            IManagement(MANAGEMENT).hasRole(ROLE_ADMIN, msg.sender) ||
            IManagement(MANAGEMENT).isStaff(msg.sender),
            "Access denied"
        );
        uint256[] storage ids = customerExecIds[customer];
        total = ids.length;
        if (offset >= total) return (new CampaignExecRecord[](0), total);
        uint256 end  = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;
        result = new CampaignExecRecord[](size);
        for (uint256 i = 0; i < size; i++) result[i] = campaignExecRecords[ids[total - 1 - offset - i]];
    }

    /**
     * @notice Tất cả exec log (paginated) — admin/staff only.
     */
    function getAllCampaignExecLogs(uint256 offset, uint256 limit)
        external onlyStaffOrAdmin view returns (CampaignExecRecord[] memory result, uint256 total)
    {
        total = allExecIds.length;
        if (offset >= total) return (new CampaignExecRecord[](0), total);
        uint256 end  = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;
        result = new CampaignExecRecord[](size);
        for (uint256 i = 0; i < size; i++) result[i] = campaignExecRecords[allExecIds[total - 1 - offset - i]];
    }

    // ================================================================
    // NEW: VIEW — POLICY / TIER / CAMPAIGN CHANGE HISTORY
    // ================================================================

    /**
     * @notice Lấy toàn bộ change history (paginated, mới nhất trước).
     */
    function getChangeHistory(uint256 offset, uint256 limit)
        external onlyStaffOrAdmin view returns (ChangeRecord[] memory result, uint256 total)
    {
        total = changeHistory.length;
        if (offset >= total) return (new ChangeRecord[](0), total);
        uint256 end  = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;
        result = new ChangeRecord[](size);
        for (uint256 i = 0; i < size; i++) result[i] = changeHistory[total - 1 - offset - i];
    }

    /**
     * @notice Lấy change history theo loại (TopupPolicy, TierCreated, ...).
     */
    function getChangeHistoryByType(ChangeType changeType, uint256 offset, uint256 limit)
        external onlyStaffOrAdmin view returns (ChangeRecord[] memory result, uint256 total)
    {
        uint256[] storage ids = changeIdsByType[uint8(changeType)];
        total = ids.length;
        if (offset >= total) return (new ChangeRecord[](0), total);
        uint256 end  = offset + limit > total ? total : offset + limit;
        uint256 size = end - offset;
        result = new ChangeRecord[](size);
        for (uint256 i = 0; i < size; i++) result[i] = changeHistory[ids[total - 1 - offset - i]];
    }
    // ================================================================
    // INTERNAL — Dashboard stat recorders 
    // ================================================================

    function _recordStatCreditA(uint256 branchId, uint256 amount, bool isTopup) internal {
        uint256 day = block.timestamp / 1 days;
        _ensureDayRecorded(day);
        if (isTopup) {
            dailyStatsByBranch[branchId][day].totalTopup += amount;
            dailyStatsByBranch[0][day].totalTopup += amount;          // global
        } else {
            dailyStatsByBranch[branchId][day].totalEarned += amount;
            dailyStatsByBranch[0][day].totalEarned += amount;
        }
        dailyStatsByBranch[branchId][day].txCount++;
        if (branchId != 0) dailyStatsByBranch[0][day].txCount++;
    }

    function _recordStatDebitA(uint256 branchId, uint256 amount) internal {
        uint256 day = block.timestamp / 1 days;
        _ensureDayRecorded(day);
        dailyStatsByBranch[branchId][day].totalSpend += amount;
        dailyStatsByBranch[0][day].totalSpend += amount;
        dailyStatsByBranch[branchId][day].txCount++;
        if (branchId != 0) dailyStatsByBranch[0][day].txCount++;
    }

    function _recordStatGrantB(uint256 amount) internal {
        uint256 day = block.timestamp / 1 days;
        _ensureDayRecorded(day);
        dailyStatsByBranch[0][day].totalGrantB += amount;
        dailyStatsByBranch[0][day].txCount++;
    }

    function _recordStatDebitB(uint256 branchId, uint256 amount) internal {
        uint256 day = block.timestamp / 1 days;
        _ensureDayRecorded(day);
        dailyStatsByBranch[branchId][day].totalDebitB += amount;
        dailyStatsByBranch[0][day].totalDebitB += amount;
        dailyStatsByBranch[branchId][day].txCount++;
        if (branchId != 0) dailyStatsByBranch[0][day].txCount++;
    }

    function _recordStatExpireB(uint256 amount) internal {
        uint256 day = block.timestamp / 1 days;
        _ensureDayRecorded(day);
        dailyStatsByBranch[0][day].totalExpiredB += amount;
    }
    // ================================================================
    // INTERNAL — Search Index sync helpers
    // Mỗi helper tương ứng 1 loại thay đổi balance → gọi syncMember
    // với đúng tokenType + actionType + delta
    // ================================================================

    function _indexCreditA(address customer, uint256 amount, uint256 branchId, bytes32 source, bytes32 refId) internal {
        require(searchIndex != address(0),"PublicDB not set");
        PublicfullDB(searchIndex).syncMember(
            agent,
            customer,
            PublicfullDB(searchIndex).TOKEN_A(),   // tokenType = "A"
            PublicfullDB(searchIndex).ACT_CREDIT(), // actionType = "CREDIT"
            int256(amount),                               // delta = +amount
            _balanceA[customer],                          // balA SAU khi credit
            _balanceB[customer],
            members[customer].totalSpent,
            branchId,
            source,
            refId
        );
    }

    function _indexDebitA(address customer, uint256 amount, uint256 branchId, bytes32 refId) internal {
        require(searchIndex != address(0),"PublicDB not set");
        PublicfullDB(searchIndex).syncMember(
            agent,
            customer,
            PublicfullDB(searchIndex).TOKEN_A(),
            PublicfullDB(searchIndex).ACT_DEBIT(),
            -int256(amount),                              // delta = -amount
            _balanceA[customer],                          // balA SAU khi debit
            _balanceB[customer],
            members[customer].totalSpent,
            branchId,
            bytes32(0),                                   // module không rõ ở _debitA
            refId
        );
    }

    function _indexGrantB(address customer, uint256 amount, bytes32 sourceEventId) internal {
        require(searchIndex != address(0),"PublicDB not set");
        PublicfullDB(searchIndex).syncMember(
            agent,
            customer,
            PublicfullDB(searchIndex).TOKEN_B(),
            PublicfullDB(searchIndex).ACT_GRANT(),
            int256(amount),                               // delta = +amount
            _balanceA[customer],
            _balanceB[customer],                          // balB SAU khi grant
            members[customer].totalSpent,
            0,                                            // branchId = 0 (global, _grantB không có branchId)
            bytes32(0),
            sourceEventId
        );
    }

    function _indexDebitB(address customer, uint256 actualSpent, uint256 branchId, bytes32 refId) internal {
        require(searchIndex != address(0),"PublicDB not set");
        PublicfullDB(searchIndex).syncMember(
            agent,
            customer,
            PublicfullDB(searchIndex).TOKEN_B(),
            PublicfullDB(searchIndex).ACT_DEBIT(),
            -int256(actualSpent),                         // delta = -actualSpent
            _balanceA[customer],
            _balanceB[customer],                          // balB SAU khi debit
            members[customer].totalSpent,
            branchId,
            bytes32(0),
            refId
        );
    }

    function _indexExpireB(address customer, uint256 expiredAmount) internal {
        require(searchIndex != address(0),"PublicDB not set");
        PublicfullDB(searchIndex).syncMember(
            agent,
            customer,
            PublicfullDB(searchIndex).TOKEN_B(),
            PublicfullDB(searchIndex).ACT_EXPIRE(),
            -int256(expiredAmount),                       // delta = -expired
            _balanceA[customer],
            _balanceB[customer],                          // balB SAU khi expire
            members[customer].totalSpent,
            0,                                            // branchId = 0 (global)
            bytes32(0),
            bytes32(0)                                    // không có refId cho expire
        );
    }
        // LOCK POINT - Added 09/03/2026
    /**
     * @dev Khóa điểm khi khách bắt đầu thanh toán (nhưng chưa hoàn tất invoice)
     * Điểm sẽ bị trừ khỏi balance và đưa vào lockedBalanceOf.
     */

    function lockPoints(address _member, uint256 _amount, bytes32 _referenceId) external onlyOrder whenNotPaused nonReentrant {
        _expireBatches(_member);
        require(balanceOf(_member) >= _amount, "Insufficient balance");
        require(!lockedPoints[_referenceId].active, "Already locked");

        (uint256 spentA, uint256 spentB) = _calcDebitSplit(_amount, _balanceA[_member], this.balanceB(_member), spendPriority);

        // Trừ A
        if (spentA > 0) _balanceA[_member] -= spentA;

        // Trừ B và Ghi nhớ Batch
        LockedPoint storage lp = lockedPoints[_referenceId];
        lp.amount = _amount;
        lp.amountA = spentA;
        lp.amountB = spentB;
        lp.referenceId = _referenceId;
        lp.lockTimestamp = block.timestamp;
        lp.active = true;

        if (spentB > 0) {
            uint256 remainingB = spentB;
            RewardBatch[] storage batches = _rewardBatches[_member];
            
            // Logic tìm và trừ vào Batch (giống _debitB nhưng có lưu vết)
            for (uint256 i = 0; i < batches.length && remainingB > 0; i++) {
                if (!batches[i].active || batches[i].amount == 0) continue;
                
                uint256 take = batches[i].amount >= remainingB ? remainingB : batches[i].amount;
                
                // Lưu lại để sau này hoàn trả
                lp.lockedBatches.push(LockedBatch({
                    batchId: batches[i].id,
                    amountTaken: take
                }));
                
                batches[i].amount -= take;
                if (batches[i].amount == 0) batches[i].active = false;
                remainingB -= take;
            }
            _balanceB[_member] -= spentB;
        }

        lockedBalanceOf[_member] += _amount;
        _updateMemberPoints(_member);
        emit PointsLocked(_member, _amount, _referenceId);
    }
    

    /**
     * @dev Xác nhận thanh toán thành công: Chuyển điểm từ trạng thái "Khóa" sang "Đã tiêu"
     */
    function confirmLockedPoints(address _member, bytes32 _referenceId, uint256 _orderAmount, uint256 branchId) 
        external 
        onlyOrder 
        nonReentrant 
    {
        LockedPoint storage lp = lockedPoints[_referenceId];
        require(lp.active, "Lock not active or already processed");
        
        uint256 amount = lp.amount;
        uint256 spentA = lp.amountA;
        uint256 spentB = lp.amountB;

        lp.active = false;
        
        // Xóa danh sách batch đã lưu để nhận Gas Refund (vì đã tiêu thành công, không cần hoàn trả nữa)
        delete lp.lockedBatches; 

        // Cập nhật ví khóa
        lockedBalanceOf[_member] -= amount;

        // Cập nhật thống kê toàn cục (Debited)
        if (spentA > 0) totalADebited += spentA;
        if (spentB > 0) totalBDebited += spentB;

        // Cập nhật thông tin thành viên
        Member storage m = members[_member];
        if (m.isActive) {
            m.totalSpent += _orderAmount;
            m.lastBuyActivityAt = block.timestamp;
            _syncAllMembersEntry(_member);
        }

        // Ghi nhận doanh thu/chi tiêu cho chi nhánh (Daily Stats)
        _recordStatDebitA(branchId, spentA);
        _recordStatDebitB(branchId, spentB);

        // Lịch sử giao dịch
        _createTransaction(
            _member,
            TransactionType.Redeem,
            -int256(amount),
            _orderAmount,
            _referenceId,
            string(abi.encodePacked("Confirmed: A=", spentA.toString(), " B=", spentB.toString())),
            0,
            branchId,
            FOOD_MODULE
        );

        memberPaymentHistory[_member].push(PaymentTransaction({
            paymentId: _referenceId,
            pointsUsed: amount,
            orderAmount: _orderAmount,
            timestamp: block.timestamp
        }));

        emit PointsUsedForPayment(_member, _referenceId, amount, _orderAmount, block.timestamp);
        emit PointsBurnConfirmed(_member, amount, _referenceId);
    }

    /**
     * @dev Hoàn trả điểm: Mở khóa và cộng lại điểm cho khách (khi đơn hàng bị hủy)
     */
    function unlockPoints(address _member, bytes32 _referenceId,uint256 branchId) external onlyOrder nonReentrant {
        LockedPoint storage lp = lockedPoints[_referenceId];
        require(lp.active, "No active lock");

        // Trả A
        if (lp.amountA > 0) _balanceA[_member] += lp.amountA;

        // Trả B về đúng Batch cũ
        if (lp.amountB > 0) {
            RewardBatch[] storage batches = _rewardBatches[_member];
            for (uint256 i = 0; i < lp.lockedBatches.length; i++) {
                uint256 bId = lp.lockedBatches[i].batchId;
                uint256 bAmt = lp.lockedBatches[i].amountTaken;
                
                // Tìm batch có ID tương ứng để cộng lại
                for (uint256 j = 0; j < batches.length; j++) {
                    if (batches[j].id == bId) {
                        batches[j].amount += bAmt;
                        batches[j].active = true; // Kích hoạt lại nếu nó từng bị về 0
                        break;
                    }
                }
            }
            _balanceB[_member] += lp.amountB;
        }

        uint256 totalAmt = lp.amount;
        lp.active = false;
        delete lp.lockedBatches; // Giải phóng storage để nhận gas refund
        
        lockedBalanceOf[_member] -= totalAmt;
        _updateMemberPoints(_member);

        _createTransaction(_member, TransactionType.Refund, int256(totalAmt), 0, _referenceId, "Refund to original batches", 0, branchId, FOOD_MODULE);
        emit PointsUnlocked(_member, totalAmt, _referenceId);
    }

}
