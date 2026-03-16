// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// // ================================================================
// // STRUCTS & INTERFACE
// // ================================================================

// struct PrefixEntry {
//     string key;
//     string value;
// }

// struct RangeFilter {
//     uint   slot;
//     string startSerialised;
//     string endSerialised;
// }

// struct SearchParams {
//     string        queries;
//     PrefixEntry[] prefixMap;
//     string[]      stopWords;
//     uint64        offset;
//     uint64        limit;
//     int64         sortByValueSlot;
//     bool          sortAscending;
//     RangeFilter[] rangeFilters;
// }

// struct SearchResult {
//     uint256 docid;
//     uint256 rank;
//     int256  percent;
//     string  data;
// }

// struct SearchResultsPage {
//     uint256        total;
//     SearchResult[] results;
// }

// interface FullDB {
//     function getOrCreateDb(string memory name) external returns (bool);
//     function newDocument(string memory dbname, string memory data) external returns (uint256);
//     function getDataDocument(string memory dbname, uint256 docId) external returns (string memory);
//     function setDataDocument(string memory dbname, uint256 docId, string memory data) external returns (bool);
//     function deleteDocument(string memory dbname, uint256 docId) external returns (bool);
//     function addTermDocument(string memory dbname, uint256 docId, string memory term) external returns (bool);
//     function indexTextForDocument(string memory dbname, uint256 docId, string memory text, uint8 weight, string memory prefix) external returns (bool);
//     function addValueDocument(string memory dbname, uint256 docId, uint256 slot, string memory data, bool isSerialise) external returns (bool);
//     function getValueDocument(string memory dbname, uint256 docId, uint256 slot, bool isSerialise) external returns (string memory);
//     function getTermsDocument(string memory dbname, uint256 docId) external returns (string[] memory);
//     function search(string memory dbname, string memory query) external returns (string memory);
//     function querySearch(string memory dbname, SearchParams memory params) external returns (SearchResultsPage memory);
//     function commit(string memory dbname) external returns (bool);
// }

// // ================================================================
// /**
//  * @title LoyaltySearchIndex
//  * @notice Search/query layer cho RestaurantLoyaltySystem.
//  *
//  * ── DB: loyalty_point_history ────────────────────────────────────
//  *   Mục đích: Nhật ký MỌI thay đổi balance của user.
//  *   Mỗi lần _creditA / _debitA / _grantB / _debitB / _expireBatches
//  *   → gọi syncMember → tạo 1 document MỚI (append-only, không upsert).
//  *
//  *   data = JSON {
//  *       wallet,
//  *       tokenType,   ← "A" | "B"
//  *       actionType,  ← "CREDIT" | "DEBIT" | "GRANT" | "EXPIRE"
//  *       delta,       ← số điểm thay đổi (dương = cộng, âm = trừ)
//  *       balA,        ← số dư Token A SAU khi thay đổi
//  *       balB,        ← số dư Token B SAU khi thay đổi
//  *       totalSpent,
//  *       branchId,
//  *       module,      ← "NET_MODULE" | "FOOD_MODULE" | "UNKNOWN"
//  *       refId,       ← invoiceId / idempotencyKey / sourceEventId
//  *       timestamp
//  *   }
//  *
//  *   prefix W = wallet address   (exact)  → lọc theo user
//  *   prefix T = tokenType        (exact)  → "A" hoặc "B"
//  *   prefix A = actionType       (exact)  → "CREDIT" | "DEBIT" | "GRANT" | "EXPIRE"
//  *   prefix B = branchId         (exact)  → lọc theo branch
//  *   prefix D = module           (exact)  → "NET_MODULE" | "FOOD_MODULE"
//  *   slot 0   = timestamp        (sort)
//  *   slot 1   = balA             (sort / range)
//  *   slot 2   = branchId         (sort / range)
//  *
//  * ── DB: loyalty_transactions ─────────────────────────────────────
//  *   Mục đích: Nhật ký các transaction do staff thực hiện.
//  *   Mỗi _createTransaction → tạo 1 document mới.
//  *
//  *   data = JSON {
//  *       txId, member, txType, points, amount,
//  *       invoiceId, note, timestamp, branchId, module
//  *   }
//  *   prefix W = wallet   (exact)
//  *   prefix X = txType   (exact)  "Earn"|"Redeem"|"Issue"|"Expire"
//  *   prefix B = branchId (exact)
//  *   prefix D = module   (exact)
//  *   slot 0   = timestamp  (sort)
//  *   slot 1   = amount     (sort / range)
//  *   slot 2   = branchId   (sort / range)
//  */
// contract PublicfullDB {

//     FullDB public fullDB = FullDB(0x0000000000000000000000000000000000000106);

//     // ── DB names ──────────────────────────────────────────────────
//     string constant DB_POINT_HISTORY = "loyalty_point_history";
//     string constant DB_TXS           = "loyalty_transactions";

//     // ── actionType constants — dùng trong syncMember ──────────────
//     // Caller truyền vào 1 trong 4 giá trị này
//     bytes32 public constant ACT_CREDIT = keccak256("CREDIT"); // _creditA
//     bytes32 public constant ACT_DEBIT  = keccak256("DEBIT");  // _debitA / _debitB
//     bytes32 public constant ACT_GRANT  = keccak256("GRANT");  // _grantB
//     bytes32 public constant ACT_EXPIRE = keccak256("EXPIRE"); // _expireBatches

//     // ── tokenType constants — dùng trong syncMember ───────────────
//     bytes32 public constant TOKEN_A = keccak256("A");
//     bytes32 public constant TOKEN_B = keccak256("B");

//     // ── module constants ──────────────────────────────────────────
//     bytes32 public constant NET_MODULE  = keccak256("NET_MODULE");
//     bytes32 public constant FOOD_MODULE = keccak256("FOOD_MODULE");

//     // ── prefix — point history DB ─────────────────────────────────
//     string constant P_WALLET     = "W";  // exact wallet
//     string constant P_TOKEN_TYPE = "T";  // exact tokenType: "A" | "B"
//     string constant P_ACTION     = "A";  // exact actionType: "CREDIT"|"DEBIT"|"GRANT"|"EXPIRE"
//     string constant P_BRANCH     = "B";  // exact branchId
//     string constant P_MODULE     = "D";  // exact module

//     // ── prefix — tx DB ───────────────────────────────────────────
//     // (W, B, D dùng lại)
//     string constant P_TXTYPE = "X";  // exact txType: "Earn"|"Redeem"|"Issue"|"Expire"

//     // ── value slots — point history DB ───────────────────────────
//     uint256 constant HIST_SLOT_TIMESTAMP = 0;
//     uint256 constant HIST_SLOT_BAL_A     = 1;
//     uint256 constant HIST_SLOT_BRANCH_ID = 2;

//     // ── value slots — tx DB ──────────────────────────────────────
//     uint256 constant TX_SLOT_TIMESTAMP  = 0;
//     uint256 constant TX_SLOT_AMOUNT     = 1;
//     uint256 constant TX_SLOT_BRANCH_ID  = 2;

//     // ── access control ────────────────────────────────────────────
//     mapping(address => bool) public isAllowedCaller; // có thể whitelist thêm các caller khác ngoài loyaltyContract nếu cần
//     address public owner;

//     // txId → docId trong DB_TXS
//     mapping(uint256 => uint256) public txDocId;

//     // ── events ────────────────────────────────────────────────────
//     event PointHistorySynced(
//         address indexed wallet,
//         bytes32 indexed tokenType,
//         bytes32 indexed actionType,
//         int256  delta,
//         uint256 branchId,
//         uint256 docId
//     );
//     event TransactionSynced(uint256 indexed txId, uint256 docId, uint256 branchId, bytes32 module);

//     // ── modifier ──────────────────────────────────────────────────
//     modifier onlyAllowedCaller() {
//         require(isAllowedCaller[msg.sender], "Unauthorized");
//         _;
//     }
//     // ── constructor ───────────────────────────────────────────────
//     constructor() {
//         owner           = msg.sender;
//         fullDB.getOrCreateDb(DB_POINT_HISTORY);
//         fullDB.getOrCreateDb(DB_TXS);
//     }

//     // ── admin ─────────────────────────────────────────────────────

//     function setAllowedCaller(address caller, bool allowed) external {
//         require(msg.sender == owner, "Only owner");
//         isAllowedCaller[caller] = allowed;
//     }

//     function commitAll() external {
//         fullDB.commit(DB_POINT_HISTORY);
//         fullDB.commit(DB_TXS);
//     }

//     // ================================================================
//     // SYNC — POINT HISTORY  (append-only)
//     //
//     // Gọi ở cuối mỗi internal token function trong loyalty contract:
//     //   _creditA   → tokenType = TOKEN_A, actionType = ACT_CREDIT,  delta = +amount
//     //   _debitA    → tokenType = TOKEN_A, actionType = ACT_DEBIT,   delta = -amount
//     //   _grantB    → tokenType = TOKEN_B, actionType = ACT_GRANT,   delta = +amount
//     //   _debitB    → tokenType = TOKEN_B, actionType = ACT_DEBIT,   delta = -amount
//     //   _expireBatches (mỗi batch expire) → TOKEN_B, ACT_EXPIRE, delta = -expiredAmount
//     // ================================================================

//     /**
//      * @notice Ghi 1 snapshot nhật ký hoạt động điểm của user.
//      *
//      * @param wallet      Địa chỉ ví user
//      * @param tokenType   TOKEN_A | TOKEN_B
//      * @param actionType  ACT_CREDIT | ACT_DEBIT | ACT_GRANT | ACT_EXPIRE
//      * @param delta       Thay đổi điểm: dương = cộng, âm = trừ
//      * @param balA        Số dư Token A SAU khi thay đổi
//      * @param balB        Số dư Token B SAU khi thay đổi
//      * @param totalSpent  Tổng đã chi tiêu (member.totalSpent)
//      * @param branchId    Branch nơi phát sinh (0 = global)
//      * @param module      NET_MODULE | FOOD_MODULE | bytes32(0)
//      * @param refId       invoiceId / idempotencyKey / sourceEventId
//      */
//     function syncMember(
//         address wallet,
//         bytes32 tokenType,
//         bytes32 actionType,
//         int256  delta,
//         uint256 balA,
//         uint256 balB,
//         uint256 totalSpent,
//         uint256 branchId,
//         bytes32 module,
//         bytes32 refId
//     ) external onlyAllowedCaller {
//         string memory data = _buildPointHistoryJson(
//             wallet, tokenType, actionType, delta,
//             balA, balB, totalSpent,
//             branchId, module, refId,
//             block.timestamp
//         );

//         // Luôn tạo document MỚI — không upsert
//         uint256 docId = fullDB.newDocument(DB_POINT_HISTORY, data);

//         // ── exact term index ──────────────────────────────────────
//         fullDB.addTermDocument(DB_POINT_HISTORY, docId,
//             string(abi.encodePacked(P_WALLET, ":", _addressToString(wallet))));

//         fullDB.addTermDocument(DB_POINT_HISTORY, docId,
//             string(abi.encodePacked(P_TOKEN_TYPE, ":", _tokenTypeName(tokenType))));

//         fullDB.addTermDocument(DB_POINT_HISTORY, docId,
//             string(abi.encodePacked(P_ACTION, ":", _actionTypeName(actionType))));

//         fullDB.addTermDocument(DB_POINT_HISTORY, docId,
//             string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))));

//         fullDB.addTermDocument(DB_POINT_HISTORY, docId,
//             string(abi.encodePacked(P_MODULE, ":", _moduleToName(module))));

//         // ── sortable slots ────────────────────────────────────────
//         fullDB.addValueDocument(DB_POINT_HISTORY, docId, HIST_SLOT_TIMESTAMP, _uint2str(block.timestamp), false);
//         fullDB.addValueDocument(DB_POINT_HISTORY, docId, HIST_SLOT_BAL_A,     _uint2str(balA),            false);
//         fullDB.addValueDocument(DB_POINT_HISTORY, docId, HIST_SLOT_BRANCH_ID, _uint2str(branchId),        false);

//         emit PointHistorySynced(wallet, tokenType, actionType, delta, branchId, docId);
//     }

//     // ================================================================
//     // SYNC — TRANSACTION
//     // ================================================================

//     function syncTransaction(
//         uint256 txId,
//         address member,
//         string  memory txType,
//         int256  points,
//         uint256 amount,
//         bytes32 invoiceId,
//         string  memory note,
//         uint256 timestamp,
//         uint256 branchId,
//         bytes32 module
//     ) external onlyAllowedCaller {
//         string memory data = _buildTxJson(
//             txId, member, txType, points, amount,
//             invoiceId, note, timestamp, branchId, module
//         );

//         uint256 docId = fullDB.newDocument(DB_TXS, data);
//         txDocId[txId] = docId;

//         fullDB.addTermDocument(DB_TXS, docId,
//             string(abi.encodePacked(P_WALLET, ":", _addressToString(member))));
//         fullDB.addTermDocument(DB_TXS, docId,
//             string(abi.encodePacked(P_TXTYPE, ":", txType)));
//         fullDB.addTermDocument(DB_TXS, docId,
//             string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))));
//         fullDB.addTermDocument(DB_TXS, docId,
//             string(abi.encodePacked(P_MODULE, ":", _moduleToName(module))));

//         fullDB.addValueDocument(DB_TXS, docId, TX_SLOT_TIMESTAMP, _uint2str(timestamp), false);
//         fullDB.addValueDocument(DB_TXS, docId, TX_SLOT_AMOUNT,    _uint2str(amount),    false);
//         fullDB.addValueDocument(DB_TXS, docId, TX_SLOT_BRANCH_ID, _uint2str(branchId),  false);

//         emit TransactionSynced(txId, docId, branchId, module);
//     }

//     // ================================================================
//     // QUERY — POINT HISTORY
//     // ================================================================

//     /// @notice Toàn bộ lịch sử điểm của user, mới nhất trước.
//     function getPointHistoryByMember(address wallet, uint64 offset, uint64 limit)
//         external returns (SearchResultsPage memory)
//     {
//         PrefixEntry[] memory pm = _pm2(P_WALLET, P_WALLET);
//         return fullDB.querySearch(DB_POINT_HISTORY, _buildParams(
//             string(abi.encodePacked(P_WALLET, ":", _addressToString(wallet))),
//             pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Lịch sử điểm của user, lọc theo tokenType ("A" hoặc "B").
//     /// @dev Ví dụ: getPointHistoryByTokenType(wallet, TOKEN_A, 0, 20)
//     function getPointHistoryByTokenType(
//         address wallet,
//         bytes32 tokenType,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_TOKEN_TYPE, P_TOKEN_TYPE);
//         return fullDB.querySearch(DB_POINT_HISTORY, _buildParams(
//             string(abi.encodePacked(
//                 P_WALLET, ":", _addressToString(wallet),
//                 " ", P_TOKEN_TYPE, ":", _tokenTypeName(tokenType)
//             )),
//             pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Lịch sử điểm của user, lọc theo actionType.
//     /// @dev actionType: ACT_CREDIT | ACT_DEBIT | ACT_GRANT | ACT_EXPIRE
//     ///      Ví dụ: getPointHistoryByAction(wallet, ACT_CREDIT, 0, 20)
//     function getPointHistoryByAction(
//         address wallet,
//         bytes32 actionType,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_ACTION, P_ACTION);
//         return fullDB.querySearch(DB_POINT_HISTORY, _buildParams(
//             string(abi.encodePacked(
//                 P_WALLET, ":", _addressToString(wallet),
//                 " ", P_ACTION, ":", _actionTypeName(actionType)
//             )),
//             pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Lịch sử điểm của user, lọc theo cả tokenType + actionType.
//     /// @dev Ví dụ: getPointHistoryByTokenAndAction(wallet, TOKEN_B, ACT_EXPIRE, 0, 10)
//     ///      → xem toàn bộ lịch sử Token B bị expire của user
//     function getPointHistoryByTokenAndAction(
//         address wallet,
//         bytes32 tokenType,
//         bytes32 actionType,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = new PrefixEntry[](6);
//         pm[0] = PrefixEntry("wallet",     P_WALLET);     pm[1] = PrefixEntry(P_WALLET,     P_WALLET);
//         pm[2] = PrefixEntry("tokenType",  P_TOKEN_TYPE); pm[3] = PrefixEntry(P_TOKEN_TYPE, P_TOKEN_TYPE);
//         pm[4] = PrefixEntry("actionType", P_ACTION);     pm[5] = PrefixEntry(P_ACTION,     P_ACTION);

//         return fullDB.querySearch(DB_POINT_HISTORY, _buildParams(
//             string(abi.encodePacked(
//                 P_WALLET, ":", _addressToString(wallet),
//                 " ", P_TOKEN_TYPE, ":", _tokenTypeName(tokenType),
//                 " ", P_ACTION, ":", _actionTypeName(actionType)
//             )),
//             pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Lịch sử điểm của user tại branch cụ thể.
//     function getPointHistoryByMemberAndBranch(
//         address wallet,
//         uint256 branchId,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_BRANCH, P_BRANCH);
//         return fullDB.querySearch(DB_POINT_HISTORY, _buildParams(
//             string(abi.encodePacked(
//                 P_WALLET, ":", _addressToString(wallet),
//                 " ", P_BRANCH, ":", _uint2str(branchId)
//             )),
//             pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Lịch sử điểm của user theo module.
//     function getPointHistoryByMemberAndModule(
//         address wallet,
//         bytes32 module,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_MODULE, P_MODULE);
//         return fullDB.querySearch(DB_POINT_HISTORY, _buildParams(
//             string(abi.encodePacked(
//                 P_WALLET, ":", _addressToString(wallet),
//                 " ", P_MODULE, ":", _moduleToName(module)
//             )),
//             pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Toàn bộ lịch sử điểm tại một branch (tất cả user).
//     function getPointHistoryByBranch(uint256 branchId, uint64 offset, uint64 limit)
//         external returns (SearchResultsPage memory)
//     {
//         PrefixEntry[] memory pm = _pm2(P_BRANCH, P_BRANCH);
//         return fullDB.querySearch(DB_POINT_HISTORY, _buildParams(
//             string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))),
//             pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Lịch sử điểm trong khoảng balA — phát hiện balance thấp bất thường.
//     function getPointHistoryByBalanceRange(
//         address wallet,
//         string  memory minBal,
//         string  memory maxBal,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = _pm2(P_WALLET, P_WALLET);
//         RangeFilter[] memory ranges = new RangeFilter[](1);
//         ranges[0] = RangeFilter(HIST_SLOT_BAL_A, minBal, maxBal);
//         return fullDB.querySearch(DB_POINT_HISTORY, _buildParams(
//             string(abi.encodePacked(P_WALLET, ":", _addressToString(wallet))),
//             pm, offset, limit, int64(int256(HIST_SLOT_TIMESTAMP)), false,
//             ranges
//         ));
//     }

//     // ================================================================
//     // QUERY — TRANSACTION
//     // ================================================================

//     /// @notice Tất cả tx của member, mới nhất trước.
//     function getTxsByMember(address member, uint64 offset, uint64 limit)
//         external returns (SearchResultsPage memory)
//     {
//         PrefixEntry[] memory pm = _pm2(P_WALLET, P_WALLET);
//         return fullDB.querySearch(DB_TXS, _buildParams(
//             string(abi.encodePacked(P_WALLET, ":", _addressToString(member))),
//             pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Tx của member theo txType + khoảng amount.
//     function getTxsByMemberAndType(
//         address member,
//         string  memory txType,
//         string  memory minAmount,
//         string  memory maxAmount,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_TXTYPE, P_TXTYPE);
//         RangeFilter[] memory ranges = new RangeFilter[](1);
//         ranges[0] = RangeFilter(TX_SLOT_AMOUNT, minAmount, maxAmount);
//         return fullDB.querySearch(DB_TXS, _buildParams(
//             string(abi.encodePacked(
//                 P_WALLET, ":", _addressToString(member),
//                 " ", P_TXTYPE, ":", txType
//             )),
//             pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
//             ranges
//         ));
//     }

//     /// @notice Tất cả tx tại branch.
//     function getTxsByBranch(uint256 branchId, uint64 offset, uint64 limit)
//         external returns (SearchResultsPage memory)
//     {
//         PrefixEntry[] memory pm = _pm2(P_BRANCH, P_BRANCH);
//         return fullDB.querySearch(DB_TXS, _buildParams(
//             string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))),
//             pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Tất cả tx từ một module.
//     function getTxsByModule(bytes32 module, uint64 offset, uint64 limit)
//         external returns (SearchResultsPage memory)
//     {
//         PrefixEntry[] memory pm = _pm2(P_MODULE, P_MODULE);
//         return fullDB.querySearch(DB_TXS, _buildParams(
//             string(abi.encodePacked(P_MODULE, ":", _moduleToName(module))),
//             pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Tx theo branch + module kết hợp.
//     function getTxsByBranchAndModule(
//         uint256 branchId,
//         bytes32 module,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = _pm4(P_BRANCH, P_BRANCH, P_MODULE, P_MODULE);
//         return fullDB.querySearch(DB_TXS, _buildParams(
//             string(abi.encodePacked(
//                 P_BRANCH, ":", _uint2str(branchId),
//                 " ", P_MODULE, ":", _moduleToName(module)
//             )),
//             pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Tx của member tại branch cụ thể.
//     function getTxsByMemberAndBranch(
//         address member,
//         uint256 branchId,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_BRANCH, P_BRANCH);
//         return fullDB.querySearch(DB_TXS, _buildParams(
//             string(abi.encodePacked(
//                 P_WALLET, ":", _addressToString(member),
//                 " ", P_BRANCH, ":", _uint2str(branchId)
//             )),
//             pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }

//     /// @notice Tx theo branch + khoảng amount.
//     function getTxsByBranchAndAmountRange(
//         uint256 branchId,
//         string  memory minAmount,
//         string  memory maxAmount,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = _pm2(P_BRANCH, P_BRANCH);
//         RangeFilter[] memory ranges = new RangeFilter[](1);
//         ranges[0] = RangeFilter(TX_SLOT_AMOUNT, minAmount, maxAmount);
//         return fullDB.querySearch(DB_TXS, _buildParams(
//             string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))),
//             pm, offset, limit, int64(int256(TX_SLOT_AMOUNT)), false,
//             ranges
//         ));
//     }

//     /// @notice Tx của member theo module.
//     function getTxsByMemberAndModule(
//         address member,
//         bytes32 module,
//         uint64  offset,
//         uint64  limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory pm = _pm4(P_WALLET, P_WALLET, P_MODULE, P_MODULE);
//         return fullDB.querySearch(DB_TXS, _buildParams(
//             string(abi.encodePacked(
//                 P_WALLET, ":", _addressToString(member),
//                 " ", P_MODULE, ":", _moduleToName(module)
//             )),
//             pm, offset, limit, int64(int256(TX_SLOT_TIMESTAMP)), false,
//             new RangeFilter[](0)
//         ));
//     }
// /// @notice Tất cả tx trong khoảng thời gian [fromTs, toTs], sort mới nhất trước.
// /// @dev Dùng range filter trên SLOT_TIMESTAMP — không cần lọc theo branch cụ thể.
// ///      Ví dụ: getTxsByTimeRange("1700000000", "1710000000", 0, 20)
// function getTxsByTimeRange(
//     string memory fromTs,
//     string memory toTs,
//     uint64 offset,
//     uint64 limit
// ) external returns (SearchResultsPage memory) {
//     RangeFilter[] memory ranges = new RangeFilter[](1);
//     ranges[0] = RangeFilter(TX_SLOT_TIMESTAMP, fromTs, toTs);

//     return fullDB.querySearch(DB_TXS, _buildParams(
//         "",
//         new PrefixEntry[](0),
//         offset,
//         limit,
//         int64(int256(TX_SLOT_TIMESTAMP)),
//         false,
//         ranges
//     ));
// }

// /// @notice Tx theo branch trong khoảng thời gian [fromTs, toTs].
// /// @dev Ví dụ: getTxsByBranchAndTimeRange(1, "1700000000", "1710000000", 0, 20)
// function getTxsByBranchAndTimeRange(
//     uint256 branchId,
//     string memory fromTs,
//     string memory toTs,
//     uint64 offset,
//     uint64 limit
// ) external returns (SearchResultsPage memory) {
//     PrefixEntry[] memory pm = _pm2(P_BRANCH, P_BRANCH);

//     RangeFilter[] memory ranges = new RangeFilter[](1);
//     ranges[0] = RangeFilter(TX_SLOT_TIMESTAMP, fromTs, toTs);

//     return fullDB.querySearch(DB_TXS, _buildParams(
//         string(abi.encodePacked(P_BRANCH, ":", _uint2str(branchId))),
//         pm,
//         offset,
//         limit,
//         int64(int256(TX_SLOT_TIMESTAMP)),
//         false,
//         ranges
//     ));
// }
//     // ================================================================
//     // INTERNAL — SearchParams builder helpers
//     // ================================================================

//     function _buildParams(
//         string      memory query,
//         PrefixEntry[] memory pm,
//         uint64      offset,
//         uint64      limit,
//         int64       sortSlot,
//         bool        ascending,
//         RangeFilter[] memory ranges
//     ) internal pure returns (SearchParams memory) {
//         return SearchParams({
//             queries:         query,
//             prefixMap:       pm,
//             stopWords:       new string[](0),
//             offset:          offset,
//             limit:           limit,
//             sortByValueSlot: sortSlot,
//             sortAscending:   ascending,
//             rangeFilters:    ranges
//         });
//     }

//     /// @dev PrefixEntry[2] helper
//     function _pm2(string memory k0, string memory v0)
//         internal pure returns (PrefixEntry[] memory pm)
//     {
//         pm = new PrefixEntry[](2);
//         pm[0] = PrefixEntry(k0, v0);
//         pm[1] = PrefixEntry(v0, v0);
//     }

//     /// @dev PrefixEntry[4] helper
//     function _pm4(string memory k0, string memory v0, string memory k1, string memory v1)
//         internal pure returns (PrefixEntry[] memory pm)
//     {
//         pm = new PrefixEntry[](4);
//         pm[0] = PrefixEntry(k0, v0); pm[1] = PrefixEntry(v0, v0);
//         pm[2] = PrefixEntry(k1, v1); pm[3] = PrefixEntry(v1, v1);
//     }

//     // ================================================================
//     // INTERNAL — JSON builders
//     // ================================================================

//     function _buildPointHistoryJson(
//         address wallet,
//         bytes32 tokenType,
//         bytes32 actionType,
//         int256  delta,
//         uint256 balA,
//         uint256 balB,
//         uint256 totalSpent,
//         uint256 branchId,
//         bytes32 module,
//         bytes32 refId,
//         uint256 timestamp
//     ) internal pure returns (string memory) {
//         return string(abi.encodePacked(
//             '{"wallet":"',      _addressToString(wallet),
//             '","tokenType":"',  _tokenTypeName(tokenType),
//             '","actionType":"', _actionTypeName(actionType),
//             '","delta":',       _int2str(delta),
//             ',"balA":',         _uint2str(balA),
//             ',"balB":',         _uint2str(balB),
//             ',"totalSpent":',   _uint2str(totalSpent),
//             ',"branchId":',     _uint2str(branchId),
//             ',"module":"',      _moduleToName(module),
//             '","refId":"',      _bytes32ToStr(refId),
//             '","timestamp":',   _uint2str(timestamp),
//             '}'
//         ));
//     }

//     function _buildTxJson(
//         uint256 txId,
//         address member,
//         string  memory txType,
//         int256  points,
//         uint256 amount,
//         bytes32 invoiceId,
//         string  memory note,
//         uint256 timestamp,
//         uint256 branchId,
//         bytes32 module
//     ) internal pure returns (string memory) {
//         return string(abi.encodePacked(
//             '{"txId":',        _uint2str(txId),
//             ',"member":"',     _addressToString(member),
//             '","txType":"',    txType,
//             '","points":',     _int2str(points),
//             ',"amount":',      _uint2str(amount),
//             ',"invoiceId":"',  _bytes32ToStr(invoiceId),
//             '","note":"',      note,
//             '","timestamp":',  _uint2str(timestamp),
//             ',"branchId":',    _uint2str(branchId),
//             ',"module":"',     _moduleToName(module),
//             '"}'
//         ));
//     }

//     // ================================================================
//     // INTERNAL — Name resolvers
//     // ================================================================

//     function _tokenTypeName(bytes32 t) internal pure returns (string memory) {
//         if (t == keccak256("A")) return "A";
//         if (t == keccak256("B")) return "B";
//         return "UNKNOWN";
//     }

//     function _actionTypeName(bytes32 a) internal pure returns (string memory) {
//         if (a == keccak256("CREDIT")) return "CREDIT";
//         if (a == keccak256("DEBIT"))  return "DEBIT";
//         if (a == keccak256("GRANT"))  return "GRANT";
//         if (a == keccak256("EXPIRE")) return "EXPIRE";
//         return "UNKNOWN";
//     }

//     function _moduleToName(bytes32 module) internal pure returns (string memory) {
//         if (module == keccak256("NET_MODULE"))  return "NET_MODULE";
//         if (module == keccak256("FOOD_MODULE")) return "FOOD_MODULE";
//         return "UNKNOWN";
//     }

//     // ================================================================
//     // INTERNAL — Utils
//     // ================================================================

//     function _uint2str(uint256 v) internal pure returns (string memory) {
//         if (v == 0) return "0";
//         uint256 tmp = v; uint256 len;
//         while (tmp != 0) { len++; tmp /= 10; }
//         bytes memory b = new bytes(len);
//         while (v != 0) { b[--len] = bytes1(uint8(48 + v % 10)); v /= 10; }
//         return string(b);
//     }

//     function _int2str(int256 v) internal pure returns (string memory) {
//         if (v < 0) return string(abi.encodePacked("-", _uint2str(uint256(-v))));
//         return _uint2str(uint256(v));
//     }

//     function _addressToString(address a) internal pure returns (string memory) {
//         bytes memory b = new bytes(42);
//         b[0] = '0'; b[1] = 'x';
//         for (uint i = 0; i < 20; i++) {
//             uint8 hi = uint8(uint160(a) >> (8 * (19 - i))) >> 4;
//             uint8 lo = uint8(uint160(a) >> (8 * (19 - i))) & 0x0f;
//             b[2 + i * 2]     = hi < 10 ? bytes1(hi + 48) : bytes1(hi + 87);
//             b[2 + i * 2 + 1] = lo < 10 ? bytes1(lo + 48) : bytes1(lo + 87);
//         }
//         return string(b);
//     }

//     function _bytes32ToStr(bytes32 bz) internal pure returns (string memory) {
//         bytes memory s = new bytes(64);
//         for (uint i = 0; i < 32; i++) {
//             uint8 hi = uint8(bz[i]) >> 4;
//             uint8 lo = uint8(bz[i]) & 0x0f;
//             s[i * 2]     = hi < 10 ? bytes1(hi + 48) : bytes1(hi + 87);
//             s[i * 2 + 1] = lo < 10 ? bytes1(lo + 48) : bytes1(lo + 87);
//         }
//         return string(s);
//     }
//       // Document

//   function newDocument(string memory dbname, string memory data) public returns(uint256) {
//     uint256 result = fullDB.newDocument(dbname, data);
//     // id = result;
//     return result;
//   }

//   function getDataDocument(string memory dbname,
//                            uint256 docId) public returns(string memory) {
//     string memory result = fullDB.getDataDocument(dbname, docId);
//     // returnString = result;
//     return result;
//   }

//   function setDataDocument(string memory dbname, uint256 docId,
//                            string memory data) public returns(bool) {
//     bool result = fullDB.setDataDocument(dbname, docId, data);
//     // status = result;
//     return result;
//   }

//   function indexTextForDocument(string memory dbname, uint256 docId,
//                                 string memory text, uint8 wdf_inc,
//                                 string memory prefix) public returns(bool) {
//     bool result =
//         fullDB.indexTextForDocument(dbname, docId, text, wdf_inc, prefix);
//     // status = result;
//     return result;
//   }

//   function addValueDocument(string memory dbname, uint256 docId, uint256 slot,
//                             string memory data, bool isSerialise)
//       external returns(bool) {
//     bool result =
//         fullDB.addValueDocument(dbname, docId, slot, data, isSerialise);
//     // status = result;
//     return result;
//   }

//   function deleteDocument(string memory dbname,
//                           uint256 docId) public returns(bool) {
//     bool result = fullDB.deleteDocument(dbname, docId);
//     // status = result;
//     return result;
//   }

//   function getValueDocument(string memory dbname, uint256 docId, uint256 slot,
//                             bool isSerialise) public returns(string memory) {
//     string memory returnString = fullDB.getValueDocument(dbname, docId, slot, isSerialise);
//     return returnString;
//   }

//   function getTermsDocument(string memory dbname,
//                             uint256 docId) public returns(string[] memory) {
//     string[] memory arrayString = fullDB.getTermsDocument(dbname, docId);
//     return arrayString;
//   }
//   function getOrCreateDb(string memory name) public returns(bool) {
//     bool result = fullDB.getOrCreateDb(name);
//     // if (result) dbName = name;
//     // status = result;
//     return result;
//   }


//   function commit(string memory name) public returns(bool) {
//     bool result = fullDB.commit(name);
//     // status = result;
//     return result;
//   }
//   event QuerySearchResults(uint256 totalResults, uint256 resultsCount);
//   event SearchResultLogged(uint256 docid, uint256 rank, uint256 percent, string data);

//   function querySearch(
//       string memory dbname,
//       SearchParams memory params) public returns(SearchResultsPage memory) {
//     SearchResultsPage memory currentPage = fullDB.querySearch(dbname, params);
//     // lastQueryResults.total = currentPage.total;
//     emit QuerySearchResults(currentPage.total, currentPage.results.length);
    
//     // delete searchResults; // Xóa toàn bộ mảng trước khi gán lại các phần tử mới
//     // for (uint256 i = 0; i < currentPage.results.length; i++) {
//     //   SearchResult memory result = currentPage.results[i];
//     //   uint256 percentValue =
//     //       (result.percent >= 0) ? uint256(result.percent) : 0;

//     //   searchResults.push(SearchResult({
//     //     docid : result.docid,
//     //     rank : result.rank,
//     //     percent : result.percent,
//     //     data : result.data
//     //   }));

//     //   emit SearchResultLogged(result.docid, result.rank, percentValue, result.data);
//     // }

//     return currentPage;
//   }


// }