// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "forge-std/console.sol";

// ================================================================
// STRUCTS & INTERFACE
// ================================================================

struct PrefixEntry {
    string key;
    string value;
}

struct RangeFilter {
    uint   slot;
    string startSerialised;
    string endSerialised;
}

struct SearchParams {
    string        queries;
    PrefixEntry[] prefixMap;
    string[]      stopWords;
    uint64        offset;
    uint64        limit;
    int64         sortByValueSlot;
    bool          sortAscending;
    RangeFilter[] rangeFilters;
}

struct SearchResult {
    uint256 docid;
    uint256 rank;
    int256  percent;
    string  data;
}

struct SearchResultsPage {
    uint256        total;
    SearchResult[] results;
}

interface FullDB {
    function getOrCreateDb(string memory name) external returns (bool);
    function newDocument(string memory dbname, string memory data) external returns (uint256);
    function getDataDocument(string memory dbname, uint256 docId) external returns (string memory);
    function setDataDocument(string memory dbname, uint256 docId, string memory data) external returns (bool);
    function deleteDocument(string memory dbname, uint256 docId) external returns (bool);
    function addTermDocument(string memory dbname, uint256 docId, string memory term) external returns (bool);
    function indexTextForDocument(string memory dbname, uint256 docId, string memory text, uint8 weight, string memory prefix) external returns (bool);
    function addValueDocument(string memory dbname, uint256 docId, uint256 slot, string memory data, bool isSerialise) external returns (bool);
    function getValueDocument(string memory dbname, uint256 docId, uint256 slot, bool isSerialise) external returns (string memory);
    function getTermsDocument(string memory dbname, uint256 docId) external returns (string[] memory);
    function search(string memory dbname, string memory query) external returns (string memory);
    function querySearch(string memory dbname, SearchParams memory params) external returns (SearchResultsPage memory);
    function commit(string memory dbname) external returns (bool);
}

// ================================================================
/**
 * @title LoyaltySearchIndex
 * @notice Search/query layer cho RestaurantLoyaltySystem.
 *         Mỗi agent address có 2 DB riêng:
 *           - loyalty_point_history_<agent_address>
 *           - loyalty_transactions_<agent_address>
 *
 * ── DB: loyalty_point_history_<agent> ────────────────────────────
 *   data = JSON {
 *       wallet, tokenType, actionType, delta,
 *       balA, balB, totalSpent, branchId, module, refId, timestamp
 *   }
 *   prefix W = wallet, T = tokenType, A = actionType, B = branchId, D = module
 *   slot 0 = timestamp, slot 1 = balA, slot 2 = branchId
 *
 * ── DB: loyalty_transactions_<agent> ─────────────────────────────
 *   data = JSON {
 *       txId, member, txType, points, amount,
 *       invoiceId, note, timestamp, branchId, module
 *   }
 *   prefix W = wallet, X = txType, B = branchId, D = module
 *   slot 0 = timestamp, slot 1 = amount, slot 2 = branchId
 */
contract PublicfullDB is Initializable, OwnableUpgradeable, UUPSUpgradeable{

    // FullDB public fullDB = FullDB(0x0000000000000000000000000000000000000106);
    FullDB public fullDB;

    // ── DB name prefixes ──────────────────────────────────────────
    string constant DB_POINT_HISTORY_PREFIX = "loyalty_point_history_";
    string constant DB_TXS_PREFIX           = "loyalty_transactions_";

    // ── actionType constants ──────────────────────────────────────
    bytes32 public constant ACT_CREDIT = keccak256("CREDIT");
    bytes32 public constant ACT_DEBIT  = keccak256("DEBIT");
    bytes32 public constant ACT_GRANT  = keccak256("GRANT");
    bytes32 public constant ACT_EXPIRE = keccak256("EXPIRE");

    // ── tokenType constants ───────────────────────────────────────
    bytes32 public constant TOKEN_A = keccak256("A");
    bytes32 public constant TOKEN_B = keccak256("B");

    // ── module constants ──────────────────────────────────────────
    bytes32 public constant NET_MODULE  = keccak256("NET_MODULE");
    bytes32 public constant FOOD_MODULE = keccak256("FOOD_MODULE");

    // ── prefix — point history DB ─────────────────────────────────
    string constant P_WALLET     = "W";
    string constant P_TOKEN_TYPE = "T";
    string constant P_ACTION     = "A";
    string constant P_BRANCH     = "B";
    string constant P_MODULE     = "D";

    // ── prefix — tx DB ───────────────────────────────────────────
    string constant P_TXTYPE = "X";

    // ── value slots — point history DB ───────────────────────────
    uint256 constant HIST_SLOT_TIMESTAMP = 0;
    uint256 constant HIST_SLOT_BAL_A     = 1;
    uint256 constant HIST_SLOT_BRANCH_ID = 2;

    // ── value slots — tx DB ──────────────────────────────────────
    uint256 constant TX_SLOT_TIMESTAMP  = 0;
    uint256 constant TX_SLOT_AMOUNT     = 1;
    uint256 constant TX_SLOT_BRANCH_ID  = 2;

    // ── access control ────────────────────────────────────────────
    mapping(address => bool) public isAllowedCaller;
    // address public owner;

    // ── per-agent state ───────────────────────────────────────────
    /// @notice Tracks whether an agent's DBs have been initialised
    mapping(address => bool) public agentInitialised;

    /// @notice agent => txId => docId in DB_TXS
    mapping(address => mapping(uint256 => uint256)) public txDocId;


    uint256[50] private __gap;
    // ── events ────────────────────────────────────────────────────
    event AgentDbsInitialised(address indexed agent, string pointHistoryDb, string txsDb);
    event PointHistorySynced(
        address indexed agent,
        address indexed wallet,
        bytes32 indexed tokenType,
        bytes32 actionType,
        int256  delta,
        uint256 branchId,
        uint256 docId
    );
    event TransactionSynced(address indexed agent, uint256 indexed txId, uint256 docId, uint256 branchId, bytes32 module);

    // ── modifier ──────────────────────────────────────────────────
    // modifier onlyAllowedCaller() {
    //     require(isAllowedCaller[msg.sender], "Unauthorized");
    //     _;
    // }

    modifier agentReady(address agent) {
        require(agentInitialised[agent], "Agent DBs not initialised");
        _;
    }

    // ── constructor ───────────────────────────────────────────────
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initialize the contract (replaces constructor)
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        fullDB = FullDB(0x0000000000000000000000000000000000000106);

        
    }
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ================================================================
    // ADMIN
    // ================================================================

    // function setAllowedCaller(address caller, bool allowed) external {
    //     require(msg.sender == owner, "Only owner");
    //     isAllowedCaller[caller] = allowed;
    // }

    function commitAll(address agent) external agentReady(agent) {
        fullDB.commit(_pointHistoryDb(agent));
        fullDB.commit(_txsDb(agent));
    }

    // ================================================================
    // DB NAME HELPERS
    // ================================================================

    /// @notice Trả về tên DB point history của agent
    function pointHistoryDbName(address agent) public pure returns (string memory) {
        return _pointHistoryDb(agent);
    }

    /// @notice Trả về tên DB transactions của agent
    function txsDbName(address agent) public pure returns (string memory) {
        return _txsDb(agent);
    }

    /// @notice Trả về cả 2 tên DB của agent
    function getDbNames(address agent)
        external pure
        returns (string memory pointHistoryDb, string memory txsDb)
    {
        pointHistoryDb = _pointHistoryDb(agent);
        txsDb          = _txsDb(agent);
    }

    // ================================================================
    // INIT AGENT DBs
    // Gọi một lần cho mỗi agent để khởi tạo 2 DB riêng.
    // Bất kỳ địa chỉ nào cũng có thể gọi (kể cả agent tự gọi).
    // ================================================================

    /// @notice Khởi tạo 2 DB riêng cho agent. Chỉ cần gọi một lần.
    function initAgentDbs(address agent) external {
        require(!agentInitialised[agent], "Already initialised");
        string memory phDb  = _pointHistoryDb(agent);
        string memory txsDb = _txsDb(agent);
        fullDB.getOrCreateDb(phDb);
        fullDB.getOrCreateDb(txsDb);
        agentInitialised[agent] = true;
        emit AgentDbsInitialised(agent, phDb, txsDb);
    }

    // ================================================================
    // SYNC — POINT HISTORY  (append-only)
    // ================================================================

    /**
     * @notice Ghi 1 snapshot nhật ký hoạt động điểm của user vào DB của agent.
     * @param agent       Địa chỉ agent sở hữu DB
     * @param wallet      Địa chỉ ví user
     * @param tokenType   TOKEN_A | TOKEN_B
     * @param actionType  ACT_CREDIT | ACT_DEBIT | ACT_GRANT | ACT_EXPIRE
     * @param delta       Thay đổi điểm: dương = cộng, âm = trừ
     * @param balA        Số dư Token A SAU khi thay đổi
     * @param balB        Số dư Token B SAU khi thay đổi
     * @param totalSpent  Tổng đã chi tiêu
     * @param branchId    Branch nơi phát sinh (0 = global)
     * @param module      NET_MODULE | FOOD_MODULE | bytes32(0)
     * @param refId       invoiceId / idempotencyKey / sourceEventId
     */
    function syncMember(
        address agent,
        address wallet,
        bytes32 tokenType,
        bytes32 actionType,
        int256  delta,
        uint256 balA,
        uint256 balB,
        uint256 totalSpent,
        uint256 branchId,
        bytes32 module,
        bytes32 refId
    ) external  agentReady(agent) {
        string memory db   = _pointHistoryDb(agent);
        string memory data = _buildPointHistoryJson(
            wallet, tokenType, actionType, delta,
            balA, balB, totalSpent,
            branchId, module, refId,
            block.timestamp
        );

        uint256 docId = fullDB.newDocument(db, data);

        fullDB.addTermDocument(db, docId,
            string(abi.encodePacked(P_WALLET, ":", _addressToString(wallet))));
        fullDB.addTermDocument(db, docId,
            string(abi.encodePacked(P_TOKEN_TYPE, ":", _tokenTypeName(tokenType))));
        fullDB.addTermDocument(db, docId,
            string(abi.encodePacked(P_ACTION, ":", _actionTypeName(actionType))));
        fullDB.addTermDocument(db, docId,
            string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))));
        fullDB.addTermDocument(db, docId,
            string(abi.encodePacked(P_MODULE, ":", _moduleToName(module))));

        fullDB.addValueDocument(db, docId, HIST_SLOT_TIMESTAMP, _uint2str(block.timestamp), false);
        fullDB.addValueDocument(db, docId, HIST_SLOT_BAL_A,     _uint2str(balA),            false);
        fullDB.addValueDocument(db, docId, HIST_SLOT_BRANCH_ID, _uint2str(branchId),        false);

        fullDB.commit(db);
    
        emit PointHistorySynced(agent, wallet, tokenType, actionType, delta, branchId, docId);
    }

    // ================================================================
    // SYNC — TRANSACTION
    // ================================================================

    function syncTransaction(
        address agent,
        uint256 txId,
        address member,
        string  memory txType,
        int256  points,
        uint256 amount,
        bytes32 invoiceId,
        string  memory note,
        uint256 timestamp,
        uint256 branchId,
        bytes32 module
    ) external  agentReady(agent) {
        string memory db   = _txsDb(agent);
        string memory data = _buildTxJson(
            txId, member, txType, points, amount,
            invoiceId, note, timestamp, branchId, module
        );
        uint256 docId = fullDB.newDocument(db, data);
        txDocId[agent][txId] = docId;
        fullDB.addTermDocument(db, docId,
            string(abi.encodePacked(P_WALLET, ":", _addressToString(member))));
        fullDB.addTermDocument(db, docId,
            string(abi.encodePacked(P_TXTYPE, ":", txType)));
        fullDB.addTermDocument(db, docId,
            string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))));
        fullDB.addTermDocument(db, docId,
            string(abi.encodePacked(P_MODULE, ":", _moduleToName(module))));
        fullDB.addValueDocument(db, docId, TX_SLOT_TIMESTAMP, _uint2str(timestamp), false);
        fullDB.addValueDocument(db, docId, TX_SLOT_AMOUNT,    _uint2str(amount),    false);
        fullDB.addValueDocument(db, docId, TX_SLOT_BRANCH_ID, _uint2str(branchId),  false);
        fullDB.commit(db);
        emit TransactionSynced(agent, txId, docId, branchId, module);
    }

    // ================================================================
    // QUERY — POINT HISTORY
    // ================================================================

    /// @notice Toàn bộ lịch sử điểm của user trong DB của agent, mới nhất trước.
    function getPointHistoryByMember(address agent, address wallet, uint64 offset, uint64 limit)
        external agentReady(agent) returns (SearchResultsPage memory)
    {
        PrefixEntry[] memory pm = _pm2(P_WALLET, P_WALLET);
        return fullDB.querySearch(_pointHistoryDb(agent), _buildParams(
            string(abi.encodePacked(P_WALLET, ":", _addressToString(wallet))),
            pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Lịch sử điểm của user, lọc theo tokenType ("A" hoặc "B").
    function getPointHistoryByTokenType(
        address agent,
        address wallet,
        bytes32 tokenType,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_TOKEN_TYPE, P_TOKEN_TYPE);
        return fullDB.querySearch(_pointHistoryDb(agent), _buildParams(
            string(abi.encodePacked(
                P_WALLET, ":", _addressToString(wallet),
                " ", P_TOKEN_TYPE, ":", _tokenTypeName(tokenType)
            )),
            pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Lịch sử điểm của user, lọc theo actionType.
    function getPointHistoryByAction(
        address agent,
        address wallet,
        bytes32 actionType,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_ACTION, P_ACTION);
        return fullDB.querySearch(_pointHistoryDb(agent), _buildParams(
            string(abi.encodePacked(
                P_WALLET, ":", _addressToString(wallet),
                " ", P_ACTION, ":", _actionTypeName(actionType)
            )),
            pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Lịch sử điểm của user, lọc theo cả tokenType + actionType.
    function getPointHistoryByTokenAndAction(
        address agent,
        address wallet,
        bytes32 tokenType,
        bytes32 actionType,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = new PrefixEntry[](6);
        pm[0] = PrefixEntry("wallet",     P_WALLET);     pm[1] = PrefixEntry(P_WALLET,     P_WALLET);
        pm[2] = PrefixEntry("tokenType",  P_TOKEN_TYPE); pm[3] = PrefixEntry(P_TOKEN_TYPE, P_TOKEN_TYPE);
        pm[4] = PrefixEntry("actionType", P_ACTION);     pm[5] = PrefixEntry(P_ACTION,     P_ACTION);

        return fullDB.querySearch(_pointHistoryDb(agent), _buildParams(
            string(abi.encodePacked(
                P_WALLET, ":", _addressToString(wallet),
                " ", P_TOKEN_TYPE, ":", _tokenTypeName(tokenType),
                " ", P_ACTION, ":", _actionTypeName(actionType)
            )),
            pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Lịch sử điểm của user tại branch cụ thể.
    function getPointHistoryByMemberAndBranch(
        address agent,
        address wallet,
        uint256 branchId,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_BRANCH, P_BRANCH);
        return fullDB.querySearch(_pointHistoryDb(agent), _buildParams(
            string(abi.encodePacked(
                P_WALLET, ":", _addressToString(wallet),
                " ", P_BRANCH, ":", _uint2str(branchId)
            )),
            pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Lịch sử điểm của user theo module.
    function getPointHistoryByMemberAndModule(
        address agent,
        address wallet,
        bytes32 module,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_MODULE, P_MODULE);
        return fullDB.querySearch(_pointHistoryDb(agent), _buildParams(
            string(abi.encodePacked(
                P_WALLET, ":", _addressToString(wallet),
                " ", P_MODULE, ":", _moduleToName(module)
            )),
            pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Toàn bộ lịch sử điểm tại một branch (tất cả user).
    function getPointHistoryByBranch(address agent, uint256 branchId, uint64 offset, uint64 limit)
        external agentReady(agent) returns (SearchResultsPage memory)
    {
        PrefixEntry[] memory pm = _pm2(P_BRANCH, P_BRANCH);
        return fullDB.querySearch(_pointHistoryDb(agent), _buildParams(
            string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))),
            pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Lịch sử điểm trong khoảng balA.
    function getPointHistoryByBalanceRange(
        address agent,
        address wallet,
        string  memory minBal,
        string  memory maxBal,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm2(P_WALLET, P_WALLET);
        RangeFilter[] memory ranges = new RangeFilter[](1);
        ranges[0] = RangeFilter(HIST_SLOT_BAL_A, minBal, maxBal);
        return fullDB.querySearch(_pointHistoryDb(agent), _buildParams(
            string(abi.encodePacked(P_WALLET, ":", _addressToString(wallet))),
            pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
            ranges
        ));
    }

    // ================================================================
    // QUERY — TRANSACTION
    // ================================================================

    /// @notice Tất cả tx của member trong DB của agent, mới nhất trước.
    function getTxsByMember(address agent, address member, uint64 offset, uint64 limit)
        external agentReady(agent) returns (SearchResultsPage memory)
    {
        PrefixEntry[] memory pm = _pm2(P_WALLET, P_WALLET);
        return fullDB.querySearch(_txsDb(agent), _buildParams(
            string(abi.encodePacked(P_WALLET, ":", _addressToString(member))),
            pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Tx của member theo txType + khoảng amount.
    function getTxsByMemberAndType(
        address agent,
        address member,
        string  memory txType,
        string  memory minAmount,
        string  memory maxAmount,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_TXTYPE, P_TXTYPE);
        RangeFilter[] memory ranges = new RangeFilter[](1);
        ranges[0] = RangeFilter(TX_SLOT_AMOUNT, minAmount, maxAmount);
        return fullDB.querySearch(_txsDb(agent), _buildParams(
            string(abi.encodePacked(
                P_WALLET, ":", _addressToString(member),
                " ", P_TXTYPE, ":", txType
            )),
            pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
            ranges
        ));
    }

    /// @notice Tất cả tx tại branch.
    function getTxsByBranch(address agent, uint256 branchId, uint64 offset, uint64 limit)
        external agentReady(agent) returns (SearchResultsPage memory)
    {
        PrefixEntry[] memory pm = _pm2(P_BRANCH, P_BRANCH);
        return fullDB.querySearch(_txsDb(agent), _buildParams(
            string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))),
            pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Tất cả tx từ một module.
    function getTxsByModule(address agent, bytes32 module, uint64 offset, uint64 limit)
        external agentReady(agent) returns (SearchResultsPage memory)
    {
        PrefixEntry[] memory pm = _pm2(P_MODULE, P_MODULE);
        return fullDB.querySearch(_txsDb(agent), _buildParams(
            string(abi.encodePacked(P_MODULE, ":", _moduleToName(module))),
            pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Tx theo branch + module kết hợp.
    function getTxsByBranchAndModule(
        address agent,
        uint256 branchId,
        bytes32 module,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm4(P_BRANCH, P_BRANCH, P_MODULE, P_MODULE);
        return fullDB.querySearch(_txsDb(agent), _buildParams(
            string(abi.encodePacked(
                P_BRANCH, ":", _uint2str(branchId),
                " ", P_MODULE, ":", _moduleToName(module)
            )),
            pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Tx của member tại branch cụ thể.
    function getTxsByMemberAndBranch(
        address agent,
        address member,
        uint256 branchId,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_BRANCH, P_BRANCH);
        return fullDB.querySearch(_txsDb(agent), _buildParams(
            string(abi.encodePacked(
                P_WALLET, ":", _addressToString(member),
                " ", P_BRANCH, ":", _uint2str(branchId)
            )),
            pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Tx theo branch + khoảng amount.
    function getTxsByBranchAndAmountRange(
        address agent,
        uint256 branchId,
        string  memory minAmount,
        string  memory maxAmount,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm2(P_BRANCH, P_BRANCH);
        RangeFilter[] memory ranges = new RangeFilter[](1);
        ranges[0] = RangeFilter(TX_SLOT_AMOUNT, minAmount, maxAmount);
        return fullDB.querySearch(_txsDb(agent), _buildParams(
            string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))),
            pm, offset, limit, int64(int256(TX_SLOT_AMOUNT)), false,
            ranges
        ));
    }

    /// @notice Tx của member theo module.
    function getTxsByMemberAndModule(
        address agent,
        address member,
        bytes32 module,
        uint64  offset,
        uint64  limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_MODULE, P_MODULE);
        return fullDB.querySearch(_txsDb(agent), _buildParams(
            string(abi.encodePacked(
                P_WALLET, ":", _addressToString(member),
                " ", P_MODULE, ":", _moduleToName(module)
            )),
            pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
            new RangeFilter[](0)
        ));
    }

    /// @notice Tất cả tx trong khoảng thời gian [fromTs, toTs].
    function getTxsByTimeRange(
        address agent,
        string memory fromTs,
        string memory toTs,
        uint64 offset,
        uint64 limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        RangeFilter[] memory ranges = new RangeFilter[](1);
        ranges[0] = RangeFilter(TX_SLOT_TIMESTAMP, fromTs, toTs);
        return fullDB.querySearch(_txsDb(agent), _buildParams(
            "",
            new PrefixEntry[](0),
            offset, limit,
            int64(int256(TX_SLOT_TIMESTAMP)), false,
            ranges
        ));
    }

    /// @notice Tx theo branch trong khoảng thời gian.
    function getTxsByBranchAndTimeRange(
        address agent,
        uint256 branchId,
        string memory fromTs,
        string memory toTs,
        uint64 offset,
        uint64 limit
    ) external agentReady(agent) returns (SearchResultsPage memory) {
        PrefixEntry[] memory pm = _pm2(P_BRANCH, P_BRANCH);
        RangeFilter[] memory ranges = new RangeFilter[](1);
        ranges[0] = RangeFilter(TX_SLOT_TIMESTAMP, fromTs, toTs);
        return fullDB.querySearch(_txsDb(agent), _buildParams(
            string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))),
            pm, offset, limit,
            int64(int256(TX_SLOT_TIMESTAMP)), false,
            ranges
        ));
    }

    // ================================================================
    // PASSTHROUGH — raw FullDB access
    // ================================================================

    function newDocument(string memory dbname, string memory data) public returns (uint256) {
        return fullDB.newDocument(dbname, data);
    }

    function getDataDocument(string memory dbname, uint256 docId) public returns (string memory) {
        return fullDB.getDataDocument(dbname, docId);
    }

    function setDataDocument(string memory dbname, uint256 docId, string memory data) public returns (bool) {
        return fullDB.setDataDocument(dbname, docId, data);
    }

    function indexTextForDocument(string memory dbname, uint256 docId, string memory text, uint8 wdf_inc, string memory prefix) public returns (bool) {
        return fullDB.indexTextForDocument(dbname, docId, text, wdf_inc, prefix);
    }

    function addValueDocument(string memory dbname, uint256 docId, uint256 slot, string memory data, bool isSerialise) external returns (bool) {
        return fullDB.addValueDocument(dbname, docId, slot, data, isSerialise);
    }

    function deleteDocument(string memory dbname, uint256 docId) public returns (bool) {
        return fullDB.deleteDocument(dbname, docId);
    }

    function getValueDocument(string memory dbname, uint256 docId, uint256 slot, bool isSerialise) public returns (string memory) {
        return fullDB.getValueDocument(dbname, docId, slot, isSerialise);
    }

    function getTermsDocument(string memory dbname, uint256 docId) public returns (string[] memory) {
        return fullDB.getTermsDocument(dbname, docId);
    }

    function getOrCreateDb(string memory name) public returns (bool) {
        return fullDB.getOrCreateDb(name);
    }

    function commit(string memory name) public returns (bool) {
        return fullDB.commit(name);
    }

    event QuerySearchResults(uint256 totalResults, uint256 resultsCount);

    function querySearch(string memory dbname, SearchParams memory params) public returns (SearchResultsPage memory) {
        SearchResultsPage memory currentPage = fullDB.querySearch(dbname, params);
        emit QuerySearchResults(currentPage.total, currentPage.results.length);
        return currentPage;
    }

    // ================================================================
    // INTERNAL — DB name builders
    // ================================================================

    function _pointHistoryDb(address agent) internal pure returns (string memory) {
        return string(abi.encodePacked(DB_POINT_HISTORY_PREFIX, _addressToString(agent)));
    }

    function _txsDb(address agent) internal pure returns (string memory) {
        return string(abi.encodePacked(DB_TXS_PREFIX, _addressToString(agent)));
    }

    // ================================================================
    // INTERNAL — SearchParams builder helpers
    // ================================================================

    function _buildParams(
        string        memory query,
        PrefixEntry[] memory pm,
        uint64        offset,
        uint64        limit,
        int64         sortSlot,
        bool          ascending,
        RangeFilter[] memory ranges
    ) internal pure returns (SearchParams memory) {
        return SearchParams({
            queries:         query,
            prefixMap:       pm,
            stopWords:       new string[](0),
            offset:          offset,
            limit:           limit,
            sortByValueSlot: sortSlot,
            sortAscending:   ascending,
            rangeFilters:    ranges
        });
    }

    function _pm2(string memory k0, string memory v0)
        internal pure returns (PrefixEntry[] memory pm)
    {
        pm = new PrefixEntry[](2);
        pm[0] = PrefixEntry(k0, v0);
        pm[1] = PrefixEntry(v0, v0);
    }

    function _pm4(string memory k0, string memory v0, string memory k1, string memory v1)
        internal pure returns (PrefixEntry[] memory pm)
    {
        pm = new PrefixEntry[](4);
        pm[0] = PrefixEntry(k0, v0); pm[1] = PrefixEntry(v0, v0);
        pm[2] = PrefixEntry(k1, v1); pm[3] = PrefixEntry(v1, v1);
    }

    // ================================================================
    // INTERNAL — JSON builders
    // ================================================================

    function _buildPointHistoryJson(
        address wallet,
        bytes32 tokenType,
        bytes32 actionType,
        int256  delta,
        uint256 balA,
        uint256 balB,
        uint256 totalSpent,
        uint256 branchId,
        bytes32 module,
        bytes32 refId,
        uint256 timestamp
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"wallet":"',      _addressToString(wallet),
            '","tokenType":"',  _tokenTypeName(tokenType),
            '","actionType":"', _actionTypeName(actionType),
            '","delta":',       _int2str(delta),
            ',"balA":',         _uint2str(balA),
            ',"balB":',         _uint2str(balB),
            ',"totalSpent":',   _uint2str(totalSpent),
            ',"branchId":',     _uint2str(branchId),
            ',"module":"',      _moduleToName(module),
            '","refId":"',      _bytes32ToStr(refId),
            '","timestamp":',   _uint2str(timestamp),
            '}'
        ));
    }

    function _buildTxJson(
        uint256 txId,
        address member,
        string  memory txType,
        int256  points,
        uint256 amount,
        bytes32 invoiceId,
        string  memory note,
        uint256 timestamp,
        uint256 branchId,
        bytes32 module
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '{"txId":',        _uint2str(txId),
            ',"member":"',     _addressToString(member),
            '","txType":"',    txType,
            '","points":',     _int2str(points),
            ',"amount":',      _uint2str(amount),
            ',"invoiceId":"',  _bytes32ToStr(invoiceId),
            '","note":"',      note,
            '","timestamp":',  _uint2str(timestamp),
            ',"branchId":',    _uint2str(branchId),
            ',"module":"',     _moduleToName(module),
            '"}'
        ));
    }

    // ================================================================
    // INTERNAL — Name resolvers
    // ================================================================

    function _tokenTypeName(bytes32 t) internal pure returns (string memory) {
        if (t == keccak256("A")) return "A";
        if (t == keccak256("B")) return "B";
        return "UNKNOWN";
    }

    function _actionTypeName(bytes32 a) internal pure returns (string memory) {
        if (a == keccak256("CREDIT")) return "CREDIT";
        if (a == keccak256("DEBIT"))  return "DEBIT";
        if (a == keccak256("GRANT"))  return "GRANT";
        if (a == keccak256("EXPIRE")) return "EXPIRE";
        return "UNKNOWN";
    }

    function _moduleToName(bytes32 module) internal pure returns (string memory) {
        if (module == keccak256("NET_MODULE"))  return "NET_MODULE";
        if (module == keccak256("FOOD_MODULE")) return "FOOD_MODULE";
        return "UNKNOWN";
    }

    // ================================================================
    // INTERNAL — Utils
    // ================================================================

    function _uint2str(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 tmp = v; uint256 len;
        while (tmp != 0) { len++; tmp /= 10; }
        bytes memory b = new bytes(len);
        while (v != 0) { b[--len] = bytes1(uint8(48 + v % 10)); v /= 10; }
        return string(b);
    }

    function _int2str(int256 v) internal pure returns (string memory) {
        if (v < 0) return string(abi.encodePacked("-", _uint2str(uint256(-v))));
        return _uint2str(uint256(v));
    }

    function _addressToString(address a) internal pure returns (string memory) {
        bytes memory b = new bytes(42);
        b[0] = '0'; b[1] = 'x';
        for (uint i = 0; i < 20; i++) {
            uint8 hi = uint8(uint160(a) >> (8 * (19 - i))) >> 4;
            uint8 lo = uint8(uint160(a) >> (8 * (19 - i))) & 0x0f;
            b[2 + i * 2]     = hi < 10 ? bytes1(hi + 48) : bytes1(hi + 87);
            b[2 + i * 2 + 1] = lo < 10 ? bytes1(lo + 48) : bytes1(lo + 87);
        }
        return string(b);
    }

    function _bytes32ToStr(bytes32 bz) internal pure returns (string memory) {
        bytes memory s = new bytes(64);
        for (uint i = 0; i < 32; i++) {
            uint8 hi = uint8(bz[i]) >> 4;
            uint8 lo = uint8(bz[i]) & 0x0f;
            s[i * 2]     = hi < 10 ? bytes1(hi + 48) : bytes1(hi + 87);
            s[i * 2 + 1] = lo < 10 ? bytes1(lo + 48) : bytes1(lo + 87);
        }
        return string(s);
    }
}