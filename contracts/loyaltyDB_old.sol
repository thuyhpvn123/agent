// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;
// /**
//  * @notice Mục nhập cho prefix map trong SearchParams.
//  */
// struct PrefixEntry {
//   string key;
//   string value;
// }

// /**
//  * @notice Đại diện cho một bộ lọc theo khoảng giá trị (range).
//  * Tương ứng với struct RangeFilter trong C++.
//  */
// struct RangeFilter {
//   // Tương ứng Xapian::valueno slot
//   uint slot;
//   // Tương ứng std::string start_serialised
//   string startSerialised;
//   // Tương ứng std::string end_serialised
//   string endSerialised;
// }

// /**
//  * @title SearchParams
//  * @notice Cấu trúc dữ liệu đại diện cho các tham số tìm kiếm,
//  * tương ứng với phiên bản hàm XapianSearcher::search hỗ trợ nhiều range filter.
//  */

// struct SearchParams {
//   string queries;

//   PrefixEntry[] prefixMap;


//   string[] stopWords;

//   uint64 offset;

//   uint64 limit;

//   int64 sortByValueSlot;

//   bool sortAscending;  // true tăng dần, false giảm dần

//   RangeFilter[] rangeFilters;
// }
// struct SearchResult {
//   uint256 docid;
//   uint256 rank;
//   int256 percent;
//   string data;
// }

// struct SearchResultsPage {
//   uint256 total;  // Tổng số kết quả tìm thấy (không phải chỉ trong trang này)
//   SearchResult[] results;  // Mảng kết quả cho trang hiện tại
// }

// interface FullDB {
//   function getOrCreateDb(string memory name) external returns(bool);

//   function newDocument(string memory dbname, string memory data)
//       external returns(uint256);
//   function getDataDocument(string memory dbname, uint256 docId)
//       external returns(string memory);
//   function setDataDocument(string memory dbname, uint256 docId,
//                            string memory data) external returns(bool);
//   function deleteDocument(string memory dbname, uint256 docId)
//       external returns(bool);
//   function addTermDocument(string memory dbname, uint256 docId,
//                            string memory term) external returns(bool);
//   function indexTextForDocument(string memory dbname, uint256 docId,
//                                 string memory text, uint8 weight,
//                                 string memory prefix) external returns(bool);
//   function addValueDocument(string memory dbname, uint256 docId, uint256 slot,
//                             string memory data, bool isSerialise)
//       external returns(bool);
//   function getValueDocument(string memory dbname, uint256 docId, uint256 slot,
//                             bool isSerialise) external returns(string memory);
//   function getTermsDocument(string memory dbname, uint256 docId)
//       external returns(string[] memory);
//   function search(string memory dbname, string memory query)
//       external returns(string memory);
//   function querySearch(string memory dbname, SearchParams memory params)
//       external returns(SearchResultsPage memory);

//   function commit(string memory dbname)
//       external returns(bool);
// }
// // import "./publicFulldb.sol"; // để dùng FullDB interface + structs

// /**
//  * @title LoyaltySearchIndex
//  * @notice Search/query layer cho RestaurantLoyaltySystem
//  *         Mỗi khi loyalty contract write data → gọi contract này để sync index
//  *
//  * DB schema:
//  *   loyalty_members:
//  *     data    = JSON { memberId, wallet, firstName, lastName, phone, tier, balA, balB, totalSpent }
//  *     prefix T = firstName + lastName (fulltext)
//  *     prefix P = phoneNumber (term exact)
//  *     prefix M = memberId (term exact)
//  *     prefix R = tier name (term exact)
//  *     slot 0  = balanceA (sortable, serialised)
//  *     slot 1  = totalSpent (sortable, serialised)
//  *     slot 2  = balanceB (sortable, serialised)
//  *
//  *   loyalty_transactions:
//  *     data    = JSON { txId, member, txType, points, amount, invoiceId, timestamp, note }
//  *     prefix W = wallet address (term exact)
//  *     prefix X = txType: "Earn"|"Redeem"|"Issue"|"Expire"
//  *     slot 0  = timestamp (sortable)
//  *     slot 1  = amount (sortable)
//  */
// contract LoyaltySearchIndex {

//     FullDB public fullDB = FullDB(0x0000000000000000000000000000000000000106);

//     string constant DB_MEMBERS = "loyalty_members";
//     string constant DB_TXS     = "loyalty_transactions";

//     // prefix constants
//     string constant P_NAME    = "T";   // fulltext tên
//     string constant P_PHONE   = "P";   // exact phone
//     string constant P_MEMBER  = "M";   // exact memberId
//     string constant P_TIER    = "R";   // exact tier name
//     string constant P_WALLET  = "W";   // exact wallet (trong tx DB)
//     string constant P_TXTYPE  = "X";   // exact txType

//     // value slots
//     uint256 constant SLOT_BAL_A      = 0;
//     uint256 constant SLOT_TOTAL_SPENT = 1;
//     uint256 constant SLOT_BAL_B      = 2;
//     uint256 constant SLOT_TIMESTAMP  = 0; // trong tx DB
//     uint256 constant SLOT_AMOUNT     = 1; // trong tx DB

//     address public loyaltyContract;
//     address public owner;

//     // wallet => docId trong DB_MEMBERS (để update sau)
//     mapping(address => uint256) public memberDocId;
//     // txId => docId trong DB_TXS
//     mapping(uint256 => uint256) public txDocId;

//     modifier onlyLoyalty() {
//         require(msg.sender == loyaltyContract || msg.sender == owner, "Unauthorized");
//         _;
//     }

//     constructor(address _loyaltyContract) {
//         owner = msg.sender;
//         loyaltyContract = _loyaltyContract;
//         // Khởi tạo 2 DB
//         fullDB.getOrCreateDb(DB_MEMBERS);
//         fullDB.getOrCreateDb(DB_TXS);
//     }

//     // ================================================================
//     // SYNC — MEMBER
//     // Gọi sau registerMember, updateMember, sau mỗi lần balance thay đổi
//     // ================================================================

//     /**
//      * @notice Upsert member vào search index
//      * @dev Nếu đã có docId → update, chưa có → tạo mới
//      */
//     function syncMember(
//         address wallet,
//         string memory memberId,
//         string memory firstName,
//         string memory lastName,
//         string memory phoneNumber,
//         string memory tierName,
//         uint256 balA,
//         uint256 balB,
//         uint256 totalSpent
//     ) external onlyLoyalty {
//         // Build JSON data
//         string memory data = _buildMemberJson(
//             wallet, memberId, firstName, lastName,
//             phoneNumber, tierName, balA, balB, totalSpent
//         );

//         uint256 docId = memberDocId[wallet];

//         if (docId == 0) {
//             // Tạo mới
//             docId = fullDB.newDocument(DB_MEMBERS, data);
//             memberDocId[wallet] = docId;

//             // Index text: tên để fulltext search
//             fullDB.indexTextForDocument(DB_MEMBERS, docId,
//                 string(abi.encodePacked(firstName, " ", lastName)), 1, P_NAME);

//             // Index exact terms
//             fullDB.addTermDocument(DB_MEMBERS, docId,
//                 string(abi.encodePacked(P_PHONE, ":", phoneNumber)));
//             fullDB.addTermDocument(DB_MEMBERS, docId,
//                 string(abi.encodePacked(P_MEMBER, ":", memberId)));
//         } else {
//             // Update data (JSON)
//             fullDB.setDataDocument(DB_MEMBERS, docId, data);
//         }

//         // Luôn update tier term và value slots (vì có thể thay đổi)
//         if (bytes(tierName).length > 0) {
//             fullDB.addTermDocument(DB_MEMBERS, docId,
//                 string(abi.encodePacked(P_TIER, ":", tierName)));
//         }

//         // Update sortable values
//         fullDB.addValueDocument(DB_MEMBERS, docId, SLOT_BAL_A,
//             _uint2str(balA), false);
//         fullDB.addValueDocument(DB_MEMBERS, docId, SLOT_TOTAL_SPENT,
//             _uint2str(totalSpent), false);
//         fullDB.addValueDocument(DB_MEMBERS, docId, SLOT_BAL_B,
//             _uint2str(balB), false);
//     }

//     // ================================================================
//     // SYNC — TRANSACTION
//     // Gọi sau mỗi _createTransaction trong loyalty contract
//     // ================================================================

//     function syncTransaction(
//         uint256 txId,
//         address member,
//         string memory txType,   // "Earn", "Redeem", "Issue", "Expire"
//         int256  points,
//         uint256 amount,
//         bytes32 invoiceId,
//         string memory note,
//         uint256 timestamp
//     ) external onlyLoyalty {
//         string memory data = _buildTxJson(
//             txId, member, txType, points, amount, invoiceId, note, timestamp
//         );

//         uint256 docId = fullDB.newDocument(DB_TXS, data);
//         txDocId[txId] = docId;

//         // Index wallet để filter theo member
//         fullDB.addTermDocument(DB_TXS, docId,
//             string(abi.encodePacked(P_WALLET, ":",
//                 _addressToString(member))));

//         // Index txType để filter
//         fullDB.addTermDocument(DB_TXS, docId,
//             string(abi.encodePacked(P_TXTYPE, ":", txType)));

//         // Sortable values
//         fullDB.addValueDocument(DB_TXS, docId, SLOT_TIMESTAMP,
//             _uint2str(timestamp), false);
//         fullDB.addValueDocument(DB_TXS, docId, SLOT_AMOUNT,
//             _uint2str(amount), false);
//     }

//     // ================================================================
//     // QUERY — MEMBER SEARCH
//     // ================================================================

//     /**
//      * @notice Tìm member theo tên (fulltext)
//      * @dev Ví dụ: searchMemberByName("Alice", 0, 10)
//      */
//     function searchMemberByName(string memory name, uint64 offset, uint64 limit)
//         external returns (SearchResultsPage memory)
//     {
//         PrefixEntry[] memory prefixMap = new PrefixEntry[](2);
//         prefixMap[0] = PrefixEntry("name", P_NAME);
//         prefixMap[1] = PrefixEntry(P_NAME, P_NAME);

//         string[] memory stopWords = new string[](0);
//         RangeFilter[] memory ranges = new RangeFilter[](0);

//         SearchParams memory params = SearchParams({
//             queries: name,
//             prefixMap: prefixMap,
//             stopWords: stopWords,
//             offset: offset,
//             limit: limit,
//             sortByValueSlot: -1,
//             sortAscending: true,
//             rangeFilters: ranges
//         });

//         return fullDB.querySearch(DB_MEMBERS, params);
//     }

//     /**
//      * @notice Tìm member theo tier
//      * @dev Ví dụ: searchMemberByTier("Gold", 0, 20)
//      */
//     function searchMemberByTier(string memory tierName, uint64 offset, uint64 limit)
//         external returns (SearchResultsPage memory)
//     {
//         PrefixEntry[] memory prefixMap = new PrefixEntry[](2);
//         prefixMap[0] = PrefixEntry("tier", P_TIER);
//         prefixMap[1] = PrefixEntry(P_TIER, P_TIER);

//         string[] memory stopWords = new string[](0);
//         RangeFilter[] memory ranges = new RangeFilter[](0);

//         // Query: R:Gold
//         SearchParams memory params = SearchParams({
//             queries: string(abi.encodePacked(P_TIER, ":", tierName)),
//             prefixMap: prefixMap,
//             stopWords: stopWords,
//             offset: offset,
//             limit: limit,
//             sortByValueSlot: int64(int256(SLOT_TOTAL_SPENT)), // sort theo totalSpent
//             sortAscending: false, // giảm dần (VIP nhất lên đầu)
//             rangeFilters: ranges
//         });

//         return fullDB.querySearch(DB_MEMBERS, params);
//     }

//     /**
//      * @notice Tìm member có balanceA trong khoảng [minBal, maxBal]
//      * @dev Ví dụ: searchMemberByBalanceRange("1000", "5000", 0, 10)
//      */
//     function searchMemberByBalanceRange(
//         string memory minBal,
//         string memory maxBal,
//         uint64 offset,
//         uint64 limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory prefixMap = new PrefixEntry[](0);
//         string[] memory stopWords = new string[](0);

//         RangeFilter[] memory ranges = new RangeFilter[](1);
//         ranges[0] = RangeFilter({
//             slot: SLOT_BAL_A,
//             startSerialised: minBal,
//             endSerialised: maxBal
//         });

//         SearchParams memory params = SearchParams({
//             queries: "",
//             prefixMap: prefixMap,
//             stopWords: stopWords,
//             offset: offset,
//             limit: limit,
//             sortByValueSlot: int64(int256(SLOT_BAL_A)),
//             sortAscending: false,
//             rangeFilters: ranges
//         });

//         return fullDB.querySearch(DB_MEMBERS, params);
//     }

//     // ================================================================
//     // QUERY — TRANSACTION SEARCH
//     // ================================================================

//     /**
//      * @notice Lấy tất cả transaction của một member, sort theo thời gian
//      * @dev wallet phải là checksummed address string
//      */
//     function getTxsByMember(address member, uint64 offset, uint64 limit)
//         external returns (SearchResultsPage memory)
//     {
//         PrefixEntry[] memory prefixMap = new PrefixEntry[](2);
//         prefixMap[0] = PrefixEntry("wallet", P_WALLET);
//         prefixMap[1] = PrefixEntry(P_WALLET, P_WALLET);

//         string[] memory stopWords = new string[](0);
//         RangeFilter[] memory ranges = new RangeFilter[](0);

//         SearchParams memory params = SearchParams({
//             queries: string(abi.encodePacked(P_WALLET, ":", _addressToString(member))),
//             prefixMap: prefixMap,
//             stopWords: stopWords,
//             offset: offset,
//             limit: limit,
//             sortByValueSlot: int64(int256(SLOT_TIMESTAMP)),
//             sortAscending: false, // mới nhất trước
//             rangeFilters: ranges
//         });

//         return fullDB.querySearch(DB_TXS, params);
//     }

//     /**
//      * @notice Lấy transaction Earn của member trong khoảng amount nhất định
//      * @dev Ví dụ: getTxsByMemberAndType(wallet, "Earn", "10000", "50000", 0, 10)
//      */
//     function getTxsByMemberAndType(
//         address member,
//         string memory txType,
//         string memory minAmount,
//         string memory maxAmount,
//         uint64 offset,
//         uint64 limit
//     ) external returns (SearchResultsPage memory) {
//         PrefixEntry[] memory prefixMap = new PrefixEntry[](4);
//         prefixMap[0] = PrefixEntry("wallet", P_WALLET);
//         prefixMap[1] = PrefixEntry(P_WALLET, P_WALLET);
//         prefixMap[2] = PrefixEntry("type", P_TXTYPE);
//         prefixMap[3] = PrefixEntry(P_TXTYPE, P_TXTYPE);

//         string[] memory stopWords = new string[](0);

//         // Range filter theo amount
//         RangeFilter[] memory ranges = new RangeFilter[](1);
//         ranges[0] = RangeFilter({
//             slot: SLOT_AMOUNT,
//             startSerialised: minAmount,
//             endSerialised: maxAmount
//         });

//         // Query: W:0xabc... X:Earn
//         string memory query = string(abi.encodePacked(
//             P_WALLET, ":", _addressToString(member),
//             " ", P_TXTYPE, ":", txType
//         ));

//         SearchParams memory params = SearchParams({
//             queries: query,
//             prefixMap: prefixMap,
//             stopWords: stopWords,
//             offset: offset,
//             limit: limit,
//             sortByValueSlot: int64(int256(SLOT_TIMESTAMP)),
//             sortAscending: false,
//             rangeFilters: ranges
//         });

//         return fullDB.querySearch(DB_TXS, params);
//     }

//     // ================================================================
//     // INTERNAL — JSON builders
//     // ================================================================

//     function _buildMemberJson(
//         address wallet,
//         string memory memberId,
//         string memory firstName,
//         string memory lastName,
//         string memory phoneNumber,
//         string memory tierName,
//         uint256 balA,
//         uint256 balB,
//         uint256 totalSpent
//     ) internal pure returns (string memory) {
//         return string(abi.encodePacked(
//             '{"wallet":"', _addressToString(wallet),
//             '","memberId":"', memberId,
//             '","firstName":"', firstName,
//             '","lastName":"', lastName,
//             '","phone":"', phoneNumber,
//             '","tier":"', tierName,
//             '","balA":', _uint2str(balA),
//             ',"balB":', _uint2str(balB),
//             ',"totalSpent":', _uint2str(totalSpent),
//             '}'
//         ));
//     }

//     function _buildTxJson(
//         uint256 txId,
//         address member,
//         string memory txType,
//         int256 points,
//         uint256 amount,
//         bytes32 invoiceId,
//         string memory note,
//         uint256 timestamp
//     ) internal pure returns (string memory) {
//         return string(abi.encodePacked(
//             '{"txId":', _uint2str(txId),
//             ',"member":"', _addressToString(member),
//             '","txType":"', txType,
//             '","points":', _int2str(points),
//             ',"amount":', _uint2str(amount),
//             ',"invoiceId":"', _bytes32ToStr(invoiceId),
//             '","note":"', note,
//             '","timestamp":', _uint2str(timestamp),
//             '}'
//         ));
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
//             uint8 hi = uint8(uint160(a) >> (8*(19-i))) >> 4;
//             uint8 lo = uint8(uint160(a) >> (8*(19-i))) & 0x0f;
//             b[2+i*2]   = hi < 10 ? bytes1(hi+48) : bytes1(hi+87);
//             b[2+i*2+1] = lo < 10 ? bytes1(lo+48) : bytes1(lo+87);
//         }
//         return string(b);
//     }

//     function _bytes32ToStr(bytes32 b) internal pure returns (string memory) {
//         bytes memory s = new bytes(64);
//         for (uint i = 0; i < 32; i++) {
//             uint8 hi = uint8(b[i]) >> 4;
//             uint8 lo = uint8(b[i]) & 0x0f;
//             s[i*2]   = hi < 10 ? bytes1(hi+48) : bytes1(hi+87);
//             s[i*2+1] = lo < 10 ? bytes1(lo+48) : bytes1(lo+87);
//         }
//         return string(s);
//     }
// }