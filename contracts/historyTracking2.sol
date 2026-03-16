// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "./interfaces/IRestaurant.sol";
// import "./interfaces/IHistoryTracking.sol";
// contract HistoryTracking is 
//     Initializable,
//     AccessControlUpgradeable,
//     UUPSUpgradeable
// {
//     bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
//     bytes32 public constant WRITER_ROLE = keccak256("WRITER_ROLE");

//     // ==================== STORAGE MAPPINGS ====================

//     // Mapping: entityType => entityId => EntityHistory
//     mapping(EntityType => mapping(string => EntityHistory)) public entityHistories;
    
//     // Lưu danh sách tất cả các entry theo thời gian
//     HistoryEntry[] public allHistoryEntries;
    
//     // Mapping để lọc history theo type
//     mapping(EntityType => uint256[]) public historyIndicesByType;
    
//     // Mapping để lọc history theo entityId
//     mapping(EntityType => mapping(string => uint256[])) public historyIndicesByEntity;

//     // ==================== DATA SNAPSHOT STORAGE ====================
    
//     // entityId => array of snapshots
//     mapping(string => DishSnapshot[]) public dishSnapshots;
//     mapping(string => CategorySnapshot[]) public categorySnapshots;
//     mapping(string => DiscountSnapshot[]) public discountSnapshots;
//     mapping(address => StaffSnapshot[]) public staffSnapshots;
//     mapping(uint => TableSnapshot[]) public tableSnapshots;
//     mapping(uint => BannerSnapshot[]) public bannerSnapshots;
//     mapping(uint => TCSnapshot[]) public tcSnapshots;
//     mapping(uint => WorkingShiftSnapshot[]) public workingShiftSnapshots;
//     mapping(uint => UniformSnapshot[]) public uniformSnapshots;
//     mapping(uint => AreaSnapshot[]) public areaSnapshots;
//     mapping(string => PositionSnapshot[]) public positionSnapshots;
//     mapping(bytes32 => DishOptionSnapshot[]) public dishOptionSnapshots;
//     mapping(address => ManagerSnapshot[]) public managerSnapshots; 
//     mapping(uint256 => PaymentInfoSnapshot[]) public paymentInfoSnapshots; // Use index 0 for single merchant

//     event HistoryRecorded(
//         EntityType indexed entityType,
//         string indexed entityId,
//         ActionType actionType,
//         uint256 timestamp,
//         address actor
//     );
    
//     event SnapshotSaved(
//         EntityType indexed entityType,
//         string indexed entityId,
//         uint256 timestamp
//     );

//     constructor() {
//         _disableInitializers();
//     }

//     function initialize(address _branchManagementSC,address _managementSC, address _agent) public initializer {
//         __AccessControl_init();
//         __UUPSUpgradeable_init();
        
//         _grantRole(DEFAULT_ADMIN_ROLE, _agent);
//         _grantRole(ADMIN_ROLE, _agent);
//         _grantRole(WRITER_ROLE, _branchManagementSC);
//         _grantRole(WRITER_ROLE, _managementSC);
//     }

//     function _authorizeUpgrade(address newImplementation) internal override  {}
//   // ==================== MANAGER HISTORY FUNCTIONS ====================
    
//     /**
//      * @dev Record MANAGER history with snapshot
//      */
//     function recordManagerCreate(
//         address wallet,
//         ManagerInfo memory manager,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.MANAGER, _addressToString(wallet), reason, nameActor);
//         _saveManagerSnapshot(wallet, manager);
//     }
    
//     function recordManagerUpdate(
//         address wallet,
//         ManagerInfo memory manager,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.MANAGER, _addressToString(wallet), reason, nameActor);
//         _saveManagerSnapshot(wallet, manager);
//     }
    
//     function recordManagerDelete(
//         address wallet,
//         ManagerInfo memory manager,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.MANAGER, _addressToString(wallet), reason, nameActor);
//         _saveManagerSnapshot(wallet, manager);
//     }
    
//     function _saveManagerSnapshot(address wallet, ManagerInfo memory manager) internal {
//         managerSnapshots[wallet].push(ManagerSnapshot({
//             manager: manager,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.MANAGER, _addressToString(wallet), block.timestamp);
//     }
//       // ==================== PAYMENT INFO HISTORY FUNCTIONS ====================
    
//     /**
//      * @dev Record PAYMENT_INFO history with snapshot
//      * @notice We use merchantId = 0 as key for single merchant
//      */
//     function recordPaymentInfoUpdate(
//         PaymentInfo memory oldPaymentInfo,
//         PaymentInfo memory newPaymentInfo,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         string memory entityId = "0"; // Use "0" for merchant payment info
        
//         // Check if this is first time
//         bool isFirstTime = bytes(oldPaymentInfo.bankAccount).length == 0;
        
//         if (isFirstTime) {
//             _recordCreate(EntityType.PAYMENT_INFO, entityId, reason, nameActor);
//         } else {
//             _recordUpdate(EntityType.PAYMENT_INFO, entityId, reason, nameActor);
//         }
        
//         _savePaymentInfoSnapshot(0, newPaymentInfo);
//     }
    
//     function _savePaymentInfoSnapshot(uint256 merchantId, PaymentInfo memory paymentInfo) internal {
//         paymentInfoSnapshots[merchantId].push(PaymentInfoSnapshot({
//             paymentInfo: paymentInfo,
//             timestamp: block.timestamp
//         }));
//        emit SnapshotSaved(EntityType.PAYMENT_INFO, _uintToString(merchantId), block.timestamp);
//     }

//     // ==================== RECORD FUNCTIONS WITH SNAPSHOTS ====================
    
//     /**
//      * @dev Record DISH history with snapshot
//      */
//     function recordDishCreate(
//         string memory dishCode,
//         Dish memory dish,
//         Variant[] memory variants,
//         Attribute[][] memory attributes,
//         string memory reason
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.DISH, dishCode, reason);
//         _saveDishSnapshot(dishCode, dish, variants, attributes);
//     }
    
//     function recordDishUpdate(
//         string memory dishCode,
//         Dish memory dish,
//         Variant[] memory variants,
//         Attribute[][] memory attributes,
//         string memory reason
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.DISH, dishCode, reason);
//         _saveDishSnapshot(dishCode, dish, variants, attributes);
//     }
    
//     function recordDishDelete(
//         string memory dishCode,
//         Dish memory dish,
//         Variant[] memory variants,
//         Attribute[][] memory attributes,
//         string memory reason
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.DISH, dishCode, reason);
//         _saveDishSnapshot(dishCode, dish, variants, attributes);
//     }
    
//     function _saveDishSnapshot(
//         string memory dishCode,
//         Dish memory dish,
//         Variant[] memory variants,
//         Attribute[][] memory attributes
//     ) internal {
//         DishSnapshot storage snapshot = dishSnapshots[dishCode].push();
//         snapshot.dish = dish;
//         snapshot.timestamp = block.timestamp;
        
//         for (uint i = 0; i < variants.length; i++) {
//             snapshot.variants.push(variants[i]);
//         }
        
//         for (uint i = 0; i < attributes.length; i++) {
//             for (uint j = 0; j < attributes[i].length; j++) {
//                 snapshot.attributes.push();
//                 snapshot.attributes[i].push(attributes[i][j]);
//             }
//         }
        
//         emit SnapshotSaved(EntityType.DISH, dishCode, block.timestamp);
//     }
    
//     /**
//      * @dev Record CATEGORY history with snapshot
//      */
//     function recordCategoryCreate(
//         string memory code,
//         Category memory category,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.CATEGORY, code, reason, nameActor);
//         _saveCategorySnapshot(code, category);
//     }
    
//     function recordCategoryUpdate(
//         string memory code,
//         Category memory category,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.CATEGORY, code, reason, nameActor);
//         _saveCategorySnapshot(code, category);
//     }
    
//     function recordCategoryDelete(
//         string memory code,
//         Category memory category,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.CATEGORY, code, reason, nameActor);
//         _saveCategorySnapshot(code, category);
//     }
    
//     function _saveCategorySnapshot(string memory code, Category memory category) internal {
//         categorySnapshots[code].push(CategorySnapshot({
//             category: category,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.CATEGORY, code, block.timestamp);
//     }
    
//     /**
//      * @dev Record DISCOUNT history with snapshot
//      */
//     function recordDiscountCreate(
//         string memory code,
//         Discount memory discount,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.DISCOUNT, code, reason, nameActor);
//         _saveDiscountSnapshot(code, discount);
//     }
    
//     function recordDiscountUpdate(
//         string memory code,
//         Discount memory discount,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.DISCOUNT, code, reason, nameActor);
//         _saveDiscountSnapshot(code, discount);
//     }
    
//     function recordDiscountDelete(
//         string memory code,
//         Discount memory discount,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.DISCOUNT, code, reason, nameActor);
//         _saveDiscountSnapshot(code, discount);
//     }
    
//     function _saveDiscountSnapshot(string memory code, Discount memory discount) internal {
//         discountSnapshots[code].push(DiscountSnapshot({
//             discount: discount,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.DISCOUNT, code, block.timestamp);
//     }
    
//     /**
//      * @dev Record STAFF history with snapshot
//      */
//     function recordStaffCreate(
//         address wallet,
//         Staff memory staff,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.STAFF, _addressToString(wallet), reason, nameActor);
//         _saveStaffSnapshot(wallet, staff);
//     }
    
//     function recordStaffUpdate(
//         address wallet,
//         Staff memory staff,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.STAFF, _addressToString(wallet), reason, nameActor);
//         _saveStaffSnapshot(wallet, staff);
//     }
    
//     function recordStaffDelete(
//         address wallet,
//         Staff memory staff,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.STAFF, _addressToString(wallet), reason, nameActor);
//         _saveStaffSnapshot(wallet, staff);
//     }
    
//     function _saveStaffSnapshot(address wallet, Staff memory staff) internal {
//         staffSnapshots[wallet].push(StaffSnapshot({
//             staff: staff,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.STAFF, _addressToString(wallet), block.timestamp);
//     }
    
//     /**
//      * @dev Record TABLE history with snapshot
//      */
//     function recordTableCreate(
//         uint tableNumber,
//         Table memory table,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.TABLE, _uintToString(tableNumber), reason, nameActor);
//         _saveTableSnapshot(tableNumber, table);
//     }
    
//     function recordTableUpdate(
//         uint tableNumber,
//         Table memory table,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.TABLE, _uintToString(tableNumber), reason, nameActor);
//         _saveTableSnapshot(tableNumber, table);
//     }
    
//     function recordTableDelete(
//         uint tableNumber,
//         Table memory table,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.TABLE, _uintToString(tableNumber), reason, nameActor);
//         _saveTableSnapshot(tableNumber, table);
//     }
    
//     function _saveTableSnapshot(uint tableNumber, Table memory table) internal {
//         tableSnapshots[tableNumber].push(TableSnapshot({
//             table: table,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.TABLE, _uintToString(tableNumber), block.timestamp);
//     }
    
//     /**
//      * @dev Record BANNER history with snapshot
//      */
//     function recordBannerCreate(
//         uint bannerId,
//         Banner memory banner,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.BANNER, _uintToString(bannerId), reason, nameActor);
//         _saveBannerSnapshot(bannerId, banner);
//     }
    
//     function recordBannerUpdate(
//         uint bannerId,
//         Banner memory banner,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.BANNER, _uintToString(bannerId), reason, nameActor);
//         _saveBannerSnapshot(bannerId, banner);
//     }
    
//     function recordBannerDelete(
//         uint bannerId,
//         Banner memory banner,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.BANNER, _uintToString(bannerId), reason, nameActor);
//         _saveBannerSnapshot(bannerId, banner);
//     }
    
//     function _saveBannerSnapshot(uint bannerId, Banner memory banner) internal {
//         bannerSnapshots[bannerId].push(BannerSnapshot({
//             banner: banner,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.BANNER, _uintToString(bannerId), block.timestamp);
//     }
    
//     /**
//      * @dev Record TC history with snapshot
//      */
//     function recordTCCreate(
//         uint tcId,
//         TCInfo memory tc,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.TC, _uintToString(tcId), reason, nameActor);
//         _saveTCSnapshot(tcId, tc);
//     }
    
//     function recordTCUpdate(
//         uint tcId,
//         TCInfo memory tc,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.TC, _uintToString(tcId), reason, nameActor);
//         _saveTCSnapshot(tcId, tc);
//     }
    
//     function recordTCDelete(
//         uint tcId,
//         TCInfo memory tc,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.TC, _uintToString(tcId), reason, nameActor);
//         _saveTCSnapshot(tcId, tc);
//     }
    
//     function _saveTCSnapshot(uint tcId, TCInfo memory tc) internal {
//         tcSnapshots[tcId].push(TCSnapshot({
//             tc: tc,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.TC, _uintToString(tcId), block.timestamp);
//     }
    
//     /**
//      * @dev Record WORKING_SHIFT history with snapshot
//      */
//     function recordWorkingShiftCreate(
//         uint shiftId,
//         WorkingShift memory shift,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.WORKING_SHIFT, _uintToString(shiftId), reason, nameActor);
//         _saveWorkingShiftSnapshot(shiftId, shift);
//     }
    
//     function recordWorkingShiftUpdate(
//         uint shiftId,
//         WorkingShift memory shift,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.WORKING_SHIFT, _uintToString(shiftId), reason, nameActor);
//         _saveWorkingShiftSnapshot(shiftId, shift);
//     }
    
//     function recordWorkingShiftDelete(
//         uint shiftId,
//         WorkingShift memory shift,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.WORKING_SHIFT, _uintToString(shiftId), reason, nameActor);
//         _saveWorkingShiftSnapshot(shiftId, shift);
//     }
    
//     function _saveWorkingShiftSnapshot(uint shiftId, WorkingShift memory shift) internal {
//         workingShiftSnapshots[shiftId].push(WorkingShiftSnapshot({
//             shift: shift,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.WORKING_SHIFT, _uintToString(shiftId), block.timestamp);
//     }
    
//     /**
//      * @dev Record UNIFORM history with snapshot
//      */
//     function recordUniformCreate(
//         uint uniformId,
//         Uniform memory uniform,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.UNIFORM, _uintToString(uniformId), reason, nameActor);
//         _saveUniformSnapshot(uniformId, uniform);
//     }
    
//     function recordUniformUpdate(
//         uint uniformId,
//         Uniform memory uniform,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.UNIFORM, _uintToString(uniformId), reason, nameActor);
//         _saveUniformSnapshot(uniformId, uniform);
//     }
    
//     function recordUniformDelete(
//         uint uniformId,
//         Uniform memory uniform,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.UNIFORM, _uintToString(uniformId), reason, nameActor);
//         _saveUniformSnapshot(uniformId, uniform);
//     }
    
//     function _saveUniformSnapshot(uint uniformId, Uniform memory uniform) internal {
//         uniformSnapshots[uniformId].push(UniformSnapshot({
//             uniform: uniform,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.UNIFORM, _uintToString(uniformId), block.timestamp);
//     }
    
//     /**
//      * @dev Record AREA history with snapshot
//      */
//     function recordAreaCreate(
//         uint areaId,
//         Area memory area,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.AREA, _uintToString(areaId), reason, nameActor);
//         _saveAreaSnapshot(areaId, area);
//     }
    
//     function recordAreaUpdate(
//         uint areaId,
//         Area memory area,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.AREA, _uintToString(areaId), reason, nameActor);
//         _saveAreaSnapshot(areaId, area);
//     }
    
//     function recordAreaDelete(
//         uint areaId,
//         Area memory area,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.AREA, _uintToString(areaId), reason, nameActor);
//         _saveAreaSnapshot(areaId, area);
//     }
    
//     function _saveAreaSnapshot(uint areaId, Area memory area) internal {
//         areaSnapshots[areaId].push(AreaSnapshot({
//             area: area,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.AREA, _uintToString(areaId), block.timestamp);
//     }
    
//     /**
//      * @dev Record POSITION history with snapshot
//      */
//     function recordPositionCreate(
//         string memory name,
//         Position memory position,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.POSITION, name, reason, nameActor);
//         _savePositionSnapshot(name, position);
//     }
    
//     function recordPositionUpdate(
//         string memory name,
//         Position memory position,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.POSITION, name, reason, nameActor);
//         _savePositionSnapshot(name, position);
//     }
    
//     function recordPositionDelete(
//         string memory name,
//         Position memory position,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.POSITION, name, reason, nameActor);
//         _savePositionSnapshot(name, position);
//     }
    
//     function _savePositionSnapshot(string memory name, Position memory position) internal {
//         positionSnapshots[name].push(PositionSnapshot({
//             position: position,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.POSITION, name, block.timestamp);
//     }
    
//     /**
//      * @dev Record DISH_OPTION history with snapshot
//      */
//     function recordDishOptionCreate(
//         bytes32 optionId,
//         DishOption memory option,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordCreate(EntityType.DISH_OPTION, _bytes32ToString(optionId), reason, nameActor);
//         _saveDishOptionSnapshot(optionId, option);
//     }
    
//     function recordDishOptionUpdate(
//         bytes32 optionId,
//         DishOption memory option,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordUpdate(EntityType.DISH_OPTION, _bytes32ToString(optionId), reason, nameActor);
//         _saveDishOptionSnapshot(optionId, option);
//     }
    
//     function recordDishOptionDelete(
//         bytes32 optionId,
//         DishOption memory option,
//         string memory reason,
//         string memory nameActor
//     ) external onlyRole(WRITER_ROLE) {
//         _recordDelete(EntityType.DISH_OPTION, _bytes32ToString(optionId), reason, nameActor);
//         _saveDishOptionSnapshot(optionId, option);
//     }
    
//     function _saveDishOptionSnapshot(bytes32 optionId, DishOption memory option) internal {
//         dishOptionSnapshots[optionId].push(DishOptionSnapshot({
//             option: option,
//             timestamp: block.timestamp
//         }));
//         emit SnapshotSaved(EntityType.DISH_OPTION, _bytes32ToString(optionId), block.timestamp);
//     }

//     // ==================== INTERNAL RECORD FUNCTIONS ====================
    
//     /**
//      * @dev Ghi lại lịch sử khi tạo entity
//      */
//     function _recordCreate(
//         EntityType entityType,
//         string memory entityId,
//         string memory reason,
//         string memory nameActor
//     ) internal {
//         require(bytes(entityId).length > 0, "Entity ID is empty");
        
//         EntityHistory storage history = entityHistories[entityType][entityId];
//         require(!history.exists, "Entity already exists");
        
//         uint256 currentTime = block.timestamp;
        
//         history.lastUpdateTime = currentTime;
//         history.previousUpdateTime = 0;
//         history.exists = true;
        
//         _addHistoryEntry(entityType, entityId, ActionType.CREATE, currentTime, reason, nameActor);
//     }

//     /**
//      * @dev Ghi lại lịch sử khi update entity
//      */
//     function _recordUpdate(
//         EntityType entityType,
//         string memory entityId,
//         string memory reason,
//         string memory nameActor
//     ) internal {
//         require(bytes(entityId).length > 0, "Entity ID is empty");
        
//         EntityHistory storage history = entityHistories[entityType][entityId];
//         require(history.exists, "Entity does not exist");
        
//         uint256 currentTime = block.timestamp;
        
//         // Lưu thời gian update trước đó
//         history.previousUpdateTime = history.lastUpdateTime;
//         history.lastUpdateTime = currentTime;
        
//         _addHistoryEntry(entityType, entityId, ActionType.UPDATE, currentTime, reason, nameActor);
//     }

//     /**
//      * @dev Ghi lại lịch sử khi xóa entity
//      */
//     function _recordDelete(
//         EntityType entityType,
//         string memory entityId,
//         string memory reason,
//         string memory nameActor
//     ) internal {
//         require(bytes(entityId).length > 0, "Entity ID is empty");
        
//         EntityHistory storage history = entityHistories[entityType][entityId];
//         require(history.exists, "Entity does not exist");
        
//         uint256 currentTime = block.timestamp;
        
//         history.previousUpdateTime = history.lastUpdateTime;
//         history.lastUpdateTime = currentTime;
        
//         _addHistoryEntry(entityType, entityId, ActionType.DELETE, currentTime, reason, nameActor);
//     }

//     /**
//      * @dev Helper function để thêm history entry
//      */
//     function _addHistoryEntry(
//         EntityType entityType,
//         string memory entityId,
//         ActionType actionType,
//         uint256 timestamp,
//         string memory reason,
//         string memory nameActor,
//         string memory positionActor,
//         uint256 branchId
//     ) internal {
//         uint256 index = allHistoryEntries.length;
        
//         allHistoryEntries.push(HistoryEntry({
//             entityType: entityType,
//             entityId: entityId,
//             actionType: actionType,
//             timestamp: timestamp,
//             actor: nameActor,
//             positionActor: positionActor,
//             branchId: branchId,
//             reason: reason
//         }));
        
//         historyIndicesByType[entityType].push(index);
//         historyIndicesByEntity[entityType][entityId].push(index);
        
//         emit HistoryRecorded(entityType, entityId, actionType, timestamp, nameActor);
//     }
    
//     // ==================== HELPER CONVERSION FUNCTIONS ====================
    
//     function _addressToString(address _addr) internal pure returns (string memory) {
//         bytes32 value = bytes32(uint256(uint160(_addr)));
//         bytes memory alphabet = "0123456789abcdef";
//         bytes memory str = new bytes(42);
//         str[0] = '0';
//         str[1] = 'x';
//         for (uint256 i = 0; i < 20; i++) {
//             str[2+i*2] = alphabet[uint8(value[i + 12] >> 4)];
//             str[3+i*2] = alphabet[uint8(value[i + 12] & 0x0f)];
//         }
//         return string(str);
//     }
    
//     function _uintToString(uint _i) internal pure returns (string memory) {
//         if (_i == 0) {
//             return "0";
//         }
//         uint j = _i;
//         uint len;
//         while (j != 0) {
//             len++;
//             j /= 10;
//         }
//         bytes memory bstr = new bytes(len);
//         uint k = len;
//         while (_i != 0) {
//             k = k-1;
//             uint8 temp = (48 + uint8(_i - _i / 10 * 10));
//             bytes1 b1 = bytes1(temp);
//             bstr[k] = b1;
//             _i /= 10;
//         }
//         return string(bstr);
//     }
    
//     function _bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
//         uint8 i = 0;
//         while(i < 32 && _bytes32[i] != 0) {
//             i++;
//         }
//         bytes memory bytesArray = new bytes(i);
//         for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
//             bytesArray[i] = _bytes32[i];
//         }
//         return string(bytesArray);
//     }

//     // ==================== GET SNAPSHOT FUNCTIONS ====================
    
//     /**
//      * @dev Get latest 2 snapshots (old and new) for comparison
//      */
//     function getDishSnapshots(string memory dishCode) external view returns (
//         DishSnapshot memory oldSnapshot,
//         DishSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         DishSnapshot[] storage snapshots = dishSnapshots[dishCode];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getCategorySnapshots(string memory code) external view returns (
//         CategorySnapshot memory oldSnapshot,
//         CategorySnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         CategorySnapshot[] storage snapshots = categorySnapshots[code];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getDiscountSnapshots(string memory code) external view returns (
//         DiscountSnapshot memory oldSnapshot,
//         DiscountSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         DiscountSnapshot[] storage snapshots = discountSnapshots[code];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getStaffSnapshots(address wallet) external view returns (
//         StaffSnapshot memory oldSnapshot,
//         StaffSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         StaffSnapshot[] storage snapshots = staffSnapshots[wallet];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getTableSnapshots(uint tableNumber) external view returns (
//         TableSnapshot memory oldSnapshot,
//         TableSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         TableSnapshot[] storage snapshots = tableSnapshots[tableNumber];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getBannerSnapshots(uint bannerId) external view returns (
//         BannerSnapshot memory oldSnapshot,
//         BannerSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         BannerSnapshot[] storage snapshots = bannerSnapshots[bannerId];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getTCSnapshots(uint tcId) external view returns (
//         TCSnapshot memory oldSnapshot,
//         TCSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         TCSnapshot[] storage snapshots = tcSnapshots[tcId];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getWorkingShiftSnapshots(uint shiftId) external view returns (
//         WorkingShiftSnapshot memory oldSnapshot,
//         WorkingShiftSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         WorkingShiftSnapshot[] storage snapshots = workingShiftSnapshots[shiftId];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getUniformSnapshots(uint uniformId) external view returns (
//         UniformSnapshot memory oldSnapshot,
//         UniformSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         UniformSnapshot[] storage snapshots = uniformSnapshots[uniformId];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getAreaSnapshots(uint areaId) external view returns (
//         AreaSnapshot memory oldSnapshot,
//         AreaSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         AreaSnapshot[] storage snapshots = areaSnapshots[areaId];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getPositionSnapshots(string memory name) external view returns (
//         PositionSnapshot memory oldSnapshot,
//         PositionSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         PositionSnapshot[] storage snapshots = positionSnapshots[name];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getDishOptionSnapshots(bytes32 optionId) external view returns (
//         DishOptionSnapshot memory oldSnapshot,
//         DishOptionSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         DishOptionSnapshot[] storage snapshots = dishOptionSnapshots[optionId];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     /**
//      * @dev Get all snapshots history with pagination
//      */
//     function getAllDishSnapshots(string memory dishCode, uint offset, uint limit) 
//         external view returns (DishSnapshot[] memory, uint totalCount) 
//     {
//         DishSnapshot[] storage snapshots = dishSnapshots[dishCode];
//         totalCount = snapshots.length;
        
//         if (offset >= totalCount) {
//             return (new DishSnapshot[](0), totalCount);
//         }
        
//         uint end = offset + limit;
//         if (end > totalCount) end = totalCount;
//         uint size = end - offset;
        
//         DishSnapshot[] memory result = new DishSnapshot[](size);
//         for (uint i = 0; i < size; i++) {
//             uint reverseIndex = totalCount - 1 - offset - i;
//             result[i] = snapshots[reverseIndex];
//         }
        
//         return (result, totalCount);
//     }
    
//     function getAllCategorySnapshots(string memory code, uint offset, uint limit) 
//         external view returns (CategorySnapshot[] memory, uint totalCount) 
//     {
//         CategorySnapshot[] storage snapshots = categorySnapshots[code];
//         totalCount = snapshots.length;
        
//         if (offset >= totalCount) {
//             return (new CategorySnapshot[](0), totalCount);
//         }
        
//         uint end = offset + limit;
//         if (end > totalCount) end = totalCount;
//         uint size = end - offset;
        
//         CategorySnapshot[] memory result = new CategorySnapshot[](size);
//         for (uint i = 0; i < size; i++) {
//             uint reverseIndex = totalCount - 1 - offset - i;
//             result[i] = snapshots[reverseIndex];
//         }
        
//         return (result, totalCount);
//     }
    
//     function getAllDiscountSnapshots(string memory code, uint offset, uint limit) 
//         external view returns (DiscountSnapshot[] memory, uint totalCount) 
//     {
//         DiscountSnapshot[] storage snapshots = discountSnapshots[code];
//         totalCount = snapshots.length;
        
//         if (offset >= totalCount) {
//             return (new DiscountSnapshot[](0), totalCount);
//         }
        
//         uint end = offset + limit;
//         if (end > totalCount) end = totalCount;
//         uint size = end - offset;
        
//         DiscountSnapshot[] memory result = new DiscountSnapshot[](size);
//         for (uint i = 0; i < size; i++) {
//             uint reverseIndex = totalCount - 1 - offset - i;
//             result[i] = snapshots[reverseIndex];
//         }
        
//         return (result, totalCount);
//     }
    
//     function getAllStaffSnapshots(address wallet, uint offset, uint limit) 
//         external view returns (StaffSnapshot[] memory, uint totalCount) 
//     {
//         StaffSnapshot[] storage snapshots = staffSnapshots[wallet];
//         totalCount = snapshots.length;
        
//         if (offset >= totalCount) {
//             return (new StaffSnapshot[](0), totalCount);
//         }
        
//         uint end = offset + limit;
//         if (end > totalCount) end = totalCount;
//         uint size = end - offset;
        
//         StaffSnapshot[] memory result = new StaffSnapshot[](size);
//         for (uint i = 0; i < size; i++) {
//             uint reverseIndex = totalCount - 1 - offset - i;
//             result[i] = snapshots[reverseIndex];
//         }
        
//         return (result, totalCount);
//     }

//     // ==================== GET FUNCTIONS ====================

//     /**
//      * @dev Lấy timestamps để query dữ liệu cũ và mới
//      * @return lastUpdateTime Thời gian update gần nhất (để lấy data mới)
//      * @return previousUpdateTime Thời gian update trước đó (để lấy data cũ)
//      * @return exists Entity có tồn tại không
//      */
//     function getUpdateTimestamps(
//         EntityType entityType,
//         string memory entityId
//     ) external view returns (
//         uint256 lastUpdateTime,
//         uint256 previousUpdateTime,
//         bool exists
//     ) {
//         EntityHistory memory history = entityHistories[entityType][entityId];
//         return (history.lastUpdateTime, history.previousUpdateTime, history.exists);
//     }

//     /**
//      * @dev Lấy lịch sử tất cả entities theo type với pagination
//      */
//     function getHistoryByType(
//         EntityType entityType,
//         uint256 offset,
//         uint256 limit
//     ) external view returns (
//         HistoryEntry[] memory entries,
//         uint256 totalCount
//     ) {
//         uint256[] storage indices = historyIndicesByType[entityType];
//         totalCount = indices.length;
        
//         if (offset >= totalCount) {
//             return (new HistoryEntry[](0), totalCount);
//         }
        
//         uint256 end = offset + limit;
//         if (end > totalCount) {
//             end = totalCount;
//         }
        
//         uint256 size = end - offset;
//         entries = new HistoryEntry[](size);
        
//         // Lấy từ mới nhất đến cũ nhất
//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = totalCount - 1 - offset - i;
//             entries[i] = allHistoryEntries[indices[reverseIndex]];
//         }
        
//         return (entries, totalCount);
//     }

//     /**
//      * @dev Lấy lịch sử của một entity cụ thể
//      */
//     function getHistoryByEntity(
//         EntityType entityType,
//         string memory entityId,
//         uint256 offset,
//         uint256 limit
//     ) external view returns (
//         HistoryEntry[] memory entries,
//         uint256 totalCount
//     ) {
//         uint256[] storage indices = historyIndicesByEntity[entityType][entityId];
//         totalCount = indices.length;
        
//         if (offset >= totalCount) {
//             return (new HistoryEntry[](0), totalCount);
//         }
        
//         uint256 end = offset + limit;
//         if (end > totalCount) {
//             end = totalCount;
//         }
        
//         uint256 size = end - offset;
//         entries = new HistoryEntry[](size);
        
//         // Lấy từ mới nhất đến cũ nhất
//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = totalCount - 1 - offset - i;
//             entries[i] = allHistoryEntries[indices[reverseIndex]];
//         }
        
//         return (entries, totalCount);
//     }

//     /**
//      * @dev Lấy tất cả lịch sử với pagination
//      */
//     function getAllHistory(
//         uint256 offset,
//         uint256 limit
//     ) external view returns (
//         HistoryEntry[] memory entries,
//         uint256 totalCount
//     ) {
//         totalCount = allHistoryEntries.length;
        
//         if (offset >= totalCount) {
//             return (new HistoryEntry[](0), totalCount);
//         }
        
//         uint256 end = offset + limit;
//         if (end > totalCount) {
//             end = totalCount;
//         }
        
//         uint256 size = end - offset;
//         entries = new HistoryEntry[](size);
        
//         // Lấy từ mới nhất đến cũ nhất
//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = totalCount - 1 - offset - i;
//             entries[i] = allHistoryEntries[reverseIndex];
//         }
        
//         return (entries, totalCount);
//     }

//     /**
//      * @dev Lấy lịch sử theo khoảng thời gian
//      */
//     function getHistoryByTimeRange(
//         EntityType entityType,
//         uint256 fromTime,
//         uint256 toTime,
//         uint256 offset,
//         uint256 limit
//     ) external view returns (
//         HistoryEntry[] memory entries,
//         uint256 totalCount
//     ) {
//         require(fromTime <= toTime, "Invalid time range");
        
//         uint256[] storage allIndices = historyIndicesByType[entityType];
        
//         // Đếm số entries trong khoảng thời gian
//         uint256 count = 0;
//         for (uint256 i = 0; i < allIndices.length; i++) {
//             HistoryEntry memory entry = allHistoryEntries[allIndices[i]];
//             if (entry.timestamp >= fromTime && entry.timestamp <= toTime) {
//                 count++;
//             }
//         }
        
//         totalCount = count;
        
//         if (count == 0 || offset >= count) {
//             return (new HistoryEntry[](0), totalCount);
//         }
        
//         // Tạo array tạm chứa các entries trong khoảng thời gian
//         HistoryEntry[] memory tempEntries = new HistoryEntry[](count);
//         uint256 tempIndex = 0;
        
//         for (uint256 i = 0; i < allIndices.length; i++) {
//             HistoryEntry memory entry = allHistoryEntries[allIndices[i]];
//             if (entry.timestamp >= fromTime && entry.timestamp <= toTime) {
//                 tempEntries[tempIndex] = entry;
//                 tempIndex++;
//             }
//         }
        
//         // Apply pagination
//         uint256 end = offset + limit;
//         if (end > count) {
//             end = count;
//         }
        
//         uint256 size = end - offset;
//         entries = new HistoryEntry[](size);
        
//         // Lấy từ mới nhất (đảo ngược array)
//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = count - 1 - offset - i;
//             entries[i] = tempEntries[reverseIndex];
//         }
        
//         return (entries, totalCount);
//     }

//     /**
//      * @dev Lấy history entries gần nhất của một entity
//      */
//     function getRecentHistoryByEntity(
//         EntityType entityType,
//         string memory entityId,
//         uint256 limit
//     ) external view returns (HistoryEntry[] memory entries) {
//         uint256[] storage indices = historyIndicesByEntity[entityType][entityId];
//         uint256 totalCount = indices.length;
        
//         if (totalCount == 0) {
//             return new HistoryEntry[](0);
//         }
        
//         uint256 size = limit > totalCount ? totalCount : limit;
//         entries = new HistoryEntry[](size);
        
//         for (uint256 i = 0; i < size; i++) {
//             entries[i] = allHistoryEntries[indices[totalCount - 1 - i]];
//         }
        
//         return entries;
//     }

//     /**
//      * @dev Kiểm tra entity có tồn tại không
//      */
//     function entityExists(
//         EntityType entityType,
//         string memory entityId
//     ) external view returns (bool) {
//         return entityHistories[entityType][entityId].exists;
//     }

//     /**
//      * @dev Lấy thống kê lịch sử theo type
//      */
//     function getHistoryStats(
//         EntityType entityType
//     ) external view returns (
//         uint256 totalEntries,
//         uint256 createCount,
//         uint256 updateCount,
//         uint256 deleteCount
//     ) {
//         uint256[] storage indices = historyIndicesByType[entityType];
//         totalEntries = indices.length;
        
//         for (uint256 i = 0; i < indices.length; i++) {
//             HistoryEntry memory entry = allHistoryEntries[indices[i]];
//             if (entry.actionType == ActionType.CREATE) {
//                 createCount++;
//             } else if (entry.actionType == ActionType.UPDATE) {
//                 updateCount++;
//             } else if (entry.actionType == ActionType.DELETE) {
//                 deleteCount++;
//             }
//         }
        
//         return (totalEntries, createCount, updateCount, deleteCount);
//     }

//     // ==================== ADMIN FUNCTIONS ====================

//     /**
//      * @dev Grant writer role to Management contract
//      */
//     function grantWriterRole(address account) external onlyRole(ADMIN_ROLE) {
//         _grantRole(WRITER_ROLE, account);
//     }

//     /**
//      * @dev Revoke writer role
//      */
//     function revokeWriterRole(address account) external onlyRole(ADMIN_ROLE) {
//         _revokeRole(WRITER_ROLE, account);
//     }
//     /**
//     * @dev Get last 2 UPDATE snapshots only (skip CREATE)
//     * Returns the 2 most recent UPDATE versions for comparison
//     */
//     function getDishUpdateSnapshots(string memory dishCode) external view returns (
//         DishSnapshot memory oldUpdateSnapshot,
//         DishSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         DishSnapshot[] storage snapshots = dishSnapshots[dishCode];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         // Find the 2 most recent UPDATE snapshots (skip CREATE)
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
        
//         // Iterate from newest to oldest
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             // Check if this snapshot is from an UPDATE action
//             if (_isUpdateAction(EntityType.DISH, dishCode, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         // updateIndices[0] is newest, updateIndices[1] is second newest
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getCategoryUpdateSnapshots(string memory code) external view returns (
//         CategorySnapshot memory oldUpdateSnapshot,
//         CategorySnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         CategorySnapshot[] storage snapshots = categorySnapshots[code];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.CATEGORY, code, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getDiscountUpdateSnapshots(string memory code) external view returns (
//         DiscountSnapshot memory oldUpdateSnapshot,
//         DiscountSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         DiscountSnapshot[] storage snapshots = discountSnapshots[code];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.DISCOUNT, code, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getStaffUpdateSnapshots(address wallet) external view returns (
//         StaffSnapshot memory oldUpdateSnapshot,
//         StaffSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         StaffSnapshot[] storage snapshots = staffSnapshots[wallet];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
//         string memory entityId = _addressToString(wallet);
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.STAFF, entityId, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getTableUpdateSnapshots(uint tableNumber) external view returns (
//         TableSnapshot memory oldUpdateSnapshot,
//         TableSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         TableSnapshot[] storage snapshots = tableSnapshots[tableNumber];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
//         string memory entityId = _uintToString(tableNumber);
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.TABLE, entityId, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getBannerUpdateSnapshots(uint bannerId) external view returns (
//         BannerSnapshot memory oldUpdateSnapshot,
//         BannerSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         BannerSnapshot[] storage snapshots = bannerSnapshots[bannerId];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
//         string memory entityId = _uintToString(bannerId);
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.BANNER, entityId, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getTCUpdateSnapshots(uint tcId) external view returns (
//         TCSnapshot memory oldUpdateSnapshot,
//         TCSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         TCSnapshot[] storage snapshots = tcSnapshots[tcId];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
//         string memory entityId = _uintToString(tcId);
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.TC, entityId, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getWorkingShiftUpdateSnapshots(uint shiftId) external view returns (
//         WorkingShiftSnapshot memory oldUpdateSnapshot,
//         WorkingShiftSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         WorkingShiftSnapshot[] storage snapshots = workingShiftSnapshots[shiftId];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
//         string memory entityId = _uintToString(shiftId);
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.WORKING_SHIFT, entityId, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getUniformUpdateSnapshots(uint uniformId) external view returns (
//         UniformSnapshot memory oldUpdateSnapshot,
//         UniformSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         UniformSnapshot[] storage snapshots = uniformSnapshots[uniformId];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
//         string memory entityId = _uintToString(uniformId);
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.UNIFORM, entityId, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getAreaUpdateSnapshots(uint areaId) external view returns (
//         AreaSnapshot memory oldUpdateSnapshot,
//         AreaSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         AreaSnapshot[] storage snapshots = areaSnapshots[areaId];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
//         string memory entityId = _uintToString(areaId);
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.AREA, entityId, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getPositionUpdateSnapshots(string memory name) external view returns (
//         PositionSnapshot memory oldUpdateSnapshot,
//         PositionSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         PositionSnapshot[] storage snapshots = positionSnapshots[name];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.POSITION, name, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     function getDishOptionUpdateSnapshots(bytes32 optionId) external view returns (
//         DishOptionSnapshot memory oldUpdateSnapshot,
//         DishOptionSnapshot memory newUpdateSnapshot,
//         bool hasOldUpdate,
//         bool hasNewUpdate
//     ) {
//         DishOptionSnapshot[] storage snapshots = dishOptionSnapshots[optionId];
        
//         if (snapshots.length == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         uint foundCount = 0;
//         uint[2] memory updateIndices;
//         string memory entityId = _bytes32ToString(optionId);
        
//         for (uint i = snapshots.length; i > 0 && foundCount < 2; i--) {
//             uint index = i - 1;
            
//             if (_isUpdateAction(EntityType.DISH_OPTION, entityId, snapshots[index].timestamp)) {
//                 updateIndices[foundCount] = index;
//                 foundCount++;
//             }
//         }
        
//         if (foundCount == 0) {
//             return (oldUpdateSnapshot, newUpdateSnapshot, false, false);
//         }
        
//         newUpdateSnapshot = snapshots[updateIndices[0]];
//         hasNewUpdate = true;
        
//         if (foundCount >= 2) {
//             oldUpdateSnapshot = snapshots[updateIndices[1]];
//             hasOldUpdate = true;
//         }
        
//         return (oldUpdateSnapshot, newUpdateSnapshot, hasOldUpdate, hasNewUpdate);
//     }

//     /**
//     * @dev Helper function to check if a snapshot corresponds to an UPDATE action
//     */
//     function _isUpdateAction(
//         EntityType entityType,
//         string memory entityId,
//         uint256 snapshotTimestamp
//     ) internal view returns (bool) {
//         uint256[] storage indices = historyIndicesByEntity[entityType][entityId];
        
//         // Find history entry with matching timestamp
//         for (uint i = 0; i < indices.length; i++) {
//             HistoryEntry memory entry = allHistoryEntries[indices[i]];
            
//             // Match timestamp (with small tolerance for block timestamp differences)
//             if (entry.timestamp == snapshotTimestamp && 
//                 entry.actionType == ActionType.UPDATE) {
//                 return true;
//             }
//         }
        
//         return false;
//     }

//     /**
//     * @dev Get count of UPDATE actions for an entity
//     */
//     function getUpdateCount(
//         EntityType entityType,
//         string memory entityId
//     ) external view returns (uint count) {
//         uint256[] storage indices = historyIndicesByEntity[entityType][entityId];
        
//         for (uint i = 0; i < indices.length; i++) {
//             if (allHistoryEntries[indices[i]].actionType == ActionType.UPDATE) {
//                 count++;
//             }
//         }
        
//         return count;
//     }

//     /**
//     * @dev Get all UPDATE timestamps for an entity (for timeline)
//     */
//     function getUpdateTimeline(
//         EntityType entityType,
//         string memory entityId
//     ) external view returns (uint256[] memory timestamps) {
//         uint256[] storage indices = historyIndicesByEntity[entityType][entityId];
        
//         // Count updates first
//         uint updateCount = 0;
//         for (uint i = 0; i < indices.length; i++) {
//             if (allHistoryEntries[indices[i]].actionType == ActionType.UPDATE) {
//                 updateCount++;
//             }
//         }
        
//         if (updateCount == 0) {
//             return new uint256[](0);
//         }
        
//         // Collect timestamps
//         timestamps = new uint256[](updateCount);
//         uint index = 0;
        
//         for (uint i = 0; i < indices.length; i++) {
//             HistoryEntry memory entry = allHistoryEntries[indices[i]];
//             if (entry.actionType == ActionType.UPDATE) {
//                 timestamps[index] = entry.timestamp;
//                 index++;
//             }
//         }
        
//         return timestamps;
//     }
//      function getManagerSnapshots(address wallet) external view returns (
//         ManagerSnapshot memory oldSnapshot,
//         ManagerSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         ManagerSnapshot[] storage snapshots = managerSnapshots[wallet];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
    
//     function getPaymentInfoSnapshots(uint256 merchantId) external view returns (
//         PaymentInfoSnapshot memory oldSnapshot,
//         PaymentInfoSnapshot memory newSnapshot,
//         bool hasOld,
//         bool hasNew
//     ) {
//         PaymentInfoSnapshot[] storage snapshots = paymentInfoSnapshots[merchantId];
//         uint length = snapshots.length;
        
//         if (length == 0) {
//             return (oldSnapshot, newSnapshot, false, false);
//         }
        
//         newSnapshot = snapshots[length - 1];
//         hasNew = true;
        
//         if (length >= 2) {
//             oldSnapshot = snapshots[length - 2];
//             hasOld = true;
//         }
        
//         return (oldSnapshot, newSnapshot, hasOld, hasNew);
//     }
//     uint256[50] private __gap;
// }