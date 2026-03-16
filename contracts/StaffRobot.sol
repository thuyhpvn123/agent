// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.20;
// import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "./interfaces/IReport.sol";
// import "./interfaces/IRestaurant.sol";
// import "./interfaces/ITimeKeeping.sol";
// import "./interfaces/IAgent.sol";
// import "./interfaces/IPoint.sol";
// import "forge-std/console.sol";
// import "./interfaces/IHistoryTracking.sol";

// contract StaffRobot is    
   
//     Initializable, 
//     OwnableUpgradeable, 
//     AccessControlUpgradeable,
//     UUPSUpgradeable    
// {
//     bytes32 public ROLE_ADMIN ;
//     bytes32 public ROLE_STAFF ;
//     bytes32 public ROLE_HASH_FINANCE_MANAGE;

//     // Restaurant Info
//     RestaurantInfo public restaurantInfo;
    
//     mapping(address => Staff) public mAddToStaff;
//     Staff[] public staffs;

//     // Historical data
//     WorkingShift[] public workingShifts;
//     // Track staff activity by date (timestamp in days since epoch)
//     mapping(uint => address[]) public dailyActiveStaff;
//     mapping(uint => mapping(address => bool)) public isDailyActive;

//     // Track staff activity by month (timestamp in months since epoch)  
//     mapping(uint => address[]) public monthlyActiveStaff;
//     mapping(uint => mapping(address => bool)) public isMonthlyActive;

//     // Track when staff was created/updated for historical data
//     mapping(address => uint) public staffCreatedDate;
//     mapping(address => uint) public staffLastActiveDate;
//     address public timeKeeping ;
//     mapping(string => Position) public mPosition;
//     Position[] public positions;
//     address public agent;
//     IStaffAgentStore public staffAgentStore;
//     IPoint public POINTS;
//     bool public active;
//     address public agentRobotSC;
//     address public branchManagement;
//     uint public branchId;
//     IHistoryTracking public historyTracking;

//     uint256[49] private __gap;

//     constructor() {
//         _disableInitializers();
//     }
//     modifier onlyBranchManager{
//         require(msg.sender == branchManagement,"only branchManagement can call");
//         _;
//     }
//     modifier onlyAdminAndRole(STAFF_ROLE role){
//         require(
//             checkRole(role,msg.sender),
//             "Access denied: missing role"
//         );
//         _;
//     }

//     modifier isActive{
//         require(active,"Contract is deactivated");
//         _;
//     }
//     function setBranchManagement(address _branchManagement) external {
//         require(msg.sender == agentRobotSC,"only agentRobotSC can call");
//         branchManagement = _branchManagement;
//     }
//     function setActive(bool _active) external  {
//         require(msg.sender == agentRobotSC,"only agentRobotSC can call");
//         active = _active;
//     }
//     function setStaffAgentStore(address _staffAgentSC)external onlyRole(ROLE_ADMIN){
//         staffAgentStore = IStaffAgentStore(_staffAgentSC);
//     }
//     function setAgentAdd(address _agent,uint _branchId) external onlyRole(ROLE_ADMIN){
//         agent = _agent;
//         branchId = _branchId;
//     }
//     function setTimeKeeping(address _timeKeeping) external onlyRole(ROLE_ADMIN) {
//         timeKeeping = _timeKeeping;
//     }
//     function setPoints(address _points) external {
//         POINTS = IPoint(_points);
//     }
//     function setAgentRobotSC(address _agentRobotSC) external onlyRole(ROLE_ADMIN) {
//         agentRobotSC = _agentRobotSC;
//     }
//     function checkRole(STAFF_ROLE role,address user)public view returns(bool rightRole){
//         if(hasRole(ROLE_ADMIN, user) || hasRole(_getRoleHash(role), user) || user == timeKeeping){
//             return true;
//         }
//     } 
//     function setHistoryTracking(address _historyTracking) external  {
//         require(_historyTracking != address(0), "Invalid address");
//         historyTracking = IHistoryTracking(_historyTracking);
//     }

//     function _authorizeUpgrade(address newImplementation) internal override {}

//     function initialize() public initializer {
//         __Ownable_init(msg.sender);
//         __AccessControl_init();
//         __UUPSUpgradeable_init();

//         ROLE_ADMIN = keccak256("ROLE_ADMIN");
//         ROLE_STAFF = keccak256("ROLE_STAFF");
//         ROLE_HASH_FINANCE_MANAGE = keccak256("ROLE_HASH_FINANCE");
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         _grantRole(ROLE_ADMIN, msg.sender);
        
//         active = true;
//     }

//     function setRoleForCoOwner(address _coOwner)external onlyBranchManager{
//         _grantRole(ROLE_ADMIN,_coOwner); 
//     }
//     function CreateStaff(
//         Staff memory staff
//     )external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) isActive {
//         require(staff.wallet != address(0),"wallet of staff is wrong");
//         require(mAddToStaff[staff.wallet].wallet == address(0),"wallet existed");
//         require(bytes(staff.position).length > 0, "position is empty");
//         require(bytes(mPosition[staff.position].name).length > 0, "position not found");
//         require(staff.roles.length > 0, "staff roles is empty");

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
//         if(address(staffAgentStore) != address(0) && agent != address(0)){
//             staffAgentStore.setAgent(staff.wallet,agent,branchId);

//         }
//         if (address(historyTracking) != address(0)) {
//             historyTracking.recordStaffCreate(
//                 staff.wallet,
//                 mAddToStaff[staff.wallet],
//                 "Create Staff"
//             );
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
//         if (_role == STAFF_ROLE.FINANCE) return "FINANCE";
//         return "UNKNOWN";
//     }  
//     function isStaff(address account) external view returns (bool) {
//         return hasRole(ROLE_STAFF, account);
//     }

//     function removeStaff(address wallet) external isActive onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) {
//     require(mAddToStaff[wallet].wallet != address(0), "Staff not found");
//     require(mAddToStaff[wallet].active, "Staff already inactive");
//     if (address(historyTracking) != address(0)) {
//         historyTracking.recordStaffDelete(
//             wallet,
//             mAddToStaff[wallet],
//             "Staff removed"
//         );
//     }
    
//     // Lưu lại roles trước khi xóa
//     STAFF_ROLE[] memory staffRoles = mAddToStaff[wallet].roles;
    
//     // Đánh dấu inactive
//     delete mAddToStaff[wallet];
//     // mAddToStaff[wallet].active = false;
    
//     // Xóa khỏi array
//     for(uint i = 0; i < staffs.length; i++){
//         if(wallet == staffs[i].wallet){
//             staffs[i] = staffs[staffs.length - 1];
//             staffs.pop();  // ✅ THÊM () ĐÂY
//             break;
//         }
//     }
    
//     // Revoke ROLE_STAFF chính
//     _revokeRole(ROLE_STAFF, wallet);
    
//     // ✅ THÊM: Revoke tất cả các role cụ thể của staff
//     for (uint idx = 0; idx < staffRoles.length; idx++) {
//         bytes32 roleHash = _getRoleHash(staffRoles[idx]);
//         _revokeRole(roleHash, wallet);
//     }
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
//     )external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) isActive returns(bool){
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
//         if (address(historyTracking) != address(0)) {
//         historyTracking.recordStaffUpdate(
//             _wallet,
//             mAddToStaff[_wallet],
//             "Staff info updated"
//         );
//     }
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
//     function GetStaffInfo(address _wallet)external view isActive returns(Staff memory){
//         require(
//             checkRole(STAFF_ROLE.STAFF_MANAGE,msg.sender) ,
//             "Access denied: missing role"
//         );
//         return mAddToStaff[_wallet];
//     }
//     function GetStaff()external view returns(Staff memory){
//         return mAddToStaff[msg.sender];
//     }
//     function GetAllStaff()
//         external
//         view
//         returns (Staff[] memory)
//     {
//         return staffs;
//     }
//     function GetStaffsPagination(uint256 offset, uint256 limit)
//         external
//         view
//         returns (Staff[] memory result,uint totalCount)
//     {
//         if(offset >= staffs.length) {
//             return ( new Staff[](0),staffs.length);
//         }

//         uint256 end = offset + limit;
//         if (end > staffs.length) {
//             end = staffs.length;
//         }

//         uint256 size = end - offset;
//         result = new Staff[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = staffs.length - 1 - offset - i;
//             result[i] = staffs[reverseIndex];
//         }

//         return (result,staffs.length);
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
    

//     // Helper functions
//     function _getDay(uint timestamp) internal pure returns (uint) {
//         return timestamp / 86400;
//     }
    
//     function _getMonth(uint timestamp) internal pure returns (uint) {
//         return timestamp / (86400 * 30);
//     }

//     //Worrking Shift Management
//     function CreateWorkingShift(
//         string memory _title,
//         uint256 from,   //số giây tính từ 0h ngày hôm đó. vd 08:00 là 8*3600=28800
//         uint256 to
//     ) external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) isActive returns(uint256){
//         uint256 shiftId = workingShifts.length + 1;
//         workingShifts.push(WorkingShift(_title,from,to,shiftId));
//         return shiftId;
//     }
//     function RemoveWorkingShift(uint256 id) external isActive onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) {
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
//     ) external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) isActive {
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
//     function GetWorkingShiftsPagination(uint256 offset, uint256 limit)
//         external
//         view
//         returns (WorkingShift[] memory result,uint totalCount)
//     {
//         if(offset >= workingShifts.length) {
//             return ( new WorkingShift[](0),workingShifts.length);
//         }

//         uint256 end = offset + limit;
//         if (end > workingShifts.length) {
//             end = workingShifts.length;
//         }

//         uint256 size = end - offset;
//         result = new WorkingShift[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = workingShifts.length - 1 - offset - i;
//             result[i] = workingShifts[reverseIndex];
//         }

//         return (result,workingShifts.length);
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

//     function _getRoleHash(STAFF_ROLE role) public view returns (bytes32) {

//         if (role == STAFF_ROLE.FINANCE) {
//             return ROLE_HASH_FINANCE_MANAGE;
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