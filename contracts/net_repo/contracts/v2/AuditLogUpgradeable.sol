 // // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
// import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

// contract AuditLog is OwnableUpgradeable, UUPSUpgradeable {
//     struct LogEntry {
//         uint256 id;
//         uint256 timestamp;
//         uint256 branchId; // ← uint256
//         address actor;
//         string actorName;
//         string action;
//         bytes32 targetId;
//         string detail;
//         address sourceContract;
//     }

//     /* =======================
//            STORAGE
//     ======================= */
//     uint256 private _logCounter;

//     mapping(uint256 => LogEntry) private _logs;
//     mapping(uint256 => uint256[]) private _logsByBranch; // key = branchId
//     mapping(address => uint256[]) private _logsByActor;
//     mapping(bytes32 => uint256[]) private _logsByTarget;
//     mapping(address => bool) private _authorizedContracts;

//     /* =======================
//            EVENTS
//     ======================= */
//     event LogWritten(
//         uint256 indexed id,
//         uint256 indexed branchId,
//         address indexed actor,
//         string action,
//         uint256 timestamp
//     );
//     event ContractAuthorized(address indexed contractAddress, bool authorized);

//     /* =======================
//            MODIFIERS
//     ======================= */
//     modifier onlyAuthorized() {
//         require(
//             _authorizedContracts[msg.sender] || msg.sender == owner(),
//             "AuditLog: Not authorized"
//         );
//         _;
//     }

//     /* =======================
//            INIT
//     ======================= */
//     function initialize(address owner_) public initializer {
//         __Ownable_init();
//         __UUPSUpgradeable_init();
//         _transferOwnership(owner_);
//         _logCounter = 0;
//     }

//     function _authorizeUpgrade(
//         address newImplementation
//     ) internal override onlyOwner {}

//     /* =======================
//            AUTHORIZE
//     ======================= */
//     function setAuthorizedContract(
//         address contractAddress,
//         bool authorized
//     ) external onlyOwner {
//         _authorizedContracts[contractAddress] = authorized;
//         emit ContractAuthorized(contractAddress, authorized);
//     }

//     function isAuthorized(
//         address contractAddress
//     ) external view returns (bool) {
//         return _authorizedContracts[contractAddress];
//     }

//     /* =======================
//            WRITE LOG
//     ======================= */
//     function writeLog(
//         uint256 branchId, // ← uint256
//         address actor,
//         string calldata actorName,
//         string calldata action,
//         bytes32 targetId,
//         string calldata detail
//     ) external onlyAuthorized returns (uint256 logId) {
//         _logCounter++;
//         logId = _logCounter;

//         _logs[logId] = LogEntry({
//             id: logId,
//             timestamp: block.timestamp,
//             branchId: branchId,
//             actor: actor,
//             actorName: actorName,
//             action: action,
//             targetId: targetId,
//             detail: detail,
//             sourceContract: msg.sender
//         });

//         _logsByBranch[branchId].push(logId);
//         _logsByActor[actor].push(logId);
//         _logsByTarget[targetId].push(logId);

//         emit LogWritten(logId, branchId, actor, action, block.timestamp);
//     }

//     /* =======================
//            READ / QUERY
//     ======================= */
//     function getLog(uint256 logId) external view returns (LogEntry memory) {
//         require(_logs[logId].id != 0, "AuditLog: Not found");
//         return _logs[logId];
//     }

//     function getTotalLogs() external view returns (uint256) {
//         return _logCounter;
//     }

//     function getLogsPaged(
//         uint256 offset,
//         uint256 limit
//     ) external view returns (LogEntry[] memory list, uint256 total) {
//         total = _logCounter;
//         if (offset >= total) return (new LogEntry[](0), total);
//         uint256 end = offset + limit > total ? total : offset + limit;
//         list = new LogEntry[](end - offset);
//         for (uint256 i = offset; i < end; i++) {
//             list[i - offset] = _logs[total - i];
//         }
//     }

//     function getLogsByBranchPaged(
//         uint256 branchId, // ← uint256
//         uint256 offset,
//         uint256 limit
//     ) external view returns (LogEntry[] memory list, uint256 total) {
//         uint256[] storage ids = _logsByBranch[branchId];
//         total = ids.length;
//         if (offset >= total) return (new LogEntry[](0), total);
//         uint256 end = offset + limit > total ? total : offset + limit;
//         list = new LogEntry[](end - offset);
//         for (uint256 i = offset; i < end; i++) {
//             list[i - offset] = _logs[ids[total - 1 - i]];
//         }
//     }

//     function getLogsByActorPaged(
//         address actor,
//         uint256 offset,
//         uint256 limit
//     ) external view returns (LogEntry[] memory list, uint256 total) {
//         uint256[] storage ids = _logsByActor[actor];
//         total = ids.length;
//         if (offset >= total) return (new LogEntry[](0), total);
//         uint256 end = offset + limit > total ? total : offset + limit;
//         list = new LogEntry[](end - offset);
//         for (uint256 i = offset; i < end; i++) {
//             list[i - offset] = _logs[ids[total - 1 - i]];
//         }
//     }

//     function getLogsByTargetPaged(
//         bytes32 targetId,
//         uint256 offset,
//         uint256 limit
//     ) external view returns (LogEntry[] memory list, uint256 total) {
//         uint256[] storage ids = _logsByTarget[targetId];
//         total = ids.length;
//         if (offset >= total) return (new LogEntry[](0), total);
//         uint256 end = offset + limit > total ? total : offset + limit;
//         list = new LogEntry[](end - offset);
//         for (uint256 i = offset; i < end; i++) {
//             list[i - offset] = _logs[ids[total - 1 - i]];
//         }
//     }

//     uint256[50] private __gap;
// }
