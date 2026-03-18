// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============================================================================
// STRUCTS - Shared data structures
// ============================================================================
struct RobotContracts {
    address StaffRobotSC;
    address RobotRegistryV2;
    address RobotActiveV2;
    address RobotDataUploadTrainingV2;
    address RobotObservationTrainingV2;      
    address RobotTestingV2;
    address RobotDashboadV2;
    address RobotLocationV2;
    address RobotQuestionV2;
    address owner;      
    address StaffAgentStore;
    address Points;

}
struct MeosContracts {
    address StaffMeosSC;
    address NetCafeUser;
    address NetCafeSession;
    address NetCafeTopUp;
    address NetCafeSpend;      
    address NetCafeManagement;
    address NetCafeStation;
    address owner;      
    address StaffAgentStore;
    address Points;
}
struct IQRContracts {
    address Management;
    address Order;
    address Report;
    address TimeKeeping;
    address owner;      
    address StaffAgentStore;
    address Points;
}
struct RobotInputs{ 
    address _StaffRobotSC; //implement ;not proxy
    address _RobotRegistryV2IMP;
    address _RobotActiveV2IMP;
    address _RobotDataUploadTrainingV2IMP;
    address _RobotObservationTrainingV2IMP;
    address _RobotTestingV2IMP;
    address _RobotDashboadV2IMP;
    address _RobotLocationV2IMP;
    address _RobotQuestionV2IMP;        
    address _StaffAgentStore; //proxy dùng cho tất cả agent
}
struct RobotInputsBeacon{ 
    address StaffRobotBeacon; //implement ;not proxy
    address RobotRegistryBeacon;
    address RobotActiveBeacon;
    address RobotLoadBeacon;
    address RobotObservationTrainingBeacon;
    address RobotTestingBeacon;
    address RobotDashboadBeacon;
    address RobotLocationBeacon;
    address RobotQuestionBeacon;  
    address StaffAgentStore; //proxy dùng cho tất cả agent
      
}
struct AgentInfo {
    address walletAddress;
    string storeName;
    string storeAddress;
    uint256 numOfBranch;
    bool[4] permissions;
    uint256 createdAt;
    uint256[4] revenueByModule;
}
struct Agent {
    address walletAddress;
    string storeName;
    string storeAddress;
    string phone;
    string note;
    bool[4] permissions; // [IQR, Loyalty, MeOS,Robot]
    // string[] subLocations;
    // string[] subPhones;
    uint256 createdAt;
    uint256 updatedAt;
    bool isActive;
    bool exists;
    string domain;
    BranchInfo[] branches;
}
struct BranchInfoInput {
    string name;
    string location;
    string phone;
    string domain;
}

struct BranchInfo {
    uint branchId;
    string name;
    string location;
    string phone;
    string domain;
    bool isActive;
    bool isMain;
    uint createdAt;
}

struct MeOSLicense {
    string licenseKey;
    bool isActive;
    uint256 createdAt;
    uint256 expiryAt;
}

struct MTDStats {
    uint256 totalSupply;
    uint256 available;
    uint256 locked;
    uint256 burned;
    uint256 frozen;
}

struct AgentOrder {
    bytes32 paymentId;
    // address customer;
    uint256 amount;
    uint256 timestamp;
    // bool completed;
    // string metadata;
}

struct Revenue {
    uint256 iqr;
    uint256 loyalty;
    uint256 meos;
    uint256 total;
}

struct AgentRevenue {
    address agent;
    uint256 iqr;
    uint256 loyalty;
    uint256 meos;
    uint256 total;
    uint256 lastUpdated;
}

struct RevenueRecord {
    address agent;
    uint8 moduleType; // 1=IQR, 2=Loyalty, 3=MeOS
    uint256 amount;
    uint256 timestamp;
    string metadata;
}

struct RewardTransaction {
    address user;
    uint256 amount;
    string transactionType; // "mint", "burn", "redeem"
    uint256 timestamp;
    string metadata;
}

struct PaginationResult {
    address[] agents;
    uint totalCount;
    uint currentPage;
    uint totalPages;
    bool hasNext;
    bool hasPrev;
}

struct AgentAnalytics {
    uint256 totalOrders;
    uint256 totalRevenue;
    uint256 loyaltyTokensIssued;
    uint256 meosLicensesActive;
    uint256 customerCount;
    uint256 averageOrderValue;
    uint256 lastActivityTimestamp;
    uint256 performanceScore; // 0-100
}

struct TimeFilter {
    uint256 startTime;
    uint256 endTime;
    string period; // "day", "week", "month", "year"
}

struct License {
    string licenseKey;
    address agent;
    bool isActive;
    uint256 createdAt;
    uint256 expiryAt;
    uint256 installCount;
    uint256 maxInstalls;
    string version;
    bytes32 hardwareFingerprint;
}
struct LastUpdateData{
    address admin;
    uint256 updateAt;
}
    // struct TxRecord {
    //     uint256         id;
    //     address         member;
    //     TransactionType txType;
    //     int256          points;
    //     uint256         amount;
    //     bytes32         invoiceId;
    //     string          note;
    //     uint256         timestamp;
    //     uint256         eventId;
    // }
// ============================================================================
// INTERFACES
// ============================================================================

interface IAgentRobot {
    function getTotalRevenue() external view returns (uint256);
    function deactivate() external;
    function reactivate() external;
    function isActive() external view returns (bool);
    function getRobotSCByAgent(address _agent,uint _branchId) external view returns(RobotContracts memory);
    function transferOwnerRobot(
        address _agent,
        address _StaffRobotSC,
        address _RobotRegistryV2,
        address _RobotActiveV2,
        address _RobotDataUploadTrainingV2,
        address _RobotObservationTrainingV2,
        address _RobotTestingV2,
        address _RobotDashboadV2,
        address _RobotLocationV2,
        address _RobotQuestionV2
    )external;

}

interface IAgentMeos {
    function getTotalRevenue() external view returns (uint256);
    function deactivate() external;
    function reactivate() external;
    function isActive() external view returns (bool);
    function getMeosSCByAgent(address _agent,uint _branchId) external view returns(MeosContracts memory);
    function transferOwnerMeos(
        address _agent,
        address _StaffMeosSC,
        address _NetCafeUser,
        address _NetCafeSession,
        address _NetCafeTopUp,
        address _NetCafeSpend,
        address _NetCafeManagement,
        address _NetCafeStation
    )external ;
    function upgradeBeacon(
        address _newImplStaffMeos,
        address _newImplNetCafeUser,
        address _newImplNetCafeSession,
        address _newImplNetCafeTopUp,
        address _newImplNetCafeSpend,
        address _newImplNetCafeManagement,
        address _newImplNetCafeStation
    ) external ;
}
interface IBMFactory {
    function getAgentMEOSContract(address _agent, uint _branchId) external view returns (address) ;
    function addManagerMainBranch(address _branchManagerProxy,address _agent, uint256[] memory branchIds)external;
    function createBranchManagement(address _agent) external  returns (address);
    function getBranchManagement(address _agent) external view returns (address);
}
interface IIQRFactory {
    function createAgentIQR(address _agent) external returns (address);
    function getAgentIQRContract(address _agent, uint _branchId) external view returns (address);   
    function setAgentIQR( address _agent, uint _branchId, address _branchManagement)external;   
    function setPointsIQRFactory(address _agent, address _Points, uint _branchId) external;
    function transferOwnerIQRContracts(address _agent, uint _branchId)external;
    function getIQRSCByAgent(address _agent,uint _branchId) external view returns(IQRContracts memory);
    function getIQRSCByAgentFromFactory(address _agent, uint _branchId) external view returns (IQRContracts memory) ;
    function getManagementSCByAgentsFromFactory(address _agent, uint[] memory _branchIds) external view returns (address[] memory managementScs, uint count) ;
}
interface ILoyaltyFactory {
    function createAgentLoyalty(address _agent) external  returns (address);
    function getAgentLoyaltyContract(address _agent) external view returns (address);
    function setPointsLoyaltyFactory(address _agent, address _Management,address _Order,address _TopUp,uint _branchId) external returns(address);
    function transferOwnerPointSC(address _agent, address POINTS_PROXY)external;
}

interface IRestaurantLoyaltySystem {
    function pause()   external ;
    function unpause() external ;
    function balanceOf(address account) external view returns (uint256);
    function grantRole(bytes32 role, address account) external;

}

interface IAgentIQR {
    function getTotalRevenue() external view returns (uint256);
    function deactivate() external;
    function reactivate() external;
    function isActive() external view returns (bool);
    function getIQRSCByAgent(address _agent,uint _branchId) external view returns(IQRContracts memory);
    function transferOwnerIQR(
        address _agent,
        address _MANAGEMENT,
        address _ORDER,
        address _REPORT,
        address _TIMEKEEPING

    )external ;
}

interface IRevenueManager {
    function addAgent(address _agent) external;
    function recordRevenue(address _agent, uint8 _moduleType, uint256 _amount, string memory _metadata) external;
    function getAgentRevenue(address _agent) external view returns (uint256, uint256, uint256, uint256);
    function getSystemRevenue() external view returns (uint256, uint256, uint256, uint256);
}

interface IMTDToken {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IAgentManagement {
    function getAgent(address _agent) external view returns (Agent memory);
    function getAllAgents() external view returns (address[] memory);
    function getActiveAgents() external view returns (address[] memory);
    function getSubLocationCount(address _agent) external view returns (uint256);
}
interface IORDER {
    function setConfig(address _management,address _merchant,address _cardVisa,uint8 _taxPercent,address _noti,address _report) external;
    function transferOwnership(address newOwner) external ;
    // function owner() external returns (address);
    function setIQRAgent(address _iqrAgentSC,address _agent, address revenueManager) external;
    function initialize() external;
    function setPointSC (address _pointSC) external;
}
interface IMANAGEMENT {
    function setRestaurantOrder(address _restaurantOrder) external;
    function setReport(address _report) external;
    function setTimeKeeping(address _timeKeeping) external;
    function transferOwnership(address newOwner) external ;
    function setStaffAgentStore(address _staffAgentSC)external;
    function setAgentAdd(address _agent,uint _branchId) external;
    function grantRole(bytes32 role, address account) external;
    function initialize() external;
    function setPoints(address _points) external;
    function setAgentIqrSC(address _agentIQRSC) external;
    function setActive(bool _active) external;
    function setBranchManagement(address _branchManagement) external;
    function setRoleForCoOwner(address _coOwner)external;
    function setHistoryTracking(address _historyTracking) external;

}
interface IREPORT {
    function transferOwnership(address newOwner) external ;
    function setManagement(address _management) external ;
    function initialize(address management) external;
}
interface ITIMEKEEPING {
    function transferOwnership(address newOwner) external ;
    function setManagement(address _managementContract) external ;
    function initialize(address management) external;
}
interface IEnhancedAgent {
    function CheckAgentExisted(address _agent)external view returns(bool);
}
interface IStaffAgentStore {
    function setManagement(address _management) external;
    function setAgent(address user, address agent,uint branchId) external;
    function setBranchManagement(address _branchManger)external;
    function setAgentForCoOwner(address _coOwner, address agent, uint256[] memory branchIds) external;

}
interface IBranchManagement {
    function createBranch(
        uint _newBranchId,
        string memory _name,
        bool _isMain,
        bool hasIqr,
        bool hasMeos,
        bool hasRobot
    ) external returns (uint256) ;
    function initialize(
        address _agent,
        address _historyTrackingIMP,
        address _freeGasSc
    )external; 
    function updateBranch(
        uint256 branchId,
        string memory _name
    ) external ;
    function deactivateBranch(uint256 branchId) external;
    function AddAndUpdateManager(
        address _wallet,
        string memory _name,
        string memory _phone,
        string memory _image,
        bool _isAllBranches,
        uint256[] memory _branchIds,
        bool _hasFullAccess,
        bool _canViewData,
        bool _canEditData,
        bool _canProposeAndVote
    ) external;
    function setMainOwner(address _agent) external;
    function setStaffAgentStore(address _staffAgentSC)external;
    function setIqrFactorySC(
        address _iqrFactorySc,
        address _meosFactorySc,
        address _robotFactorySc
    ) external;
        function getMainBranchId()external view returns(uint);
}
interface IMeosFactory {
    function setAgentMeos( address _agent, uint _branchId, address _branchManagement)external ;
    function getMeosSCByAgentFromFactory(address _agent, uint _branchId) external view returns (MeosContracts memory);
    function setPointsMeosFactory(address _agent, address _Points, uint _branchId) external;
    function getManagementSCByAgentsFromFactory(address _agent, uint[] memory _branchIds) external view returns (address[] memory managementScs, uint count) ;


}
interface IRobotFactory {
    function getRobotSCByAgentFromFactory(address _agent, uint _branchId) external view returns (RobotContracts memory);
    function getManagementSCByAgentsFromFactory(address _agent, uint[] memory _branchIds) external view returns (address[] memory managementScs, uint count) ;

}
interface IPublicfullDB {
    function initAgentDbs(address _agent) external;
}