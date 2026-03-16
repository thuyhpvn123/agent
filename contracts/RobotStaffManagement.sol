// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title RobotStaffManagement
 * @dev Smart contract quản lý nhân viên và phân quyền cho Module M4: ROBOT
 * Hệ thống RBAC với các role: OWNER, BRAND_MANAGER, STAFF và các Job Types đặc biệt
 */
contract RobotStaffManagement is AccessControl {
    
    // ============ ROLES ============
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant BRAND_MANAGER_ROLE = keccak256("BRAND_MANAGER_ROLE");
    bytes32 public constant STAFF_ROLE = keccak256("STAFF_ROLE");
    
    // Job Types - Roles đặc biệt cho Robot
    bytes32 public constant ROBOT_TRAINER_ROLE = keccak256("ROBOT_TRAINER_ROLE");
    bytes32 public constant ROBOT_CONTROLLER_ROLE = keccak256("ROBOT_CONTROLLER_ROLE");
    bytes32 public constant ROBOT_SUPPORTER_ROLE = keccak256("ROBOT_SUPPORTER_ROLE");
    
    // ============ STRUCTS ============
    
    struct Staff {
        address walletAddress;
        string name;
        string email;
        bytes32 role;
        uint256 merchantId;
        uint256 brandId;
        uint256 branchId;
        bool isActive;
        uint256 createdAt;
        uint256 updatedAt;
    }
    
    struct RobotTrainer {
        address walletAddress;
        uint256[] allowedRobotIds;
        bool canEditTrainingData;
        bool canTestConversations;
        bool canSubmitSuggestions;
        uint256 createdAt;
    }
    
    struct RobotController {
        address walletAddress;
        uint256[] assignedRobotIds;
        bool canControlRealtime;
        bool canSwitchToManualMode;
        uint256 shiftStartTime;
        uint256 shiftEndTime;
        bool isOnDuty;
        uint256 createdAt;
    }
    
    struct RobotSupporter {
        address walletAddress;
        uint256 branchId;
        bool canReceiveAlerts;
        bool canConfirmCashCollection;
        bool canSubmitFeedback;
        uint256 createdAt;
    }
    
    struct Permission {
        bool canControlRobot;           // Điều khiển robot từ xa
        bool canStartStopRobot;         // Bật/tắt robot
        bool canViewRealTimeLocation;   // Xem vị trí thời gian thực
        bool canEditMap;                // Sửa bản đồ không gian
        bool canTrainRobot;             // Huấn luyện robot (full)
        bool canApproveTraining;        // Phê duyệt huấn luyện
        bool canDeleteTrainingData;     // Xóa dữ liệu huấn luyện
        bool canViewAllReports;         // Xem tất cả báo cáo
        bool canReceiveCriticalAlerts;  // Nhận cảnh báo Critical
        bool canReceiveWarnings;        // Nhận cảnh báo Warning
        bool canReceiveInfoAlerts;      // Nhận cảnh báo Info
        bool canManageAllRobots;        // Quản lý tất cả robot
        bool canAssignPermissions;      // Phân quyền cho người khác
        bool canHandleIncidents;        // Xử lý sự cố hiện trường
        bool canConfirmCashCollection;  // Xác nhận nhận tiền mặt
    }
    
    // ============ STATE VARIABLES ============
    
    mapping(address => Staff) public staffs;
    mapping(address => RobotTrainer) public robotTrainers;
    mapping(address => RobotController) public robotControllers;
    mapping(address => RobotSupporter) public robotSupporters;
    mapping(bytes32 => Permission) public rolePermissions;
    
    address[] public allStaffAddresses;
    
    uint256 public totalStaffs;
    uint256 public merchantId;
    
    // ============ EVENTS ============
    
    event StaffAdded(address indexed staffAddress, string name, bytes32 role, uint256 branchId);
    event StaffUpdated(address indexed staffAddress, bytes32 newRole);
    event StaffRemoved(address indexed staffAddress);
    event StaffActivated(address indexed staffAddress);
    event StaffDeactivated(address indexed staffAddress);
    
    event RobotTrainerAdded(address indexed trainerAddress, uint256[] robotIds);
    event RobotControllerAdded(address indexed controllerAddress, uint256[] robotIds);
    event RobotSupporterAdded(address indexed supporterAddress, uint256 branchId);
    
    event PermissionUpdated(bytes32 indexed role, string permissionType, bool value);
    event ShiftStarted(address indexed controllerAddress, uint256 startTime);
    event ShiftEnded(address indexed controllerAddress, uint256 endTime);
    
    // ============ MODIFIERS ============
    
    modifier onlyOwnerOrSuperAdmin() {
        require(
            hasRole(OWNER_ROLE, msg.sender) || hasRole(SUPER_ADMIN_ROLE, msg.sender),
            "Only Owner or Super Admin"
        );
        _;
    }
    
    modifier onlyActiveStaff(address staffAddress) {
        require(staffs[staffAddress].isActive, "Staff is not active");
        _;
    }
    
    modifier onlyDuringShift() {
        RobotController memory controller = robotControllers[msg.sender];
        require(controller.isOnDuty, "Not on duty");
        require(
            block.timestamp >= controller.shiftStartTime && 
            block.timestamp <= controller.shiftEndTime,
            "Outside shift hours"
        );
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    constructor(uint256 _merchantId) {
        merchantId = _merchantId;
        
        // Setup admin role
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SUPER_ADMIN_ROLE, msg.sender);
        _grantRole(OWNER_ROLE, msg.sender);
        
        // Initialize default permissions cho từng role
        _initializeRolePermissions();
    }
    
    // ============ ROLE PERMISSION INITIALIZATION ============
    
    function _initializeRolePermissions() internal {
        // OWNER - Full quyền
        rolePermissions[OWNER_ROLE] = Permission({
            canControlRobot: true,
            canStartStopRobot: true,
            canViewRealTimeLocation: true,
            canEditMap: true,
            canTrainRobot: true,
            canApproveTraining: true,
            canDeleteTrainingData: true,
            canViewAllReports: true,
            canReceiveCriticalAlerts: true,
            canReceiveWarnings: true,
            canReceiveInfoAlerts: true,
            canManageAllRobots: true,
            canAssignPermissions: true,
            canHandleIncidents: false,
            canConfirmCashCollection: false
        });
        
        // BRAND_MANAGER - Quản lý thương hiệu
        rolePermissions[BRAND_MANAGER_ROLE] = Permission({
            canControlRobot: false,
            canStartStopRobot: false,
            canViewRealTimeLocation: true,
            canEditMap: false,
            canTrainRobot: false,
            canApproveTraining: false,
            canDeleteTrainingData: false,
            canViewAllReports: true,
            canReceiveCriticalAlerts: false,
            canReceiveWarnings: true,
            canReceiveInfoAlerts: true,
            canManageAllRobots: true,
            canAssignPermissions: false,
            canHandleIncidents: false,
            canConfirmCashCollection: false
        });
        
        // STAFF - Vận hành tuyến đầu
        rolePermissions[STAFF_ROLE] = Permission({
            canControlRobot: false,
            canStartStopRobot: false,
            canViewRealTimeLocation: false,
            canEditMap: false,
            canTrainRobot: false,
            canApproveTraining: false,
            canDeleteTrainingData: false,
            canViewAllReports: false,
            canReceiveCriticalAlerts: true,
            canReceiveWarnings: true,
            canReceiveInfoAlerts: true,
            canManageAllRobots: false,
            canAssignPermissions: false,
            canHandleIncidents: true,
            canConfirmCashCollection: true
        });
    }
    
    // ============ STAFF MANAGEMENT FUNCTIONS ============
    
    /**
     * @dev Thêm nhân viên mới
     */
    function addStaff(
        address _staffAddress,
        string memory _name,
        string memory _email,
        bytes32 _role,
        uint256 _brandId,
        uint256 _branchId
    ) external onlyOwnerOrSuperAdmin  {
        require(_staffAddress != address(0), "Invalid address");
        require(staffs[_staffAddress].walletAddress == address(0), "Staff already exists");
        require(
            _role == STAFF_ROLE || 
            _role == BRAND_MANAGER_ROLE || 
            _role == OWNER_ROLE,
            "Invalid role"
        );
        
        staffs[_staffAddress] = Staff({
            walletAddress: _staffAddress,
            name: _name,
            email: _email,
            role: _role,
            merchantId: merchantId,
            brandId: _brandId,
            branchId: _branchId,
            isActive: true,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });
        
        // Grant role
        _grantRole(_role, _staffAddress);
        
        allStaffAddresses.push(_staffAddress);
        totalStaffs++;
        
        emit StaffAdded(_staffAddress, _name, _role, _branchId);
    }
    
    /**
     * @dev Cập nhật role của nhân viên
     */
    function updateStaffRole(address _staffAddress, bytes32 _newRole) 
        external 
        onlyOwnerOrSuperAdmin 
        onlyActiveStaff(_staffAddress)
         
    {
        require(staffs[_staffAddress].walletAddress != address(0), "Staff not found");
        
        bytes32 oldRole = staffs[_staffAddress].role;
        
        // Revoke old role
        _revokeRole(oldRole, _staffAddress);
        
        // Grant new role
        _grantRole(_newRole, _staffAddress);
        
        staffs[_staffAddress].role = _newRole;
        staffs[_staffAddress].updatedAt = block.timestamp;
        
        emit StaffUpdated(_staffAddress, _newRole);
    }
    
    /**
     * @dev Vô hiệu hóa nhân viên
     */
    function deactivateStaff(address _staffAddress) 
        external 
        onlyOwnerOrSuperAdmin 
         
    {
        require(staffs[_staffAddress].walletAddress != address(0), "Staff not found");
        require(staffs[_staffAddress].isActive, "Staff already inactive");
        
        staffs[_staffAddress].isActive = false;
        staffs[_staffAddress].updatedAt = block.timestamp;
        
        emit StaffDeactivated(_staffAddress);
    }
    
    /**
     * @dev Kích hoạt lại nhân viên
     */
    function activateStaff(address _staffAddress) 
        external 
        onlyOwnerOrSuperAdmin 
         
    {
        require(staffs[_staffAddress].walletAddress != address(0), "Staff not found");
        require(!staffs[_staffAddress].isActive, "Staff already active");
        
        staffs[_staffAddress].isActive = true;
        staffs[_staffAddress].updatedAt = block.timestamp;
        
        emit StaffActivated(_staffAddress);
    }
    
    // ============ ROBOT TRAINER FUNCTIONS ============
    
    /**
     * @dev Thêm Robot Trainer (Người huấn luyện robot)
     */
    function addRobotTrainer(
        address _trainerAddress,
        uint256[] memory _allowedRobotIds
    ) external onlyOwnerOrSuperAdmin  {
        require(_trainerAddress != address(0), "Invalid address");
        require(staffs[_trainerAddress].isActive, "Must be active staff");
        
        robotTrainers[_trainerAddress] = RobotTrainer({
            walletAddress: _trainerAddress,
            allowedRobotIds: _allowedRobotIds,
            canEditTrainingData: true,
            canTestConversations: true,
            canSubmitSuggestions: true,
            createdAt: block.timestamp
        });
        
        _grantRole(ROBOT_TRAINER_ROLE, _trainerAddress);
        
        emit RobotTrainerAdded(_trainerAddress, _allowedRobotIds);
    }
    
    /**
     * @dev Cập nhật danh sách robot được phép huấn luyện
     */
    function updateTrainerRobots(
        address _trainerAddress,
        uint256[] memory _newRobotIds
    ) external onlyOwnerOrSuperAdmin  {
        require(hasRole(ROBOT_TRAINER_ROLE, _trainerAddress), "Not a trainer");
        
        robotTrainers[_trainerAddress].allowedRobotIds = _newRobotIds;
    }
    
    /**
     * @dev Kiểm tra trainer có được phép huấn luyện robot này không
     */
    function canTrainRobot(address _trainerAddress, uint256 _robotId) 
        external 
        view 
        returns (bool) 
    {
        RobotTrainer memory trainer = robotTrainers[_trainerAddress];
        
        for (uint256 i = 0; i < trainer.allowedRobotIds.length; i++) {
            if (trainer.allowedRobotIds[i] == _robotId) {
                return true;
            }
        }
        return false;
    }
    
    // ============ ROBOT CONTROLLER FUNCTIONS ============
    
    /**
     * @dev Thêm Robot Controller (Người điều khiển robot)
     */
    function addRobotController(
        address _controllerAddress,
        uint256[] memory _assignedRobotIds
    ) external onlyOwnerOrSuperAdmin  {
        require(_controllerAddress != address(0), "Invalid address");
        require(staffs[_controllerAddress].isActive, "Must be active staff");
        
        robotControllers[_controllerAddress] = RobotController({
            walletAddress: _controllerAddress,
            assignedRobotIds: _assignedRobotIds,
            canControlRealtime: true,
            canSwitchToManualMode: true,
            shiftStartTime: 0,
            shiftEndTime: 0,
            isOnDuty: false,
            createdAt: block.timestamp
        });
        
        _grantRole(ROBOT_CONTROLLER_ROLE, _controllerAddress);
        
        emit RobotControllerAdded(_controllerAddress, _assignedRobotIds);
    }
    
    /**
     * @dev Controller bắt đầu ca làm việc
     */
    function startShift(uint256 _durationInHours) external  {
        require(hasRole(ROBOT_CONTROLLER_ROLE, msg.sender), "Not a controller");
        require(!robotControllers[msg.sender].isOnDuty, "Already on duty");
        
        uint256 shiftEnd = block.timestamp + (_durationInHours * 1 hours);
        
        robotControllers[msg.sender].shiftStartTime = block.timestamp;
        robotControllers[msg.sender].shiftEndTime = shiftEnd;
        robotControllers[msg.sender].isOnDuty = true;
        
        emit ShiftStarted(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Controller kết thúc ca làm việc
     */
    function endShift() external  {
        require(hasRole(ROBOT_CONTROLLER_ROLE, msg.sender), "Not a controller");
        require(robotControllers[msg.sender].isOnDuty, "Not on duty");
        
        robotControllers[msg.sender].isOnDuty = false;
        
        emit ShiftEnded(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Kiểm tra controller có được phép điều khiển robot này không (trong ca làm việc)
     */
    function canControlRobot(address _controllerAddress, uint256 _robotId) 
        external 
        view 
        returns (bool) 
    {
        RobotController memory controller = robotControllers[_controllerAddress];
        
        if (!controller.isOnDuty) return false;
        if (block.timestamp < controller.shiftStartTime || block.timestamp > controller.shiftEndTime) {
            return false;
        }
        
        for (uint256 i = 0; i < controller.assignedRobotIds.length; i++) {
            if (controller.assignedRobotIds[i] == _robotId) {
                return true;
            }
        }
        return false;
    }
    
    // ============ ROBOT SUPPORTER FUNCTIONS ============
    
    /**
     * @dev Thêm Robot Supporter (Người hỗ trợ robot tại hiện trường)
     */
    function addRobotSupporter(
        address _supporterAddress,
        uint256 _branchId
    ) external onlyOwnerOrSuperAdmin  {
        require(_supporterAddress != address(0), "Invalid address");
        require(staffs[_supporterAddress].isActive, "Must be active staff");
        
        robotSupporters[_supporterAddress] = RobotSupporter({
            walletAddress: _supporterAddress,
            branchId: _branchId,
            canReceiveAlerts: true,
            canConfirmCashCollection: true,
            canSubmitFeedback: true,
            createdAt: block.timestamp
        });
        
        _grantRole(ROBOT_SUPPORTER_ROLE, _supporterAddress);
        
        emit RobotSupporterAdded(_supporterAddress, _branchId);
    }
    
    // ============ PERMISSION CHECK FUNCTIONS ============
    
    /**
     * @dev Kiểm tra quyền của một địa chỉ với một permission cụ thể
     */
    function hasPermission(address _address, string memory _permissionType) 
        external 
        view 
        returns (bool) 
    {
        Staff memory staff = staffs[_address];
        if (!staff.isActive) return false;
        
        Permission memory perm = rolePermissions[staff.role];
        
        bytes32 permHash = keccak256(abi.encodePacked(_permissionType));
        
        if (permHash == keccak256("canControlRobot")) return perm.canControlRobot;
        if (permHash == keccak256("canStartStopRobot")) return perm.canStartStopRobot;
        if (permHash == keccak256("canViewRealTimeLocation")) return perm.canViewRealTimeLocation;
        if (permHash == keccak256("canEditMap")) return perm.canEditMap;
        if (permHash == keccak256("canTrainRobot")) return perm.canTrainRobot;
        if (permHash == keccak256("canApproveTraining")) return perm.canApproveTraining;
        if (permHash == keccak256("canDeleteTrainingData")) return perm.canDeleteTrainingData;
        if (permHash == keccak256("canViewAllReports")) return perm.canViewAllReports;
        if (permHash == keccak256("canManageAllRobots")) return perm.canManageAllRobots;
        if (permHash == keccak256("canHandleIncidents")) return perm.canHandleIncidents;
        if (permHash == keccak256("canConfirmCashCollection")) return perm.canConfirmCashCollection;
        
        return false;
    }
    
    /**
     * @dev Lấy tất cả permissions của một role
     */
    function getRolePermissions(bytes32 _role) 
        external 
        view 
        returns (Permission memory) 
    {
        return rolePermissions[_role];
    }
    
    /**
     * @dev Cập nhật permission cho một role (chỉ Owner)
     */
    function updateRolePermission(
        bytes32 _role,
        string memory _permissionType,
        bool _value
    ) external onlyRole(OWNER_ROLE)  {
        Permission storage perm = rolePermissions[_role];
        
        bytes32 permHash = keccak256(abi.encodePacked(_permissionType));
        
        if (permHash == keccak256("canControlRobot")) perm.canControlRobot = _value;
        else if (permHash == keccak256("canStartStopRobot")) perm.canStartStopRobot = _value;
        else if (permHash == keccak256("canViewRealTimeLocation")) perm.canViewRealTimeLocation = _value;
        else if (permHash == keccak256("canEditMap")) perm.canEditMap = _value;
        else if (permHash == keccak256("canTrainRobot")) perm.canTrainRobot = _value;
        else if (permHash == keccak256("canApproveTraining")) perm.canApproveTraining = _value;
        else if (permHash == keccak256("canDeleteTrainingData")) perm.canDeleteTrainingData = _value;
        else if (permHash == keccak256("canViewAllReports")) perm.canViewAllReports = _value;
        else if (permHash == keccak256("canManageAllRobots")) perm.canManageAllRobots = _value;
        else if (permHash == keccak256("canHandleIncidents")) perm.canHandleIncidents = _value;
        else if (permHash == keccak256("canConfirmCashCollection")) perm.canConfirmCashCollection = _value;
        else revert("Invalid permission type");
        
        emit PermissionUpdated(_role, _permissionType, _value);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev Lấy thông tin nhân viên
     */
    function getStaff(address _staffAddress) 
        external 
        view 
        returns (Staff memory) 
    {
        return staffs[_staffAddress];
    }
    
    /**
     * @dev Lấy danh sách tất cả nhân viên (phân trang)
     */
    function getAllStaffs(uint256 _offset, uint256 _limit) 
        external 
        view 
        returns (Staff[] memory) 
    {
        require(_offset < allStaffAddresses.length, "Offset out of bounds");
        
        uint256 end = _offset + _limit;
        if (end > allStaffAddresses.length) {
            end = allStaffAddresses.length;
        }
        
        Staff[] memory result = new Staff[](end - _offset);
        
        for (uint256 i = _offset; i < end; i++) {
            result[i - _offset] = staffs[allStaffAddresses[i]];
        }
        
        return result;
    }
    
    /**
     * @dev Lấy danh sách nhân viên theo branch
     */
    function getStaffsByBranch(uint256 _branchId) 
        external 
        view 
        returns (Staff[] memory) 
    {
        uint256 count = 0;
        
        // Đếm số nhân viên thuộc branch
        for (uint256 i = 0; i < allStaffAddresses.length; i++) {
            if (staffs[allStaffAddresses[i]].branchId == _branchId && 
                staffs[allStaffAddresses[i]].isActive) {
                count++;
            }
        }
        
        Staff[] memory result = new Staff[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allStaffAddresses.length; i++) {
            if (staffs[allStaffAddresses[i]].branchId == _branchId && 
                staffs[allStaffAddresses[i]].isActive) {
                result[index] = staffs[allStaffAddresses[i]];
                index++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Lấy thông tin Robot Trainer
     */
    function getRobotTrainer(address _trainerAddress) 
        external 
        view 
        returns (RobotTrainer memory) 
    {
        return robotTrainers[_trainerAddress];
    }
    
    /**
     * @dev Lấy thông tin Robot Controller
     */
    function getRobotController(address _controllerAddress) 
        external 
        view 
        returns (RobotController memory) 
    {
        return robotControllers[_controllerAddress];
    }
    
    /**
     * @dev Lấy thông tin Robot Supporter
     */
    function getRobotSupporter(address _supporterAddress) 
        external 
        view 
        returns (RobotSupporter memory) 
    {
        return robotSupporters[_supporterAddress];
    }
    
    /**
     * @dev Kiểm tra địa chỉ có phải là nhân viên active không
     */
    function isActiveStaff(address _address) external view returns (bool) {
        return staffs[_address].isActive;
    }
    
    /**
     * @dev Lấy role của nhân viên
     */
    function getStaffRole(address _address) external view returns (bytes32) {
        return staffs[_address].role;
    }
    
    // ============ EMERGENCY FUNCTIONS ============
    
    // /**
    //  * @dev Tạm dừng contract (emergency)
    //  */
    // function pause() external onlyOwnerOrSuperAdmin {
    //     _pause();
    // }
    
    // /**
    //  * @dev Tiếp tục contract
    //  */
    // function unpause() external onlyOwnerOrSuperAdmin {
    //     _unpause();
    // }
}
