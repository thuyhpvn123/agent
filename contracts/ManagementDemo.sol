// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IReport.sol";
import "./interfaces/IRestaurant.sol";
import "./interfaces/ITimeKeeping.sol";
import "./interfaces/IAgent.sol";
import "./interfaces/IPoint.sol";
// import "forge-std/console.sol";
import "./interfaces/IHistoryTracking.sol";
import "./loyaltyDB.sol";
// import "./FullDB.sol";
contract Management is    
   
    Initializable, 
    OwnableUpgradeable, 
    AccessControlUpgradeable
    // UUPSUpgradeable    
{
    bytes32 public ROLE_ADMIN ;
    bytes32 public ROLE_STAFF ;
    bytes32 public ROLE_HASH_STATUS_ORDER;
    bytes32 public ROLE_HASH_PAYMENT_CONFIRM;
    bytes32 public ROLE_HASH_UPDATE_TC;
    bytes32 public ROLE_HASH_TABLE_MANAGE;
    bytes32 public ROLE_HASH_MENU_MANAGE;
    bytes32 public ROLE_HASH_FINANCE;
    bytes32 public ROLE_HASH_ACCOUNT_MANAGE;
    bytes32 public ROLE_HASH_PC_MANAGE;
    
    // Restaurant Info
    RestaurantInfo public restaurantInfo;
    address public restaurantOrder;
    
    mapping(address => Staff) public mAddToStaff;
    Staff[] public staffs;
    mapping(uint => Table) public mNumberToTable;
    Table[] public tables;
    mapping(string => Category) public mCodeToCat;
    Category[]public categories;
    mapping(string => Dish) public mCodeToDish;
    mapping(string => Dish[]) public mCodeCatToDishes;
    mapping(string => Discount) public mCodeToDiscount;
    Discount[] public discounts;
    mapping(string => bool) public isCodeExist;
    // mapping(string => uint) public mDishRemain;
    mapping(string => bytes32[]) public mDishVariant; // dishcode => variants
    mapping(string => mapping(bytes32 => Variant)) public mVariant;
    mapping(string => mapping(bytes32 => Attribute[])) public mVariantAttributes; // dishcode => variantID => attribute

    mapping(bytes32 => Attribute) public mAttribute;
    mapping(string => bytes32[]) public mCategoryAttributes;
    // uint256 public productID;
    string[] public allDishCodes;
    mapping(string => uint) public dishCodeIndex;  
    
    mapping(string => bool) public dishIsNew;
    mapping(string => uint) public dishTotalRevenue;
    mapping(string => uint) public dishTotalOrders;
    mapping(string => uint) public dishStartTime;

    // Top dishes tracking
    
    // Historical data
    uint public serviceStartTime;
    DigitalMenu[] public digitalMenu;
    Banner[] public banners;
    TCInfo[] public tcs;
    WorkingShift[] public workingShifts;
    Uniform[] public uniforms;
    string public linkGG;
    // Track staff activity by date (timestamp in days since epoch)
    mapping(uint => address[]) public dailyActiveStaff;
    mapping(uint => mapping(address => bool)) public isDailyActive;

    // Track staff activity by month (timestamp in months since epoch)  
    mapping(uint => address[]) public monthlyActiveStaff;
    mapping(uint => mapping(address => bool)) public isMonthlyActive;

    // Track when staff was created/updated for historical data
    mapping(address => uint) public staffCreatedDate;
    mapping(address => uint) public staffLastActiveDate;
    DishWithOrder[] public dishesWithOrder;
    address public timeKeeping ;
    bytes32 public  ROLE_HASH_STAFF_MANAGE = keccak256("ROLE_HASH_STAFF_MANAGE");
    mapping(string => Position) public mPosition;
    Position[] public positions;
    VoucherUse[] public voucherUseHistory;
    ChartTotalCustomers[] public totalCustomersDays;
    ChartTotalRevenue[] public totalRevenueDays;
    
    mapping(uint => mapping(string => bool)) public mDayToDishCode;
    mapping(uint => mapping(string => bool)) public mMonthToDishCode; 
    mapping(uint =>string[]) public mMonthToDishCodeOrder;
    mapping(uint =>string[]) public mDayToDishCodeOrder;
    address public report;
    mapping(string =>RankReport[]) public mDishCodeToRankReport;
    mapping(string => uint) public dishOrderIndex;
    mapping(uint => Table[]) public mAreaToTable; //area id => table 
    mapping(uint => Area) public mIdToArea;
    Area[] public areas;
    mapping(uint => uint) public mTableToAreaId;
    address public agent;
    IStaffAgentStore public staffAgentStore;
    IPoint public POINTS;
    mapping(string => mapping(address => bool)) public voucherRedeemed; // code => user => đã redeem chưa
    mapping(string => uint)mDishRemain;
    // Reserve storage for upgradeability
    mapping(bytes32 => DishOption) public mIdToOption;
    mapping(string =>mapping(string => bytes32[])) public mDishCodeToFeatureIds; //dishCode -> optionName -> mang feature ids
    mapping(string => string[]) public mDishCodeToOptionNames;
    mapping(string => DishOption[]) public mDishCodeToOptions;
    mapping(bytes32 => string[]) public mOptionIdToDishCodes;
    DishOption[] public allDishOptions;
    string[] public allOptionNames;
    mapping(string => bool) public isOptionNameExist;
    bool public active;
    address public agentIQRSC;
    address public branchManagement;
    ChartTotalOrder[] public totalOrderDays;
    uint public branchId;
    IHistoryTracking public historyTracking;

    // Added 06/01/2026
    PublicfullDB public dbWrapper;
    string private constant DB_NAME = "CustomerDB";



    // emit thông báo cập nhật sản phẩm
    event ProductPriceUpdated(address indexed updater, string dishCode, bytes32 variantID, uint256 newPrice, uint256 timestamp);
    uint256[44] private __gap;

    // constructor() {
    //     _disableInitializers();
    // }
    modifier onlyBranchManager{
        require(msg.sender == branchManagement,"only branchManagement can call");
        _;
    }
    modifier onlyAdminAndRole(STAFF_ROLE role){
        require(
            checkRole(role,msg.sender),
            "Access denied: missing role"
        );
        _;
    }
    modifier onlyOrder{
        require(msg.sender == restaurantOrder,"only restaurantOrder can call");
        _;
    }
    modifier isActive{
        require(active,"Contract is deactivated");
        _;
    }
    function setBranchManagement(address _branchManagement) external {
        require(msg.sender == agentIQRSC,"only agentIQRSC can call");
        branchManagement = _branchManagement;
    }
    function setActive(bool _active) external  {
        require(msg.sender == agentIQRSC,"only agentIQRSC can call");
        active = _active;
    }
    function setStaffAgentStore(address _staffAgentSC)external onlyRole(ROLE_ADMIN){
        staffAgentStore = IStaffAgentStore(_staffAgentSC);
    }
    function setAgentAdd(address _agent,uint _branchId) external onlyRole(ROLE_ADMIN){
        agent = _agent;
        branchId = _branchId;
    }
    function setTimeKeeping(address _timeKeeping) external onlyRole(ROLE_ADMIN) {
        timeKeeping = _timeKeeping;
    }
    function setPoints(address _points) external {
        POINTS = IPoint(_points);
    }
    function setAgentIqrSC(address _agentIQRSC) external onlyRole(ROLE_ADMIN) {
        
        agentIQRSC = _agentIQRSC;
    }
    function getPoints() external view returns(address){
        return address(POINTS);
    }
    function checkRole(STAFF_ROLE role,address user)public view returns(bool rightRole){
        if(hasRole(ROLE_ADMIN, user) || hasRole(_getRoleHash(role), user) || user == timeKeeping){
            return true;
        }
    } 
    function getUserRoleSummary(address user) external view returns (UserRoleSummary memory r) {
        r.isAdmin = hasRole(ROLE_ADMIN, user);
        r.isStaff = hasRole(ROLE_STAFF, user);
        r.isUpdateStatusDish = hasRole(_getRoleHash(STAFF_ROLE.UPDATE_STATUS_DISH), user);
        r.isPaymentConfirm   = hasRole(_getRoleHash(STAFF_ROLE.PAYMENT_CONFIRM), user);
        r.isTcManage         = hasRole(_getRoleHash(STAFF_ROLE.TC_MANAGE), user);
        r.isTableManage      = hasRole(_getRoleHash(STAFF_ROLE.TABLE_MANAGE), user);
        r.isMenuManage       = hasRole(_getRoleHash(STAFF_ROLE.MENU_MANAGE), user);
        r.isStaffManage      = hasRole(_getRoleHash(STAFF_ROLE.STAFF_MANAGE), user);
        r.isFinance          = hasRole(_getRoleHash(STAFF_ROLE.FINANCE), user);
        r.isAccountManage    = hasRole(_getRoleHash(STAFF_ROLE.ACCOUNT_MANAGE), user);
        r.isPcManage         = hasRole(_getRoleHash(STAFF_ROLE.PC_MANAGE), user);

    }
    function getMyRoleSummary() external view returns (UserRoleSummary memory) {
        return this.getUserRoleSummary(msg.sender);
    }
    function setHistoryTracking(address _historyTracking) external  {
        require(_historyTracking != address(0), "Invalid address");
        historyTracking = IHistoryTracking(_historyTracking);
    }

    // function _authorizeUpgrade(address newImplementation) internal override {}

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __AccessControl_init();
        // __UUPSUpgradeable_init();

        ROLE_ADMIN = keccak256("ROLE_ADMIN");
        ROLE_STAFF = keccak256("ROLE_STAFF");
        ROLE_HASH_STATUS_ORDER = keccak256("ROLE_HASH_STATUS_ORDER");
        ROLE_HASH_PAYMENT_CONFIRM = keccak256("ROLE_HASH_PAYMENT_CONFIRM");
        ROLE_HASH_UPDATE_TC = keccak256("ROLE_HASH_UPDATE_TC");
        ROLE_HASH_TABLE_MANAGE = keccak256("ROLE_HASH_TABLE_MANAGE");
        ROLE_HASH_MENU_MANAGE = keccak256("ROLE_HASH_MENU_MANAGE");
        ROLE_HASH_STAFF_MANAGE = keccak256("ROLE_HASH_STAFF_MANAGE");
        ROLE_HASH_FINANCE = keccak256("ROLE_HASH_FINANCE");
        ROLE_HASH_ACCOUNT_MANAGE = keccak256("ROLE_HASH_ACCOUNT_MANAGE");
        ROLE_HASH_PC_MANAGE = keccak256("ROLE_HASH_PC_MANAGE");
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ROLE_ADMIN, msg.sender);
        
        serviceStartTime = block.timestamp;
        // restaurantOrder = _restaurantOrder;
        active = true;
    }
    function setServiceStartTime(uint _serviceStartTime) external onlyRole(ROLE_ADMIN) {
        serviceStartTime = _serviceStartTime;
    }
    function setRestaurantOrder(address _restaurantOrder) external onlyRole(ROLE_ADMIN) {
        restaurantOrder = _restaurantOrder;
    }
    function setReport(address _report) external onlyRole(ROLE_ADMIN) {
        report = _report;
    }

    // Restaurant Info Management
    function RegisterRestaurantInfo(
        string memory _name,
        string memory _addr,
        string memory _phone,
        string memory _visaInfo,
        address _walletAddress,
        uint _workPlaceId,
        string memory _imgLink
    ) external onlyRole(ROLE_ADMIN) isActive {
        ITimeKeeping(timeKeeping).getWorkPlaceById(_workPlaceId);
        restaurantInfo = RestaurantInfo({
            name: _name,
            addr: _addr,
            phone: _phone,
            visaInfo: _visaInfo,
            walletAddress: _walletAddress,
            workPlaceId: _workPlaceId,
            imgLink: _imgLink,
            registeredAt: block.timestamp,
            updatedAt: block.timestamp
        });
    }

    function GetRestaurantInfo() external view returns (RestaurantInfo memory) {
        return restaurantInfo;
    }

    function UpdateRestaurantInfo(
        string memory _name,
        string memory _addr,
        string memory _phone,
        string memory _visaInfo,
        address _walletAddress,
        string memory _imgLink,
        uint _workPlaceId
    ) external onlyRole(ROLE_ADMIN) isActive {
        restaurantInfo.name = _name;
        restaurantInfo.addr = _addr;
        restaurantInfo.phone = _phone;
        restaurantInfo.visaInfo = _visaInfo;
        restaurantInfo.imgLink = _imgLink;
        restaurantInfo.workPlaceId = _workPlaceId;
        restaurantInfo.walletAddress = _walletAddress;
        restaurantInfo.updatedAt = block.timestamp;
    }
    function setRoleForCoOwner(address _coOwner)external onlyBranchManager{
        _grantRole(ROLE_ADMIN,_coOwner); 
    }
    function CreateStaff(
        Staff memory staff
    ) external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) isActive returns (string memory) {

        require(staff.wallet != address(0),"wallet of staff is wrong");
        require(mAddToStaff[staff.wallet].wallet == address(0),"wallet existed");
        require(bytes(staff.position).length > 0, "position is empty");
        require(bytes(mPosition[staff.position].name).length > 0, "position not found");
        require(staff.roles.length > 0, "staff roles is empty");
        require(address(staffAgentStore) != address(0),"IStaffAgentStore not set yet");
        // Kiểm tra tất cả roles của staff có nằm trong roles được phép của position
        // _validateStaffRoles(staff.position, staff.roles);

        mAddToStaff[staff.wallet] = staff;
        staffs.push(staff);
        _grantRole(ROLE_STAFF, staff.wallet);   
        // Track creation date and mark as active from today
        uint currentDate = block.timestamp;
        staffCreatedDate[staff.wallet] = currentDate;
        staffLastActiveDate[staff.wallet] = currentDate;
        
        // Automatically mark staff as active for today if they are active
        if (staff.active) {
            _markStaffActiveForDate(staff.wallet, currentDate);
        }    
        for (uint idx = 0; idx < staff.roles.length; idx++) {
            bytes32 roleHash = _getRoleHash(staff.roles[idx]);
            _grantRole(roleHash, staff.wallet);
        }    
        if(address(staffAgentStore) != address(0) && agent != address(0)){
            staffAgentStore.setAgent(staff.wallet,agent,branchId);

        }
        if (address(historyTracking) != address(0)) {
            historyTracking.recordStaffCreate(
                staff.wallet,
                mAddToStaff[staff.wallet],
                "Create Staff"
            );
        }
        return unicode"xin chào 222";
    }
    // Hàm helper để validate roles của staff
    function _validateStaffRoles(string memory _position, STAFF_ROLE[] memory _staffRoles) 
        internal 
        view 
    {
        STAFF_ROLE[] memory positionRoles = mPosition[_position].positionRoles;
        
        // Kiểm tra từng role của staff
        for (uint i = 0; i < _staffRoles.length; i++) {
            bool roleFound = false;
            
            // Tìm xem role này có trong position roles không
            for (uint j = 0; j < positionRoles.length; j++) {
                if (_staffRoles[i] == positionRoles[j]) {
                    roleFound = true;
                    break;
                }
            }
            
            require(roleFound, string(abi.encodePacked(
                "role ", 
                _staffRoleToString(_staffRoles[i]),
                " is not allowed for position ",
                _position
            )));
        }
    }  
    // Hàm helper để convert STAFF_ROLE thành string (để hiển thị lỗi rõ ràng hơn)
    function _staffRoleToString(STAFF_ROLE _role) 
        internal 
        pure 
        returns (string memory) 
    {
        if (_role == STAFF_ROLE.UPDATE_STATUS_DISH) return "UPDATE_STATUS_DISH";
        if (_role == STAFF_ROLE.PAYMENT_CONFIRM) return "PAYMENT_CONFIRM";
        if (_role == STAFF_ROLE.TC_MANAGE) return "TC_MANAGE";
        if (_role == STAFF_ROLE.TABLE_MANAGE) return "TABLE_MANAGE";
        if (_role == STAFF_ROLE.MENU_MANAGE) return "MENU_MANAGE";
        if (_role == STAFF_ROLE.STAFF_MANAGE) return "STAFF_MANAGE";
        return "UNKNOWN";
    }  
    function isStaff(address account) external view returns (bool) {
        return hasRole(ROLE_STAFF, account);
    }

    function removeStaff(address wallet) external isActive onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) {
    require(mAddToStaff[wallet].wallet != address(0), "Staff not found");
    require(mAddToStaff[wallet].active, "Staff already inactive");
    if (address(historyTracking) != address(0)) {
        historyTracking.recordStaffDelete(
            wallet,
            mAddToStaff[wallet],
            "Staff removed"
        );
    }
    
    // Lưu lại roles trước khi xóa
    STAFF_ROLE[] memory staffRoles = mAddToStaff[wallet].roles;
    
    // Đánh dấu inactive
    delete mAddToStaff[wallet];
    // mAddToStaff[wallet].active = false;
    
    // Xóa khỏi array
    for(uint i = 0; i < staffs.length; i++){
        if(wallet == staffs[i].wallet){
            staffs[i] = staffs[staffs.length - 1];
            staffs.pop();  // ✅ THÊM () ĐÂY
            break;
        }
    }
    
    // Revoke ROLE_STAFF chính
    _revokeRole(ROLE_STAFF, wallet);
    
    // ✅ THÊM: Revoke tất cả các role cụ thể của staff
    for (uint idx = 0; idx < staffRoles.length; idx++) {
        bytes32 roleHash = _getRoleHash(staffRoles[idx]);
        _revokeRole(roleHash, wallet);
    }
}
    function UpdateStaffInfo(
        address _wallet,
        string memory _name,
        string memory _code,
        string memory _phone,
        string memory _addr,
        STAFF_ROLE[] memory _roles,
        WorkingShift[] memory _shifts, 
        string memory _linkImgSelfie,
        string memory _linkImgPortrait,
        string memory _position,
        bool _active    
    )external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) isActive returns(bool){
        require(_wallet != address(0),"wallet of staff is wrong");
        Staff storage staff = mAddToStaff[_wallet];
        require(mAddToStaff[staff.wallet].wallet != address(0),"does not find any staff");
        bool wasActive = staff.active;
        staff.name = _name;
        staff.code = _code;
        staff.phone = _phone;
        staff.addr = _addr;
        staff.active = _active;
        staff.shifts = _shifts;
        staff.linkImgSelfie = _linkImgSelfie;
        staff.linkImgPortrait = _linkImgPortrait;
        staff.position = _position;
        for (uint i = 0; i < staffs.length; i++) {
            if (staffs[i].wallet == _wallet) {
                staffs[i] = staff;
                break;
            }
        }
        for (uint idx = 0; idx < staff.roles.length; idx++) {
            bytes32 roleHash = _getRoleHash(staff.roles[idx]);
            _revokeRole(roleHash, staff.wallet);
        }
        staff.roles = _roles;
        for (uint idx = 0; idx < staff.roles.length; idx++) {
            bytes32 roleHash = _getRoleHash(staff.roles[idx]);
            _grantRole(roleHash, staff.wallet);
        }    
        if (!wasActive && _active) {
            _markStaffActiveForDate(_wallet, block.timestamp);
            staffLastActiveDate[_wallet] = block.timestamp;
        }
        if (address(historyTracking) != address(0)) {
        historyTracking.recordStaffUpdate(
            _wallet,
            mAddToStaff[_wallet],
            "Staff info updated"
        );
    }
        return true;
    }
    // Internal function to mark staff active for a specific date
    function _markStaffActiveForDate(address staffWallet, uint date) internal {
        uint dayKey = _getDay(date);
        uint monthKey = _getMonth(date);
        
        // Mark daily active
        if (!isDailyActive[dayKey][staffWallet]) {
            dailyActiveStaff[dayKey].push(staffWallet);
            isDailyActive[dayKey][staffWallet] = true;
        }
        
        // Mark monthly active  
        if (!isMonthlyActive[monthKey][staffWallet]) {
            monthlyActiveStaff[monthKey].push(staffWallet);
            isMonthlyActive[monthKey][staffWallet] = true;
        }
    }
    function GetStaffInfo(address _wallet)external view isActive returns(Staff memory){
        // require(
        //     checkRole(STAFF_ROLE.STAFF_MANAGE,msg.sender) || msg.sender == restaurantOrder,
        //     "Access denied: missing role"
        // );
        return mAddToStaff[_wallet];
    }
    function GetStaff()external view returns(Staff memory){
        return mAddToStaff[msg.sender];
    }
    function GetAllStaff()
        external
        view
        returns (Staff[] memory)
    {
        return staffs;
    }
    function GetStaffsPagination(uint256 offset, uint256 limit)
        external
        view
        returns (Staff[] memory result,uint totalCount)
    {
        if(offset >= staffs.length) {
            return ( new Staff[](0),staffs.length);
        }

        uint256 end = offset + limit;
        if (end > staffs.length) {
            end = staffs.length;
        }

        uint256 size = end - offset;
        result = new Staff[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = staffs.length - 1 - offset - i;
            result[i] = staffs[reverseIndex];
        }

        return (result,staffs.length);
    }

    function GetStaffRolePayment()external view returns(address[] memory staffsPayment){
        uint count;
        Staff[] memory staffsTemp = new Staff[](staffs.length);
        for(uint i; i< staffs.length; i++){
            if(hasRole(_getRoleHash(STAFF_ROLE.PAYMENT_CONFIRM), staffs[i].wallet)){
                staffsTemp[count] =  staffs[i];
                count++;
            }
        } 
        staffsPayment = new address[](count);
        for(uint i; i<count; i++){
            staffsPayment[i] = staffsTemp[i].wallet;
        }

    }
    /**
    * @dev Get list of active staff for a specific date
    * @param date The date to query (timestamp)
    * @return Array of Staff structs that were active on that date
    */
    function GetActiveStaffByDate(uint date) external view returns (Staff[] memory) {
        uint dayKey = _getDay(date);
        address[] memory activeAddresses = dailyActiveStaff[dayKey];
        // Count valid active staff
        uint validCount = 0;
        for (uint i = 0; i < activeAddresses.length; i++) {
            if (mAddToStaff[activeAddresses[i]].active && 
                mAddToStaff[activeAddresses[i]].wallet != address(0)) {
                validCount++;
            }
        }
        
        // Build result array
        Staff[] memory activeStaff = new Staff[](validCount);
        uint index = 0;
        
        for (uint i = 0; i < activeAddresses.length; i++) {
            Staff memory staff = mAddToStaff[activeAddresses[i]];
            if (staff.active && staff.wallet != address(0)) {
                activeStaff[index] = staff;
                index++;
            }
        }
        
        return activeStaff;
    }

    /**
    * @dev Get list of active staff for a specific month
    * @param date The date within the month to query (timestamp)
    * @return Array of Staff structs that were active during that month
    */
    function GetActiveStaffByMonth(uint date) external view returns (Staff[] memory) {
        uint monthKey = _getMonth(date);
        address[] memory activeAddresses = monthlyActiveStaff[monthKey];
        
        // Count valid active staff
        uint validCount = 0;
        for (uint i = 0; i < activeAddresses.length; i++) {
            if (mAddToStaff[activeAddresses[i]].active && 
                mAddToStaff[activeAddresses[i]].wallet != address(0)) {
                validCount++;
            }
        }
        
        // Build result array
        Staff[] memory activeStaff = new Staff[](validCount);
        uint index = 0;
        
        for (uint i = 0; i < activeAddresses.length; i++) {
            Staff memory staff = mAddToStaff[activeAddresses[i]];
            if (staff.active && staff.wallet != address(0)) {
                activeStaff[index] = staff;
                index++;
            }
        }
        
        return activeStaff;
    }

    /**
    * @dev Get count of active staff for a specific date
    * @param date The date to query (timestamp)
    * @return Number of active staff on that date
    */
    function GetActiveStaffCountByDate(uint date) external view returns (uint) {
        uint dayKey = _getDay(date);
        address[] memory activeAddresses = dailyActiveStaff[dayKey];
        
        uint count = 0;
        for (uint i = 0; i < activeAddresses.length; i++) {
            if (mAddToStaff[activeAddresses[i]].active && 
                mAddToStaff[activeAddresses[i]].wallet != address(0)) {
                count++;
            }
        }
        
        return count;
    }

    /**
    * @dev Get count of active staff for a specific month
    * @param date The date within the month to query (timestamp)
    * @return Number of active staff during that month
    */
    function GetActiveStaffCountByMonth(uint date) external view returns (uint) {
        uint monthKey = _getMonth(date);
        address[] memory activeAddresses = monthlyActiveStaff[monthKey];
        
        uint count = 0;
        for (uint i = 0; i < activeAddresses.length; i++) {
            if (mAddToStaff[activeAddresses[i]].active && 
                mAddToStaff[activeAddresses[i]].wallet != address(0)) {
                count++;
            }
        }
        
        return count;
    }

    /**
    * @dev Get active staff addresses for a specific date (more gas efficient)
    * @param date The date to query (timestamp)
    * @return Array of wallet addresses that were active on that date
    */
    function GetActiveStaffAddressesByDate(uint date) external view returns (address[] memory) {
        uint dayKey = _getDay(date);
        address[] memory activeAddresses = dailyActiveStaff[dayKey];
        
        // Count valid addresses
        uint validCount = 0;
        for (uint i = 0; i < activeAddresses.length; i++) {
            if (mAddToStaff[activeAddresses[i]].active && 
                mAddToStaff[activeAddresses[i]].wallet != address(0)) {
                validCount++;
            }
        }
        // Build result array
        address[] memory result = new address[](validCount);
        uint index = 0;
        
        for (uint i = 0; i < activeAddresses.length; i++) {
            if (mAddToStaff[activeAddresses[i]].active && 
                mAddToStaff[activeAddresses[i]].wallet != address(0)) {
                result[index] = activeAddresses[i];
                index++;
            }
        }
        return result;
    }

    /**
    * @dev Get active staff addresses for a specific month (more gas efficient)
    * @param date The date within the month to query (timestamp)
    * @return Array of wallet addresses that were active during that month
    */
    function GetActiveStaffAddressesByMonth(uint date) external view returns (address[] memory) {
        uint monthKey = _getMonth(date);
        address[] memory activeAddresses = monthlyActiveStaff[monthKey];
        
        // Count valid addresses
        uint validCount = 0;
        for (uint i = 0; i < activeAddresses.length; i++) {
            if (mAddToStaff[activeAddresses[i]].active && 
                mAddToStaff[activeAddresses[i]].wallet != address(0)) {
                validCount++;
            }
        }
        
        // Build result array
        address[] memory result = new address[](validCount);
        uint index = 0;
        
        for (uint i = 0; i < activeAddresses.length; i++) {
            if (mAddToStaff[activeAddresses[i]].active && 
                mAddToStaff[activeAddresses[i]].wallet != address(0)) {
                result[index] = activeAddresses[i];
                index++;
            }
        }
        
        return result;
    }
    
    //Area management
    function CreateArea(uint _id,string memory _name)external onlyAdminAndRole(STAFF_ROLE.TABLE_MANAGE) isActive{
        require(_id != 0,"Area id can not be 0");
        require(mIdToArea[_id].id == 0,"this id existed");
        Area memory area = Area({
            id: _id,
            name: _name
        });
        mIdToArea[_id] = area;
        areas.push(area);
    }
    function getAllAreas() external returns(Area[] memory){
        return areas;
    }
    function GetAllAreasPagination(uint256 offset, uint256 limit)
        external
        view
        returns (Area[] memory result,uint totalCount)
    {
        if(offset >= areas.length) {
            return ( new Area[](0),areas.length);
        }

        uint256 end = offset + limit;
        if (end > areas.length) {
            end = areas.length;
        }

        uint256 size = end - offset;
        result = new Area[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = areas.length - 1 - offset - i;
            result[i] = areas[reverseIndex];
        }

        return (result,areas.length);
    }


    function getAreaById(uint _id) external returns(Area memory){
        return mIdToArea[_id];
    }
    function deleteArea(uint _id) external onlyAdminAndRole(STAFF_ROLE.TABLE_MANAGE) isActive{
        delete mIdToArea[_id];
        for(uint i;i<areas.length;i++){
            if(areas[i].id == _id){
                areas[i] = areas[areas.length-1];
                areas.pop();
                break;
            }
        }
        delete mAreaToTable[_id];
    }
    function updateArea(uint _id, string memory _newName) external onlyAdminAndRole(STAFF_ROLE.TABLE_MANAGE) isActive {
        // 1. Kiểm tra ID không được bằng 0
        require(_id != 0, "Area id can not be 0");
        
        // 2. Kiểm tra Area phải tồn tại trước khi cập nhật
        require(mIdToArea[_id].id != 0, "Area not found");
        
        // 3. Cập nhật tên trong mapping mIdToArea
        mIdToArea[_id].name = _newName;
        
        // 4. Cập nhật tên trong mảng areas
        for (uint i = 0; i < areas.length; i++) {
            if (areas[i].id == _id) {
                areas[i].name = _newName;
                break; // Thoát vòng lặp ngay khi tìm thấy và cập nhật
            }
        }
        
    }
    // Table management
    function CreateTable(
        uint _number,
        uint _numPeople,
        bool _active,
        string memory _name,
        uint _areaId
    )external onlyAdminAndRole(STAFF_ROLE.TABLE_MANAGE) isActive {
        require(_number != 0,"Table number can not be 0");
        require(mNumberToTable[_number].number == 0,"this number existed");
        Table memory table = Table({
            number: _number,
            numPeople: _numPeople,
            occupiedSeats: 0,
            status: TABLE_STATUS.AVAILABLE,
            sessionIds: new bytes32[](0),
            active: _active,
            name: _name,
            area: mIdToArea[_areaId],
            parentTableId: 0
        });


        mNumberToTable[_number] = table;
        tables.push(table);
        mAreaToTable[_areaId].push(table);
        mTableToAreaId[_number] = _areaId;
        if (address(historyTracking) != address(0)) {
            historyTracking.recordTableCreate(
                _number,
                mNumberToTable[_number],
                "create table"
            );
        }
    }
    function getTablesByArea(uint _areaId) external view returns(Table[] memory){
        return mAreaToTable[_areaId];
    }
    function GetTablesByAreaPagination(uint _areaId,uint256 offset, uint256 limit)
        external
        view
        returns (Table[] memory result,uint totalCount)
    {
        if(offset >= mAreaToTable[_areaId].length) {
            return ( new Table[](0),mAreaToTable[_areaId].length);
        }

        uint256 end = offset + limit;
        if (end > mAreaToTable[_areaId].length) {
            end = mAreaToTable[_areaId].length;
        }

        uint256 size = end - offset;
        result = new Table[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = mAreaToTable[_areaId].length - 1 - offset - i;
            result[i] = mAreaToTable[_areaId][reverseIndex];
        }

        return (result,mAreaToTable[_areaId].length);
    }

    function removeTable(uint _number)external onlyAdminAndRole(STAFF_ROLE.TABLE_MANAGE) isActive {
        if (address(historyTracking) != address(0)) {
            historyTracking.recordTableDelete(
                _number,
                mNumberToTable[_number],
                "Table removed"
            );
        }
        for(uint i;i<tables.length;i++){
            if(tables[i].number == _number){
                tables[i] = tables[tables.length-1];
                tables.pop();
            }
        }
        delete  mNumberToTable[_number];        
        uint areaId = mTableToAreaId[_number];
        Table[] storage tablesArea = mAreaToTable[areaId];
        for (uint i; i<tablesArea.length;i++ ){
            if(tablesArea[i].number == _number){
                tablesArea[i] = tablesArea[tablesArea.length -1];
                tablesArea.pop();
                break;
            }
        }
        delete mTableToAreaId[_number];
    }


    function UpdateTable(
        uint _number,
        uint _numPeople,
        bool _active,
        string memory _name,
        uint _newAreaId
    )external onlyAdminAndRole(STAFF_ROLE.TABLE_MANAGE) isActive returns(bool){
        require(_number != 0,"Table number can not be 0");
        require(mNumberToTable[_number].number != 0,"this number table does not exist");
        mNumberToTable[_number].numPeople = _numPeople;
        mNumberToTable[_number].active = _active;
        mNumberToTable[_number].name = _name;
        mNumberToTable[_number].area = mIdToArea[_newAreaId];
        for(uint i;i<tables.length;i++){
            if(keccak256(abi.encodePacked(tables[i].number ))== keccak256(abi.encodePacked(_number))){
                tables[i] = mNumberToTable[_number];
                break;
            }
        }
        
        uint oldAreaId = mTableToAreaId[_number];
        if( oldAreaId != _newAreaId){
            require(mIdToArea[_newAreaId].id != 0,"this area id does not exist");                   
            Table[] storage tablesArea = mAreaToTable[oldAreaId];
            for(uint i; i<tablesArea.length ;i++){
                if(tablesArea[i].number == _number){
                    tablesArea[i] = tablesArea[tablesArea.length -1];
                    tablesArea.pop();
                    break;
                }
            }
            mAreaToTable[_newAreaId].push(mNumberToTable[_number]);
            mTableToAreaId[_number] = _newAreaId;

        }else{
            for (uint i; i< mAreaToTable[oldAreaId].length; i++){
                if(mAreaToTable[oldAreaId][i].number == _number){
                    mAreaToTable[oldAreaId][i] = mNumberToTable[_number];
                    break;
                }

            }

        }
        if (address(historyTracking) != address(0)) {
            historyTracking.recordTableUpdate(
                _number,
                mNumberToTable[_number],
                "Table updated"
            );
        }
        return true;
    }
    function GetAllTables()external view returns(Table[] memory){
        return tables;
    }
    function GetAllTablesPagination(uint256 offset, uint256 limit)
        external
        view
        returns (Table[] memory result,uint totalCount)
    {
        if(offset >= tables.length) {
            return ( new Table[](0),tables.length);
        }

        uint256 end = offset + limit;
        if (end > tables.length) {
            end = tables.length;
        }

        uint256 size = end - offset;
        result = new Table[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = tables.length - 1 - offset - i;
            result[i] = tables[reverseIndex];
        }

        return (result,tables.length);
    }

    function GetTable(uint _number)external view returns(Table memory){
        return mNumberToTable[_number];
    }

    // Category management
    function CreateCategory(
        Category memory category
    )external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) isActive {
        require(bytes(category.code).length >0,"category code can not be empty");
        require(
            bytes(mCodeToCat[category.code].code).length == 0,
            "category code existed"
        );
        require(!isCodeExist[category.code],"code category exists");
        Category storage cat = mCodeToCat[category.code];
        cat.code= category.code;
        cat.name= category.name;
        cat.rank= category.rank;
        cat.desc= category.desc;
        cat.active= category.active;
        cat.imgUrl= category.imgUrl;
        cat.icon = category.icon;
        categories.push(cat);
        isCodeExist[cat.code] = true;
        if (address(historyTracking) != address(0)) {
        historyTracking.recordCategoryCreate(
            category.code,
            mCodeToCat[category.code],
            "Create Category"
        );
    }
    }
    function RemoveCategory(string memory _code)external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) isActive {
        if (address(historyTracking) != address(0)) {
            historyTracking.recordCategoryDelete(
                _code,
                mCodeToCat[_code],
                "Category removed"
            );
        }

        for(uint i;i<categories.length;i++){
            if(keccak256(abi.encodePacked(categories[i].code ))== keccak256(abi.encodePacked(_code))){
                categories[i] = categories[categories.length-1];
                categories.pop();
            }
        }
        delete  mCodeToCat[_code];
    }

    function UpdateCategory(
        string memory _code,
        string memory _name,
        uint _rank,
        string memory _desc,
        bool _active,
        string memory _imgUrl,
        string memory _icon
    )external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) isActive returns(bool)  {
        require(bytes(_code).length >0,"category code can not be empty");
        require(bytes(mCodeToCat[_code].code).length > 0,"category code does not exist");
        Category storage category = mCodeToCat[_code];
        category.name = _name;
        category.rank = _rank;
        category.desc = _desc;
        category.active = _active;
        category.imgUrl = _imgUrl;
        category.icon = _icon;
        for(uint i;i<categories.length;i++){
            if(keccak256(abi.encodePacked(categories[i].code ))== keccak256(abi.encodePacked(_code))){
                categories[i] = category;
            }
        }
        if (address(historyTracking) != address(0)) {
            historyTracking.recordCategoryUpdate(
                _code,
                mCodeToCat[_code],
                "Category updated"
            );
        }
        return true;
    }
    
    function GetCategories()external view returns(Category[] memory){
        return categories;
    }
    
    function GetCategory(
        string memory _code
    )external view returns(Category memory){
        require(bytes(_code).length >0,"category code can not be empty");
        require(bytes(mCodeToCat[_code].code).length > 0 ,"category code does not exist");
        return mCodeToCat[_code];
    }
    function GetCategoriesPagination(
        uint offset,
        uint limit
    )external view returns(Category[] memory categoryArr,uint[] memory dishCounts,uint totalCount){
        uint256 length = categories.length; 
        if(offset >= length){return (new Category[](0),new uint[](0),length);}

        uint256 end = offset + limit;
        if (end > length) {
            end = length;
        }

        uint256 size = end - offset;
        categoryArr = new Category[](size);
        dishCounts = new uint[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = length - 1 - offset - i;
            categoryArr[i] =categories[reverseIndex];
            dishCounts[i]=mCodeCatToDishes[categories[reverseIndex].code].length;
        }

        return (categoryArr,dishCounts,length);
    }


    // Dish management
    function CreateDish(
        string memory _codeCategory,
        Dish memory dish,
        // uint _quantity
        VariantParams[] memory _variants,
        bytes32[] memory optionIds
    )external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) isActive {
        require(bytes(_codeCategory).length >0 && bytes(dish.code).length >0,"category code and dish code can not be empty");
        require(
            bytes(mCodeToCat[_codeCategory].code).length > 0,
            "category code does not exist"
        );
        require(!isCodeExist[dish.code],"code dish exists");
        require(_variants.length > 0,"Invalid variants length");
        require(report != address(0),"report not set");
        // productID++;
        dish.createdAt = block.timestamp;
        IRestaurantReporting(report).updateDishStartTime(dish.code,block.timestamp);
        mCodeCatToDishes[_codeCategory].push(dish);
        isCodeExist[dish.code] = true;
        // mDishRemain[dish.code] = _quantity;
        for (uint256 i = 0; i < _variants.length; i++) {
            // HASH the attributes of the product to avoid duplicate attr and have the same price
            Variant memory newVariant;
            bytes32 attributesHash = hashAttributes(_variants[i].attrs);
            newVariant.variantID = attributesHash;
            newVariant.dishPrice = _variants[i].price;
            mDishVariant[dish.code].push(attributesHash);
            mVariant[dish.code][attributesHash] = newVariant;
            // wild things happen all the time
            for (uint256 j = 0; j < _variants[i].attrs.length; j++) {
                // tips and trick for copy
                mVariantAttributes[dish.code][attributesHash].push();

                bytes32 attrID = keccak256(abi.encode(_variants[i].attrs[j]));

                mVariantAttributes[dish.code][attributesHash][j] = _variants[i].attrs[j];
                mVariantAttributes[dish.code][attributesHash][j].id = attrID;
                
                mAttribute[attrID] = _variants[i].attrs[j];
                mAttribute[attrID].id = attrID;
                bool foundAttr;
                for (uint256 m = 0; m < mCategoryAttributes[_codeCategory].length; m++){
                    if (attrID == mCategoryAttributes[_codeCategory][m]){
                        foundAttr = true;
                        break;
                    }
                }
                if (!foundAttr){
                    mCategoryAttributes[_codeCategory].push(attrID);
                }
            }
            for (uint256 k = 0; k < i; k++) {
                // 1 product have many variants
                // 1 variants have many attributes
                // those attributes must not be the same
                // if a variant already have color : red, size: big
                // another variant can't be the same, must be more or less or different
                require(mDishVariant[dish.code][k] != attributesHash,"Duplicate variant attributes detected");
            }
        }
        mCodeToDish[dish.code] = dish;
        // Initialize dish tracking
        dishStartTime[dish.code] = block.timestamp;
        dishIsNew[dish.code] = true;
        
            // dishesWithOrder.push(dish.code);
        if (dishCodeIndex[dish.code] == 0) {
            bool isFirstDish = allDishCodes.length == 0;
            bool isExisting = !isFirstDish && 
                keccak256(abi.encodePacked(allDishCodes[0])) == keccak256(abi.encodePacked(dish.code));
            
            if (!isExisting) {
                allDishCodes.push(dish.code);
                dishCodeIndex[dish.code] = allDishCodes.length; // ✅ LƯU INDEX + 1 = 1, 2, 3...
                //
                bytes32 variantId0 = mDishVariant[dish.code][0];
                DishWithOrder memory dishWithOrder = DishWithOrder({
                    dish: mCodeToDish[dish.code],
                    orderNum: 0,
                    originalIndex: 0,
                    variant: mVariant[dish.code][variantId0],
                    attributes: mVariantAttributes[dish.code][variantId0]
                });
                dishesWithOrder.push(dishWithOrder);
                dishOrderIndex[dish.code] = dishesWithOrder.length - 1; // index + 1
            }
        }
        if(optionIds.length > 0){
            _batchChooseOption(dish.code,optionIds);
        }
         if (address(historyTracking) != address(0)) {
        // Prepare data
        Variant[] memory variants = new Variant[](_variants.length);
        Attribute[][] memory attributes = new Attribute[][](_variants.length);
        
        for (uint i = 0; i < _variants.length; i++) {
            bytes32 variantHash = mDishVariant[dish.code][i];
            variants[i] = mVariant[dish.code][variantHash];
            attributes[i] = mVariantAttributes[dish.code][variantHash];
        }
        
        historyTracking.recordDishCreate(
            dish.code,
            mCodeToDish[dish.code],
            variants,
            attributes,
            "Create new dish"
        );
    }
    }
    // Purpose: This function prevent 1 product have same attributes
    // so it maybe like: Shirt, Color : Red, Size : M
    // avoid the same attribute but maybe different price
    function hashAttributes(
        Attribute[] memory attrs
    ) internal pure returns (bytes32) {
        bytes memory attributesHash;

        for (uint256 i = 0; i < attrs.length; i++) {
            attributesHash = abi.encodePacked(
                attributesHash,
                attrs[i].key,
                attrs[i].value
            );
        }

        return keccak256(attributesHash);
    }
    function BatchUpdateTopDish(string[] memory dishCodes) public {
        uint n = dishesWithOrder.length;
        require(n > 0, "No dishes");

        // B1: gom các phần tử cần update
        DishWithOrder[] memory updated = new DishWithOrder[](dishCodes.length);
        bool[] memory removed = new bool[](n); // đánh dấu đã xóa để bỏ khỏi mảng chính

        for (uint j = 0; j < dishCodes.length; j++) {
            string memory _dishCode = dishCodes[j];

            // tìm vị trí trong dishesWithOrder
            uint index = type(uint).max;
            for (uint i = 0; i < n; i++) {
                if (
                    !removed[i] &&
                    keccak256(bytes(dishesWithOrder[i].dish.code)) ==
                    keccak256(bytes(_dishCode))
                ) {
                    index = i;
                    removed[i] = true; // đánh dấu đã loại bỏ
                    break;
                }
            }
            require(index != type(uint).max, "Dish not found");

            // cập nhật dữ liệu mới
            bytes32[] memory variantIds = mDishVariant[_dishCode];
            Variant memory variant = mVariant[_dishCode][variantIds[0]];
            Attribute[] memory attributes = mVariantAttributes[_dishCode][variantIds[0]];

            updated[j] = DishWithOrder({
                dish: mCodeToDish[_dishCode],
                orderNum: mCodeToDish[_dishCode].orderNum,
                originalIndex: index,
                variant: variant,
                attributes: attributes
            });
        }

        // B2: sort nhóm updated theo orderNum giảm dần
        for (uint i = 0; i < updated.length; i++) {
            for (uint j = i + 1; j < updated.length; j++) {
                if (updated[j].orderNum > updated[i].orderNum) {
                    DishWithOrder memory tmp = updated[i];
                    updated[i] = updated[j];
                    updated[j] = tmp;
                }
            }
        }

        // B3: build lại mảng mới
        DishWithOrder[] memory newArr = new DishWithOrder[](n); 
        uint pos = 0;

        // copy lại những phần tử cũ chưa bị xóa, chèn nhóm updated vào đúng chỗ
        for (uint i = 0; i < n; i++) {
            if (removed[i]) continue; // bỏ phần tử bị update
            // chèn phần tử update vào trước khi orderNum nhỏ hơn
            while (
                updated.length > 0 &&
                pos < updated.length &&
                updated[pos].orderNum > dishesWithOrder[i].orderNum
            ) {
                newArr[pos + i] = updated[pos];
                pos++;
            }
            newArr[pos + i] = dishesWithOrder[i];
        }

        // nếu còn phần tử update chưa chèn thì push tiếp
        uint filled = 0;
        for (uint k = 0; k < n; k++) {
            if (bytes(newArr[k].dish.code).length != 0) filled++;
        }
        for (uint k = filled; k < n; k++) {
            newArr[k] = updated[pos];
            pos++;
        }

        // B4: gán lại vào storage
        delete dishesWithOrder;
        for (uint i = 0; i < n; i++) {
            dishesWithOrder.push(newArr[i]);
        }
    }
    // Helper function cho insertion sort
    function _insertionSortDescending(DishWithOrder[] memory arr) internal pure {
        for (uint256 i = 1; i < arr.length; i++) {
            DishWithOrder memory key = arr[i];
            uint256 keyOrderNum = key.orderNum;
            
            uint256 j = i;
            while (j > 0 && arr[j - 1].orderNum < keyOrderNum) {
                arr[j] = arr[j - 1];
                j--;
            }
            arr[j] = key;
        }
    }

    // Phiên bản tối ưu hơn nữa - chỉ sort khi cần
    function BatchUpdateTopDishOptimal(string[] memory dishCodes) public {
        uint256 n = dishesWithOrder.length;
        require(n > 0 && dishCodes.length > 0, "Invalid input");
        
        // Nếu update quá nhiều item (>50% mảng), tốt hơn là full update
        if (dishCodes.length * 2 >= n) {
            _fullUpdateAllDishes();
            return;
        }
        
        // Tạo temp array để track changes
        DishWithOrder[] memory tempArray = new DishWithOrder[](n);
        bool hasChanges = false;
        
        // Copy existing array và update các items cần thiết
        for (uint256 i = 0; i < n; i++) {
            tempArray[i] = dishesWithOrder[i];
            
            // Check if this dish needs update
            for (uint256 j = 0; j < dishCodes.length; j++) {
                if (keccak256(bytes(tempArray[i].dish.code)) == 
                    keccak256(bytes(dishCodes[j]))) {
                    
                    // Update the dish data
                    string memory dishCode = dishCodes[j];
                    bytes32 variantId = mDishVariant[dishCode][0];
                    
                    uint256 newOrderNum = mCodeToDish[dishCode].orderNum;
                    
                    // Chỉ update nếu thực sự thay đổi
                    if (newOrderNum != tempArray[i].orderNum) {
                        tempArray[i] = DishWithOrder({
                            dish: mCodeToDish[dishCode],
                            orderNum: newOrderNum,
                            originalIndex: tempArray[i].originalIndex,
                            variant: mVariant[dishCode][variantId],
                            attributes: mVariantAttributes[dishCode][variantId]
                        });
                        hasChanges = true;
                    }
                    break;
                }
            }
        }
        
        // Chỉ sort và update storage nếu có thay đổi
        if (hasChanges) {
            _insertionSortDescending(tempArray);
            
            delete dishesWithOrder;
            for (uint256 i = 0; i < n; i++) {
                dishesWithOrder.push(tempArray[i]);
            }
        }
    }

    // Fallback cho full update khi batch quá lớn
    function _fullUpdateAllDishes() internal {
        // Reuse logic from optimized UpdateTopDish
        uint256 dishCount = allDishCodes.length;
        delete dishesWithOrder;
        
        DishWithOrder[] memory tempDishes = new DishWithOrder[](dishCount);
        
        for (uint256 i = 0; i < dishCount; i++) {
            string memory dishCode = allDishCodes[i];
            bytes32 variantId = mDishVariant[dishCode][0];
            
            tempDishes[i] = DishWithOrder({
                dish: mCodeToDish[dishCode],
                orderNum: mCodeToDish[dishCode].orderNum,
                originalIndex: i,
                variant: mVariant[dishCode][variantId],
                attributes: mVariantAttributes[dishCode][variantId]
            });
        }
        
        _insertionSortDescending(tempDishes);
        
        for (uint256 i = 0; i < dishCount; i++) {
            dishesWithOrder.push(tempDishes[i]);
        }
    }
    // //FE cần gọi hàm này sau mỗi khi gọi executeOrder
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
    //FE cần gọi hàm này sau mỗi khi gọi executeOrder
function SortDishesWithOrderRange(uint256 from, uint256 topN) public {
    uint256 length = dishesWithOrder.length;
    require(from < length, "Start index out of bounds");
    
    uint256 endIndex = from + topN;
    if (endIndex > length) {
        endIndex = length;
    }
    
    uint256 rangeSize = endIndex - from;
    
    // Copy range to memory
    DishWithOrder[] memory tempRange = new DishWithOrder[](rangeSize);
    for (uint256 i = 0; i < rangeSize; i++) {
        tempRange[i] = dishesWithOrder[from + i];
    }
    
    // Sort in memory (cần so sánh với các phần tử đã sort trước đó)
    for (uint256 i = 0; i < rangeSize; i++) {
        DishWithOrder memory key = tempRange[i];
        uint256 keyOrderNum = key.orderNum;
        
        // Tìm vị trí chèn từ đầu mảng (bao gồm cả phần đã sort)
        uint256 insertPos = from + i;
        
        // So sánh ngược lại để tìm vị trí đúng
        while (insertPos > 0 && dishesWithOrder[insertPos - 1].orderNum < keyOrderNum) {
            insertPos--;
        }
        
        // Nếu cần di chuyển
        if (insertPos < from + i) {
            // Shift các phần tử
            for (uint256 j = from + i; j > insertPos; j--) {
                dishesWithOrder[j] = dishesWithOrder[j - 1];
            }
            dishesWithOrder[insertPos] = key;
            string memory dishCode = dishesWithOrder[insertPos].dish.code;
            dishOrderIndex[dishCode] = insertPos;
        } else {
            dishesWithOrder[from + i] = key;
            string memory dishCode = dishesWithOrder[insertPos].dish.code;
            dishOrderIndex[dishCode] = from + i;
        }
    }

}    
    function getDishOrderIndex(string memory dishCode) external view returns (uint) {
        return dishOrderIndex[dishCode];
    }

    //FE gọi sau mỗi khi executeOrder được gọi
    function UpdateRankDishes()external isActive{
        uint256 dishCount = dishesWithOrder.length;
        for(uint i; i< dishCount; i++){
            uint rank = i;
            RankReport memory rankReport = RankReport({
                createdAt: block.timestamp,
                rank:rank
            });
            mDishCodeToRankReport[allDishCodes[i]].push(rankReport);
        }

    }
    function GetRanksCreatedTimes(
        string memory dishCode,
        uint from,
        uint to
    ) external view returns (RankReport[] memory times, uint totalCount) {
        RankReport[] storage allTimes = mDishCodeToRankReport[dishCode];
        totalCount = allTimes.length;

        // Đếm số phần tử thỏa timestamp
        uint count = 0;
        for (uint i = 0; i < totalCount; i++) {
            if (allTimes[i].createdAt >= from && allTimes[i].createdAt <= to) {
                count++;
            }
        }

        // Tạo mảng memory với đúng kích thước
        times = new RankReport[](count);

        // Copy dữ liệu thỏa timestamp
        uint j = 0;
        for (uint i = 0; i < totalCount; i++) {
            if (allTimes[i].createdAt >= from && allTimes[i].createdAt <= to) {
                times[j] = allTimes[i];
                j++;
            }
        }

        return (times, totalCount);
    }

    function UpdateTopDish() public isActive {
        uint dishCount = allDishCodes.length;
        
        // Tạo mảng dishes với orderNum
        // DishWithOrder[] memory dishesWithOrder = new DishWithOrder[](dishCount);
        delete dishesWithOrder;
        for (uint i = 0; i < dishCount; i++) {
            string memory _dishCode = allDishCodes[i];
            bytes32[] memory variantIds = mDishVariant[_dishCode];
            Variant memory variant = mVariant[_dishCode][variantIds[0]];
            Attribute[] memory attributes = mVariantAttributes[_dishCode][variantIds[0]];

            dishesWithOrder.push(DishWithOrder({
                dish: mCodeToDish[_dishCode],
                orderNum: mCodeToDish[_dishCode].orderNum,
                originalIndex: i,
                variant: variant,
                attributes: attributes
            }));
        }
        
        // Heap sort
        _updateHeapSort();
                
    }
    function _updateHeapSort() internal  {
        uint n = dishesWithOrder.length;
        
        // Build heap (rearrange array)
        for (int i = int(n / 2) - 1; i >= 0; i--) {
            _updateHeapify(n, uint(i));
        }
        
        // Extract elements from heap one by one
        for (uint i = n - 1; i > 0; i--) {
            // Move current root to end
            DishWithOrder memory temp = dishesWithOrder[0];
            dishesWithOrder[0] = dishesWithOrder[i];
            dishesWithOrder[i] = temp;
            
            // Call max heapify on the reduced heap
            _updateHeapify(i, 0);
        }
    }

    function _updateHeapify(uint n, uint i) internal  {
        uint largest = i;
        uint left = 2 * i + 1;
        uint right = 2 * i + 2;
        
        // If left child is larger than root
        if (left < n && dishesWithOrder[left].orderNum > dishesWithOrder[largest].orderNum) {
            largest = left;
        }
        
        // If right child is larger than largest so far
        if (right < n && dishesWithOrder[right].orderNum > dishesWithOrder[largest].orderNum) {
            largest = right;
        }
        
        // If largest is not root
        if (largest != i) {
            DishWithOrder memory temp = dishesWithOrder[i];
            dishesWithOrder[i] = dishesWithOrder[largest];
            dishesWithOrder[largest] = temp;
            
            // Recursively heapify the affected sub-tree
            _updateHeapify(n, largest);
        }
    }
    function getDishInfo(
        string memory _dishCode
    ) public view returns (DishInfo memory productInfo) {
        Dish memory dish = mCodeToDish[_dishCode];
        bytes32[] memory variantIds = mDishVariant[_dishCode];
        uint256 length = variantIds.length;
        Variant[] memory variants = new Variant[](length);
        Attribute[][] memory attributes = new Attribute[][](length);
        for (uint256 i = 0; i < length; i++) {
            bytes32 variantId = variantIds[i];
            variants[i] = mVariant[_dishCode][variantId];
            attributes[i] = mVariantAttributes[_dishCode][variantId];
        }
        productInfo = DishInfo({
            dish: dish,
            variants: variants,
            attributes: attributes
        });
    }
    function getAllDishInfo()
        public
        view
        returns (DishInfo[] memory productsInfo)
    {
        uint256 length = allDishCodes.length;
        productsInfo = new DishInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            productsInfo[i] = getDishInfo(allDishCodes[i]);
        }
    }
    function GetDish(
        string memory _codeDish
    )external view returns(Dish memory){
        return mCodeToDish[_codeDish];
    }
    function GetDishes(
        string memory _codeCategory
    )external view returns(Dish[] memory){
        return mCodeCatToDishes[_codeCategory];
    }
    function GetAllDishInfosByCat(
        string memory _codeCategory
    )external view returns(DishInfo[] memory productsInfo){
        uint len = mCodeCatToDishes[_codeCategory].length;
        productsInfo = new DishInfo[](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 reverseIndex = len - 1 - i;
            productsInfo[i] = getDishInfo(mCodeCatToDishes[_codeCategory][reverseIndex].code);
        }

        return productsInfo;
    }

    function GetDishInfosByCat(
        string memory _codeCategory,
        uint offset,
        uint limit
    )external view returns(DishInfo[] memory productsInfo,uint totalCount){
        uint256 length = mCodeCatToDishes[_codeCategory].length;
        if(offset >= length){return (new DishInfo[](0), length);}

        uint256 end = offset + limit;
        if (end > length) {
            end = length;
        }

        uint256 size = end - offset;
        productsInfo = new DishInfo[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = length - 1 - offset - i;
            productsInfo[i] = getDishInfo(mCodeCatToDishes[_codeCategory][reverseIndex].code);
        }

        return (productsInfo,length);
    }

    function getVariant(
        string memory _dishCode,
        bytes32 _variantID
    ) public view returns (Variant memory) {
        return mVariant[_dishCode][_variantID];
    }
 
    // Function for RestaurantOrder to get basic dish info
    function GetDishBasic(string memory code) external view returns (string memory name,bool available, bool active,string memory imgUrl) {
        Dish memory dish = mCodeToDish[code];
        return (dish.name, dish.available, dish.active, dish.imgUrl);
    }
    function GetAllDishCodes() external view returns (string[] memory) {
        return allDishCodes;
    }
    function GetTopDishesWithLimit(uint offset, uint limit) external returns (DishWithFirstPrice[] memory, uint totalCount) {
        // if (dishesWithOrder.length == 0){
        //     UpdateTopDishLimited(50);
        // }
        uint dishCount = allDishCodes.length;
        totalCount = dishCount;
        
        if (dishCount == 0 || offset >= dishCount) {
            return (new DishWithFirstPrice[](0), totalCount);
        }
        
        // Tính toán số lượng thực tế cần lấy
        uint remainingItems = dishCount - offset;
        if (limit > remainingItems) {
            limit = remainingItems;
        }
        if (limit == 0) {
            return (new DishWithFirstPrice[](0), totalCount);
        }
        // Lấy kết quả từ offset
        DishWithFirstPrice[] memory result = new DishWithFirstPrice[](limit);
        for (uint i = 0; i < limit; i++) {
            result[i] = DishWithFirstPrice({
                dish: dishesWithOrder[offset + i].dish,
                variant: dishesWithOrder[offset + i].variant,
                attributes: dishesWithOrder[offset + i].attributes
            });
        }
        
        return (result,totalCount);
    }

    function Get5TopDishesByTime(uint256 dayOrMonth,bool isDay) external view returns (
        DishWithFirstPrice[] memory result,
        uint256 totalCount
    ) {
        string[] memory dishCodes;
        if(isDay){
            dishCodes = mDayToDishCodeOrder[dayOrMonth];
        }else{
            dishCodes = mMonthToDishCodeOrder[dayOrMonth];
        }
        
        totalCount = dishCodes.length;
        
        if (totalCount == 0) {
            return (new DishWithFirstPrice[](0), 0);
        }
        
        // Cache tất cả data cần thiết
        DishSimpleData[] memory allDishes = new DishSimpleData[](totalCount);
        
        for (uint256 i = 0; i < totalCount; i++) {
            allDishes[i] = DishSimpleData({
                dishCode: dishCodes[i],
                orderNum: mCodeToDish[dishCodes[i]].orderNum,
                index: i
            });
        }
        
        // Sort toàn bộ array
        _insertionSortSimple(allDishes, totalCount);
        
        // Lấy top 5
        uint256 resultSize = totalCount < 5 ? totalCount : 5;
        result = new DishWithFirstPrice[](resultSize);
        
        for (uint256 i = 0; i < resultSize; i++) {
            string memory dishCode = allDishes[i].dishCode;
            bytes32 variantId = mDishVariant[dishCode].length > 0 
                ? mDishVariant[dishCode][0] 
                : bytes32(0);
            
            result[i] = DishWithFirstPrice({
                dish: mCodeToDish[dishCode],
                variant: mVariant[dishCode][variantId],
                attributes: mVariantAttributes[dishCode][variantId]
            });
        }
        
        return (result, totalCount);
    }
    
    struct DishSimpleData {
        string dishCode;
        uint256 orderNum;
        uint256 index;
    }
    
    /**
     * @dev Insertion sort cho DishSimpleData (descending)
     */
    function _insertionSortSimple(
        DishSimpleData[] memory arr,
        uint256 length
    ) internal pure {
        for (uint256 i = 1; i < length; i++) {
            DishSimpleData memory key = arr[i];
            uint256 j = i;
            
            while (j > 0 && arr[j - 1].orderNum < key.orderNum) {
                arr[j] = arr[j - 1];
                j--;
            }
            
            if (j != i) {
                arr[j] = key;
            }
        }
    }
    function GetNewDishes() 
        public 
        view 
        returns (NewDish[] memory) 
    {
        uint dishCount = allDishCodes.length;
        
        // Đếm số món ăn mới (trong vòng 30 ngày)
        uint count = 0;
        for(uint i = 0; i < dishCount; i++){
            string memory _dishCode = allDishCodes[i];
            Dish memory dish = mCodeToDish[_dishCode];
            if(dish.createdAt >= block.timestamp - 30 days){
                count++;
            }
        }
        NewDish[] memory result = new NewDish[](count);
        uint resultIndex = 0;
        
        for (uint i = 0; i < dishCount; i++) {
            string memory _dishCode = allDishCodes[i];
            Dish memory dish = mCodeToDish[_dishCode];           
            result[resultIndex] = NewDish({
                name: dish.name,
                codeDish: _dishCode,
                createAt: dish.createdAt
            });
            resultIndex++;
        }
        return result;
    }
    //dishes in 30 days back
    function GetNewDishesWithLimit(uint offset, uint limit) 
        public 
        view 
        returns (NewDish[] memory, uint totalCount) 
    {
        uint dishCount = allDishCodes.length;
        
        // Đếm số món ăn mới (trong vòng 30 ngày)
        uint count = 0;
        for(uint i = 0; i < dishCount; i++){
            string memory _dishCode = allDishCodes[i];
            Dish memory dish = mCodeToDish[_dishCode];
            if(dish.createdAt >= block.timestamp - 30 days){
                count++;
            }
        }
        
        // Kiểm tra edge cases
        if (count == 0 || offset >= count) {
            return (new NewDish[](0), count);
        }
        
        // Tính toán số lượng thực tế cần lấy
        uint remainingItems = count - offset;
        uint actualLimit = limit > remainingItems ? remainingItems : limit;
        
        if (actualLimit == 0) {
            return (new NewDish[](0), count);
        }
        
        // Lấy kết quả với pagination
        NewDish[] memory result = new NewDish[](actualLimit);
        uint resultIndex = 0;
        uint newDishIndex = 0;
        
        for (uint i = 0; i < dishCount && resultIndex < actualLimit; i++) {
            string memory _dishCode = allDishCodes[i];
            Dish memory dish = mCodeToDish[_dishCode];
            
            if(dish.createdAt >= block.timestamp - 30 days){
                // Chỉ thêm vào kết quả nếu đã qua offset
                if(newDishIndex >= offset){
                    result[resultIndex] = NewDish({
                        name: dish.name,
                        codeDish: _dishCode,
                        createAt: dish.createdAt
                    });
                    resultIndex++;
                }
                newDishIndex++;
            }
        }
        
        return (result, count);
    }

    function GetRecentDishes(uint fromTime, uint limit) external view returns (string[] memory) {
        uint count = 0;
        
        // Count recent dishes first
        for (uint i = 0; i < allDishCodes.length; i++) {
            if (dishStartTime[allDishCodes[i]] >= fromTime) {
                count++;
            }
        }
        
        if (count == 0) return new string[](0);
        if (limit > count) limit = count;
        
        string[] memory recentDishes = new string[](limit);
        uint index = 0;
        
        // Get recent dishes (newest first)
        for (uint i = allDishCodes.length; i > 0 && index < limit; i--) {
            if (dishStartTime[allDishCodes[i-1]] >= fromTime) {
                recentDishes[index] = allDishCodes[i-1];
                index++;
            }
        }
        
        return recentDishes;
    }
    function UpdateOrderNum (
        string memory _codeDish,
        uint orderNumAdd,
        uint createdAt
    )external isActive onlyOrder() {
        require(orderNumAdd >0, "orderNum added can be zero");
        require(
            bytes(mCodeToDish[_codeDish].code).length > 0,
            "can not find dish"
        );
        mCodeToDish[_codeDish].orderNum += orderNumAdd;
        uint day = _getDay(createdAt);
        uint month = _getMonth(createdAt);
        if(mDayToDishCode[day][_codeDish] != true){
            mDayToDishCodeOrder[day].push(_codeDish);
            mDayToDishCode[day][_codeDish] = true;
        }
        
        if(mDayToDishCode[month][_codeDish] != true){
            mMonthToDishCodeOrder[month].push(_codeDish);
            mMonthToDishCode[month][_codeDish] = true;
        }
        uint index = dishOrderIndex[_codeDish];
        require(index < dishesWithOrder.length, "Invalid dish index");
        dishesWithOrder[index].orderNum += orderNumAdd;
    }
    //FE cần gọi sau khi gọi executeOrder
    function UpdateTotalRevenueReport(uint createdAt, uint addRevenue) external isActive{
        totalRevenueDays.push(ChartTotalRevenue({
            time:createdAt,
            addRevenue: addRevenue
        }));
        totalOrderDays.push(ChartTotalOrder({
            time:createdAt,
            addOrder: 1
        }));
    }
        // Lấy dữ liệu với offset và limit
    function getHistoryOrderReportByTime(
    uint from,
    uint to,
    uint offset,
    uint limit
) external view returns(
    ChartTotalOrder[] memory data,
    uint totalRecords,
    bool hasMore
) {
    require(limit > 0, "Limit must be greater than 0");
    
    // Đếm trước
    uint filteredCount = 0;
    for(uint i = 0; i < totalOrderDays.length; i++) {
        if(totalOrderDays[i].time >= from && totalOrderDays[i].time <= to) {
            filteredCount++;
        }
    }
    
    totalRecords = filteredCount;
    
    if(filteredCount == 0 || offset >= filteredCount) {
        return (new ChartTotalOrder[](0), totalRecords, false);
    }
    
    // Tạo mảng filtered đúng kích thước
    ChartTotalOrder[] memory filtered = new ChartTotalOrder[](filteredCount);
    uint index = 0;
    
    for(uint i = 0; i < totalOrderDays.length; i++) {
        if(totalOrderDays[i].time >= from && totalOrderDays[i].time <= to) {
            filtered[index] = totalOrderDays[i];
            index++;
        }
    }
    
    // Áp dụng pagination
    uint endIndex = offset + limit;
    if(endIndex > filteredCount) {
        endIndex = filteredCount;
    }
    
    uint resultSize = endIndex - offset;
    data = new ChartTotalOrder[](resultSize);
    
    for(uint i = 0; i < resultSize; i++) {
        data[i] = filtered[offset + i];
    }
    
    hasMore = endIndex < filteredCount;
    
    return (data, totalRecords, hasMore);
}

    // Lấy dữ liệu với offset và limit
    function getHistoryRevenueReportByTime(
        uint from,
        uint to,
        uint offset,
        uint limit
    ) external view returns(
        ChartTotalRevenue[] memory data,
        uint totalRecords,
        bool hasMore
    ) 
    {
        require(limit > 0, "Limit must be greater than 0");
        
        // ✅ BƯỚC 1: Đếm số lượng records thỏa điều kiện trước
        uint filteredCount = 0;
        for(uint i = 0; i < totalRevenueDays.length; i++) {
            if(totalRevenueDays[i].time >= from && totalRevenueDays[i].time <= to) {
                filteredCount++;
            }
        }
        
        totalRecords = filteredCount;
        
        // Kiểm tra nếu không có dữ liệu hoặc offset vượt quá
        if(filteredCount == 0 || offset >= filteredCount) {
            return (new ChartTotalRevenue[](0), totalRecords, false);
        }
        
        // ✅ BƯỚC 2: Khởi tạo mảng filtered với đúng kích thước
        ChartTotalRevenue[] memory filtered = new ChartTotalRevenue[](filteredCount);
        uint index = 0;
        
        for(uint i = 0; i < totalRevenueDays.length; i++) {
            if(totalRevenueDays[i].time >= from && totalRevenueDays[i].time <= to) {
                filtered[index] = totalRevenueDays[i];
                index++;
            }
        }
        
        // ✅ BƯỚC 3: Áp dụng pagination
        uint endIndex = offset + limit;
        if(endIndex > filteredCount) {
            endIndex = filteredCount;
        }
        
        uint resultSize = endIndex - offset;
        data = new ChartTotalRevenue[](resultSize);
        
        for(uint i = 0; i < resultSize; i++) {
            data[i] = filtered[offset + i];
        }
        
        hasMore = endIndex < filteredCount;
        
        return (data, totalRecords, hasMore);    
    }
    //camera AI sẽ gọi sau
    function UpdateTotalCustomerReport(uint createdAt, uint addCustomers) external{
        totalCustomersDays.push(ChartTotalCustomers({
            time:createdAt,
            totalCustomers: addCustomers
        }));
    }
    // Lấy dữ liệu với offset và limit
    function getHistoryCustomersReportByTime(
    uint from,
    uint to,
    uint offset,
    uint limit
) external view returns(
    ChartTotalCustomers[] memory data,
    uint totalRecords,
    bool hasMore
) {
    require(limit > 0, "Limit must be greater than 0");
    
    // Đếm trước
    uint filteredCount = 0;
    for(uint i = 0; i < totalCustomersDays.length; i++) {
        if(totalCustomersDays[i].time >= from && totalCustomersDays[i].time <= to) {
            filteredCount++;
        }
    }
    
    totalRecords = filteredCount;
    
    if(filteredCount == 0 || offset >= filteredCount) {
        return (new ChartTotalCustomers[](0), totalRecords, false);
    }
    
    // Tạo mảng filtered đúng kích thước
    ChartTotalCustomers[] memory filtered = new ChartTotalCustomers[](filteredCount);
    uint index = 0;
    
    for(uint i = 0; i < totalCustomersDays.length; i++) {
        if(totalCustomersDays[i].time >= from && totalCustomersDays[i].time <= to) {
            filtered[index] = totalCustomersDays[i];
            index++;
        }
    }
    
    // Áp dụng pagination
    uint endIndex = offset + limit;
    if(endIndex > filteredCount) {
        endIndex = filteredCount;
    }
    
    uint resultSize = endIndex - offset;
    data = new ChartTotalCustomers[](resultSize);
    
    for(uint i = 0; i < resultSize; i++) {
        data[i] = filtered[offset + i];
    }
    
    hasMore = endIndex < filteredCount;
    
    return (data, totalRecords, hasMore);
}

    function UpdateDish(
        string memory _codeCat,
        string memory _codeDish,
        string memory _nameCategory,
        string memory _name,
        string memory _des,
        bool _available,
        bool _active,
        string memory _imgUrl,
        uint _cookingTime,
        bool _showIngredient,
        string memory _videoLink,
        VariantParams[] memory _variants,
        string[] memory _ingredients
    )external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) isActive returns(bool){
        require(bytes(_codeDish).length >0 && bytes(_codeCat).length >0,"dish code and category code can not be empty");
        require(
            bytes(mCodeToDish[_codeDish].code).length > 0,
            "can not find dish"
        );
        // require(_variants.length > 0,"Invalid variants length");

        Dish storage dish = mCodeToDish[_codeDish];
        
        if (bytes(_codeCat).length >0){ dish.nameCategory = _nameCategory; }
        if (bytes(_name).length >0){ dish.name = _name;}
        if (bytes(_des).length >0){ dish.des = _des;}
        // dish.price = _price;
        dish.available = _available;
        dish.active = _active;
        if (bytes(_imgUrl).length >0){ dish.imgUrl = _imgUrl;}
        // dish.size = _size;
        dish.cookingTime = _cookingTime;
        dish.showIngredient = _showIngredient;
        if (bytes(_videoLink).length >0){ dish.videoLink = _videoLink;}
        _updateDishFromCat(_codeCat,_codeDish);
        if (_variants.length >0){ 
            bytes32[] storage variantHashes = mDishVariant[_codeDish];
            for (uint256 i = 0; i < variantHashes.length; i++) {
                delete mVariant[_codeDish][variantHashes[i]];
                delete mVariantAttributes[_codeDish][variantHashes[i]];
            }
            delete mDishVariant[_codeDish];
            for (uint256 i = 0; i < _variants.length; i++) {
                Variant memory newVariant;
                bytes32 attributesHash = hashAttributes(_variants[i].attrs);
                newVariant.variantID = attributesHash;
                newVariant.dishPrice = _variants[i].price;
                mDishVariant[_codeDish].push(attributesHash);
                mVariant[_codeDish][attributesHash] = newVariant;

                for (uint256 j = 0; j < _variants[i].attrs.length; j++) {
                    mVariantAttributes[_codeDish][attributesHash].push();
                    mVariantAttributes[_codeDish][attributesHash][j] = _variants[i]
                        .attrs[j];
                }

                for (uint256 k = 0; k < i; k++) {
                    require(
                        mDishVariant[_codeDish][k] != attributesHash,"Duplicate variant attributes detected"
                    );
                }
            }
        }
        if (_ingredients.length > 0){
            delete dish.ingredients;  // Clear old ingredients first
            for (uint256 i = 0; i < _ingredients.length; i++) {
                dish.ingredients.push(_ingredients[i]);
            }        
        }
        if (dishesWithOrder.length > 0) {
            uint256 stored = dishOrderIndex[_codeDish];
            bool updated = false;

            // trường hợp đúng chuẩn: stored > 0 và stored là index+1
            if (stored > 0) {
                uint256 idx = stored - 1;
                if (idx < dishesWithOrder.length) {
                    // kiểm tra chắc chắn cùng dish
                    if (keccak256(abi.encodePacked(dishesWithOrder[idx].dish.code)) == keccak256(abi.encodePacked(_codeDish))) {
                        dishesWithOrder[idx].dish = mCodeToDish[_codeDish];
                        // cập nhật variant + attributes nếu có variant hiện thời (lấy variant[0])
                        if (mDishVariant[_codeDish].length > 0) {
                            bytes32 v0 = mDishVariant[_codeDish][0];
                            dishesWithOrder[idx].variant = mVariant[_codeDish][v0];
                            dishesWithOrder[idx].attributes = mVariantAttributes[_codeDish][v0];
                        }
                        updated = true;
                    }
                }
            }
        }
        if (address(historyTracking) != address(0)) {
            Variant[] memory variants = new Variant[](mDishVariant[_codeDish].length);
            Attribute[][] memory attributes = new Attribute[][](mDishVariant[_codeDish].length);
            
            for (uint i = 0; i < mDishVariant[_codeDish].length; i++) {
                bytes32 variantHash = mDishVariant[_codeDish][i];
                variants[i] = mVariant[_codeDish][variantHash];
                attributes[i] = mVariantAttributes[_codeDish][variantHash];
            }
            
            historyTracking.recordDishUpdate(
                _codeDish,
                mCodeToDish[_codeDish],
                variants,
                attributes,
                "Updated dish information"
            );
        }
    
        return true;
    }
    function RemoveDish(
        string memory _codeCategory,
        string memory _dishCode
    ) external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) isActive {
        require(bytes(_codeCategory).length > 0, "Invalid category code");
        require(bytes(_dishCode).length > 0, "Invalid dish code");
        require(isCodeExist[_dishCode], "Dish does not exist");
        require(
            bytes(mCodeToCat[_codeCategory].code).length > 0,
            "Category code does not exist"
        );
        //Record BEFORE deleting (để lưu snapshot cuối cùng)
        if (address(historyTracking) != address(0)) {
            Variant[] memory variants = new Variant[](mDishVariant[_dishCode].length);
            Attribute[][] memory attributes = new Attribute[][](mDishVariant[_dishCode].length);
            
            for (uint i = 0; i < mDishVariant[_dishCode].length; i++) {
                bytes32 variantHash = mDishVariant[_dishCode][i];
                variants[i] = mVariant[_dishCode][variantHash];
                attributes[i] = mVariantAttributes[_dishCode][variantHash];
            }
            
            historyTracking.recordDishDelete(
                _dishCode,
                mCodeToDish[_dishCode],
                variants,
                attributes,
                "Dish removed from menu"
            );
        }

        // Xoá dish khỏi danh sách trong category
        Dish[] storage dishes = mCodeCatToDishes[_codeCategory];
        for (uint256 i = 0; i < dishes.length; i++) {
            if (
                keccak256(abi.encodePacked(dishes[i].code)) ==
                keccak256(abi.encodePacked(_dishCode))
            ) {
                dishes[i] = dishes[dishes.length - 1];
                dishes.pop();
                break;
            }
        }

        // Xoá variants liên quan
        bytes32[] storage variants = mDishVariant[_dishCode];
        for (uint256 i = 0; i < variants.length; i++) {
            bytes32 variantID = variants[i];
            // xoá attributes của variant
            delete mVariantAttributes[_dishCode][variantID];
            // xoá variant struct
            delete mVariant[_dishCode][variantID];
        }
        delete mDishVariant[_dishCode];

        // Xoá dish chính
        delete mCodeToDish[_dishCode];
        isCodeExist[_dishCode] = false;

        // Xoá tracking
        delete dishStartTime[_dishCode];
        delete dishIsNew[_dishCode];

        // Xoá khỏi allDishCodes  
        uint256 indexPlusOne = dishCodeIndex[_dishCode];
        
        uint256 index = indexPlusOne - 1;
        uint256 lastIndex = allDishCodes.length - 1;
        
        if (index != lastIndex) {
            // Swap with last element
            string memory lastCode = allDishCodes[lastIndex];
            allDishCodes[index] = lastCode;
            dishCodeIndex[lastCode] = indexPlusOne;
        }
        
        allDishCodes.pop();
        delete dishCodeIndex[_dishCode];
        //xóa khỏi dishesWithOrder
         uint256 orderIndexPlusOne = dishOrderIndex[_dishCode];
        if (orderIndexPlusOne > 0) {
            uint256 orderIndex = orderIndexPlusOne - 1;
            uint256 orderLastIndex = dishesWithOrder.length - 1;
            
            if (orderIndex != orderLastIndex) {
                DishWithOrder memory lastDishWithOrder = dishesWithOrder[orderLastIndex];
                dishesWithOrder[orderIndex] = lastDishWithOrder;
                dishOrderIndex[lastDishWithOrder.dish.code] = orderIndexPlusOne;
            }
            
            dishesWithOrder.pop();
            delete dishOrderIndex[_dishCode];
        }
        emit DishRemoved(_dishCode, _codeCategory);
    }

    event DishRemoved(string dishCode, string categoryCode);

    function updateAverageStarDish(uint8 _newStar, string memory _codeDish) external onlyOrder {
        Dish storage dish = mCodeToDish[_codeDish];
        dish.averageStar = (_newStar + dish.averageStar * dish.totalReview) / (dish.totalReview + 1);
    } 
    function _updateDishFromCat(
        string memory _codeCat,
        string memory _codeDish  
    )internal{
        Dish[] storage dishes = mCodeCatToDishes[_codeCat];
        Dish storage dish = mCodeToDish[_codeDish];
        require(dishes.length > 0,"no dish in this category found");
        for(uint i; i < dishes.length; i++){
            if(keccak256(abi.encodePacked(dishes[i].code)) == keccak256(abi.encodePacked(_codeDish))){
                dishes[i] = dish;
                break;
            }
        }
    }
      
    function UpdateDishStatus(
        string memory _codeCat,
        string memory _codeDish,
        bool _available
    ) external onlyAdminAndRole(STAFF_ROLE.UPDATE_STATUS_DISH) isActive returns(bool) {
        require(bytes(mCodeToDish[_codeDish].code).length != 0,"can not find dish");
        mCodeToDish[_codeDish].available = _available;
        _updateDishFromCat(_codeCat,_codeDish);
        return true;
    }

    // Discount management for Loyalty
    function CreateDiscount(
        string memory _code,
        string memory _name,
        uint _discountPercent,
        string memory _desc,
        uint _from,
        uint _to,
        bool _active,
        string memory _imgURL,
        uint _amountMax,
        DiscountType _discountType,
        bytes32[] memory _targetGroupIds,
        uint _pointCost,
        bool _isRedeemable,
        string memory _textDes
    )external onlyRole(ROLE_ADMIN){
        require(bytes(_code).length >0,"code of discount can not be empty");
        require(bytes(mCodeToDiscount[_code].code).length == 0,"code of discount existed");
        require(_discountPercent > 0 && _discountPercent <= 100, "Invalid discount percent");
        require(_from < _to, "Invalid time range");
         // Validate theo loại discount
        if (_discountType == DiscountType.AUTO_GROUP) {
            require(_targetGroupIds.length > 0, "Group IDs required for AUTO_GROUP");
        }
        
        if (_isRedeemable) {
            require(_pointCost > 0, "Point cost required for redeemable discount");
            require(address(POINTS) != address(0),"POINTS contract not set yet");
            for(uint i; i <_targetGroupIds.length; i++ ){
                require(POINTS.isMemberGroupId(_targetGroupIds[i]),"membergroup id is wrong");
            }

        }

        mCodeToDiscount[_code] = Discount({
            code: _code ,
            name: _name ,
            discountPercent : _discountPercent,
            desc : _desc,
            from : _from,
            to : _to,
            active : _active,
            imgURL : _imgURL,
            amountMax : _amountMax,
            amountUsed : 0,
            updatedAt  : block.timestamp,
            discountType: _discountType,
            targetGroupIds: _targetGroupIds,
            pointCost: _pointCost,
            isRedeemable: _isRedeemable,
            textDes: _textDes
        });
        discounts.push(mCodeToDiscount[_code]);
        if (address(historyTracking) != address(0)) {
        historyTracking.recordDiscountCreate(
            _code,
            mCodeToDiscount[_code],
            "Create Discount"
        );
    }
    }
    function RemoveDiscount(string memory _code)external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE){
        if (address(historyTracking) != address(0)) {
            historyTracking.recordDiscountDelete(
                _code,
                mCodeToDiscount[_code],
                "Discount removed"
            );
        }
        for(uint i;i<discounts.length;i++){
            if(keccak256(abi.encodePacked(discounts[i].code ))== keccak256(abi.encodePacked(_code))){
                discounts[i] = discounts[discounts.length-1];
                discounts.pop();
            }
        }
        delete  mCodeToDiscount[_code];
    }

    function UpdateDiscount(
        string memory _code,
        string memory _name,
        uint _discountPercent,
        string memory _desc,
        uint _from,
        uint _to,
        bool _active,
        string memory _imgURL,
        uint _amountMax,
        DiscountType _discountType,
        bytes32[] memory _targetGroupIds,
        uint _pointCost,
        bool _isRedeemable,
        string memory _textDes
    )external onlyRole(ROLE_ADMIN) isActive{
        require(bytes(_code).length >0,"code of discount can not be empty");
        require(bytes(mCodeToDiscount[_code].code).length > 0,"can not find any discount");
        require(_amountMax > 0 && _discountPercent > 0 ,"maximum number and percent of discount can be zero" );
        require(_discountPercent <= 100, "discount percent need to be less than 100");
        // require(_from >= block.timestamp && _to > block.timestamp,"time is not valid");
        require(_amountMax >= mCodeToDiscount[_code].amountUsed , 
                "number of maximum can not be less than number discount used");
         if (_discountType == DiscountType.AUTO_GROUP) {
            require(_targetGroupIds.length > 0, "Group IDs required");
        }
        
        if (_isRedeemable) {
            require(_pointCost > 0, "Point cost required");
        }
        Discount storage discount = mCodeToDiscount[_code];
        // Check if sensitive fields changed (requires voting)
        bool needsVoting = (
            _discountPercent != discount.discountPercent ||
            _amountMax != discount.amountMax ||
            _pointCost != discount.pointCost ||
            _isRedeemable != discount.isRedeemable
        );
        discount.name = _name;
        discount.discountPercent = _discountPercent;
        discount.desc = _desc;
        discount.from = _from;
        discount.to = _to;
        discount.active = _active;
        discount.imgURL = _imgURL;
        discount.amountMax = _amountMax;
        discount.discountType = _discountType;
        discount.targetGroupIds = _targetGroupIds;
        discount.pointCost = _pointCost;
        discount.isRedeemable = _isRedeemable;
        discount.updatedAt = block.timestamp;
        discount.textDes =  _textDes;
        for(uint i;i<discounts.length;i++){
            if(keccak256(abi.encodePacked(discounts[i].code ))== keccak256(abi.encodePacked(_code))){
                discounts[i] = discount;
            }
        }
        if (address(historyTracking) != address(0)) {
            historyTracking.recordDiscountUpdate(
                _code,
                mCodeToDiscount[_code],
                "Discount updated"
            );
        }
    }
    // // Hàm để member redeem voucher bằng điểm
    // function RedeemVoucher(string memory _code) external returns (bool) {
    //     Discount storage discount = mCodeToDiscount[_code];
        
    //     require(bytes(discount.code).length > 0, "Discount not found");
    //     require(discount.active, "Discount inactive");
    //     require(discount.isRedeemable, "Discount not redeemable");
    //     require(block.timestamp >= discount.from && block.timestamp <= discount.to, "Discount expired");
    //     require(discount.amountUsed < discount.amountMax, "Discount limit reached");
    //     require(!voucherRedeemed[_code][msg.sender], "Already redeemed");
        
    //     // Gọi sang Point contract để trừ điểm
    //     require(address(POINTS) != address(0), "POINTS contract not set yet");
    //     POINTS.redeemVoucherPoints(msg.sender, discount.pointCost);
        
    //     voucherRedeemed[_code][msg.sender] = true;
    //     discount.amountUsed++;
        
    //     return true;
    // }
    function UpdateDiscountCodeUsed(string memory _code)external{
        mCodeToDiscount[_code].amountUsed += 1;
        for(uint i;i<discounts.length;i++){
            if(keccak256(abi.encodePacked(discounts[i].code ))== keccak256(abi.encodePacked(_code))){
                discounts[i] = mCodeToDiscount[_code];
                break;
            }
        }
         // Auto record voucher statistics
        _recordCurrentVoucherStats();
    }
    // Internal helper function
    function _recordCurrentVoucherStats() internal {
        uint totalUsed = 0;
        uint totalExpired = 0;
        uint totalUnused = 0;
        uint currentTime = block.timestamp;
        
        for (uint i = 0; i < discounts.length; i++) {
            Discount memory discount = discounts[i];
            
            totalUsed += discount.amountUsed;
            
            if (discount.to < currentTime) {
                totalExpired += discount.amountMax - discount.amountUsed;
            } else {
                totalUnused += discount.amountMax - discount.amountUsed;
            }
        }
        
        voucherUseHistory.push(VoucherUse({
            time: currentTime,
            amountUsed: totalUsed,
            amountExpired: totalExpired,
            amountUnused: totalUnused
        }));
    }
        // Function for RestaurantOrder to get basic discount info
    // function GetDiscountBasic(string memory code) external view returns (uint discountPercent, bool active, uint amountUsed, uint amountMax, uint from, uint to) {
    //     Discount memory discount = mCodeToDiscount[code];
    //     return (discount.discountPercent, discount.active, discount.amountUsed, discount.amountMax, discount.from, discount.to);
    // }
    function GetDiscountBasic(string memory code) external view returns (
        uint discountPercent, 
        bool active, 
        uint amountUsed, 
        uint amountMax, 
        uint from, 
        uint to,
        DiscountType discountType,
        bytes32[] memory targetGroupIds
    ) {
        Discount memory discount = mCodeToDiscount[code];
        return (
            discount.discountPercent, 
            discount.active, 
            discount.amountUsed, 
            discount.amountMax, 
            discount.from, 
            discount.to,
            discount.discountType,
            discount.targetGroupIds
        );
    }

    // // Lấy danh sách discounts tự động(all+ group) cho user
    // function GetAutoDiscountsForUser(address _user, bytes32 _userGroup) external view returns (Discount[] memory) {
    //     uint count = 0;
        
    //     // Đếm số discounts hợp lệ
    //     for (uint i = 0; i < discounts.length; i++) {
    //         Discount memory d = discounts[i];
    //         if (_isDiscountApplicableForUser(d, _user, _userGroup)) {
    //             count++;
    //         }
    //     }
        
    //     Discount[] memory result = new Discount[](count);
    //     uint index = 0;
        
    //     for (uint i = 0; i < discounts.length; i++) {
    //         Discount memory d = discounts[i];
    //         if (_isDiscountApplicableForUser(d, _user, _userGroup)) {
    //             result[index] = d;
    //             index++;
    //         }
    //     }
        
    //     return result;
    // }

    // function _isDiscountApplicableForUser(
    //     Discount memory d,
    //     address _user,
    //     bytes32 _userGroup
    // ) internal view returns (bool) {
    //     if (!d.active) return false;
    //     if (block.timestamp < d.from || block.timestamp > d.to) return false;
    //     if (d.amountUsed >= d.amountMax) return false;
        
    //     // Check discount type
    //     if (d.discountType == DiscountType.AUTO_ALL) {
    //         return true;
    //     }
        
    //     if (d.discountType == DiscountType.AUTO_GROUP) {
    //         for (uint i = 0; i < d.targetGroupIds.length; i++) {
    //             if (d.targetGroupIds[i] == _userGroup) {
    //                 return true;
    //             }
    //         }
    //     }
        
    //     return false;
    // }
        // Lấy danh sách discounts tự động(all) cho user
    function GetAutoDiscountsTypeAllForUser(address _user) external view returns (Discount[] memory) {
        uint count = 0;
        
        // Đếm số discounts hợp lệ
        for (uint i = 0; i < discounts.length; i++) {
            Discount memory d = discounts[i];
            if (_isDiscountAllApplicableForUser(d, _user)) {
                count++;
            }
        }
        
        Discount[] memory result = new Discount[](count);
        uint index = 0;
        
        for (uint i = 0; i < discounts.length; i++) {
            Discount memory d = discounts[i];
            if (_isDiscountAllApplicableForUser(d, _user)) {
                result[index] = d;
                index++;
            }
        }
        
        return result;
    }

    function _isDiscountAllApplicableForUser(
        Discount memory d,
        address _user
    ) internal view returns (bool) {
        if (!d.active) return false;
        if (block.timestamp < d.from || block.timestamp > d.to) return false;
        if (d.amountUsed >= d.amountMax) return false;
        
        // Check discount type
        if (d.discountType == DiscountType.AUTO_ALL) {
            return true;
        }
        
        return false;
    }

    function GetDiscount(
        string memory _code
    )external view returns(Discount memory){
        return mCodeToDiscount[_code];
    }
    
    function GetAllDiscounts()external view returns(Discount[] memory){
        return discounts;
    }
    function GetAllDiscountsPagination(
        uint256 offset, 
        uint256 limit
    )external view returns(Discount[] memory,uint totalCount)
    {
        if(offset >= discounts.length) {
            return ( new Discount[](0),discounts.length);
        }

        uint256 end = offset + limit;
        if (end > discounts.length) {
            end = discounts.length;
        }

        uint256 size = end - offset;
        Discount[] memory result = new Discount[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = discounts.length - 1 - offset - i;
            result[i] = discounts[reverseIndex];
        }

        return (result,discounts.length);
    }


    function GetVoucherReport(uint fromTime, uint toTime) external view returns (VoucherReport memory) {
        uint totalUsed = 0;
        uint totalUnused = 0;
        uint totalExpired = 0;

        // đếm số lượng voucher hợp lệ trước
        uint count = 0;
        for (uint i = 0; i < discounts.length; i++) {
             // Voucher có giao với [fromTime, toTime] nếu:
            // - Bắt đầu trước/trong khoảng thời gian VÀ
            // - Kết thúc sau/trong khoảng thời gian
            if (discounts[i].from <= toTime && discounts[i].to >= fromTime) {
                count++;
            }
        }

        VoucherDetail[] memory details = new VoucherDetail[](count);
        uint index = 0;

        for (uint i = 0; i < discounts.length; i++) {
            Discount memory discount = discounts[i];
            if (discount.from <= toTime && discount.to >= fromTime) {
                uint expired = 0;
                uint unused = 0;

                if (discount.to < block.timestamp) {
                    expired = discount.amountMax - discount.amountUsed;
                } else {
                    unused = discount.amountMax - discount.amountUsed;
                }

                details[index] = VoucherDetail({
                    code: discount.code,
                    name: discount.name,
                    amountUsed: discount.amountUsed,
                    amountExpired: expired,
                    amountUnused: unused,
                    amountMax: discount.amountMax
                });
                index++;

                totalUsed += discount.amountUsed;
                totalExpired += expired;
                totalUnused += unused;
            }
        }

        return VoucherReport({
            totalUsed: totalUsed,
            totalUnused: totalUnused,
            totalExpired: totalExpired,
            details: details
        });
    }
    function GetVoucherStats() external view returns (uint totalUsed, uint totalMax, uint totalActive) {
        uint used = 0;
        uint maxAmount = 0;
        uint active = 0;
        
        for (uint i = 0; i < discounts.length; i++) {
            used += discounts[i].amountUsed;
            maxAmount += discounts[i].amountMax;
            if (discounts[i].active) {
                active++;
            }
        }
        return (used, maxAmount, active);
    }

    function GetVoucherUseHistory(uint offset, uint limit) external view returns(VoucherUse[] memory voucherUseArr,uint totalCount){
        uint256 length = voucherUseHistory.length;
        // require(offset < length, "offset out of range");
        totalCount = length;
        // Nếu offset >= length, trả về mảng rỗng
        if (offset >= length) {
            return (new VoucherUse[](0), totalCount);
        }
        uint256 end = offset + limit;
        if (end > length) {
            end = length;
        }

        uint256 size = end - offset;
        voucherUseArr = new VoucherUse[](size);

        for (uint256 i = 0; i < size; i++) {
            voucherUseArr[i] = voucherUseHistory[offset +i];
        }
        return (voucherUseArr,totalCount);
    }

    function GetDishCount() external view returns (uint) {
        return allDishCodes.length;
    }

    // Helper functions
    function _getDay(uint timestamp) internal pure returns (uint) {
        return timestamp / 86400;
    }
    
    function _getMonth(uint timestamp) internal pure returns (uint) {
        return timestamp / (86400 * 30);
    }
    // Digital Menu Management 
    function CreateDigitalMenu(
        string memory _linkImg,
        string memory _title
    ) external onlyRole(ROLE_ADMIN){
        uint256 newId = digitalMenu.length + 1;
        digitalMenu.push(DigitalMenu(newId,_linkImg,_title));
    }
    function RemoveDigitalMenu(uint256 id) external onlyRole(ROLE_ADMIN) {
        uint256 index = findDigitalMenuIndex(id);
        require(index < digitalMenu.length, "Digital menu not found");
        
        digitalMenu[index] = digitalMenu[digitalMenu.length-1];
        digitalMenu.pop();
    }
    function getDigitalMenu() external view returns(DigitalMenu[] memory){
        return digitalMenu;
    }
    function getADigitalMenu(uint256 id) external view returns(DigitalMenu memory) {
        uint256 index = findDigitalMenuIndex(id);
        require(index < digitalMenu.length, "Digital menu not found");
        return digitalMenu[index];
    }
    function findDigitalMenuIndex(uint256 id) internal view returns(uint256) {
        for (uint256 i = 0; i < digitalMenu.length; i++) {
            if (digitalMenu[i].id == id) {
                return i;
            }
        }
        return digitalMenu.length; // Return invalid index if not found
    }
    //Banner Management
    function CreateBanner(
        string memory _name,
        string memory _linkImg,
        string memory _description,
        string memory _linkTo,
        bool active,
        uint from,
        uint to,
        BannerPosition _location,
        LinkBannerType _type
    ) external onlyRole(ROLE_ADMIN) returns(uint256){
        if(_type == LinkBannerType.WRITING){ 
            require(bytes(_description).length >0,"this banner type need description");
        }else{
             require(bytes(_description).length == 0,"this banner type has no description");
        }
        uint256 newId = banners.length + 1;
        banners.push(Banner(newId,_name,_linkImg,_description,_linkTo,active,from, to,_location));
        return newId;
    }
    function RemoveBanner(uint256 id) external onlyRole(ROLE_ADMIN) {
        uint256 index = findBannerIndex(id);
        require(index < banners.length, "Banner not found");
        
        banners[index] = banners[banners.length-1];
        banners.pop();
    }
    function UpdateBanner(
        string memory _name,
        string memory _linkImg,
        string memory _description,
        string memory _linkTo,
        bool _active,
        uint _from,
        uint _to,
        BannerPosition _location,
        uint256 id
    ) external onlyRole(ROLE_ADMIN) isActive {
        uint256 index = findBannerIndex(id);
        require(index < banners.length, "Banner not found");
        
        Banner storage banner = banners[index];
        if (bytes(_name).length != 0) {
            banner.name = _name;
        }
        if (bytes(_linkImg).length != 0) {
            banner.linkImg = _linkImg;
        }   
        if (bytes(_description).length != 0) {
            banner.description = _description;
        }   
        if (bytes(_linkTo).length != 0) {
            banner.linkTo = _linkTo;
        }
        if(_from >0){
            banner.from = _from;
        }  
        if(_to >0){
            banner.to = _to;
        }
        banner.active = _active; 
        banner.location = _location;
    }
    function getBanners() external view returns(Banner[] memory){
        return banners;
    }
    function GetBannersPagination(uint256 offset, uint256 limit)
        external
        view
        returns (Banner[] memory result,uint totalCount)
    {
        if(offset >= banners.length) {
            return ( new Banner[](0),banners.length);
        }

        uint256 end = offset + limit;
        if (end > banners.length) {
            end = banners.length;
        }

        uint256 size = end - offset;
        result = new Banner[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = banners.length - 1 - offset - i;
            result[i] = banners[reverseIndex];
        }

        return (result,banners.length);
    }

    function getABanner(uint256 id) external view returns(Banner memory) {
        uint256 index = findBannerIndex(id);
        require(index < banners.length, "Banner not found");
        return banners[index];
    }

    function findBannerIndex(uint256 id) internal view returns(uint256) {
        for (uint256 i = 0; i < banners.length; i++) {
            if (banners[i].id == id) {
                return i;
            }
        }
        return banners.length; // Return invalid index if not found
    }
    //TC Management
    function CreateTC(
        string memory _title,
        string memory _content,
        TCStatus status
    ) external onlyAdminAndRole(STAFF_ROLE.TC_MANAGE) returns(uint256) {
        uint256 newId = tcs.length + 1;
        // if (hasRole(ROLE_ADMIN, msg.sender)) {
        //     tcs.push(TCInfo(newId, _title, _content, TCStatus.APPLIED));
        // } else {
        //     tcs.push(TCInfo(newId, _title, _content, TCStatus.WAITTING_APPLY));
        // }
        tcs.push(TCInfo(newId, _title, _content, status));

        return newId;
    }

    function RemoveTC(uint256 id) external onlyAdminAndRole(STAFF_ROLE.TC_MANAGE) {
        uint256 index = findTCIndex(id);
        require(index < tcs.length, "TC not found");
        
        tcs[index] = tcs[tcs.length - 1];
        tcs.pop();
    }

    function UpdateTC(
        string memory _title,
        string memory _content,
        TCStatus _status,        
        uint256 id
    ) external onlyAdminAndRole(STAFF_ROLE.TC_MANAGE) isActive{
        uint256 index = findTCIndex(id);
        require(index < tcs.length, "TC not found");
        
        TCInfo storage tc = tcs[index];
        if (bytes(_title).length != 0) {
            tc.title = _title;
        }
        if (bytes(_content).length != 0) {
            tc.content = _content;
        }  
        if (tc.status != _status) {
            tc.status = _status;
        }
    }

    function getTcs() external view returns(TCInfo[] memory) {
        return tcs;
    }
    function getTcsPagination(uint256 offset, uint256 limit)
        external
        view
        returns (TCInfo[] memory result,uint totalCount)
    {
        if(offset >= tcs.length) {
            return ( new TCInfo[](0),tcs.length);
        }

        uint256 end = offset + limit;
        if (end > tcs.length) {
            end = tcs.length;
        }

        uint256 size = end - offset;
        result = new TCInfo[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = tcs.length - 1 - offset - i;
            result[i] = tcs[reverseIndex];
        }

        return (result,tcs.length);
    }

    function getATC(uint256 id) external view returns(TCInfo memory) {
        uint256 index = findTCIndex(id);
        require(index < tcs.length, "TC not found");
        return tcs[index];
    }

    function findTCIndex(uint256 id) internal view returns(uint256) {
        for (uint256 i = 0; i < tcs.length; i++) {
            if (tcs[i].id == id) {
                return i;
            }
        }
        return tcs.length; // Return invalid index if not found
    }
    //Worrking Shift Management
    function CreateWorkingShift(
        string memory _title,
        uint256 from,   //số giây tính từ 0h ngày hôm đó. vd 08:00 là 8*3600=28800
        uint256 to
    ) external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) isActive returns(uint256){
        uint256 shiftId = workingShifts.length + 1;
        workingShifts.push(WorkingShift(_title,from,to,shiftId));
        return shiftId;
    }
    function RemoveWorkingShift(uint256 id) external isActive onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) {
        uint256 index = findWorkingShiftIndex(id);
        require(index < workingShifts.length, "Working shift not found");
        
        workingShifts[index] = workingShifts[workingShifts.length - 1];
        workingShifts.pop();
    }

    function UpdateWorkingShift(
        string memory _title,
        uint256 from,  
        uint256 to,
        uint256 id
    ) external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) isActive {
        uint256 index = findWorkingShiftIndex(id);
        require(index < workingShifts.length, "Working shift not found");
        
        WorkingShift storage ws = workingShifts[index];
        if (bytes(_title).length != 0) {
            ws.title = _title;
        }
        if (from != 0) {
            ws.from = from;
        }
        if (to != 0) {
            ws.to = to;
        }
    }

    function getWorkingShifts() external view returns(WorkingShift[] memory) {
        return workingShifts;
    }
    function GetWorkingShiftsPagination(uint256 offset, uint256 limit)
        external
        view
        returns (WorkingShift[] memory result,uint totalCount)
    {
        if(offset >= workingShifts.length) {
            return ( new WorkingShift[](0),workingShifts.length);
        }

        uint256 end = offset + limit;
        if (end > workingShifts.length) {
            end = workingShifts.length;
        }

        uint256 size = end - offset;
        result = new WorkingShift[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = workingShifts.length - 1 - offset - i;
            result[i] = workingShifts[reverseIndex];
        }

        return (result,workingShifts.length);
    }

    function getAWorkingShift(uint256 id) external view returns(WorkingShift memory) {
        uint256 index = findWorkingShiftIndex(id);
        require(index < workingShifts.length, "Working shift not found");
        return workingShifts[index];
    }

    function findWorkingShiftIndex(uint256 id) internal view returns(uint256) {
        for (uint256 i = 0; i < workingShifts.length; i++) {
            if (workingShifts[i].shiftId == id) {
                return i;
            }
        }
        return workingShifts.length; // Return invalid index if not found
    }

    // Uniform Management
    function CreateUniform(
        string memory name,
        string memory linkImgFront,
        string memory linkImgBack
    ) external onlyRole(ROLE_ADMIN) returns(uint256) {
        uint256 newId = uniforms.length + 1;
        uniforms.push(Uniform(newId, name, linkImgFront, linkImgBack));
        return newId;
    }

    function UpdateUniform(
        string memory name,
        string memory linkImgFront,
        string memory linkImgBack,
        uint256 id
    ) external onlyRole(ROLE_ADMIN) {
        uint256 index = findUniformIndex(id);
        require(index < uniforms.length, "Uniform not found");
        
        Uniform storage u = uniforms[index];
        if (bytes(name).length != 0) {
            u.name = name;
        }
        if (bytes(linkImgFront).length != 0) {
            u.linkImgFront = linkImgFront;
        }
        if (bytes(linkImgBack).length != 0) {
            u.linkImgBack = linkImgBack;
        }
    }

    function RemoveUniform(uint256 id) external onlyRole(ROLE_ADMIN) {
        uint256 index = findUniformIndex(id);
        require(index < uniforms.length, "Uniform not found");
        
        uniforms[index] = uniforms[uniforms.length-1];
        uniforms.pop();
    }

    function getUniforms() external view returns(Uniform[] memory) {
        return uniforms;
    }
    function GetUniformsPagination(uint256 offset, uint256 limit)
        external
        view
        returns (Uniform[] memory result,uint totalCount)
    {
        if(offset >= uniforms.length) {
            return ( new Uniform[](0),uniforms.length);
        }

        uint256 end = offset + limit;
        if (end > uniforms.length) {
            end = uniforms.length;
        }

        uint256 size = end - offset;
        result = new Uniform[](size);

        for (uint256 i = 0; i < size; i++) {
            uint256 reverseIndex = uniforms.length - 1 - offset - i;
            result[i] = uniforms[reverseIndex];
        }

        return (result,uniforms.length);
    }


    function getAUniform(uint256 id) external view returns(Uniform memory) {
        uint256 index = findUniformIndex(id);
        require(index < uniforms.length, "Uniform not found");
        return uniforms[index];
    }

    function findUniformIndex(uint256 id) internal view returns(uint256) {
        for (uint256 i = 0; i < uniforms.length; i++) {
            if (uniforms[i].id == id) {
                return i;
            }
        }
        return uniforms.length; // Return invalid index if not found
    }   
     function setLinkGG(string memory _linkGG) external onlyRole(ROLE_ADMIN){
        linkGG = _linkGG;
    }
    function _getRoleHash(STAFF_ROLE role) public view returns (bytes32) {
        if (role == STAFF_ROLE.UPDATE_STATUS_DISH) {
            return ROLE_HASH_STATUS_ORDER;
        }
        if (role == STAFF_ROLE.PAYMENT_CONFIRM) {
            return ROLE_HASH_PAYMENT_CONFIRM;
        }
        if (role == STAFF_ROLE.TC_MANAGE) {
            return ROLE_HASH_UPDATE_TC;
        }
        if (role == STAFF_ROLE.TABLE_MANAGE) {
            return ROLE_HASH_TABLE_MANAGE;
        }
        if (role == STAFF_ROLE.MENU_MANAGE) {
            return ROLE_HASH_MENU_MANAGE;
        }
        if (role == STAFF_ROLE.STAFF_MANAGE) {
            return ROLE_HASH_STAFF_MANAGE;
        }
        if (role == STAFF_ROLE.FINANCE) {
            return ROLE_HASH_FINANCE;
        }
        if (role == STAFF_ROLE.ACCOUNT_MANAGE) {
            return ROLE_HASH_ACCOUNT_MANAGE;
        }
        if (role == STAFF_ROLE.PC_MANAGE) {
            return ROLE_HASH_PC_MANAGE;
        }
        revert(
            '{"from": "Mananagement.sol","msg": "Position id invalid"}'
        );
    }
    //Position
    function CreatePosition(string memory _name, STAFF_ROLE[] memory _roles)external onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE){
        require(bytes(_name).length != 0,"name is empty");
        require(_roles.length > 0,"roles is empty");
        require(bytes(mPosition[_name].name).length == 0,"position existed");
        mPosition[_name].id = positions.length + 1;
        mPosition[_name].name = _name;
        mPosition[_name].positionRoles = _roles;
        positions.push(mPosition[_name]);
    }

    // Hàm lấy thông tin position theo tên
    function GetPosition(string memory _name) 
        external 
        view 
        returns (uint256 id, string memory name, STAFF_ROLE[] memory positionRoles) 
    {
        require(bytes(_name).length > 0, "name is empty");
        require(bytes(mPosition[_name].name).length > 0, "position not found");
        
        Position memory pos = mPosition[_name];
        return (pos.id, pos.name, pos.positionRoles);
    }

    // Hàm lấy thông tin position theo ID
    function GetPositionById(uint256 _id) 
        external 
        view 
        returns (uint256 id, string memory name, STAFF_ROLE[] memory positionRoles) 
    {
        require(_id > 0 && _id <= positions.length, "invalid position id");
        
        Position memory pos = positions[_id - 1]; // vì id bắt đầu từ 1
        return (pos.id, pos.name, pos.positionRoles);
    }

    // Hàm lấy tất cả positions
    function GetAllPositions() 
        external 
        view 
        returns (Position[] memory) 
    {
        return positions;
    }

    // Hàm kiểm tra position có tồn tại không
    function PositionExists(string memory _name) 
        external 
        view 
        returns (bool) 
    {
        return bytes(mPosition[_name].name).length > 0;
    }

    // Hàm xóa position theo tên
    function RemovePosition(string memory _name) 
        external 
        onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) 
    {
        require(bytes(_name).length > 0, "name is empty");
        require(bytes(mPosition[_name].name).length > 0, "position not found");
        
        uint256 positionId = mPosition[_name].id;
        
        // Xóa khỏi mapping
        delete mPosition[_name];
        
        // Tìm và xóa khỏi array positions
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].id == positionId) {
                // Di chuyển phần tử cuối lên vị trí cần xóa
                positions[i] = positions[positions.length - 1];
                positions.pop();
                break;
            }
        }
        
    }

    // Hàm xóa position theo ID
    function RemovePositionById(uint256 _id) 
        external 
        onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) 
    {
        require(_id > 0 && _id <= positions.length, "invalid position id");
        
        // Tìm position theo ID để lấy tên
        string memory positionName;
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].id == _id) {
                positionName = positions[i].name;
                
                // Xóa khỏi mapping
                delete mPosition[positionName];
                
                // Di chuyển phần tử cuối lên vị trí cần xóa
                positions[i] = positions[positions.length - 1];
                positions.pop();
                break;
            }
        }
        
    }

    // Hàm cập nhật position (bonus)
    function UpdatePosition(string memory _name, STAFF_ROLE[] memory _newRoles) 
        external 
        onlyAdminAndRole(STAFF_ROLE.STAFF_MANAGE) 
    {
        require(bytes(_name).length > 0, "name is empty");
        require(_newRoles.length > 0, "roles is empty");
        require(bytes(mPosition[_name].name).length > 0, "position not found");
        
        // Cập nhật roles trong mapping
        mPosition[_name].positionRoles = _newRoles;
        
        // Cập nhật trong array
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].id == mPosition[_name].id) {
                positions[i].positionRoles = _newRoles;
                break;
            }
        }
        
    }
    // Hàm public để kiểm tra role có được phép cho position không
    function IsRoleAllowedForPosition(string memory _position, STAFF_ROLE _role) 
        external 
        view 
        returns (bool) 
    {
        require(bytes(mPosition[_position].name).length > 0, "position not found");
        
        STAFF_ROLE[] memory positionRoles = mPosition[_position].positionRoles;
        
        for (uint i = 0; i < positionRoles.length; i++) {
            if (positionRoles[i] == _role) {
                return true;
            }
        }
        return false;
    }
    //DishOptions Management
    // ================= CREATE DISH OPTIONS (UPDATED) =================
    function CreateDishOptions(
        // string memory dishCode,
        string memory _optionName,
        string[] memory _featureNames,
        uint256[] memory _featurePrices,
        bool _isCompulsory,
        uint _maximumSelection
    ) external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) returns(bytes32){
        require(bytes(_optionName).length > 0, "option name is required");
        require(_featureNames.length > 0, "features is required");
        require(_featureNames.length == _featurePrices.length, "features and prices length mismatch");
        // require(_maximumSelection > 0, "maximum selection is required");
        require(_isCompulsory == false || _maximumSelection >= 1, "maximum selection must be at least 1 if option is compulsory");
        require(!isOptionNameExist[_optionName],"option name existed");
        require(_maximumSelection <= _featureNames.length," _maximumSelection is over number of features");
        bytes32 _optionId = keccak256(abi.encodePacked(block.timestamp, _optionName));

        DishOption storage newOption = mIdToOption[_optionId];
        newOption.optionId = _optionId;
        newOption.optionName = _optionName;
        newOption.isCompulsory = _isCompulsory;
        newOption.maximumSelection = _maximumSelection;
        
        // Create features with unique IDs
        for (uint i = 0; i < _featureNames.length; i++) {
            bytes32 featureId = keccak256(abi.encodePacked(_optionId, _featureNames[i], i));
            newOption.features.push(OptionFeature({
                featureId: featureId,
                featureName: _featureNames[i],
                featurePrice: _featurePrices[i]
            }));
            // mDishCodeToFeatureIds[dishCode][_optionName].push(featureId);
        }
        allDishOptions.push(newOption);
        allOptionNames.push(_optionName);
        isOptionNameExist[_optionName] = true;
        return _optionId;
    }
    function _batchChooseOption(
        string memory dishCode,
        bytes32[] memory _optionIds
        // bytes32 _featureId
    )internal{
        for (uint i = 0; i < _optionIds.length; i++) {
            _chooseOption(dishCode, _optionIds[i]);
        }
    }
    function _chooseOption(
        string memory dishCode,
        bytes32 _optionId
        // bytes32 _featureId
    )internal{
        string memory _optionName = mIdToOption[_optionId].optionName;
        require(isOptionNameExist[_optionName],"option not found");
        mDishCodeToOptionNames[dishCode].push(_optionName);
        // mDishCodeToFeatureIds[dishCode][_optionName].push(_featureId);
        mDishCodeToOptions[dishCode].push(mIdToOption[_optionId]);
         // add reverse mapping but avoid duplicate
        string[] storage dishList = mOptionIdToDishCodes[_optionId];
        bool exists = false;
        for (uint i = 0; i < dishList.length; i++) {
            if (keccak256(bytes(dishList[i])) == keccak256(bytes(dishCode))) {
                exists = true;
                break;
            }
        }
        if (!exists) {
            mOptionIdToDishCodes[_optionId].push(dishCode);
        }
    }
    // function getFeatureIdsAFromDishCode(
    //     string memory dishCode,
    //     string memory _optionName
    // ) external view returns(bytes32[] memory){
    //     return  mDishCodeToFeatureIds[dishCode][_optionName];
    // }
    function getOptionNamesFromDishCode(string memory dishCode) public view returns(string[] memory){
        return mDishCodeToOptionNames[dishCode];
    }
    // Update DishOption by optionId
    function updateDishOption(
        // string memory _dishCode,
        bytes32 _optionId,
        string memory _optionName,
        string[] memory _featureNames,
        uint256[] memory _featurePrices,
        bool _isCompulsory,
        uint _maximumSelection
    ) external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) {
        // require(bytes(_optionName).length > 0, "option name is required");
        // require(_featureNames.length > 0, "features is required");   
        require(_featureNames.length == _featurePrices.length, "features and prices length mismatch");
        require(_maximumSelection > 0, "maximum selection is required");
        require(!_isCompulsory || _maximumSelection >= 1, "max selection at least 1 if compulsory");
        
        DishOption storage dishOption = mIdToOption[_optionId];
        require(dishOption.optionId != bytes32(0), "DishOption not found");

        string memory oldNameOption = dishOption.optionName;
        require(bytes(oldNameOption).length > 0,"old option not found");

        if(bytes(_optionName).length > 0 &&
            keccak256(abi.encodePacked(_optionName)) != keccak256(abi.encodePacked(oldNameOption)))
        {
            require(!isOptionNameExist[_optionName],"new option name existed");
            dishOption.optionName = _optionName;
            isOptionNameExist[_optionName] = true;
            isOptionNameExist[oldNameOption] = false;
            for(uint i; i< allOptionNames.length; i++){
                if( keccak256(abi.encodePacked(allOptionNames[i])) == keccak256(abi.encodePacked(oldNameOption))){
                    allOptionNames[i] = _optionName;
                    break;
                }
            }
        }
        dishOption.isCompulsory = _isCompulsory;
        dishOption.maximumSelection = _maximumSelection;
        
        // Reset and rebuild features
        delete dishOption.features;
        if(_featureNames.length > 0) {
            for (uint j = 0; j < _featureNames.length; j++) {
                bytes32 featureId = keccak256(abi.encodePacked(_optionId, _featureNames[j], j));
                dishOption.features.push(OptionFeature({
                    featureId: featureId,
                    featureName: _featureNames[j],
                    featurePrice: _featurePrices[j]
                }));
            }
        }
        for(uint i; i < allDishOptions.length; i++){
            if(allDishOptions[i].optionId == _optionId){
                allDishOptions[i] = dishOption;
                break;
            }
        }
         // ✅ THÊM: Update in all dishes using this option
        string[] memory dishCodes = mOptionIdToDishCodes[_optionId];
        for(uint i = 0; i < dishCodes.length; i++) {
            string memory dishCode = dishCodes[i];
            DishOption[] storage dishOptions = mDishCodeToOptions[dishCode];
            
            // Find and update the option in this dish
            for(uint j = 0; j < dishOptions.length; j++) {
                if(dishOptions[j].optionId == _optionId) {
                    dishOptions[j] = dishOption;
                    break;
                }
            }
            
            // ✅ THÊM: Update option name in mDishCodeToOptionNames if changed
            if(bytes(_optionName).length > 0 &&
                keccak256(abi.encodePacked(_optionName)) != keccak256(abi.encodePacked(oldNameOption)))
            {
                string[] storage optionNames = mDishCodeToOptionNames[dishCode];
                for(uint k = 0; k < optionNames.length; k++) {
                    if(keccak256(abi.encodePacked(optionNames[k])) == keccak256(abi.encodePacked(oldNameOption))) {
                        optionNames[k] = _optionName;
                        break;
                    }
                }
            }
        }
        
    }

        //xoa toan bo option cu, them danh sach option moi
    function BatchAddOptionToDish(
        string memory dishCode,
        bytes32[] memory optionIds
    ) external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) {
        // 1) remove reverse links for existing options
        for (uint i = 0; i < mDishCodeToOptions[dishCode].length; i++) {
            bytes32 oldOptionId = mDishCodeToOptions[dishCode][i].optionId;
            _removeDishFromOptionReverse(oldOptionId, dishCode);
        }
        //delete all old optionIds first
        delete mDishCodeToOptions[dishCode];  
        delete mDishCodeToOptionNames[dishCode];
        //add new optionIds Array
        for(uint i; i < optionIds.length; i++){
            _addOptionToDish(dishCode,optionIds[i]);
        }
    }
    // --- helper: remove dishCode from optionId -> dishCodes list (if present)
    function _removeDishFromOptionReverse(bytes32 optionId, string memory dishCode) internal {
        string[] storage dishCodes = mOptionIdToDishCodes[optionId];
        for (uint i = 0; i < dishCodes.length; i++) {
            if (keccak256(bytes(dishCodes[i])) == keccak256(bytes(dishCode))) {
                dishCodes[i] = dishCodes[dishCodes.length - 1];
                dishCodes.pop();
                break;
            }
        }
    }
    // Thêm hàm helper để thêm option vào dish (sau khi dish đã được tạo)
    function _addOptionToDish(
        string memory dishCode,
        bytes32 optionId
    ) internal {
        require(bytes(mCodeToDish[dishCode].code).length > 0, "Dish not found");
        require(mIdToOption[optionId].optionId != bytes32(0), "Option not found");
        
        string memory optionName = mIdToOption[optionId].optionName;
        
        // ✅ Check xem option đã được thêm vào dish chưa
        string[] storage existingNames = mDishCodeToOptionNames[dishCode];
        for(uint i = 0; i < existingNames.length; i++) {
            require(
                keccak256(abi.encodePacked(existingNames[i])) != keccak256(abi.encodePacked(optionName)),
                "Option already added to this dish"
            );
        }
        
        _chooseOption(dishCode, optionId);
    }


    function getOptionNameFromId(bytes32 _optionId) public view returns(string memory){
        DishOption memory option = mIdToOption[_optionId];
        require(option.optionId != bytes32(0),"dish option not exist");
        return option.optionName;
    }
    function getAllOptionNames()external view returns(string[] memory){
        return allOptionNames;
    }
    // Delete DishOption by optionId
    function DeleteDishOption(bytes32 optionId)
        external
        onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE)
    {
        string memory nameOption = getOptionNameFromId(optionId);
        require(bytes(nameOption).length > 0, "Option not found");

        isOptionNameExist[nameOption] = false;

        bool found = false;
        for (uint i = 0; i < allDishOptions.length; i++) {
            if (allDishOptions[i].optionId == optionId) {
                // xóa phần tử i bằng cách swap với phần tử cuối
                allDishOptions[i] = allDishOptions[allDishOptions.length - 1];
                allDishOptions.pop();
                found = true;
                break;
            }
        }
        require(found, "optionId not found");
        
        found = false;
        for (uint i = 0; i < allOptionNames.length; i++) {
            if (keccak256(abi.encodePacked(allOptionNames[i])) == keccak256(abi.encodePacked(nameOption))) {
                // xóa phần tử i bằng cách swap với phần tử cuối
                allOptionNames[i] = allOptionNames[allOptionNames.length - 1];
                allOptionNames.pop();
                found = true;
                break;
            }
        }
        require(found, "option name not found in allOptionNames");

        string[] memory dishCodes = mOptionIdToDishCodes[optionId];
        for(uint i; i< dishCodes.length; i++){
            if(mDishCodeToOptionNames[dishCodes[i]].length > 0){
                _deleteDishOptionFromDishCode(dishCodes[i],optionId);

            }
        }
        delete mIdToOption[optionId];

    }
    function DeleteDishOptionFromDishCode(string memory dishCode,bytes32 optionId)
        public
        onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE)
        
    {
        _deleteDishOptionFromDishCode(dishCode,optionId);
    }

    function _deleteDishOptionFromDishCode(string memory dishCode,bytes32 optionId)
        internal
    {
        require(mIdToOption[optionId].optionId != bytes32(0), "Option not found");
        string[] storage optionNames = mDishCodeToOptionNames[dishCode];
        string memory optionNameInput = getOptionNameFromId(optionId);
        bool found = false;

        for (uint i = 0; i < optionNames.length; i++) {
            
            if (keccak256(abi.encodePacked(optionNames[i])) == keccak256(abi.encodePacked(optionNameInput))) {
                // xóa phần tử i bằng cách swap với phần tử cuối
                optionNames[i] = optionNames[optionNames.length - 1];
                optionNames.pop();
                found = true;
                break;
            }
        }
        require(found, "option name not found in mDishCodeToOptionNames");

        found = false;
        DishOption[] storage dishOptions = mDishCodeToOptions[dishCode];
        for (uint i = 0; i < dishOptions.length; i++) {
            if (dishOptions[i].optionId == optionId) {
                // xóa phần tử i bằng cách swap với phần tử cuối
                dishOptions[i] = dishOptions[dishOptions.length - 1];
                dishOptions.pop();
                found = true;
                break;
            }
        }
        require(found, "optionId not found");
    }

    function GetDishOptionById(
        bytes32 optionId
    ) public view returns (DishOption memory) {
        return mIdToOption[optionId];
    }
    function GetAllDishOptions() external view returns (DishOption[] memory) {
        return allDishOptions;
    }
    // ------------------- GET ALL PAGINATION -------------------
    function GetAllDishOptionsPagination(
        uint offset,
        uint limit
    ) external view returns (DishOption[] memory, uint totalCount) {
        totalCount = allDishOptions.length;

        if (offset >= totalCount) {
            return (new DishOption[](0) , totalCount);
        }

        uint end = offset + limit;
        if (end > totalCount) end = totalCount;
        uint count = end - offset;

        DishOption[] memory result = new DishOption[](count);
        for (uint i = 0; i < count; i++) {
            uint reverseIndex = totalCount -1 - offset - i;
            result[i] = allDishOptions[reverseIndex];
        }

        return (result, totalCount);
    }

    function GetAllDishOptionsFromDishCode(
        string memory dishCode
    ) external view returns (DishOption[] memory) {
        return mDishCodeToOptions[dishCode];
    }
    function checkShowOption(string memory _dishCode) external view returns(bool){
        if(mDishVariant[_dishCode].length > 1) return true;
        DishOption[] storage allOptions = mDishCodeToOptions[_dishCode];
        if(allOptions.length >= 1) return true;
    }
    function GetAllDishOptionsFromDishCodePagination(
        string memory dishCode,
        uint offset,
        uint limit
    ) external view returns (DishOption[] memory, uint totalCount) {
        DishOption[] storage allOptions = mDishCodeToOptions[dishCode];
        totalCount = allOptions.length;

        if (offset >= totalCount) {
            return (new DishOption[](0) , totalCount);
        }

        uint end = offset + limit;
        if (end > totalCount) end = totalCount;
        uint count = end - offset;

        DishOption[] memory result = new DishOption[](count);
        for (uint i = 0; i < count; i++) {
            uint reverseIndex = totalCount -1 - offset - i;
            result[i] = allOptions[reverseIndex];
        }

        return (result, totalCount);
    }

    function CalculateAndValidateOptions(
        string memory dishCode,
        SelectedOption[] memory selectedOptions
    ) external view returns (uint totalOptionsPrice, OptionSelected[] memory optionsSelected) {
        DishOption[] storage allOptions = mDishCodeToOptions[dishCode];
        // require(allOptions.length > 0, "Dish has no options configured");
        if(allOptions.length == 0){
            return (0, new OptionSelected[](0));
        }
        // Count compulsory options in dish
        uint compulsoryCount = 0;
        for (uint i = 0; i < allOptions.length; i++) {
            if (allOptions[i].isCompulsory) {
                compulsoryCount++;
            }
        }
        
        // If no options selected
        if (selectedOptions.length == 0) {
            require(compulsoryCount == 0, "Missing compulsory options");
            return (0, new OptionSelected[](0));
        }
        
        // Initialize optionsSelected array
        optionsSelected = new OptionSelected[](selectedOptions.length);
        uint selectedCompulsoryCount = 0;
        
        // Validate each selected option
        for (uint i = 0; i < selectedOptions.length; i++) {
            bytes32 optionId = selectedOptions[i].optionId;
            bytes32[] memory featureIds = selectedOptions[i].selectedFeatureIds;
            
            // Check minimum features
            require(featureIds.length > 0, "Option must have at least one feature selected");
            
            // Check duplicate option selection
            _checkDuplicateOption(selectedOptions, i);
            
            // Find and validate option
            DishOption storage currentOption = _findOption(allOptions, optionId);
            
            // Validate and process option
            _validateOptionSelection(currentOption, featureIds);
            
            // Track compulsory
            if (currentOption.isCompulsory) {
                selectedCompulsoryCount++;
            }
            
            // Calculate price and collect feature names
            (uint optionPrice, string[] memory featureNames) = _calculateOptionPrice(
                currentOption,
                featureIds
            );
            
            totalOptionsPrice += optionPrice;
            
            // Build OptionSelected struct
            optionsSelected[i] = OptionSelected({
                optionName: currentOption.optionName,
                selectedFeatureNames: featureNames
            });
        }
        
        // Validate all compulsory options selected
        require(selectedCompulsoryCount == compulsoryCount, "Missing compulsory options");
        
        return (totalOptionsPrice, optionsSelected);
    }

    // Helper function: Check duplicate option
    function _checkDuplicateOption(
        SelectedOption[] memory selectedOptions,
        uint currentIndex
    ) private pure {
        bytes32 currentOptionId = selectedOptions[currentIndex].optionId;
        for (uint i = 0; i < currentIndex; i++) {
            require(
                selectedOptions[i].optionId != currentOptionId,
                "Duplicate option selected"
            );
        }
    }

    // Helper function: Find option in dish
    function _findOption(
        DishOption[] storage allOptions,
        bytes32 optionId
    ) private view returns (DishOption storage) {
        for (uint i = 0; i < allOptions.length; i++) {
            if (allOptions[i].optionId == optionId) {
                require(allOptions[i].features.length > 0, "Option has no features");
                return allOptions[i];
            }
        }
        revert("Option not found in dish");
    }

    // Helper function: Validate option selection
    function _validateOptionSelection(
        DishOption storage option,
        bytes32[] memory featureIds
    ) private view {
        uint featureCount = featureIds.length;
        
        // Check compulsory has at least 1 feature
        if (option.isCompulsory) {
            require(featureCount >= 1, "Compulsory option needs at least 1 feature");
        }
        
        // Check maximum selection
        require(
            featureCount <= option.maximumSelection,
            string(abi.encodePacked(
                "Exceeded maximum selection for option: ",
                option.optionName
            ))
        );
        
        // Check duplicate features
        for (uint i = 0; i < featureCount; i++) {
            for (uint j = 0; j < i; j++) {
                require(
                    featureIds[i] != featureIds[j],
                    "Duplicate feature in same option"
                );
            }
        }
    }

    // Helper function: Calculate price and get feature names
    function _calculateOptionPrice(
        DishOption storage option,
        bytes32[] memory featureIds
    ) private view returns (uint totalPrice, string[] memory names) {
        names = new string[](featureIds.length);
        
        for (uint i = 0; i < featureIds.length; i++) {
            bool found = false;
            
            for (uint j = 0; j < option.features.length; j++) {
                if (option.features[j].featureId == featureIds[i]) {
                    totalPrice += option.features[j].featurePrice;
                    names[i] = option.features[j].featureName;
                    found = true;
                    break;
                }
            }
            
            require(found, string(abi.encodePacked(
                "Invalid feature ID in option: ",
                option.optionName
            )));
        }
        
        return (totalPrice, names);
    }

     // Added 05/01/2026
    /**
     * @dev CalculateOrder - "Source of Truth" để báo giá chính xác
     * @param listItems Danh sách món kèm Variant và Options
     */
    function CalculateOrder(SelectedItemsParams[] memory listItems) 
        public 
        view 
        returns (
            uint256 totalAmount, 
            ItemPriceDetail[] memory detailList
        ) 
    {
        detailList = new ItemPriceDetail[](listItems.length);
        uint256 grandTotal = 0;

        for (uint i = 0; i < listItems.length; i++) {
            string memory dishCode = listItems[i].dishCode;
            uint256 qty = listItems[i].quantity;
            bytes32 variantID = listItems[i].variantID;

            // Lấy giá từ Variant (Size/Loại món chính)
            Variant memory v = mVariant[dishCode][variantID];
            require(v.variantID != bytes32(0), "Variant not found");
            uint256 basePrice = v.dishPrice;

            // Lấy giá từ các Option được chọn (Topping/Side dish) thông qua hàm có sẵn
            (uint256 optionsPrice, ) = this.CalculateAndValidateOptions(dishCode, listItems[i].selectedOptions);

            // Tính tổng cho item
            uint256 finalUnitPrice = basePrice + optionsPrice;
            uint256 itemTotal = finalUnitPrice * qty;

            detailList[i] = ItemPriceDetail({
                productID: dishCode,
                confirmedPrice: finalUnitPrice,
                itemTotal: itemTotal
            });

            grandTotal += itemTotal;
        }

        return (grandTotal, detailList);
    }

    // Cập nhật giá sản phẩm
    function UpdateProductPrice(
        string memory _dishCode, 
        bytes32 _variantID, 
        uint256 _newPrice
    ) external onlyAdminAndRole(STAFF_ROLE.MENU_MANAGE) isActive {
        
        require(isCodeExist[_dishCode], "Dish code does not exist");
        Variant storage targetVar = mVariant[_dishCode][_variantID];
        require(targetVar.variantID != bytes32(0), "Variant not found");

        uint256 oldPrice = targetVar.dishPrice;
        targetVar.dishPrice = _newPrice;

        // Cập nhật snapshot hiển thị
        uint256 indexDish = dishOrderIndex[_dishCode];
        if (indexDish > 0) {
            uint256 idx = indexDish - 1;
            if (dishesWithOrder[idx].variant.variantID == _variantID) {
                dishesWithOrder[idx].variant.dishPrice = _newPrice;
            }
        }

       // Ghi log lịch sử thay đổi 
        if (address(historyTracking) != address(0)) {
            Variant[] memory updatedVariantLog = new Variant[](1);
            updatedVariantLog[0] = mVariant[_dishCode][_variantID];

            string memory detailLog = "Update Price";

            historyTracking.recordDishUpdate(
                _dishCode, 
                mCodeToDish[_dishCode], 
                updatedVariantLog, 
                new Attribute[][](0), 
                detailLog
            );
        }

        emit ProductPriceUpdated( msg.sender, _dishCode, _variantID, _newPrice, block.timestamp);
    }


    
//    function UploadCustomerInfo(
//         string calldata _name,
//         string calldata _imgURL,
//         string calldata _dob,
//         string calldata _gender,
//         string calldata _nationality,
//         int256[] calldata _faceVector
//     ) external returns (bool status, uint256 Customer_ID) {
//         require(_faceVector.length == 128, "Invalid vector");

//         // Lưu Vector dưới dạng Bytes thô
//         bytes memory vectorRaw = abi.encode(_faceVector);

//         // Tính Magnitude
//         uint256 mag = sqrt(calculateSumSq(_faceVector));
        
//         string memory fullJson = string(abi.encodePacked(
//             '{',
//             '"name":"', _name, '",',
//             '"img":"', _imgURL, '",',
//             '"dob":"', _dob, '",',
//             '"gender":"', _gender, '",',
//             '"nat":"', _nationality, '"',
//             '}'
//         ));

//         // Đẩy vào FullDB
//         uint256 docId = dbWrapper.newDocument(DB_NAME, fullJson);
        
//         // Lưu Vector và Magnitude vào các Slot
//         dbWrapper.addValueDocument(DB_NAME, docId, 0, string(vectorRaw), false); // Slot 0: Vector thô
//         dbWrapper.addValueDocument(DB_NAME, docId, 1, uintToString(mag), true); // Slot 1: Magnitude

//         // Lập chỉ mục văn bản 
//         dbWrapper.indexTextForDocument(DB_NAME, docId, _name, 1, "N");
//         dbWrapper.indexTextForDocument(DB_NAME, docId, _nationality, 1, "NAT");
//         dbWrapper.indexTextForDocument(DB_NAME, docId, _gender, 1, "GEN");

//         dbWrapper.commit(DB_NAME);

//         // emit CustomerRegistered(true, docId, _name);
//         return (true, docId);
//     }

    struct CustomerInput {
        string name;
        string imgURL;
        string dob;
        string gender;
        string nationality;
    }

    function UploadCustomerInfo(
        CustomerInput calldata input,
        int256[] calldata _faceVector
    ) external returns (bool status, uint256 Customer_ID) {
        require(_faceVector.length == 128, "Invalid vector");

        bytes memory vectorRaw = abi.encode(_faceVector);

        uint256 mag = sqrt(calculateSumSq(_faceVector));
        
        // Tạo chuỗi JSON - gom các trường từ struct 'input'
        string memory fullJson = string(abi.encodePacked(
            '{"name":"', input.name, 
            '","img":"', input.imgURL, 
            '","dob":"', input.dob, 
            '","gender":"', input.gender, 
            '","nat":"', input.nationality, '"}'
        ));

        // Đẩy vào FullDB
        uint256 docId = dbWrapper.newDocument(DB_NAME, fullJson);
        
        // Lưu Vector và Magnitude vào các Slot
        dbWrapper.addValueDocument(DB_NAME, docId, 0, string(vectorRaw), false);
        dbWrapper.addValueDocument(DB_NAME, docId, 1, uintToString(mag), true);

        // Lập chỉ mục văn bản - sử dụng dữ liệu từ struct
        dbWrapper.indexTextForDocument(DB_NAME, docId, input.name, 1, "N");
        dbWrapper.indexTextForDocument(DB_NAME, docId, input.nationality, 1, "NAT");
        dbWrapper.indexTextForDocument(DB_NAME, docId, input.gender, 1, "GEN");

        dbWrapper.commit(DB_NAME);

        return (true, docId);
    }

    // function SearchCustomerByVector(int256[] calldata queryVector) 
    //     public 
    //     returns (
    //         uint256[3] memory Customer_ID, 
    //         string[3] memory Names, 
    //         int256[3] memory Similarity_Scores,
    //         string[3] memory Img_URL
    //     ) 
    // {
    //     require(queryVector.length == 128, "Query vector invalid");
    //     uint256 qMag = sqrt(calculateSumSq(queryVector));
    //     if (qMag == 0) return (Customer_ID, Names, Similarity_Scores, Img_URL);

    //     // Dùng struct để giải phóng stack
    //     SearchTopResult memory res;

    //     // Giới hạn phạm vi biến bằng block {}
    //     SearchParams memory params;
    //     {
    //         uint256 margin = qMag / 10;
    //         params.queries = ""; 
    //         params.offset = 0;
    //         params.limit = 1000;
    //         params.sortByValueSlot = -1;
    //         params.rangeFilters = new RangeFilter[](1);
    //         params.rangeFilters[0] = RangeFilter({
    //             slot: 1, 
    //             startSerialised: uintToString((qMag > margin) ? qMag - margin : 0),
    //             endSerialised: uintToString(qMag + margin)
    //         });
    //     }

    //     SearchResultsPage memory page = dbWrapper.querySearch(DB_NAME, params);
    //     uint256 len = page.results.length;

    //     for (uint256 i = 0; i < len; i++) {
    //         uint256 currentDocId = page.results[i].docid;
    //         uint256 pMag = stringToUint(dbWrapper.getValueDocument(DB_NAME, currentDocId, 1, true));
    //         if (pMag == 0) continue;

    //         bytes memory rawVector = bytes(dbWrapper.getValueDocument(DB_NAME, currentDocId, 0, false));
    //         if (rawVector.length < 4160) continue;
            
    //         int256 dotProduct;
    //         assembly ("memory-safe") {
    //             let qPtr := queryVector.offset
    //             let tPtr := add(rawVector, 0x40)
    //             for { let j := 0 } lt(j, 128) { j := add(j, 1) } {
    //                 dotProduct := add(dotProduct, mul(calldataload(add(qPtr, mul(j, 0x20))), mload(add(tPtr, mul(j, 0x20)))))
    //             }
    //         }

    //         uint256 denom = qMag * pMag;
    //         if (denom > 0) {
    //             int256 score = (dotProduct * 1000000) / int256(denom);
    //             if (score >= 700000) {
    //                 _updateTop3(res, score, page.results[i].data, currentDocId);
    //             }
    //         }
    //     }
    //     return (res.ids, res.names, res.scores, res.imgs);
    // }


    function SearchCustomerByVector(int256[] calldata queryVector) 
        public 
        returns (SearchTopResult memory res) 
    {
        require(queryVector.length == 128, "Query vector invalid");
        uint256 qMag = sqrt(calculateSumSq(queryVector));
        if (qMag == 0) return res;

        // Lấy kết quả từ DB
        SearchResultsPage memory page;
        {
            SearchParams memory params;
            uint256 margin = qMag / 10;
            params.limit = 1000;
            params.rangeFilters = new RangeFilter[](1);
            params.rangeFilters[0] = RangeFilter({
                slot: 1, 
                startSerialised: uintToString((qMag > margin) ? qMag - margin : 0),
                endSerialised: uintToString(qMag + margin)
            });
            page = dbWrapper.querySearch(DB_NAME, params);
        }

        // Duyệt loop
        for (uint256 i = 0; i < page.results.length; i++) {
            // Thay vì dùng struct Item, ta truyền thẳng ID và Data vào hàm phụ
            _evaluateSimilarity(
                res, 
                page.results[i].docid, 
                page.results[i].data, 
                queryVector, 
                qMag
            );
        }

        return res;
    }

    function _evaluateSimilarity(
        SearchTopResult memory res,
        uint256 currentDocId,
        string memory jsonData,
        int256[] calldata queryVector,
        uint256 qMag
    ) internal {
        // Lấy pMag từ slot 1
        uint256 pMag = stringToUint(dbWrapper.getValueDocument(DB_NAME, currentDocId, 1, true));
        if (pMag == 0) return;

        // Lấy vector từ slot 0
        bytes memory rawVector = bytes(dbWrapper.getValueDocument(DB_NAME, currentDocId, 0, false));
        if (rawVector.length < 4160) return;

        int256 dotProduct;
        assembly ("memory-safe") {
            let qPtr := queryVector.offset
            let tPtr := add(rawVector, 0x40)
            for { let j := 0 } lt(j, 128) { j := add(j, 1) } {
                dotProduct := add(dotProduct, mul(calldataload(add(qPtr, mul(j, 0x20))), mload(add(tPtr, mul(j, 0x20)))))
            }
        }

        uint256 denom = qMag * pMag;
        if (denom > 0) {
            int256 score = (dotProduct * 1000000) / int256(denom);
            if (score >= 700000) {
                // Cập nhật top 3
                _updateTop3(res, score, jsonData, currentDocId);
            }
        }
    }

    function stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
                result = result * 10 + (uint8(b[i]) - 48);
            }
        }
        return result;
    }

    function calculateSumSq(int256[] calldata _vector) internal pure returns (uint256) {
        uint256 sumSq = 0;
        for (uint256 i = 0; i < 128; i++) {
            int256 val = _vector[i];
            sumSq += uint256(val * val);
        }
        return sumSq;
    }

    // Hàm hỗ trợ chuyển số nguyên sang chuỗi
    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    

    // Thêm hàm tính căn bậc hai để tính độ dài Vector
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }


    function _updateTop3(
        SearchTopResult memory res,
        int256 score,
        string memory jsonData,
        uint256 docId
    ) internal pure {
        if (score > res.scores[0]) {
            res.scores[2] = res.scores[1]; res.names[2] = res.names[1]; res.ids[2] = res.ids[1]; res.imgs[2] = res.imgs[1];
            res.scores[1] = res.scores[0]; res.names[1] = res.names[0]; res.ids[1] = res.ids[0]; res.imgs[1] = res.imgs[0];
            res.scores[0] = score;
            res.ids[0] = docId;
            res.names[0] = parseField(jsonData, "name");
            res.imgs[0] = parseField(jsonData, "img");
        } else if (score > res.scores[1]) {
            res.scores[2] = res.scores[1]; res.names[2] = res.names[1]; res.ids[2] = res.ids[1]; res.imgs[2] = res.imgs[1];
            res.scores[1] = score;
            res.ids[1] = docId;
            res.names[1] = parseField(jsonData, "name");
            res.imgs[1] = parseField(jsonData, "img");
        } else if (score > res.scores[2]) {
            res.scores[2] = score;
            res.ids[2] = docId;
            res.names[2] = parseField(jsonData, "name");
            res.imgs[2] = parseField(jsonData, "img");
        }
    }

    function parseField(string memory json, string memory field) internal pure returns (string memory) {
        bytes memory b = bytes(json);
        // Tạo từ khóa tìm kiếm, ví dụ: "name":"
        bytes memory key = abi.encodePacked('"', field, '":"');
        uint256 bLen = b.length;
        uint256 kLen = key.length;

        for (uint256 i = 0; i <= bLen - kLen; ) {
            bool matchFound = true;
            for (uint256 j = 0; j < kLen; ) {
                if (b[i + j] != key[j]) {
                    matchFound = false;
                    break;
                }
                unchecked { j++; }
            }

            if (matchFound) {
                uint256 start = i + kLen;
                uint256 len = 0;
                // Tìm dấu ngoặc kép kết thúc "
                while (start + len < bLen && b[start + len] != '"') {
                    unchecked { len++; }
                }
                
                bytes memory val = new bytes(len);
                for (uint256 j = 0; j < len; ) {
                    val[j] = b[start + j];
                    unchecked { j++; }
                }
                return string(val);
            }
            unchecked { i++; }
        }
        return "";
    }

    function connectToDB(address _db) external onlyOwner { 
        // if (address(dbWrapper) == _db) return;

        require(_db != address(0), "Invalid address");
        
        dbWrapper = PublicfullDB(_db);
        dbWrapper.getOrCreateDb(DB_NAME);
    }

    // Added 22/01/2026
    // gộp bàn
    function _updateTableStatusForReservation(
        uint256[] memory _numbers, 
        bytes32 sessionId, 
        // uint256 _numPeople, 
        TABLE_STATUS _status
    ) internal {
        // uint256 totalPeople = 0;
        // if (_status != TABLE_STATUS.AVAILABLE) {
        //     for (uint i = 0; i < _numbers.length; i++) {
        //         totalPeople += mNumberToTable[_numbers[i]].numPeople;
        //     }

        //     // Nếu là trạng thái đặt bàn, phải đủ chỗ cho đoàn khách
        //     require(_numPeople <= totalPeople, "Not enough storage space");
        // }


        // uint256 remainingPeople = _numPeople;

        for (uint i = 0; i < _numbers.length; i++) {
            uint256 tableNum = _numbers[i];
            Table storage table = mNumberToTable[tableNum]; 
            require(table.number != 0, "Table not found");
            
            if (_status == TABLE_STATUS.AVAILABLE) {
                table.status = _status;
                delete table.sessionIds;
                // table.occupiedSeats = 0;
            } else {
                if(i == 0) 
                {
                    table.status = _status;
                    if (sessionId != bytes32(0)) {
                        table.sessionIds.push(sessionId);
                    }
                }
                else {
                    table.parentTableId = _numbers[0];
                    table.status = TABLE_STATUS.MERGED;
                }
                // if (remainingPeople > 0) {
                //     if (remainingPeople >= table.numPeople) {
                //         table.occupiedSeats = table.numPeople; // Bàn này đầy
                //         remainingPeople -= table.numPeople;
                //     } else {
                //         table.occupiedSeats = remainingPeople; // Bàn này nhận nốt số lẻ
                //         remainingPeople = 0;
                //     }
                // } else {
                //     table.occupiedSeats = 0; 
                // }
               
            }
            _syncIndividualTable(tableNum);
        }
    }

    // Hàm helper để tránh lặp code và tiết kiệm Gas
    function _syncIndividualTable(uint256 _num) internal {
        Table storage t = mNumberToTable[_num];
        
        // Cập nhật mảng tổng
        {
            uint len = tables.length;
            for(uint i = 0; i < len; i++) {
                if(tables[i].number == _num) {
                    tables[i] = t;
                    break;
                }
            }
        }

        // Cập nhật mảng khu vực
        {
            uint areaId = mTableToAreaId[_num];
            uint areaLen = mAreaToTable[areaId].length;
            for (uint i = 0; i < areaLen; i++) {
                if (mAreaToTable[areaId][i].number == _num) {
                    mAreaToTable[areaId][i] = t;
                    break;
                }
            }
        }
    }

    // check đủ chỗ ngồi k trước khi cho quét gọi món
    function isSessionAvailable(uint tableId, uint _numPeople) external view onlyOrder returns(bool) {
        Table memory table = mNumberToTable[tableId];
        if((table.numPeople - table.occupiedSeats) >= _numPeople)
            return true;
        return false;
    }

    // function mergeTables(uint256[] memory _tableNumbers,bytes32 _sessionId,uint256 _numPeople, TABLE_STATUS _status) external onlyOrder {
    function mergeTables(uint256[] memory _tableNumbers,bytes32 _sessionId, TABLE_STATUS _status) external onlyOrder {

        // require(_tableNumbers.length > 1, "At least two tables are needed to assemble them.");

        // Truyền nguyên mảng bàn vào để hàm tự phân bổ chỗ ngồi
        _updateTableStatusForReservation(
            _tableNumbers, 
            _sessionId, 
            // _numPeople, 
            _status
        );

    }

    //  function mergeMoreTables(uint256[] memory _tableNumbers, uint256 tableParent,uint256 _numPeople) external onlyOrder {
     function mergeMoreTables(uint256[] memory _tableNumbers, uint256 tableParent) external onlyOrder {

        // uint256 remainingPeople = _numPeople;
         for (uint i = 0; i < _tableNumbers.length; i++) {
            uint256 tableNum = _tableNumbers[i];
            Table storage table = mNumberToTable[tableNum]; 
            require(table.number != 0, "Table not found");
            require(table.status == TABLE_STATUS.AVAILABLE, "Table not available");
            
            table.status = TABLE_STATUS.MERGED;
            table.parentTableId = tableParent;

            // if (remainingPeople > 0) {
            //     if (remainingPeople >= table.numPeople) {
            //         table.occupiedSeats = table.numPeople;
            //         remainingPeople -= table.numPeople;
            //     } else {
            //         table.occupiedSeats = remainingPeople; 
            //         remainingPeople = 0;
            //     }
            // } else {
            //     table.occupiedSeats = 0; 
            // }
            _syncIndividualTable(tableNum);
        }

    }

    function separateTables(uint256[] memory _numbers) external onlyOrder {

        // Gọi lại hàm update với trạng thái AVAILABLE
        // sessionId truyền bytes32(0), số người truyền 0
        _updateTableStatusForReservation(
            _numbers, 
            bytes32(0), 
            // 0, 
            TABLE_STATUS.AVAILABLE
        );
    }   

    function transferTable(uint256 _fromTable, uint256 _toTable) external onlyOrder {
        // require(checkRole(STAFF_ROLE.TABLE_MANAGE, msg.sender), "Only staff can transfer");

        Table storage oldTable = mNumberToTable[_fromTable];
        Table storage newTable = mNumberToTable[_toTable];

        require(oldTable.number != 0 && newTable.number != 0, "Table not found");
        require(oldTable.number != newTable.number, "New table must be different");
        // require(
        //     newTable.numPeople >= (newTable.occupiedSeats + oldTable.occupiedSeats), 
        //     "There aren't enough seats."
        // );

        // dữ liệu sang bàn mới
        newTable.status = oldTable.status;
        // newTable.occupiedSeats = newTable.occupiedSeats + oldTable.occupiedSeats;
        newTable.parentTableId = oldTable.parentTableId;
        // newTable.sessionIds = oldTable.sessionIds;
        uint256 sessionLength = oldTable.sessionIds.length;
        for (uint256 i = 0; i < sessionLength; i++) {
            newTable.sessionIds.push(oldTable.sessionIds[i]);
        }

        // GIẢI PHÓNG BÀN CŨ & ĐẶT TRẠNG THÁI BẢO TRÌ
        delete oldTable.sessionIds;
        // oldTable.occupiedSeats = 0;
        oldTable.parentTableId = 0;
        oldTable.status = TABLE_STATUS.BLOCKED; // Khóa bàn cũ để sửa

        // ĐỒNG BỘ CẢ 2 BÀN (Cập nhật mảng tables và mAreaToTable)
        _syncIndividualTable(_fromTable);
        _syncIndividualTable(_toTable);
    }

    function updateTableFromOrder(
        uint256 _tableNumber, 
        bytes32 sessionId
        // uint256 _numPeople
    ) external onlyOrder {
        Table storage table = mNumberToTable[_tableNumber];
        require(table.number != 0, "Table not found");

        // uint count = table.occupiedSeats + _numPeople;
        // table.status = count == table.numPeople ? TABLE_STATUS.FULL : TABLE_STATUS.ACTIVE;
        table.status = TABLE_STATUS.ACTIVE;
        // table.occupiedSeats += _numPeople;
        
        if (sessionId != bytes32(0)) {
            table.sessionIds.push(sessionId);
        }
        _syncIndividualTable(_tableNumber);
    }

    // hàm chỉ dành cho các bàn đã dc merge + reserved
    function checkSessionIdFromTableMerge(uint256 tableNum) external view returns(bytes32) {
        Table memory table = mNumberToTable[tableNum];
        require(table.number != 0, "Table not found");
        if(table.status == TABLE_STATUS.MERGED) {
            Table memory tableParent = mNumberToTable[table.parentTableId];
            return tableParent.sessionIds[0];
        }
        else {
            return table.sessionIds[0];
        }
    }

    function removeTablesFromMerge(uint256[] memory _tableNumbers) external onlyOrder {
        for (uint i = 0; i < _tableNumbers.length; i++) {
            uint256 tableNum = _tableNumbers[i];
            Table storage table = mNumberToTable[tableNum];
            
            require(table.number != 0, "Table not found");
            require(table.status == TABLE_STATUS.MERGED, "Table is not in a merged state");

            // Reset trạng thái bàn về mặc định
            table.status = TABLE_STATUS.AVAILABLE;
            table.parentTableId = 0;
            // table.occupiedSeats = 0;
            
            _syncIndividualTable(tableNum);
        }
    }

     // clear bàn 
    // function ClearTable(uint256 tableNum, bytes32 sessionId, uint _numPeople) external {
    //     Table storage table = mNumberToTable[tableNum];
    //     require(table.number != 0, "Table not found");

    //     if(table.occupiedSeats > _numPeople) {
    //         table.status = TABLE_STATUS.ACTIVE;
    //         table.occupiedSeats -= _numPeople;
    //     } else {
    //         table.status = TABLE_STATUS.AVAILABLE;
    //         table.occupiedSeats = 0;
    //     }

    //     uint length = table.sessionIds.length;
    //     for(uint i = 0; i < length; i++) {
    //         if(table.sessionIds[i] == sessionId) {
    //             table.sessionIds[i] = table.sessionIds[length - 1];
    //             table.sessionIds.pop();
    //             break; 
    //         }
    //     }
    // }

    function ClearTable(uint256 tableNum, bytes32 sessionId) external {
        Table storage table = mNumberToTable[tableNum];
        require(table.number != 0, "Table not found");

        uint256 length = table.sessionIds.length;
        bool found = false;

        // Tìm và xóa sessionId cụ thể (Swap and Pop)
        for (uint256 i = 0; i < length; i++) {
            if (table.sessionIds[i] == sessionId) {
                table.sessionIds[i] = table.sessionIds[length - 1];
                table.sessionIds.pop();
                found = true;
                break; 
            }
        }

        if (table.sessionIds.length == 0) {
            table.status = TABLE_STATUS.AVAILABLE;
            // table.occupiedSeats = 0; 
        } else {
            table.status = TABLE_STATUS.ACTIVE;
        }
    }
}