// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.20;
// import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "./interfaces/IRestaurant.sol";
// import "./interfaces/ITimeKeeping.sol";
// contract Management is 
//     Initializable, 
//     AccessControlUpgradeable,
//     UUPSUpgradeable    
// {
//     bytes32 public ROLE_ADMIN ;
//     bytes32 public ROLE_STAFF ;
//     bytes32 public ROLE_HASH_STATUS_ORDER;
//     bytes32 public ROLE_HASH_PAYMENT_CONFIRM;
//     bytes32 public ROLE_HASH_UPDATE_TC;
//     bytes32 public ROLE_HASH_TABLE_MANAGE;
//     bytes32 public ROLE_HASH_MENU_MANAGE;
    
//     // Restaurant Info
//     RestaurantInfo public restaurantInfo;
//     address public restaurantOrder;
    
//     mapping(address => Staff) public mAddToStaff;
//     Staff[] public staffs;
//     mapping(uint => Table) public mNumberToTable;
//     Table[] public tables;
//     mapping(string => Category) public mCodeToCat;
//     Category[]public categories;
//     mapping(string => Dish) public mCodeToDish;
//     mapping(string => Dish[]) public mCodeCatToDishes;
//     mapping(string => Discount) public mCodeToDiscount;
//     Discount[] public discounts;
//     mapping(string => bool) public isCodeExist;
//     // mapping(string => uint) public mDishRemain;
//     mapping(string => bytes32[]) public mDishVariant; // dishcode => variants
//     mapping(string => mapping(bytes32 => Variant)) public mVariant;
//     mapping(string => mapping(bytes32 => Attribute[])) public mVariantAttributes; // dishcode => variantID => attribute

//     mapping(bytes32 => Attribute) public mAttribute;
//     mapping(string => bytes32[]) public mCategoryAttributes;
//     // uint256 public productID;
//     string[] public allDishCodes;
//     mapping(string => uint) public dishCodeIndex;  
//     mapping(string => bool) public dishIsNew;
//     mapping(string => uint) public dishTotalRevenue;
//     mapping(string => uint) public dishTotalOrders;
//     mapping(string => uint) public dishStartTime;

//     // Top dishes tracking
    
//     // Historical data
//     uint public serviceStartTime;
//     DigitalMenu[] public digitalMenu;
//     Banner[] public banners;
//     TCInfo[] public tcs;
//     WorkingShift[] public workingShifts;
//     Uniform[] public uniforms;
//     string public linkGG;
//     // Track staff activity by date (timestamp in days since epoch)
//     mapping(uint => address[]) public dailyActiveStaff;
//     mapping(uint => mapping(address => bool)) public isDailyActive;

//     // Track staff activity by month (timestamp in months since epoch)  
//     mapping(uint => address[]) public monthlyActiveStaff;
//     mapping(uint => mapping(address => bool)) public isMonthlyActive;

//     // Track when staff was created/updated for historical data
//     mapping(address => uint) public staffCreatedDate;
//     mapping(address => uint) public staffLastActiveDate;
//     DishWithOrder[] public dishesWithOrder;
//     address public timeKeeping ;
//     bytes32 public  ROLE_HASH_STAFF_MANAGE = keccak256("ROLE_HASH_STAFF_MANAGE");
//     mapping(string => Position) public mPosition;
//     Position[] public positions;
//     VoucherUse[] public voucherUseHistory;
//     // Reserve storage for upgradeability
//     uint256[17] private __gap;

//     constructor() {
//         _disableInitializers();
//     }
//     modifier onlyAdminAndRole(STAFF_ROLE role){
//         require(
//             checkRole(role,msg.sender),
//             "Access denied: missing role"
//         );
//         _;
//     }
//     modifier onlyOrder{
//         require(msg.sender == restaurantOrder,"only restaurantOrder can call");
//         _;
//     }
//     function setTimeKeeping(address _timeKeeping) external onlyRole(ROLE_ADMIN) {
//         timeKeeping = _timeKeeping;
//     }
//     function checkRole(STAFF_ROLE role,address user)public view returns(bool rightRole){
//         if(hasRole(ROLE_ADMIN, user) || hasRole(_getRoleHash(role), user) || user == timeKeeping){
//             return true;
//         }
//     } 
//     function _authorizeUpgrade(address newImplementation) internal override {}

//     function initialize() public initializer {
//         __AccessControl_init();
//         __UUPSUpgradeable_init();

//         ROLE_ADMIN = keccak256("ROLE_ADMIN");
//         ROLE_STAFF = keccak256("ROLE_STAFF");
//         ROLE_HASH_STATUS_ORDER = keccak256("ROLE_HASH_STATUS_ORDER");
//         ROLE_HASH_PAYMENT_CONFIRM = keccak256("ROLE_HASH_PAYMENT_CONFIRM");
//         ROLE_HASH_UPDATE_TC = keccak256("ROLE_HASH_UPDATE_TC");
//         ROLE_HASH_TABLE_MANAGE = keccak256("ROLE_HASH_TABLE_MANAGE");
//         ROLE_HASH_STAFF_MANAGE = keccak256("ROLE_HASH_STAFF_MANAGE");
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         _grantRole(ROLE_ADMIN, msg.sender);
        
//         serviceStartTime = block.timestamp;
//         // restaurantOrder = _restaurantOrder;
//     }
//     function setServiceStartTime(uint _serviceStartTime) external onlyRole(ROLE_ADMIN) {
//         serviceStartTime = _serviceStartTime;
//     }
//     function setRestaurantOrder(address _restaurantOrder) external onlyRole(ROLE_ADMIN) {
//         restaurantOrder = _restaurantOrder;
//     }

//     // Restaurant Info Management
//     function RegisterRestaurantInfo(
//         string memory _name,
//         string memory _addr,
//         string memory _phone,
//         string memory _visaInfo,
//         address _walletAddress,
//         uint _workPlaceId,
//         string memory _imgLink
//     ) external onlyRole(ROLE_ADMIN) {
//         ITimeKeeping(timeKeeping).getWorkPlaceById(_workPlaceId);
//         restaurantInfo = RestaurantInfo({
//             name: _name,
//             addr: _addr,
//             phone: _phone,
//             visaInfo: _visaInfo,
//             walletAddress: _walletAddress,
//             workPlaceId: _workPlaceId,
//             imgLink: _imgLink,
//             registeredAt: block.timestamp,
//             updatedAt: block.timestamp
//         });
//     }

//     function GetRestaurantInfo() external view returns (RestaurantInfo memory) {
//         return restaurantInfo;
//     }

//     function UpdateRestaurantInfo(
//         string memory _name,
//         string memory _addr,
//         string memory _phone,
//         string memory _visaInfo,
//         address _walletAddress,
//         string memory _imgLink,
//         uint _workPlaceId
//     ) external onlyRole(ROLE_ADMIN) {
//         restaurantInfo.name = _name;
//         restaurantInfo.addr = _addr;
//         restaurantInfo.phone = _phone;
//         restaurantInfo.visaInfo = _visaInfo;
//         restaurantInfo.imgLink = _imgLink;
//         restaurantInfo.workPlaceId = _workPlaceId;
//         restaurantInfo.walletAddress = _walletAddress;
//         restaurantInfo.updatedAt = block.timestamp;
//     }

//     function CreateStaff(
//         Staff memory staff
//     )external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE){
//         require(staff.wallet != address(0),"wallet of staff is wrong");
//         require(mAddToStaff[staff.wallet].wallet == address(0),"wallet existed");
//         require(bytes(staff.position).length > 0, "position is empty");
//         require(bytes(mPosition[staff.position].name).length > 0, "position not found");
//         require(staff.roles.length > 0, "staff roles is empty");
//         // Kiểm tra tất cả roles của staff có nằm trong roles được phép của position
//         _validateStaffRoles(staff.position, staff.roles);

//         mAddToStaff[staff.wallet] = staff;
//         staffs.push(staff);
//         _grantRole(ROLE_STAFF, staff.wallet);   
//         // Track creation date and mark as active from today
//         uint currentDate = block.timestamp;
//         staffCreatedDate[staff.wallet] = currentDate;
//         staffLastActiveDate[staff.wallet] = currentDate;
        
//         // Automatically mark staff as active for today if they are active
//         if (staff.active) {
//             _markStaffActiveForDate(staff.wallet, currentDate);
//         }    
//         for (uint idx = 0; idx < staff.roles.length; idx++) {
//             bytes32 roleHash = _getRoleHash(staff.roles[idx]);
//             _grantRole(roleHash, staff.wallet);
//         }    
//     }
//     // Hàm helper để validate roles của staff
//     function _validateStaffRoles(string memory _position, STAFF_ROLE[] memory _staffRoles) 
//         internal 
//         view 
//     {
//         STAFF_ROLE[] memory positionRoles = mPosition[_position].positionRoles;
        
//         // Kiểm tra từng role của staff
//         for (uint i = 0; i < _staffRoles.length; i++) {
//             bool roleFound = false;
            
//             // Tìm xem role này có trong position roles không
//             for (uint j = 0; j < positionRoles.length; j++) {
//                 if (_staffRoles[i] == positionRoles[j]) {
//                     roleFound = true;
//                     break;
//                 }
//             }
            
//             require(roleFound, string(abi.encodePacked(
//                 "role ", 
//                 _staffRoleToString(_staffRoles[i]),
//                 " is not allowed for position ",
//                 _position
//             )));
//         }
//     }  
//     // Hàm helper để convert STAFF_ROLE thành string (để hiển thị lỗi rõ ràng hơn)
//     function _staffRoleToString(STAFF_ROLE _role) 
//         internal 
//         pure 
//         returns (string memory) 
//     {
//         if (_role == STAFF_ROLE.UPDATE_STATUS_DISH) return "UPDATE_STATUS_DISH";
//         if (_role == STAFF_ROLE.PAYMENT_CONFIRM) return "PAYMENT_CONFIRM";
//         if (_role == STAFF_ROLE.TC_MANAGE) return "TC_MANAGE";
//         if (_role == STAFF_ROLE.TABLE_MANAGE) return "TABLE_MANAGE";
//         if (_role == STAFF_ROLE.MENU_MANAGE) return "MENU_MANAGE";
//         if (_role == STAFF_ROLE.STAFF_MANAGE) return "STAFF_MANAGE";
//         return "UNKNOWN";
//     }  
//     function isStaff(address account) external view returns (bool) {
//         return hasRole(ROLE_STAFF, account);
//     }

//     // function removeStaff(address wallet) external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) {
//     //     require(mAddToStaff[wallet].active, "Staff not found");
//     //     mAddToStaff[wallet].active = false;
//     //     for(uint i = 0; i < staffs.length; i++){
//     //         if(wallet == staffs[i].wallet){
//     //             staffs[i] = staffs[staffs.length -1];
//     //             staffs.pop();
//     //             break;
//     //         }
            
//     //     }
//     //     _revokeRole(ROLE_STAFF, wallet);
//     // }
//     function removeStaff(address wallet) external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) {
//         require(mAddToStaff[wallet].wallet != address(0), "Staff not found");
//         // require(mAddToStaff[wallet].active, "Staff already inactive");
        
//         // Lưu lại roles trước khi xóa
//         STAFF_ROLE[] memory staffRoles = mAddToStaff[wallet].roles;
        
//         // Đánh dấu inactive
//         mAddToStaff[wallet].active = false;
        
//         // Xóa khỏi array
//         for(uint i = 0; i < staffs.length; i++){
//             if(wallet == staffs[i].wallet){
//                 staffs[i] = staffs[staffs.length - 1];
//                 staffs.pop();  // ✅ THÊM () ĐÂY
//                 break;
//             }
//         }
        
//         // Revoke ROLE_STAFF chính
//         _revokeRole(ROLE_STAFF, wallet);
        
//         // ✅ THÊM: Revoke tất cả các role cụ thể của staff
//         for (uint idx = 0; idx < staffRoles.length; idx++) {
//             bytes32 roleHash = _getRoleHash(staffRoles[idx]);
//             _revokeRole(roleHash, wallet);
//         }
// }
//     function UpdateStaffInfo(
//         address _wallet,
//         string memory _name,
//         string memory _code,
//         string memory _phone,
//         string memory _addr,
//         STAFF_ROLE[] memory _roles,
//         WorkingShift[] memory _shifts, 
//         string memory _linkImgSelfie,
//         string memory _linkImgPortrait,
//         string memory _position,
//         bool _active    
//     )external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) returns(bool){
//         require(_wallet != address(0),"wallet of staff is wrong");
//         Staff storage staff = mAddToStaff[_wallet];
//         require(mAddToStaff[staff.wallet].wallet != address(0),"does not find any staff");
//         bool wasActive = staff.active;
//         staff.name = _name;
//         staff.code = _code;
//         staff.phone = _phone;
//         staff.addr = _addr;
//         staff.active = _active;
//         staff.shifts = _shifts;
//         staff.linkImgSelfie = _linkImgSelfie;
//         staff.linkImgPortrait = _linkImgPortrait;
//         staff.position = _position;
//         for (uint i = 0; i < staffs.length; i++) {
//             if (staffs[i].wallet == _wallet) {
//                 staffs[i] = staff;
//                 break;
//             }
//         }
//         for (uint idx = 0; idx < staff.roles.length; idx++) {
//             bytes32 roleHash = _getRoleHash(staff.roles[idx]);
//             _revokeRole(roleHash, staff.wallet);
//         }
//         staff.roles = _roles;
//         for (uint idx = 0; idx < staff.roles.length; idx++) {
//             bytes32 roleHash = _getRoleHash(staff.roles[idx]);
//             _grantRole(roleHash, staff.wallet);
//         }    
//         if (!wasActive && _active) {
//             _markStaffActiveForDate(_wallet, block.timestamp);
//             staffLastActiveDate[_wallet] = block.timestamp;
//         }
//         return true;
//     }
//     // Internal function to mark staff active for a specific date
//     function _markStaffActiveForDate(address staffWallet, uint date) internal {
//         uint dayKey = _getDay(date);
//         uint monthKey = _getMonth(date);
        
//         // Mark daily active
//         if (!isDailyActive[dayKey][staffWallet]) {
//             dailyActiveStaff[dayKey].push(staffWallet);
//             isDailyActive[dayKey][staffWallet] = true;
//         }
        
//         // Mark monthly active  
//         if (!isMonthlyActive[monthKey][staffWallet]) {
//             monthlyActiveStaff[monthKey].push(staffWallet);
//             isMonthlyActive[monthKey][staffWallet] = true;
//         }
//     }
//     function GetStaffInfo(address _wallet)external view onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) returns(Staff memory){
//         return mAddToStaff[_wallet];
//     }

//     function GetStaffsPagination(uint256 offset, uint256 limit)
//         external
//         view
//         returns (Staff[] memory result,uint totalCount)
//     {
//         // require(offset < staffs.length, "offset out of range");
//         uint256 length = staffs.length;
//         totalCount = length;
        
//         // Nếu offset >= length, trả về mảng rỗng
//         if (offset >= length) {
//             return (new Staff[](0), totalCount);
//         }
//         uint256 end = offset + limit;
//         if (end > length) {
//             end = length;
//         }

//         uint256 size = end - offset;
//         result = new Staff[](size);

//         for (uint256 i = 0; i < size; i++) {
//             result[i] = staffs[offset + i];
//         }

//         return (result,totalCount);
//     }

//     function GetStaffRolePayment()external view returns(address[] memory staffsPayment){
//         uint count;
//         Staff[] memory staffsTemp = new Staff[](staffs.length);
//         for(uint i; i< staffs.length; i++){
//             if(hasRole(_getRoleHash(STAFF_ROLE.PAYMENT_CONFIRM), staffs[i].wallet)){
//                 staffsTemp[count] =  staffs[i];
//                 count++;
//             }
//         } 
//         staffsPayment = new address[](count);
//         for(uint i; i<count; i++){
//             staffsPayment[i] = staffsTemp[i].wallet;
//         }

//     }
//     /**
//     * @dev Get list of active staff for a specific date
//     * @param date The date to query (timestamp)
//     * @return Array of Staff structs that were active on that date
//     */
//     function GetActiveStaffByDate(uint date) external view returns (Staff[] memory) {
//         uint dayKey = _getDay(date);
//         address[] memory activeAddresses = dailyActiveStaff[dayKey];
        
//         // Count valid active staff
//         uint validCount = 0;
//         for (uint i = 0; i < activeAddresses.length; i++) {
//             if (mAddToStaff[activeAddresses[i]].active && 
//                 mAddToStaff[activeAddresses[i]].wallet != address(0)) {
//                 validCount++;
//             }
//         }
        
//         // Build result array
//         Staff[] memory activeStaff = new Staff[](validCount);
//         uint index = 0;
        
//         for (uint i = 0; i < activeAddresses.length; i++) {
//             Staff memory staff = mAddToStaff[activeAddresses[i]];
//             if (staff.active && staff.wallet != address(0)) {
//                 activeStaff[index] = staff;
//                 index++;
//             }
//         }
        
//         return activeStaff;
//     }

//     /**
//     * @dev Get list of active staff for a specific month
//     * @param date The date within the month to query (timestamp)
//     * @return Array of Staff structs that were active during that month
//     */
//     function GetActiveStaffByMonth(uint date) external view returns (Staff[] memory) {
//         uint monthKey = _getMonth(date);
//         address[] memory activeAddresses = monthlyActiveStaff[monthKey];
        
//         // Count valid active staff
//         uint validCount = 0;
//         for (uint i = 0; i < activeAddresses.length; i++) {
//             if (mAddToStaff[activeAddresses[i]].active && 
//                 mAddToStaff[activeAddresses[i]].wallet != address(0)) {
//                 validCount++;
//             }
//         }
        
//         // Build result array
//         Staff[] memory activeStaff = new Staff[](validCount);
//         uint index = 0;
        
//         for (uint i = 0; i < activeAddresses.length; i++) {
//             Staff memory staff = mAddToStaff[activeAddresses[i]];
//             if (staff.active && staff.wallet != address(0)) {
//                 activeStaff[index] = staff;
//                 index++;
//             }
//         }
        
//         return activeStaff;
//     }

//     /**
//     * @dev Get count of active staff for a specific date
//     * @param date The date to query (timestamp)
//     * @return Number of active staff on that date
//     */
//     function GetActiveStaffCountByDate(uint date) external view returns (uint) {
//         uint dayKey = _getDay(date);
//         address[] memory activeAddresses = dailyActiveStaff[dayKey];
        
//         uint count = 0;
//         for (uint i = 0; i < activeAddresses.length; i++) {
//             if (mAddToStaff[activeAddresses[i]].active && 
//                 mAddToStaff[activeAddresses[i]].wallet != address(0)) {
//                 count++;
//             }
//         }
        
//         return count;
//     }

//     /**
//     * @dev Get count of active staff for a specific month
//     * @param date The date within the month to query (timestamp)
//     * @return Number of active staff during that month
//     */
//     function GetActiveStaffCountByMonth(uint date) external view returns (uint) {
//         uint monthKey = _getMonth(date);
//         address[] memory activeAddresses = monthlyActiveStaff[monthKey];
        
//         uint count = 0;
//         for (uint i = 0; i < activeAddresses.length; i++) {
//             if (mAddToStaff[activeAddresses[i]].active && 
//                 mAddToStaff[activeAddresses[i]].wallet != address(0)) {
//                 count++;
//             }
//         }
        
//         return count;
//     }

//     /**
//     * @dev Get active staff addresses for a specific date (more gas efficient)
//     * @param date The date to query (timestamp)
//     * @return Array of wallet addresses that were active on that date
//     */
//     function GetActiveStaffAddressesByDate(uint date) external view returns (address[] memory) {
//         uint dayKey = _getDay(date);
//         address[] memory activeAddresses = dailyActiveStaff[dayKey];
        
//         // Count valid addresses
//         uint validCount = 0;
//         for (uint i = 0; i < activeAddresses.length; i++) {
//             if (mAddToStaff[activeAddresses[i]].active && 
//                 mAddToStaff[activeAddresses[i]].wallet != address(0)) {
//                 validCount++;
//             }
//         }
        
//         // Build result array
//         address[] memory result = new address[](validCount);
//         uint index = 0;
        
//         for (uint i = 0; i < activeAddresses.length; i++) {
//             if (mAddToStaff[activeAddresses[i]].active && 
//                 mAddToStaff[activeAddresses[i]].wallet != address(0)) {
//                 result[index] = activeAddresses[i];
//                 index++;
//             }
//         }
        
//         return result;
//     }

//     /**
//     * @dev Get active staff addresses for a specific month (more gas efficient)
//     * @param date The date within the month to query (timestamp)
//     * @return Array of wallet addresses that were active during that month
//     */
//     function GetActiveStaffAddressesByMonth(uint date) external view returns (address[] memory) {
//         uint monthKey = _getMonth(date);
//         address[] memory activeAddresses = monthlyActiveStaff[monthKey];
        
//         // Count valid addresses
//         uint validCount = 0;
//         for (uint i = 0; i < activeAddresses.length; i++) {
//             if (mAddToStaff[activeAddresses[i]].active && 
//                 mAddToStaff[activeAddresses[i]].wallet != address(0)) {
//                 validCount++;
//             }
//         }
        
//         // Build result array
//         address[] memory result = new address[](validCount);
//         uint index = 0;
        
//         for (uint i = 0; i < activeAddresses.length; i++) {
//             if (mAddToStaff[activeAddresses[i]].active && 
//                 mAddToStaff[activeAddresses[i]].wallet != address(0)) {
//                 result[index] = activeAddresses[i];
//                 index++;
//             }
//         }
        
//         return result;
//     }

//     // Table management
//     function CreateTable(
//         uint _number,
//         uint _numPeople,
//         bool _active
//     )external onlyAdminAndRole(STAFF_ROLE.TABLE_MANAGE){
//         require(_number != 0,"Table number can not be 0");
//         require(mNumberToTable[_number].number == 0,"this number existed");
//         Table memory table = Table({
//             number: _number,
//             numPeople: _numPeople,
//             status: TABLE_STATUS.EMPTY,
//             paymentId: bytes32(0),
//             active: _active
//         });
//         mNumberToTable[_number] = table;
//         tables.push(table);
//     }
//     function removeTable(uint _number)external onlyAdminAndRole(STAFF_ROLE.TABLE_MANAGE){
//         for(uint i;i<tables.length;i++){
//             if(tables[i].number == _number){
//                 tables[i] = tables[tables.length-1];
//                 tables.pop();
//             }
//         }
//         delete  mNumberToTable[_number];
//     }


//     function UpdateTable(
//         uint _number,
//         uint _numPeople,
//         bool _active
//     )external onlyAdminAndRole(STAFF_ROLE.TABLE_MANAGE) returns(bool){
//         require(_number != 0,"Table number can not be 0");
//         require(mNumberToTable[_number].number != 0,"this number table does not exist");
//         mNumberToTable[_number].numPeople = _numPeople;
//         mNumberToTable[_number].active = _active;
//         for(uint i;i<tables.length;i++){
//             if(keccak256(abi.encodePacked(tables[i].number ))== keccak256(abi.encodePacked(_number))){
//                 tables[i] = mNumberToTable[_number];
//             }
//         }
//         return true;
//     }
//     function GetAllTables()external view returns(Table[] memory){
//         return tables;
//     }
    
//     function GetTable(uint _number)external view returns(Table memory){
//         return mNumberToTable[_number];
//     }

//     // Category management
//     function CreateCategory(
//         Category memory category
//     )external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE){
//         require(bytes(category.code).length >0,"category code can not be empty");
//         require(
//             bytes(mCodeToCat[category.code].code).length == 0,
//             "category code existed"
//         );
//         require(!isCodeExist[category.code],"code category exists");
//         Category storage cat = mCodeToCat[category.code];
//         cat.code= category.code;
//         cat.name= category.name;
//         cat.rank= category.rank;
//         cat.desc= category.desc;
//         cat.active= category.active;
//         cat.imgUrl= category.imgUrl;
//         categories.push(cat);
//         isCodeExist[cat.code] = true;
//     }
//     function RemoveCategory(string memory _code)external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE){
//         for(uint i;i<categories.length;i++){
//             if(keccak256(abi.encodePacked(categories[i].code ))== keccak256(abi.encodePacked(_code))){
//                 categories[i] = categories[categories.length-1];
//                 categories.pop();
//             }
//         }
//         delete  mCodeToCat[_code];
//     }

//     function UpdateCategory(
//         string memory _code,
//         string memory _name,
//         uint _rank,
//         string memory _desc,
//         bool _active,
//         string memory _imgUrl
//     )external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) returns(bool){
//         require(bytes(_code).length >0,"category code can not be empty");
//         require(bytes(mCodeToCat[_code].code).length > 0,"category code does not exist");
//         Category storage category = mCodeToCat[_code];
//         category.name = _name;
//         category.rank = _rank;
//         category.desc = _desc;
//         category.active = _active;
//         category.imgUrl = _imgUrl;
//         for(uint i;i<categories.length;i++){
//             if(keccak256(abi.encodePacked(categories[i].code ))== keccak256(abi.encodePacked(_code))){
//                 categories[i] = category;
//             }
//         }
//         return true;
//     }
    
//     function GetCategories()external view returns(Category[] memory){
//         return categories;
//     }
    
//     function GetCategory(
//         string memory _code
//     )external view returns(Category memory){
//         require(bytes(_code).length >0,"category code can not be empty");
//         require(bytes(mCodeToCat[_code].code).length > 0 ,"category code does not exist");
//         return mCodeToCat[_code];
//     }
//     function GetCategoriesPagination(
//         uint offset,
//         uint limit
//     )external view returns(Category[] memory categoryArr,uint[] memory dishCounts,uint totalCount){
//         uint256 length = categories.length; 
//         // require(offset < length, "offset out of range");
//         totalCount = length;
    
//     // Nếu offset >= length, trả về mảng rỗng
//     if (offset >= length) {
//         return (new Category[](0),new uint[](0), totalCount);
//     }
//         uint256 end = offset + limit;
//         if (end > length) {
//             end = length;
//         }

//         uint256 size = end - offset;
//         categoryArr = new Category[](size);
//         dishCounts = new uint[](size);

//         for (uint256 i = 0; i < size; i++) {
//             categoryArr[i] =categories[offset +i];
//             dishCounts[i]=mCodeCatToDishes[categories[offset +i].code].length;
//         }
//         //
//         // uint256 length = mCodeCatToDishes[_codeCategory].length;
//         // productsInfo = new DishInfo[](length);

//         // for (uint256 i = 0; i < length; i++) {
//         //     productsInfo[i] = getDishInfo(mCodeCatToDishes[_codeCategory][i].code);
//         // }
//         return (categoryArr,dishCounts,length);
//     }


//     // Dish management
//     function CreateDish(
//         string memory _codeCategory,
//         Dish memory dish,
//         // uint _quantity
//         VariantParams[] memory _variants
//     )external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE){
//         require(bytes(_codeCategory).length >0 && bytes(dish.code).length >0,"category code and dish code can not be empty");
//         require(
//             bytes(mCodeToCat[_codeCategory].code).length > 0,
//             "category code does not exist"
//         );
//         require(!isCodeExist[dish.code],"code dish exists");
//         require(_variants.length > 0,"Invalid variants length");
//         // productID++;
//         mCodeCatToDishes[_codeCategory].push(dish);
//         isCodeExist[dish.code] = true;
//         // mDishRemain[dish.code] = _quantity;
//         for (uint256 i = 0; i < _variants.length; i++) {
//             // HASH the attributes of the product to avoid duplicate attr and have the same price
//             Variant memory newVariant;
//             bytes32 attributesHash = hashAttributes(_variants[i].attrs);
//             newVariant.variantID = attributesHash;
//             newVariant.dishPrice = _variants[i].price;
//             mDishVariant[dish.code].push(attributesHash);
//             mVariant[dish.code][attributesHash] = newVariant;
//             // wild things happen all the time
//             for (uint256 j = 0; j < _variants[i].attrs.length; j++) {
//                 // tips and trick for copy
//                 mVariantAttributes[dish.code][attributesHash].push();

//                 bytes32 attrID = keccak256(abi.encode(_variants[i].attrs[j]));

//                 mVariantAttributes[dish.code][attributesHash][j] = _variants[i].attrs[j];
//                 mVariantAttributes[dish.code][attributesHash][j].id = attrID;
                
//                 mAttribute[attrID] = _variants[i].attrs[j];
//                 mAttribute[attrID].id = attrID;
//                 bool foundAttr;
//                 for (uint256 m = 0; m < mCategoryAttributes[_codeCategory].length; m++){
//                     if (attrID == mCategoryAttributes[_codeCategory][m]){
//                         foundAttr = true;
//                         break;
//                     }
//                 }
//                 if (!foundAttr){
//                     mCategoryAttributes[_codeCategory].push(attrID);
//                 }
//             }
//             for (uint256 k = 0; k < i; k++) {
//                 // 1 product have many variants
//                 // 1 variants have many attributes
//                 // those attributes must not be the same
//                 // if a variant already have color : red, size: big
//                 // another variant can't be the same, must be more or less or different
//                 require(mDishVariant[dish.code][k] != attributesHash,"Duplicate variant attributes detected");
//             }
//         }
//         mCodeToDish[dish.code] = dish;
//         // Initialize dish tracking
//         dishStartTime[dish.code] = block.timestamp;
//         dishIsNew[dish.code] = true;
        
//         // Add to allDishCodes if not exists
//         if (dishCodeIndex[dish.code] == 0 && (allDishCodes.length == 0 || keccak256(abi.encodePacked(allDishCodes[0])) != keccak256(abi.encodePacked(dish.code)))) {
//             allDishCodes.push(dish.code);
//             dishCodeIndex[dish.code] = allDishCodes.length - 1;
//         }
//     }
//     // Purpose: This function prevent 1 product have same attributes
//     // so it maybe like: Shirt, Color : Red, Size : M
//     // avoid the same attribute but maybe different price
//     function hashAttributes(
//         Attribute[] memory attrs
//     ) internal pure returns (bytes32) {
//         bytes memory attributesHash;

//         for (uint256 i = 0; i < attrs.length; i++) {
//             attributesHash = abi.encodePacked(
//                 attributesHash,
//                 attrs[i].key,
//                 attrs[i].value
//             );
//         }

//         return keccak256(attributesHash);
//     }
//     function BatchUpdateTopDish(string[] memory dishCodes) public {
//         uint n = dishesWithOrder.length;
//         require(n > 0, "No dishes");

//         // B1: gom các phần tử cần update
//         DishWithOrder[] memory updated = new DishWithOrder[](dishCodes.length);
//         bool[] memory removed = new bool[](n); // đánh dấu đã xóa để bỏ khỏi mảng chính

//         for (uint j = 0; j < dishCodes.length; j++) {
//             string memory _dishCode = dishCodes[j];

//             // tìm vị trí trong dishesWithOrder
//             uint index = type(uint).max;
//             for (uint i = 0; i < n; i++) {
//                 if (
//                     !removed[i] &&
//                     keccak256(bytes(dishesWithOrder[i].dish.code)) ==
//                     keccak256(bytes(_dishCode))
//                 ) {
//                     index = i;
//                     removed[i] = true; // đánh dấu đã loại bỏ
//                     break;
//                 }
//             }
//             require(index != type(uint).max, "Dish not found");

//             // cập nhật dữ liệu mới
//             bytes32[] memory variantIds = mDishVariant[_dishCode];
//             Variant memory variant = mVariant[_dishCode][variantIds[0]];
//             Attribute[] memory attributes = mVariantAttributes[_dishCode][variantIds[0]];

//             updated[j] = DishWithOrder({
//                 dish: mCodeToDish[_dishCode],
//                 orderNum: mCodeToDish[_dishCode].orderNum,
//                 originalIndex: index,
//                 variant: variant,
//                 attributes: attributes
//             });
//         }

//         // B2: sort nhóm updated theo orderNum giảm dần
//         for (uint i = 0; i < updated.length; i++) {
//             for (uint j = i + 1; j < updated.length; j++) {
//                 if (updated[j].orderNum > updated[i].orderNum) {
//                     DishWithOrder memory tmp = updated[i];
//                     updated[i] = updated[j];
//                     updated[j] = tmp;
//                 }
//             }
//         }

//         // B3: build lại mảng mới
//         DishWithOrder[] memory newArr = new DishWithOrder[](n); 
//         uint pos = 0;

//         // copy lại những phần tử cũ chưa bị xóa, chèn nhóm updated vào đúng chỗ
//         for (uint i = 0; i < n; i++) {
//             if (removed[i]) continue; // bỏ phần tử bị update
//             // chèn phần tử update vào trước khi orderNum nhỏ hơn
//             while (
//                 updated.length > 0 &&
//                 pos < updated.length &&
//                 updated[pos].orderNum > dishesWithOrder[i].orderNum
//             ) {
//                 newArr[pos + i] = updated[pos];
//                 pos++;
//             }
//             newArr[pos + i] = dishesWithOrder[i];
//         }

//         // nếu còn phần tử update chưa chèn thì push tiếp
//         uint filled = 0;
//         for (uint k = 0; k < n; k++) {
//             if (bytes(newArr[k].dish.code).length != 0) filled++;
//         }
//         for (uint k = filled; k < n; k++) {
//             newArr[k] = updated[pos];
//             pos++;
//         }

//         // B4: gán lại vào storage
//         delete dishesWithOrder;
//         for (uint i = 0; i < n; i++) {
//             dishesWithOrder.push(newArr[i]);
//         }
//     }
// // Helper function cho insertion sort
// function _insertionSortDescending(DishWithOrder[] memory arr) internal pure {
//     for (uint256 i = 1; i < arr.length; i++) {
//         DishWithOrder memory key = arr[i];
//         uint256 keyOrderNum = key.orderNum;
        
//         uint256 j = i;
//         while (j > 0 && arr[j - 1].orderNum < keyOrderNum) {
//             arr[j] = arr[j - 1];
//             j--;
//         }
//         arr[j] = key;
//     }
// }

// // Phiên bản tối ưu hơn nữa - chỉ sort khi cần
// function BatchUpdateTopDishOptimal(string[] memory dishCodes) public {
//     uint256 n = dishesWithOrder.length;
//     require(n > 0 && dishCodes.length > 0, "Invalid input");
    
//     // Nếu update quá nhiều item (>50% mảng), tốt hơn là full update
//     if (dishCodes.length * 2 >= n) {
//         _fullUpdateAllDishes();
//         return;
//     }
    
//     // Tạo temp array để track changes
//     DishWithOrder[] memory tempArray = new DishWithOrder[](n);
//     bool hasChanges = false;
    
//     // Copy existing array và update các items cần thiết
//     for (uint256 i = 0; i < n; i++) {
//         tempArray[i] = dishesWithOrder[i];
        
//         // Check if this dish needs update
//         for (uint256 j = 0; j < dishCodes.length; j++) {
//             if (keccak256(bytes(tempArray[i].dish.code)) == 
//                 keccak256(bytes(dishCodes[j]))) {
                
//                 // Update the dish data
//                 string memory dishCode = dishCodes[j];
//                 bytes32 variantId = mDishVariant[dishCode][0];
                
//                 uint256 newOrderNum = mCodeToDish[dishCode].orderNum;
                
//                 // Chỉ update nếu thực sự thay đổi
//                 if (newOrderNum != tempArray[i].orderNum) {
//                     tempArray[i] = DishWithOrder({
//                         dish: mCodeToDish[dishCode],
//                         orderNum: newOrderNum,
//                         originalIndex: tempArray[i].originalIndex,
//                         variant: mVariant[dishCode][variantId],
//                         attributes: mVariantAttributes[dishCode][variantId]
//                     });
//                     hasChanges = true;
//                 }
//                 break;
//             }
//         }
//     }
    
//     // Chỉ sort và update storage nếu có thay đổi
//     if (hasChanges) {
//         _insertionSortDescending(tempArray);
        
//         delete dishesWithOrder;
//         for (uint256 i = 0; i < n; i++) {
//             dishesWithOrder.push(tempArray[i]);
//         }
//     }
// }

// // Fallback cho full update khi batch quá lớn
// function _fullUpdateAllDishes() internal {
//     // Reuse logic from optimized UpdateTopDish
//     uint256 dishCount = allDishCodes.length;
//     delete dishesWithOrder;
    
//     DishWithOrder[] memory tempDishes = new DishWithOrder[](dishCount);
    
//     for (uint256 i = 0; i < dishCount; i++) {
//         string memory dishCode = allDishCodes[i];
//         bytes32 variantId = mDishVariant[dishCode][0];
        
//         tempDishes[i] = DishWithOrder({
//             dish: mCodeToDish[dishCode],
//             orderNum: mCodeToDish[dishCode].orderNum,
//             originalIndex: i,
//             variant: mVariant[dishCode][variantId],
//             attributes: mVariantAttributes[dishCode][variantId]
//         });
//     }
    
//     _insertionSortDescending(tempDishes);
    
//     for (uint256 i = 0; i < dishCount; i++) {
//         dishesWithOrder.push(tempDishes[i]);
//     }
// }
// function UpdateTopDishLimited(uint256 topN) public {
//     uint256 dishCount = allDishCodes.length;
//     uint256 resultSize = dishCount < topN ? dishCount : topN;
    
//     delete dishesWithOrder;
    
//     // Chỉ lưu top N items
//     DishWithOrder[] memory tempDishes = new DishWithOrder[](resultSize);
//     uint256 minOrderNum = 0;
//     uint256 minIndex = 0;
    
//     for (uint256 i = 0; i < dishCount; i++) {
//         string memory dishCode = allDishCodes[i];
//         uint256 currentOrderNum = mCodeToDish[dishCode].orderNum;
        
//         if (i < resultSize) {
//             // Fill initial array
//             bytes32 variantId = mDishVariant[dishCode][0];
//             tempDishes[i] = DishWithOrder({
//                 dish: mCodeToDish[dishCode],
//                 orderNum: currentOrderNum,
//                 originalIndex: i,
//                 variant: mVariant[dishCode][variantId],
//                 attributes: mVariantAttributes[dishCode][variantId]
//             });
            
//             // Track minimum
//             if (currentOrderNum < minOrderNum || i == 0) {
//                 minOrderNum = currentOrderNum;
//                 minIndex = i;
//             }
//         } else if (currentOrderNum > minOrderNum) {
//             // Replace minimum with current item
//             bytes32 variantId = mDishVariant[dishCode][0];
//             tempDishes[minIndex] = DishWithOrder({
//                 dish: mCodeToDish[dishCode],
//                 orderNum: currentOrderNum,
//                 originalIndex: i,
//                 variant: mVariant[dishCode][variantId],
//                 attributes: mVariantAttributes[dishCode][variantId]
//             });
            
//             // Find new minimum
//             minOrderNum = currentOrderNum;
//             for (uint256 j = 0; j < resultSize; j++) {
//                 if (tempDishes[j].orderNum < minOrderNum) {
//                     minOrderNum = tempDishes[j].orderNum;
//                     minIndex = j;
//                 }
//             }
//         }
//     }
    
//     // Sort final result
//     _optimizedInsertionSort(tempDishes, resultSize);
    
//     // Write to storage once
//     for (uint256 i = 0; i < resultSize; i++) {
//         dishesWithOrder.push(tempDishes[i]);
//     }
// }
// function _optimizedInsertionSort(DishWithOrder[] memory arr, uint256 length) internal pure {
//     for (uint256 i = 1; i < length; i++) {
//         DishWithOrder memory key = arr[i];
//         uint256 orderNum = key.orderNum;
        
//         uint256 j = i;
//         // Tối ưu: so sánh orderNum trước khi di chuyển struct
//         while (j > 0 && arr[j - 1].orderNum < orderNum) {
//             arr[j] = arr[j - 1];
//             j--;
//         }
        
//         if (j != i) {
//             arr[j] = key;
//         }
//     }
// }
//     function UpdateTopDish() public  {
//         uint dishCount = allDishCodes.length;
        
//         // Tạo mảng dishes với orderNum
//         // DishWithOrder[] memory dishesWithOrder = new DishWithOrder[](dishCount);
//         delete dishesWithOrder;
//         for (uint i = 0; i < dishCount; i++) {
//             string memory _dishCode = allDishCodes[i];
//             bytes32[] memory variantIds = mDishVariant[_dishCode];
//             Variant memory variant = mVariant[_dishCode][variantIds[0]];
//             Attribute[] memory attributes = mVariantAttributes[_dishCode][variantIds[0]];

//             dishesWithOrder.push(DishWithOrder({
//                 dish: mCodeToDish[_dishCode],
//                 orderNum: mCodeToDish[_dishCode].orderNum,
//                 originalIndex: i,
//                 variant: variant,
//                 attributes: attributes
//             }));
//         }
        
//         // Heap sort
//         _updateHeapSort();
                
//     }
// function _updateHeapSort() internal  {
//     uint n = dishesWithOrder.length;
    
//     // Build heap (rearrange array)
//     for (int i = int(n / 2) - 1; i >= 0; i--) {
//         _updateHeapify(n, uint(i));
//     }
    
//     // Extract elements from heap one by one
//     for (uint i = n - 1; i > 0; i--) {
//         // Move current root to end
//         DishWithOrder memory temp = dishesWithOrder[0];
//         dishesWithOrder[0] = dishesWithOrder[i];
//         dishesWithOrder[i] = temp;
        
//         // Call max heapify on the reduced heap
//         _updateHeapify(i, 0);
//     }
// }

//     function _updateHeapify(uint n, uint i) internal  {
//         uint largest = i;
//         uint left = 2 * i + 1;
//         uint right = 2 * i + 2;
        
//         // If left child is larger than root
//         if (left < n && dishesWithOrder[left].orderNum > dishesWithOrder[largest].orderNum) {
//             largest = left;
//         }
        
//         // If right child is larger than largest so far
//         if (right < n && dishesWithOrder[right].orderNum > dishesWithOrder[largest].orderNum) {
//             largest = right;
//         }
        
//         // If largest is not root
//         if (largest != i) {
//             DishWithOrder memory temp = dishesWithOrder[i];
//             dishesWithOrder[i] = dishesWithOrder[largest];
//             dishesWithOrder[largest] = temp;
            
//             // Recursively heapify the affected sub-tree
//             _updateHeapify(n, largest);
//         }
//     }
//     function UpdateTopADish(string memory _dishCode) public {
//         uint dishCount = dishesWithOrder.length;
//         require(dishCount > 0, "No dishes");

//         // Tìm index của dish trong mảng
//         uint index = type(uint).max;
//         for (uint i = 0; i < dishCount; i++) {
//             if (
//                 keccak256(bytes(dishesWithOrder[i].dish.code)) == 
//                 keccak256(bytes(_dishCode))
//             ) {
//                 index = i;
//                 break;
//             }
//         }
//         require(index != type(uint).max, "Dish not found");

//         // Cập nhật orderNum và dữ liệu mới
//         bytes32[] memory variantIds = mDishVariant[_dishCode];
//         Variant memory variant = mVariant[_dishCode][variantIds[0]];
//         Attribute[] memory attributes = mVariantAttributes[_dishCode][variantIds[0]];

//         dishesWithOrder[index] = DishWithOrder({
//             dish: mCodeToDish[_dishCode],
//             orderNum: mCodeToDish[_dishCode].orderNum,
//             originalIndex: index,
//             variant: variant,
//             attributes: attributes
//         });

//         // Di chuyển lại phần tử để giữ mảng sorted (giảm dần orderNum)
//         _repositionDish(index);
//     }

//     function _repositionDish(uint index) internal {
//         uint n = dishesWithOrder.length;
//         if (n <= 1) return;

//         DishWithOrder memory updated = dishesWithOrder[index];

//         // Nếu orderNum mới lớn hơn -> dịch lên trên
//         while (index > 0 && dishesWithOrder[index - 1].orderNum < updated.orderNum) {
//             dishesWithOrder[index] = dishesWithOrder[index - 1];
//             index--;
//         }

//         // Nếu orderNum mới nhỏ hơn -> dịch xuống dưới
//         while (
//             index < n - 1 &&
//             dishesWithOrder[index + 1].orderNum > updated.orderNum
//         ) {
//             dishesWithOrder[index] = dishesWithOrder[index + 1];
//             index++;
//         }

//         // Đặt lại phần tử
//         dishesWithOrder[index] = updated;
//     }
//     function getDishInfo(
//         string memory _dishCode
//     ) public view returns (DishInfo memory productInfo) {
//         Dish memory dish = mCodeToDish[_dishCode];

//         bytes32[] memory variantIds = mDishVariant[_dishCode];
//         uint256 length = variantIds.length;

//         Variant[] memory variants = new Variant[](length);
//         Attribute[][] memory attributes = new Attribute[][](length);

//         for (uint256 i = 0; i < length; i++) {
//             bytes32 variantId = variantIds[i];
//             variants[i] = mVariant[_dishCode][variantId];
//             attributes[i] = mVariantAttributes[_dishCode][variantId];
//         }

//         productInfo = DishInfo({
//             dish: dish,
//             variants: variants,
//             attributes: attributes
//         });
//     }
//     function getAllDishInfo()
//         public
//         view
//         returns (DishInfo[] memory productsInfo)
//     {
//         uint256 length = allDishCodes.length;
//         productsInfo = new DishInfo[](length);

//         for (uint256 i = 0; i < length; i++) {
//             productsInfo[i] = getDishInfo(allDishCodes[i]);
//         }
//     }
//     function GetDish(
//         string memory _codeDish
//     )external view returns(Dish memory){
//         return mCodeToDish[_codeDish];
//     }
//     function GetDishes(
//         string memory _codeCategory
//     )external view returns(Dish[] memory){
//         return mCodeCatToDishes[_codeCategory];
//     }

//     function GetDishInfosByCat(
//         string memory _codeCategory,
//         uint offset,
//         uint limit
//     )external view returns(DishInfo[] memory productsInfo,uint totalCount){
//         uint256 length = mCodeCatToDishes[_codeCategory].length;
//         // require(offset < length, "offset out of range");
//         totalCount = length;
    
//         // Nếu offset >= length, trả về mảng rỗng
//         if (offset >= length) {
//             return (new DishInfo[](0), totalCount);
//         }
//         uint256 end = offset + limit;
//         if (end > length) {
//             end = length;
//         }

//         uint256 size = end - offset;
//         productsInfo = new DishInfo[](size);

//         for (uint256 i = 0; i < size; i++) {
//             productsInfo[i] = getDishInfo(mCodeCatToDishes[_codeCategory][offset +i].code);
//         }
//         //
//         // uint256 length = mCodeCatToDishes[_codeCategory].length;
//         // productsInfo = new DishInfo[](length);

//         // for (uint256 i = 0; i < length; i++) {
//         //     productsInfo[i] = getDishInfo(mCodeCatToDishes[_codeCategory][i].code);
//         // }
//         return (productsInfo,length);
//     }

//     function getVariant(
//         string memory _dishCode,
//         bytes32 _variantID
//     ) public view returns (Variant memory) {
//         return mVariant[_dishCode][_variantID];
//     }

//     function getProduct(
//         string memory _dishCode
//     ) public view returns (Dish memory) {
//         return mCodeToDish[_dishCode];
//     }
    
//     // Function for RestaurantOrder to get basic dish info
//     function GetDishBasic(string memory code) external view returns (string memory name,bool available, bool active,string memory imgUrl) {
//         Dish memory dish = mCodeToDish[code];
//         return (dish.name, dish.available, dish.active, dish.imgUrl);
//     }
    
//     // Function for RestaurantOrder to get basic discount info
//     function GetDiscountBasic(string memory code) external view returns (uint discountPercent, bool active, uint amountUsed, uint amountMax, uint from, uint to) {
//         Discount memory discount = mCodeToDiscount[code];
//         return (discount.discountPercent, discount.active, discount.amountUsed, discount.amountMax, discount.from, discount.to);
//     }
//     function UpdateOrderNum(
//         string memory _codeDish,
//         uint orderNumAdd
//     )external onlyOrder() {
//         require(orderNumAdd >0, "orderNum added can be zero");
//         require(
//             bytes(mCodeToDish[_codeDish].code).length > 0,
//             "can not find dish"
//         );
//         mCodeToDish[_codeDish].orderNum += orderNumAdd;
//     }
//     function UpdateDish(
//         string memory _codeCat,
//         string memory _codeDish,
//         string memory _nameCategory,
//         string memory _name,
//         string memory _des,
//         bool _available,
//         bool _active,
//         string memory _imgUrl,
//         uint _cookingTime,
//         bool _showIngredient,
//         string memory _videoLink,
//         VariantParams[] memory _variants,
//         string[] memory _ingredients
//     )external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) returns(bool){
//         require(bytes(_codeDish).length >0 && bytes(_codeCat).length >0,"dish code and category code can not be empty");
//         require(
//             bytes(mCodeToDish[_codeDish].code).length > 0,
//             "can not find dish"
//         );
//         // require(_variants.length > 0,"Invalid variants length");

//         Dish storage dish = mCodeToDish[_codeDish];
        
//         if (bytes(_codeCat).length >0){ dish.nameCategory = _nameCategory; }
//         if (bytes(_name).length >0){ dish.name = _name;}
//         if (bytes(_des).length >0){ dish.des = _des;}
//         // dish.price = _price;
//         dish.available = _available;
//         dish.active = _active;
//         if (bytes(_imgUrl).length >0){ dish.imgUrl = _imgUrl;}
//         // dish.size = _size;
//         dish.cookingTime = _cookingTime;
//         dish.showIngredient = _showIngredient;
//         if (bytes(_videoLink).length >0){ dish.videoLink = _videoLink;}
//         _updateDishFromCat(_codeCat,_codeDish);
//         if (_variants.length >0){ 
//             bytes32[] storage variantHashes = mDishVariant[_codeDish];
//             for (uint256 i = 0; i < variantHashes.length; i++) {
//                 delete mVariant[_codeDish][variantHashes[i]];
//                 delete mVariantAttributes[_codeDish][variantHashes[i]];
//             }
//             delete mDishVariant[_codeDish];
//             for (uint256 i = 0; i < _variants.length; i++) {
//                 Variant memory newVariant;
//                 bytes32 attributesHash = hashAttributes(_variants[i].attrs);
//                 newVariant.variantID = attributesHash;
//                 newVariant.dishPrice = _variants[i].price;
//                 mDishVariant[_codeDish].push(attributesHash);
//                 mVariant[_codeDish][attributesHash] = newVariant;

//                 for (uint256 j = 0; j < _variants[i].attrs.length; j++) {
//                     mVariantAttributes[_codeDish][attributesHash].push();
//                     mVariantAttributes[_codeDish][attributesHash][j] = _variants[i]
//                         .attrs[j];
//                 }

//                 for (uint256 k = 0; k < i; k++) {
//                     require(
//                         mDishVariant[_codeDish][k] != attributesHash,"Duplicate variant attributes detected"
//                     );
//                 }
//             }
//         }
//         if (_ingredients.length > 0){
//             delete dish.ingredients;  // Clear old ingredients first
//             for (uint256 i = 0; i < _ingredients.length; i++) {
//                 dish.ingredients.push(_ingredients[i]);
//             }        
//         }
//         return true;
//     }
//     function RemoveDish(
//         string memory _codeCategory,
//         string memory _dishCode
//     ) external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) {
//         require(bytes(_codeCategory).length > 0, "Invalid category code");
//         require(bytes(_dishCode).length > 0, "Invalid dish code");
//         require(isCodeExist[_dishCode], "Dish does not exist");
//         require(
//             bytes(mCodeToCat[_codeCategory].code).length > 0,
//             "Category code does not exist"
//         );

//         // Xoá dish khỏi danh sách trong category
//         Dish[] storage dishes = mCodeCatToDishes[_codeCategory];
//         for (uint256 i = 0; i < dishes.length; i++) {
//             if (
//                 keccak256(abi.encodePacked(dishes[i].code)) ==
//                 keccak256(abi.encodePacked(_dishCode))
//             ) {
//                 dishes[i] = dishes[dishes.length - 1];
//                 dishes.pop();
//                 break;
//             }
//         }

//         // Xoá variants liên quan
//         bytes32[] storage variants = mDishVariant[_dishCode];
//         for (uint256 i = 0; i < variants.length; i++) {
//             bytes32 variantID = variants[i];
//             // xoá attributes của variant
//             delete mVariantAttributes[_dishCode][variantID];
//             // xoá variant struct
//             delete mVariant[_dishCode][variantID];
//         }
//         delete mDishVariant[_dishCode];

//         // Xoá dish chính
//         delete mCodeToDish[_dishCode];
//         isCodeExist[_dishCode] = false;

//         // Xoá tracking
//         delete dishStartTime[_dishCode];
//         delete dishIsNew[_dishCode];

//         // Xoá khỏi allDishCodes
//         uint256 index = dishCodeIndex[_dishCode];
//         if (allDishCodes.length > 0 && index < allDishCodes.length) {
//             string memory lastCode = allDishCodes[allDishCodes.length - 1];
//             allDishCodes[index] = lastCode;
//             dishCodeIndex[lastCode] = index;
//             allDishCodes.pop();
//         }
//         delete dishCodeIndex[_dishCode];

//         emit DishRemoved(_dishCode, _codeCategory);
//     }

//     event DishRemoved(string dishCode, string categoryCode);

//     function updateAverageStarDish(uint8 _newStar, string memory _codeDish) external onlyOrder {
//         Dish storage dish = mCodeToDish[_codeDish];
//         dish.averageStar = (_newStar + dish.averageStar * dish.totalReview) / (dish.totalReview + 1);
//     } 
//     function _updateDishFromCat(
//         string memory _codeCat,
//         string memory _codeDish  
//     )internal{
//         Dish[] storage dishes = mCodeCatToDishes[_codeCat];
//         Dish storage dish = mCodeToDish[_codeDish];
//         require(dishes.length > 0,"no dish in this category found");
//         for(uint i; i < dishes.length; i++){
//             if(keccak256(abi.encodePacked(dishes[i].code)) == keccak256(abi.encodePacked(_codeDish))){
//                 dishes[i] = dish;
//                 break;
//             }
//         }
//     }
    
    
//     function UpdateDishStatus(
//         string memory _codeCat,
//         string memory _codeDish,
//         bool _available
//     ) external onlyAdminAndRole(STAFF_ROLE.UPDATE_STATUS_DISH) returns(bool) {
//         require(bytes(mCodeToDish[_codeDish].code).length != 0,"can not find dish");
//         mCodeToDish[_codeDish].available = _available;
//         _updateDishFromCat(_codeCat,_codeDish);
//         return true;
//     }

//     // Discount management
//     function CreateDiscount(
//         string memory _code,
//         string memory _name,
//         uint _discountPercent,
//         string memory _desc,
//         uint _from,
//         uint _to,
//         bool _active,
//         string memory _imgURL,
//         uint _amountMax
//     )external onlyRole(ROLE_ADMIN){
//         require(bytes(_code).length >0,"code of discount can not be empty");
//         require(bytes(mCodeToDiscount[_code].code).length == 0,"code of discount existed");
//         mCodeToDiscount[_code] = Discount({
//             code: _code ,
//             name: _name ,
//             discountPercent : _discountPercent,
//             desc : _desc,
//             from : _from,
//             to : _to,
//             active : _active,
//             imgURL : _imgURL,
//             amountMax : _amountMax,
//             amountUsed : 0,
//             updatedAt  : block.timestamp
//         });
//         discounts.push(mCodeToDiscount[_code]);
//     }
//     function RemoveDiscount(string memory _code)external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE){
//         for(uint i;i<discounts.length;i++){
//             if(keccak256(abi.encodePacked(discounts[i].code ))== keccak256(abi.encodePacked(_code))){
//                 discounts[i] = discounts[discounts.length-1];
//                 discounts.pop();
//             }
//         }
//         delete  mCodeToDiscount[_code];
//     }

//     function UpdateDiscount(
//         string memory _code,
//         string memory _name,
//         uint _discountPercent,
//         string memory _desc,
//         uint _from,
//         uint _to,
//         bool _active,
//         string memory _imgURL,
//         uint _amountMax
//     )external onlyRole(ROLE_ADMIN){
//         require(bytes(_code).length >0,"code of discount can not be empty");
//         require(bytes(mCodeToDiscount[_code].code).length > 0,"can not find any discount");
//         require(_amountMax > 0 && _discountPercent > 0 ,"maximum number and percent of discount can be zero" );
//         require(_discountPercent <= 100, "discount percent need to be less than 100");
//         require(_from >= block.timestamp && _to > block.timestamp,"time is not valid");
//         require(_amountMax >= mCodeToDiscount[_code].amountUsed , 
//                 "number of maximum can not be less than number discount used");
//         mCodeToDiscount[_code].name = _name;
//         mCodeToDiscount[_code].discountPercent = _discountPercent;
//         mCodeToDiscount[_code].desc = _desc;
//         mCodeToDiscount[_code].from = _from;
//         mCodeToDiscount[_code].to = _to;
//         mCodeToDiscount[_code].active = _active;
//         mCodeToDiscount[_code].imgURL = _imgURL;
//         mCodeToDiscount[_code].amountMax = _amountMax;
//         for(uint i;i<discounts.length;i++){
//             if(keccak256(abi.encodePacked(discounts[i].code ))== keccak256(abi.encodePacked(_code))){
//                 discounts[i] = mCodeToDiscount[_code];
//             }
//         }
//     }
//     function UpdateDiscountCodeUsed(string memory _code)external onlyOrder {
//         mCodeToDiscount[_code].amountUsed += 1;
//         for(uint i;i<discounts.length;i++){
//             if(keccak256(abi.encodePacked(discounts[i].code ))== keccak256(abi.encodePacked(_code))){
//                 discounts[i] = mCodeToDiscount[_code];
//                 break;
//             }
//         }
//         uint totalUsed = 0;
//         uint totalUnused = 0;
//         uint totalExpired = 0;

//         for (uint i = 0; i < discounts.length; i++) {
//             Discount memory discount = discounts[i];
//             if (discount.from >= block.timestamp && discount.to <= block.timestamp) {
//                 uint expired = 0;
//                 uint unused = 0;

//                 if (discount.to < block.timestamp) {
//                     expired = discount.amountMax - discount.amountUsed;
//                 } else {
//                     unused = discount.amountMax - discount.amountUsed;
//                 }

//                 totalUsed += discount.amountUsed;
//                 totalExpired += expired;
//                 totalUnused += unused;
//             }
//         }
//         VoucherUse memory voucherUse = VoucherUse({
//             time: block.timestamp,
//             amountUsed: totalUsed,
//             amountExpired: totalExpired,
//             amountUnused: totalUnused
//         });
//         voucherUseHistory.push(voucherUse);

//     }
//     function GetVoucherUseHistory(uint offset, uint limit) external view returns(VoucherUse[] memory voucherUseArr,uint totalCount){
//         uint256 length = voucherUseHistory.length;
//         // require(offset < length, "offset out of range");
//         totalCount = length;
//         // Nếu offset >= length, trả về mảng rỗng
//         if (offset >= length) {
//             return (new VoucherUse[](0), totalCount);
//         }
//         uint256 end = offset + limit;
//         if (end > length) {
//             end = length;
//         }

//         uint256 size = end - offset;
//         voucherUseArr = new VoucherUse[](size);

//         for (uint256 i = 0; i < size; i++) {
//             voucherUseArr[i] = voucherUseHistory[offset +i];
//         }
//         return (voucherUseArr,totalCount);
//     }
//     function GetDiscount(
//         string memory _code
//     )external view returns(Discount memory){
//         return mCodeToDiscount[_code];
//     }
    
//     function GetAllDiscounts()external view returns(Discount[] memory){
//         return discounts;
//     }


//     function GetVoucherReport(uint fromTime, uint toTime) external view returns (VoucherReport memory) {
//         uint totalUsed = 0;
//         uint totalUnused = 0;
//         uint totalExpired = 0;

//         // đếm số lượng voucher hợp lệ trước
//         uint count = 0;
//         for (uint i = 0; i < discounts.length; i++) {
//             if (discounts[i].from >= fromTime && discounts[i].to <= toTime) {
//                 count++;
//             }
//         }

//         VoucherDetail[] memory details = new VoucherDetail[](count);
//         uint index = 0;

//         for (uint i = 0; i < discounts.length; i++) {
//             Discount memory discount = discounts[i];
//             if (discount.from >= fromTime && discount.to <= toTime) {
//                 uint expired = 0;
//                 uint unused = 0;

//                 if (discount.to < block.timestamp) {
//                     expired = discount.amountMax - discount.amountUsed;
//                 } else {
//                     unused = discount.amountMax - discount.amountUsed;
//                 }

//                 details[index] = VoucherDetail({
//                     code: discount.code,
//                     name: discount.name,
//                     amountUsed: discount.amountUsed,
//                     amountExpired: expired,
//                     amountUnused: unused,
//                     amountMax: discount.amountMax
//                 });
//                 index++;

//                 totalUsed += discount.amountUsed;
//                 totalExpired += expired;
//                 totalUnused += unused;
//             }
//         }

//         return VoucherReport({
//             totalUsed: totalUsed,
//             totalUnused: totalUnused,
//             totalExpired: totalExpired,
//             details: details
//         });
//     }
// function GetTopDishesWithLimit(uint offset, uint limit) external returns (DishWithFirstPrice[] memory, uint totalCount) {
//     if (dishesWithOrder.length == 0){
//         UpdateTopDishLimited(50);
//     }
//     uint dishCount = allDishCodes.length;
//     totalCount = dishCount;
    
//     if (dishCount == 0 || offset >= dishCount) {
//         return (new DishWithFirstPrice[](0), totalCount);
//     }
    
//     // Tính toán số lượng thực tế cần lấy
//     uint remainingItems = dishCount - offset;
//     if (limit > remainingItems) {
//         limit = remainingItems;
//     }
//     if (limit == 0) {
//         return (new DishWithFirstPrice[](0), totalCount);
//     }
//      // Lấy kết quả từ offset
//     DishWithFirstPrice[] memory result = new DishWithFirstPrice[](limit);
//     for (uint i = 0; i < limit; i++) {
//         result[i] = DishWithFirstPrice({
//             dish: dishesWithOrder[offset + i].dish,
//             variant: dishesWithOrder[offset + i].variant,
//             attributes: dishesWithOrder[offset + i].attributes
//         });
//     }
    
//     return (result,totalCount);
// }

// // // Hàm phân trang đơn giản và đáng tin cậy
// // function GetTopDishesWithPagination(uint offset, uint limit) external view returns (DishWithFirstPrice[] memory, uint totalCount) {
// //     uint dishCount = allDishCodes.length;
// //     totalCount = dishCount;
    
// //     if (dishCount == 0 || offset >= dishCount) {
// //         return (new DishWithFirstPrice[](0), totalCount);
// //     }
    
// //     // Tính toán số lượng thực tế cần lấy
// //     uint remainingItems = dishCount - offset;
// //     if (limit > remainingItems) {
// //         limit = remainingItems;
// //     }
// //     if (limit == 0) {
// //         return (new DishWithFirstPrice[](0), totalCount);
// //     }
    
// //     // Sử dụng insertion sort đơn giản và đáng tin cậy
// //     return (_getTopDishesSimple(offset, limit), totalCount);
// // }
// // // Quick Sort - O(n log n) thay vì O(n²) của insertion sort
// // function _getTopDishesQuickSort(uint offset, uint limit) internal view returns (DishWithFirstPrice[] memory) {
// //     uint dishCount = allDishCodes.length;
    
// //     // Tạo mảng dishes với orderNum
// //     DishWithOrder[] memory dishesWithOrder = new DishWithOrder[](dishCount);
    
// //     for (uint i = 0; i < dishCount; i++) {
// //         string memory _dishCode = allDishCodes[i];
// //         bytes32[] memory variantIds = mDishVariant[_dishCode];
// //         Variant memory variant = mVariant[_dishCode][variantIds[0]];
// //         Attribute[] memory attributes = mVariantAttributes[_dishCode][variantIds[0]];

// //         dishesWithOrder[i] = DishWithOrder({
// //             dish: mCodeToDish[_dishCode],
// //             orderNum: mCodeToDish[_dishCode].orderNum,
// //             originalIndex: i,
// //             variant: variant,
// //             attributes: attributes
// //         });
// //     }
    
// //     // Quick sort
// //     _quickSort(dishesWithOrder, 0, int(dishCount - 1));
    
// //     // Lấy kết quả từ offset
// //     DishWithFirstPrice[] memory result = new DishWithFirstPrice[](limit);
    
// //     for (uint i = 0; i < limit; i++) {
// //         result[i] = DishWithFirstPrice({
// //             dish: dishesWithOrder[offset + i].dish,
// //             variant: dishesWithOrder[offset + i].variant,
// //             attributes: dishesWithOrder[offset + i].attributes
// //         });
// //     }
    
// //     return result;
// // }

// // function _quickSort(DishWithOrder[] memory arr, int low, int high) internal pure {
// //     if (low < high) {
// //         int pi = _partition(arr, low, high);
// //         _quickSort(arr, low, pi - 1);
// //         _quickSort(arr, pi + 1, high);
// //     }
// // }

// // function _partition(DishWithOrder[] memory arr, int low, int high) internal pure returns (int) {
// //     uint pivot = arr[uint(high)].orderNum;
// //     int i = low - 1;
    
// //     for (int j = low; j <= high - 1; j++) {
// //         if (arr[uint(j)].orderNum >= pivot) { // Giảm dần
// //             i++;
// //             _swap(arr, uint(i), uint(j));
// //         }
// //     }
// //     _swap(arr, uint(i + 1), uint(high));
// //     return i + 1;
// // }

// // function _swap(DishWithOrder[] memory arr, uint i, uint j) internal pure {
// //     DishWithOrder memory temp = arr[i];
// //     arr[i] = arr[j];
// //     arr[j] = temp;
// // }
// // // PHƯƠNG PHÁP 2: Sử dụng Partial Sort (chỉ sort phần cần thiết)
// // function _getTopDishesPartialSort(uint offset, uint limit) internal view returns (DishWithFirstPrice[] memory) {
// //     uint dishCount = allDishCodes.length;
// //     uint needSort = offset + limit; // Chỉ cần sort đến vị trí này
    
// //     if (needSort > dishCount) {
// //         needSort = dishCount;
// //     }
    
// //     // Tạo mảng dishes với orderNum
// //     DishWithOrder[] memory dishesWithOrder = new DishWithOrder[](dishCount);
    
// //     for (uint i = 0; i < dishCount; i++) {
// //         string memory _dishCode = allDishCodes[i];
// //         bytes32[] memory variantIds = mDishVariant[_dishCode];
// //         Variant memory variant = mVariant[_dishCode][variantIds[0]];
// //         Attribute[] memory attributes = mVariantAttributes[_dishCode][variantIds[0]];

// //         dishesWithOrder[i] = DishWithOrder({
// //             dish: mCodeToDish[_dishCode],
// //             orderNum: mCodeToDish[_dishCode].orderNum,
// //             originalIndex: i,
// //             variant: variant,
// //             attributes: attributes
// //         });
// //     }
    
// //     // Partial sort - chỉ sort needSort phần tử đầu
// //     _partialSort(dishesWithOrder, needSort);
    
// //     // Lấy kết quả từ offset
// //     DishWithFirstPrice[] memory result = new DishWithFirstPrice[](limit);
    
// //     for (uint i = 0; i < limit; i++) {
// //         result[i] = DishWithFirstPrice({
// //             dish: dishesWithOrder[offset + i].dish,
// //             variant: dishesWithOrder[offset + i].variant,
// //             attributes: dishesWithOrder[offset + i].attributes
// //         });
// //     }
    
// //     return result;
// // }
// // function _partialSort(DishWithOrder[] memory arr, uint k) internal pure {
// //     uint n = arr.length;
// //     if (k >= n) k = n;
    
// //     // Sử dụng selection sort cho k phần tử đầu
// //     for (uint i = 0; i < k; i++) {
// //         uint maxIdx = i;
// //         for (uint j = i + 1; j < n; j++) {
// //             if (arr[j].orderNum > arr[maxIdx].orderNum) {
// //                 maxIdx = j;
// //             }
// //         }
// //         if (maxIdx != i) {
// //             DishWithOrder memory temp = arr[i];
// //             arr[i] = arr[maxIdx];
// //             arr[maxIdx] = temp;
// //         }
// //     }
// // }

// // // PHƯƠNG PHÁP 3: Heap Sort (tốt nhất cho large dataset)
// // function _getTopDishesHeapSort(uint offset, uint limit) internal view returns (DishWithFirstPrice[] memory) {
// //     uint dishCount = allDishCodes.length;
    
// //     // Tạo mảng dishes với orderNum
// //     DishWithOrder[] memory dishesWithOrder = new DishWithOrder[](dishCount);
    
// //     for (uint i = 0; i < dishCount; i++) {
// //         string memory _dishCode = allDishCodes[i];
// //         bytes32[] memory variantIds = mDishVariant[_dishCode];
// //         Variant memory variant = mVariant[_dishCode][variantIds[0]];
// //         Attribute[] memory attributes = mVariantAttributes[_dishCode][variantIds[0]];

// //         dishesWithOrder[i] = DishWithOrder({
// //             dish: mCodeToDish[_dishCode],
// //             orderNum: mCodeToDish[_dishCode].orderNum,
// //             originalIndex: i,
// //             variant: variant,
// //             attributes: attributes
// //         });
// //     }
    
// //     // Heap sort
// //     _heapSort(dishesWithOrder);
    
// //     // Lấy kết quả từ offset
// //     DishWithFirstPrice[] memory result = new DishWithFirstPrice[](limit);
    
// //     for (uint i = 0; i < limit; i++) {
// //         result[i] = DishWithFirstPrice({
// //             dish: dishesWithOrder[offset + i].dish,
// //             variant: dishesWithOrder[offset + i].variant,
// //             attributes: dishesWithOrder[offset + i].attributes
// //         });
// //     }
    
// //     return result;
// // }

// // function _heapSort(DishWithOrder[] memory arr) internal pure {
// //     uint n = arr.length;
    
// //     // Build heap (rearrange array)
// //     for (int i = int(n / 2) - 1; i >= 0; i--) {
// //         _heapify(arr, n, uint(i));
// //     }
    
// //     // Extract elements from heap one by one
// //     for (uint i = n - 1; i > 0; i--) {
// //         // Move current root to end
// //         DishWithOrder memory temp = arr[0];
// //         arr[0] = arr[i];
// //         arr[i] = temp;
        
// //         // Call max heapify on the reduced heap
// //         _heapify(arr, i, 0);
// //     }
// // }

// // function _heapify(DishWithOrder[] memory arr, uint n, uint i) internal pure {
// //     uint largest = i;
// //     uint left = 2 * i + 1;
// //     uint right = 2 * i + 2;
    
// //     // If left child is larger than root
// //     if (left < n && arr[left].orderNum < arr[largest].orderNum) {
// //         largest = left;
// //     }
    
// //     // If right child is larger than largest so far
// //     if (right < n && arr[right].orderNum < arr[largest].orderNum) {
// //         largest = right;
// //     }
    
// //     // If largest is not root
// //     if (largest != i) {
// //         DishWithOrder memory temp = arr[i];
// //         arr[i] = arr[largest];
// //         arr[largest] = temp;
        
// //         // Recursively heapify the affected sub-tree
// //         _heapify(arr, n, largest);
// //     }
// // }
// // // Hàm đơn giản sử dụng insertion sort - đảm bảo chính xác
// // function _getTopDishesSimple(uint offset, uint limit) internal view returns (DishWithFirstPrice[] memory) {
// //     uint dishCount = allDishCodes.length;
    
// //     // Tạo mảng tất cả dishes với orderNum
// //     DishWithOrder[] memory dishesWithOrder = new DishWithOrder[](dishCount);
    
// //     for (uint i = 0; i < dishCount; i++) {
// //         string memory _dishCode = allDishCodes[i];
// //         bytes32[] memory variantIds = mDishVariant[_dishCode];
// //         Variant memory variant = mVariant[_dishCode][variantIds[0]];
// //         Attribute[] memory attributes = mVariantAttributes[_dishCode][variantIds[0]];

// //         dishesWithOrder[i] = DishWithOrder({
// //             dish: mCodeToDish[_dishCode],
// //             orderNum: mCodeToDish[_dishCode].orderNum,
// //             originalIndex: i,
// //             variant:variant,
// //             attributes:attributes
// //         });

// //     }
    
// //     // Insertion sort - sắp xếp giảm dần theo orderNum
// //     for (uint i = 1; i < dishCount; i++) {
// //         DishWithOrder memory key = dishesWithOrder[i];
// //         int j = int(i) - 1;
        
// //         // Di chuyển các phần tử có orderNum nhỏ hơn về phía sau
// //         while (j >= 0 && dishesWithOrder[uint(j)].orderNum < key.orderNum) {
// //             dishesWithOrder[uint(j + 1)] = dishesWithOrder[uint(j)];
// //             j--;
// //         }
// //         dishesWithOrder[uint(j + 1)] = key;
// //     }
    
// //     // Lấy kết quả từ offset
// //     DishWithFirstPrice[] memory result = new DishWithFirstPrice[](limit);
    
// //     for (uint i = 0; i < limit; i++) {

// //         DishWithFirstPrice memory dishWithFirstPrice = DishWithFirstPrice({
// //             dish: dishesWithOrder[offset + i].dish,
// //             variant: dishesWithOrder[offset + i].variant,
// //             attributes: dishesWithOrder[offset + i].attributes
// //         });
// //         result[i] = dishWithFirstPrice;
// //     }
    
// //     return result;
// // }

// // Struct helper để sort
// struct DishWithOrder {
//     Dish dish;
//     uint orderNum;
//     uint originalIndex;
//     Variant variant;
//     Attribute[] attributes;
// }
// struct DishWithFirstPrice{
//     Dish dish;
//     Variant variant;
//     Attribute[] attributes; 
// }

// // // Hàm backup sử dụng bubble sort nếu cần
// // function _getTopDishesBubbleSort(uint offset, uint limit) internal view returns (Dish[] memory) {
// //     uint dishCount = allDishCodes.length;
    
// //     // Tạo copy của indices
// //     uint[] memory indices = new uint[](dishCount);
// //     for (uint i = 0; i < dishCount; i++) {
// //         indices[i] = i;
// //     }
    
// //     // Bubble sort - sắp xếp indices theo orderNum giảm dần
// //     for (uint i = 0; i < dishCount - 1; i++) {
// //         for (uint j = 0; j < dishCount - i - 1; j++) {
// //             uint orderNum1 = mCodeToDish[allDishCodes[indices[j]]].orderNum;
// //             uint orderNum2 = mCodeToDish[allDishCodes[indices[j + 1]]].orderNum;
            
// //             if (orderNum1 < orderNum2) {
// //                 // Swap
// //                 uint temp = indices[j];
// //                 indices[j] = indices[j + 1];
// //                 indices[j + 1] = temp;
// //             }
// //         }
// //     }
    
// //     // Lấy kết quả từ offset
// //     Dish[] memory result = new Dish[](limit);
// //     for (uint i = 0; i < limit; i++) {
// //         result[i] = mCodeToDish[allDishCodes[indices[offset + i]]];
// //     }
    
// //     return result;
// // }

// // // Hàm kiểm tra kết quả - để debug
// // function GetTopDishesDebug(uint offset, uint limit) external view returns (
// //     DishWithFirstPrice[] memory dishes,
// //     uint[] memory orderNums,
// //     uint totalCount
// // ) {
// //     uint dishCount = allDishCodes.length;
// //     totalCount = dishCount;
    
// //     if (dishCount == 0 || offset >= dishCount) {
// //         return (new DishWithFirstPrice[](0), new uint[](0), totalCount);
// //     }
    
// //     uint remainingItems = dishCount - offset;
// //     if (limit > remainingItems) {
// //         limit = remainingItems;
// //     }
    
// //     dishes = _getTopDishesSimple(offset, limit);
// //     orderNums = new uint[](limit);
    
// //     for (uint i = 0; i < limit; i++) {
// //         orderNums[i] = dishes[i].orderNum;
// //     }
    
// //     return (dishes, orderNums, totalCount);
// // }



//     function GetRecentDishes(uint fromTime, uint limit) external view returns (string[] memory) {
//         uint count = 0;
        
//         // Count recent dishes first
//         for (uint i = 0; i < allDishCodes.length; i++) {
//             if (dishStartTime[allDishCodes[i]] >= fromTime) {
//                 count++;
//             }
//         }
        
//         if (count == 0) return new string[](0);
//         if (limit > count) limit = count;
        
//         string[] memory recentDishes = new string[](limit);
//         uint index = 0;
        
//         // Get recent dishes (newest first)
//         for (uint i = allDishCodes.length; i > 0 && index < limit; i--) {
//             if (dishStartTime[allDishCodes[i-1]] >= fromTime) {
//                 recentDishes[index] = allDishCodes[i-1];
//                 index++;
//             }
//         }
        
//         return recentDishes;
//     }

//     function GetVoucherStats() external view returns (uint totalUsed, uint totalMax, uint totalActive) {
//         uint used = 0;
//         uint maxAmount = 0;
//         uint active = 0;
        
//         for (uint i = 0; i < discounts.length; i++) {
//             used += discounts[i].amountUsed;
//             maxAmount += discounts[i].amountMax;
//             if (discounts[i].active) {
//                 active++;
//             }
//         }
//         return (used, maxAmount, active);
//     }

//     function GetAllDishCodes() external view returns (string[] memory) {
//         return allDishCodes;
//     }

//     function GetDishCount() external view returns (uint) {
//         return allDishCodes.length;
//     }

//     // Helper functions
//     function _getDay(uint timestamp) internal pure returns (uint) {
//         return timestamp / 86400;
//     }
    
//     function _getMonth(uint timestamp) internal pure returns (uint) {
//         return timestamp / (86400 * 30);
//     }

//     // // Admin functions for data management
//     // function ResetDishAsNew(string[] memory dishCodesArr) external onlyRole(ROLE_ADMIN) {
//     //     for (uint i = 0; i < dishCodesArr.length; i++) {
//     //         dishIsNew[dishCodesArr[i]] = false;
//     //     }
//     // }


//     function CreateDigitalMenu(
//         string memory _linkImg,
//         string memory _title
//     ) external onlyRole(ROLE_ADMIN){
//         uint256 newId = digitalMenu.length + 1;
//         digitalMenu.push(DigitalMenu(newId,_linkImg,_title));
//     }
//     function RemoveDigitalMenu(uint256 id) external onlyRole(ROLE_ADMIN) {
//         uint256 index = findDigitalMenuIndex(id);
//         require(index < digitalMenu.length, "Digital menu not found");
        
//         digitalMenu[index] = digitalMenu[digitalMenu.length-1];
//         digitalMenu.pop();
//     }
//     function getDigitalMenu() external view returns(DigitalMenu[] memory){
//         return digitalMenu;
//     }
//     function getADigitalMenu(uint256 id) external view returns(DigitalMenu memory) {
//         uint256 index = findDigitalMenuIndex(id);
//         require(index < digitalMenu.length, "Digital menu not found");
//         return digitalMenu[index];
//     }
//     function findDigitalMenuIndex(uint256 id) internal view returns(uint256) {
//         for (uint256 i = 0; i < digitalMenu.length; i++) {
//             if (digitalMenu[i].id == id) {
//                 return i;
//             }
//         }
//         return digitalMenu.length; // Return invalid index if not found
//     }
//     //Banner Management
//     function CreateBanner(
//         string memory _name,
//         string memory _linkImg,
//         string memory _description,
//         string memory _linkTo,
//         bool active,
//         uint from,
//         uint to
//     ) external onlyRole(ROLE_ADMIN) returns(uint256){
//         uint256 newId = banners.length + 1;
//         banners.push(Banner(newId,_name,_linkImg,_description,_linkTo,active,from, to));
//         return newId;
//     }
//     function RemoveBanner(uint256 id) external onlyRole(ROLE_ADMIN) {
//         uint256 index = findBannerIndex(id);
//         require(index < banners.length, "Banner not found");
        
//         banners[index] = banners[banners.length-1];
//         banners.pop();
//     }
//     function UpdateBanner(
//         string memory _name,
//         string memory _linkImg,
//         string memory _description,
//         string memory _linkTo,
//         bool _active,
//         uint _from,
//         uint _to,
//         uint256 id
//     ) external onlyRole(ROLE_ADMIN){
//         uint256 index = findBannerIndex(id);
//         require(index < banners.length, "Banner not found");
        
//         Banner storage banner = banners[index];
//         if (bytes(_name).length != 0) {
//             banner.name = _name;
//         }
//         if (bytes(_linkImg).length != 0) {
//             banner.linkImg = _linkImg;
//         }   
//         if (bytes(_description).length != 0) {
//             banner.description = _description;
//         }   
//         if (bytes(_linkTo).length != 0) {
//             banner.linkTo = _linkTo;
//         }
//         if(_from >0){
//             banner.from = _from;
//         }  
//         if(_to >0){
//             banner.to = _to;
//         }
//         banner.active = _active; 
//     }
//     function getBanners() external view returns(Banner[] memory){
//         return banners;
//     }
//     function getABanner(uint256 id) external view returns(Banner memory) {
//         uint256 index = findBannerIndex(id);
//         require(index < banners.length, "Banner not found");
//         return banners[index];
//     }

//     function findBannerIndex(uint256 id) internal view returns(uint256) {
//         for (uint256 i = 0; i < banners.length; i++) {
//             if (banners[i].id == id) {
//                 return i;
//             }
//         }
//         return banners.length; // Return invalid index if not found
//     }
//     //TC Management
//     function CreateTC(
//         string memory _title,
//         string memory _content,
//         TCStatus status
//     ) external onlyAdminAndRole(STAFF_ROLE.TC_MANAGE) returns(uint256) {
//         uint256 newId = tcs.length + 1;
//         // if (hasRole(ROLE_ADMIN, msg.sender)) {
//         //     tcs.push(TCInfo(newId, _title, _content, TCStatus.APPLIED));
//         // } else {
//         //     tcs.push(TCInfo(newId, _title, _content, TCStatus.WAITTING_APPLY));
//         // }
//         tcs.push(TCInfo(newId, _title, _content, status));

//         return newId;
//     }

//     function RemoveTC(uint256 id) external onlyAdminAndRole(STAFF_ROLE.TC_MANAGE) {
//         uint256 index = findTCIndex(id);
//         require(index < tcs.length, "TC not found");
        
//         tcs[index] = tcs[tcs.length - 1];
//         tcs.pop();
//     }

//     function UpdateTC(
//         string memory _title,
//         string memory _content,
//         TCStatus _status,        
//         uint256 id
//     ) external onlyAdminAndRole(STAFF_ROLE.TC_MANAGE) {
//         uint256 index = findTCIndex(id);
//         require(index < tcs.length, "TC not found");
        
//         TCInfo storage tc = tcs[index];
//         if (bytes(_title).length != 0) {
//             tc.title = _title;
//         }
//         if (bytes(_content).length != 0) {
//             tc.content = _content;
//         }  
//         if (tc.status != _status) {
//             tc.status = _status;
//         }
//     }

//     function getTcs() external view returns(TCInfo[] memory) {
//         return tcs;
//     }

//     function getATC(uint256 id) external view returns(TCInfo memory) {
//         uint256 index = findTCIndex(id);
//         require(index < tcs.length, "TC not found");
//         return tcs[index];
//     }

//     function findTCIndex(uint256 id) internal view returns(uint256) {
//         for (uint256 i = 0; i < tcs.length; i++) {
//             if (tcs[i].id == id) {
//                 return i;
//             }
//         }
//         return tcs.length; // Return invalid index if not found
//     }
//     //Worrking Shift Management
//     function CreateWorkingShift(
//         string memory _title,
//         uint256 from,   //số giây tính từ 0h ngày hôm đó. vd 08:00 là 8*3600=28800
//         uint256 to
//     ) external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) returns(uint256){
//         uint256 shiftId = workingShifts.length + 1;
//         workingShifts.push(WorkingShift(_title,from,to,shiftId));
//         return shiftId;
//     }
//     function RemoveWorkingShift(uint256 id) external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) {
//         uint256 index = findWorkingShiftIndex(id);
//         require(index < workingShifts.length, "Working shift not found");
        
//         workingShifts[index] = workingShifts[workingShifts.length - 1];
//         workingShifts.pop();
//     }

//     function UpdateWorkingShift(
//         string memory _title,
//         uint256 from,  
//         uint256 to,
//         uint256 id
//     ) external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) {
//         uint256 index = findWorkingShiftIndex(id);
//         require(index < workingShifts.length, "Working shift not found");
        
//         WorkingShift storage ws = workingShifts[index];
//         if (bytes(_title).length != 0) {
//             ws.title = _title;
//         }
//         if (from != 0) {
//             ws.from = from;
//         }
//         if (to != 0) {
//             ws.to = to;
//         }
//     }

//     function getWorkingShifts() external view returns(WorkingShift[] memory) {
//         return workingShifts;
//     }

//     function getAWorkingShift(uint256 id) external view returns(WorkingShift memory) {
//         uint256 index = findWorkingShiftIndex(id);
//         require(index < workingShifts.length, "Working shift not found");
//         return workingShifts[index];
//     }

//     function findWorkingShiftIndex(uint256 id) internal view returns(uint256) {
//         for (uint256 i = 0; i < workingShifts.length; i++) {
//             if (workingShifts[i].shiftId == id) {
//                 return i;
//             }
//         }
//         return workingShifts.length; // Return invalid index if not found
//     }

//     // Uniform Management
//     function CreateUniform(
//         string memory name,
//         string memory linkImgFront,
//         string memory linkImgBack
//     ) external onlyRole(ROLE_ADMIN) returns(uint256) {
//         uint256 newId = uniforms.length + 1;
//         uniforms.push(Uniform(newId, name, linkImgFront, linkImgBack));
//         return newId;
//     }

//     function UpdateUniform(
//         string memory name,
//         string memory linkImgFront,
//         string memory linkImgBack,
//         uint256 id
//     ) external onlyRole(ROLE_ADMIN) {
//         uint256 index = findUniformIndex(id);
//         require(index < uniforms.length, "Uniform not found");
        
//         Uniform storage u = uniforms[index];
//         if (bytes(name).length != 0) {
//             u.name = name;
//         }
//         if (bytes(linkImgFront).length != 0) {
//             u.linkImgFront = linkImgFront;
//         }
//         if (bytes(linkImgBack).length != 0) {
//             u.linkImgBack = linkImgBack;
//         }
//     }

//     function RemoveUniform(uint256 id) external onlyRole(ROLE_ADMIN) {
//         uint256 index = findUniformIndex(id);
//         require(index < uniforms.length, "Uniform not found");
        
//         uniforms[index] = uniforms[uniforms.length-1];
//         uniforms.pop();
//     }

//     function getUniforms() external view returns(Uniform[] memory) {
//         return uniforms;
//     }

//     function getAUniform(uint256 id) external view returns(Uniform memory) {
//         uint256 index = findUniformIndex(id);
//         require(index < uniforms.length, "Uniform not found");
//         return uniforms[index];
//     }

//     function findUniformIndex(uint256 id) internal view returns(uint256) {
//         for (uint256 i = 0; i < uniforms.length; i++) {
//             if (uniforms[i].id == id) {
//                 return i;
//             }
//         }
//         return uniforms.length; // Return invalid index if not found
//     }   
//      function setLinkGG(string memory _linkGG) external onlyRole(ROLE_ADMIN){
//         linkGG = _linkGG;
//     }
//     function _getRoleHash(STAFF_ROLE role) public view returns (bytes32) {
//         if (role == STAFF_ROLE.UPDATE_STATUS_DISH) {
//             return ROLE_HASH_STATUS_ORDER;
//         }
//         if (role == STAFF_ROLE.PAYMENT_CONFIRM) {
//             return ROLE_HASH_PAYMENT_CONFIRM;
//         }
//         if (role == STAFF_ROLE.TC_MANAGE) {
//             return ROLE_HASH_UPDATE_TC;
//         }
//         if (role == STAFF_ROLE.TABLE_MANAGE) {
//             return ROLE_HASH_TABLE_MANAGE;
//         }
//         if (role == STAFF_ROLE.MENU_MANAGE) {
//             return ROLE_HASH_MENU_MANAGE;
//         }
//         if (role == STAFF_ROLE.STAFF_MANAGE) {
//             return ROLE_HASH_STAFF_MANAGE;
//         }
//         revert(
//             '{"from": "Mananagement.sol","msg": "Position id invalid"}'
//         );
//     }
//     //Position
//     function CreatePosition(string memory _name, STAFF_ROLE[] memory _roles)external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE){
//         require(bytes(_name).length != 0,"name is empty");
//         require(_roles.length > 0,"roles is empty");
//         require(bytes(mPosition[_name].name).length == 0,"position existed");
//         mPosition[_name].id = positions.length + 1;
//         mPosition[_name].name = _name;
//         mPosition[_name].positionRoles = _roles;
//         positions.push(mPosition[_name]);
//     }

//     // Hàm lấy thông tin position theo tên
//     function GetPosition(string memory _name) 
//         external 
//         view 
//         returns (uint256 id, string memory name, STAFF_ROLE[] memory positionRoles) 
//     {
//         require(bytes(_name).length > 0, "name is empty");
//         require(bytes(mPosition[_name].name).length > 0, "position not found");
        
//         Position memory pos = mPosition[_name];
//         return (pos.id, pos.name, pos.positionRoles);
//     }

//     // Hàm lấy thông tin position theo ID
//     function GetPositionById(uint256 _id) 
//         external 
//         view 
//         returns (uint256 id, string memory name, STAFF_ROLE[] memory positionRoles) 
//     {
//         require(_id > 0 && _id <= positions.length, "invalid position id");
        
//         Position memory pos = positions[_id - 1]; // vì id bắt đầu từ 1
//         return (pos.id, pos.name, pos.positionRoles);
//     }

//     // Hàm lấy tất cả positions
//     function GetAllPositions() 
//         external 
//         view 
//         returns (Position[] memory) 
//     {
//         return positions;
//     }

//     // Hàm kiểm tra position có tồn tại không
//     function PositionExists(string memory _name) 
//         external 
//         view 
//         returns (bool) 
//     {
//         return bytes(mPosition[_name].name).length > 0;
//     }

//     // Hàm xóa position theo tên
//     function RemovePosition(string memory _name) 
//         external 
//         onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) 
//     {
//         require(bytes(_name).length > 0, "name is empty");
//         require(bytes(mPosition[_name].name).length > 0, "position not found");
        
//         uint256 positionId = mPosition[_name].id;
        
//         // Xóa khỏi mapping
//         delete mPosition[_name];
        
//         // Tìm và xóa khỏi array positions
//         for (uint256 i = 0; i < positions.length; i++) {
//             if (positions[i].id == positionId) {
//                 // Di chuyển phần tử cuối lên vị trí cần xóa
//                 positions[i] = positions[positions.length - 1];
//                 positions.pop();
//                 break;
//             }
//         }
        
//     }

//     // Hàm xóa position theo ID
//     function RemovePositionById(uint256 _id) 
//         external 
//         onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) 
//     {
//         require(_id > 0 && _id <= positions.length, "invalid position id");
        
//         // Tìm position theo ID để lấy tên
//         string memory positionName;
//         for (uint256 i = 0; i < positions.length; i++) {
//             if (positions[i].id == _id) {
//                 positionName = positions[i].name;
                
//                 // Xóa khỏi mapping
//                 delete mPosition[positionName];
                
//                 // Di chuyển phần tử cuối lên vị trí cần xóa
//                 positions[i] = positions[positions.length - 1];
//                 positions.pop();
//                 break;
//             }
//         }
        
//     }

//     // Hàm cập nhật position (bonus)
//     function UpdatePosition(string memory _name, STAFF_ROLE[] memory _newRoles) 
//         external 
//         onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) 
//     {
//         require(bytes(_name).length > 0, "name is empty");
//         require(_newRoles.length > 0, "roles is empty");
//         require(bytes(mPosition[_name].name).length > 0, "position not found");
        
//         // Cập nhật roles trong mapping
//         mPosition[_name].positionRoles = _newRoles;
        
//         // Cập nhật trong array
//         for (uint256 i = 0; i < positions.length; i++) {
//             if (positions[i].id == mPosition[_name].id) {
//                 positions[i].positionRoles = _newRoles;
//                 break;
//             }
//         }
        
//     }
//     // Hàm public để kiểm tra role có được phép cho position không
//     function IsRoleAllowedForPosition(string memory _position, STAFF_ROLE _role) 
//         external 
//         view 
//         returns (bool) 
//     {
//         require(bytes(mPosition[_position].name).length > 0, "position not found");
        
//         STAFF_ROLE[] memory positionRoles = mPosition[_position].positionRoles;
        
//         for (uint i = 0; i < positionRoles.length; i++) {
//             if (positionRoles[i] == _role) {
//                 return true;
//             }
//         }
//         return false;
//     }
// }