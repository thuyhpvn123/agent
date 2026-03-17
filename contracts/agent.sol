// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IAgent.sol";
import {AgentIQR} from "./agentIqr.sol";
import {RestaurantLoyaltySystem} from "./agentLoyalty.sol";
import {IQRFactory} from "./iqrFactory.sol";
import {MeosFactory} from "./meosFactory.sol";
import {RobotFactory} from "./robotFactory.sol";
// import {BMFactory} from "./bmFactory.sol";

// import "forge-std/console.sol";
contract AgentManagement is 
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    
    // Version for upgrade tracking
    string public version;
    
    // Admin state
    address public superAdmin;
    bool public adminInitialized;
    
    // Contract addresses
    address public iqrFactory;
    address public loyaltyFactory;
    address public meosFactory;
    address public revenueManager;
    address public mtdToken;
    address public bmFactory;
    address public robotFactory;
    // Mappings
    mapping(address => Agent) public agents;
    mapping(address =>mapping(uint => address)) public agentIQRContracts;
    mapping(address =>mapping(uint => address)) public agentMEOSContracts;
    mapping(address =>mapping(uint => address)) public agentROBOTContracts;
    mapping(address => address) public agentLoyaltyContracts;
    mapping(address => address) public agentBranchManagement; // agent => BranchManagement contract
    mapping(address => mapping(uint => MeOSLicense)) public meosLicenses;
    address[] public agentList;
    
    // Pause functionality
    bool public paused ;
    Agent[] public deletedAgents;
    mapping(address => bool) public isAdmin;
    mapping(string => address) public mDomainToWallet;
    mapping(address => string) public mAgentToDomain;
    mapping(address =>mapping(uint => bool)) public iqrTransfered;
    mapping(address => uint[]) public agentToBranchIds;
    mapping(uint => BranchInfo) public mBranchIdToBranch;
    mapping(address => uint) public mAgentToMainBranchId;
    uint public branchIdCount;
    mapping(uint => bool) public existsInNew;
    mapping(string => uint) public mDomainToBranchId;
    // Thêm vào đầu contract, sau các mapping hiện có
    bytes32 public constant COMPANY_ADMIN_ROLE = keccak256("COMPANY_ADMIN_ROLE");
    bytes32 public constant DA_ROLE = keccak256("DA_ROLE"); // Data Analyst
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");

    mapping(address => bool) public isCompanyAdmin;
    mapping(address => bool) public isDA;

    // Track super admins created by company admin
    mapping(address => address) public superAdminToCompanyAdmin; // superAdmin => companyAdmin who created them
    mapping(address => address[]) public companyAdminSuperAdmins; // companyAdmin => list of their super admins
    address public publicfullDB;
    uint256[45] private __gap;
    // Events
    event SuperAdminSet(address indexed admin);
    event AgentCreated(address indexed agent, string storeName, uint256 timestamp);
    event AgentUpdated(address indexed agent, uint256 timestamp);
    event AgentDeleted(address indexed agent, uint256 timestamp);
    event PermissionGranted(address indexed agent, uint8 permissionType, uint256 timestamp);
    event PermissionRevoked(address indexed agent, uint8 permissionType, uint256 timestamp);
    event MeOSLicenseIssued(address indexed agent, string licenseKey, uint256 expiryAt);
    event LoyaltyTokensUnlocked(address indexed agent, uint256 amount);
    event LoyaltyTokensMigrated(address indexed fromAgent, address indexed toAgent, uint256 amount);
    event ContractUpgraded(string oldVersion, string newVersion, uint256 timestamp);
    event ContractPausedEvent(uint256 timestamp);
    event ContractUnpaused(uint256 timestamp);
    event CompanyAdminAdded(address indexed companyAdmin, uint256 timestamp);
    event DAAdded(address indexed da, uint256 timestamp);
    event SuperAdminCreated(address indexed superAdmin, address indexed companyAdmin, uint256 timestamp);
    
   modifier onlySuperAdmin() {
        require(
            isAdmin[msg.sender] == true || 
            isCompanyAdmin[msg.sender] == true,
            "OnlySuperAdminOrCompanyAdmin"
        );
        _;
    }

    // Thêm modifier mới
    modifier onlyCompanyAdmin() {
        require(isCompanyAdmin[msg.sender] == true, "OnlyCompanyAdmin");
        _;
    }

    modifier onlySuperAdminOrDA() {
        require(
            isAdmin[msg.sender] == true || 
            isCompanyAdmin[msg.sender] == true ||
            isDA[msg.sender] == true,
            "OnlySuperAdminOrDA"
        );
        _;
    }
    
    modifier validAgent(address _agent) {
        require(agents[_agent].exists,"AgentNotFound");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused,"ContractPaused");
        _;
    }
    
    // ========================================================================
    // INITIALIZER (REPLACES CONSTRUCTOR)
    // ========================================================================
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initialize the contract (replaces constructor)
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        version = "1.0.0";
        // adminInitialized = false;
        paused = false;
        isAdmin[msg.sender] = true;
    }
    
    /**
     * @dev Authorize upgrade (only owner can upgrade)
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ========================================================================
    // ADMIN INITIALIZATION
    // ========================================================================
    
    function setPublicfullDB(address _publicfullDB) external onlyOwner {
        publicfullDB = _publicfullDB;
    }

    function setAdmin(address _adminWallet) external onlyOwner {
        require(_adminWallet != address(0), "InvalidWallet");       
        // _transferOwnership(_adminWallet);
        isAdmin[_adminWallet] = true;
        emit SuperAdminSet(_adminWallet);
    }
    /**
    * @dev Set company admin (only owner)
    */
    function setCompanyAdmin(address _companyAdmin, bool _isActive) 
        external 
        onlyOwner 
    {
        require(_companyAdmin != address(0), "InvalidAddress");
        isCompanyAdmin[_companyAdmin] = _isActive;
        
        if (_isActive) {
            emit CompanyAdminAdded(_companyAdmin, block.timestamp);
        }
    }

    /**
    * @dev Set DA role (only company admin or owner)
    */
    function setDA(address _da, bool _isActive) 
        external 
    {
        require(
            msg.sender == owner() || isCompanyAdmin[msg.sender],
            "OnlyOwnerOrCompanyAdmin"
        );
        require(_da != address(0), "InvalidAddress");
        
        isDA[_da] = _isActive;
        
        if (_isActive) {
            emit DAAdded(_da, block.timestamp);
        }
    }
    /**
    * @dev Company admin creates super admin
    */
    function createSuperAdmin(address _superAdmin) 
        external 
        onlyCompanyAdmin 
    {
        require(_superAdmin != address(0), "InvalidAddress");
        require(!isAdmin[_superAdmin], "AlreadySuperAdmin");
        
        isAdmin[_superAdmin] = true;
        superAdminToCompanyAdmin[_superAdmin] = msg.sender;
        companyAdminSuperAdmins[msg.sender].push(_superAdmin);
        
        emit SuperAdminCreated(_superAdmin, msg.sender, block.timestamp);
    }

    /**
    * @dev Company admin removes their super admin
    */
    function removeSuperAdmin(address _superAdmin) 
        external 
        onlyCompanyAdmin 
    {
        require(isAdmin[_superAdmin], "NotASuperAdmin");
        require(
            superAdminToCompanyAdmin[_superAdmin] == msg.sender,
            "NotYourSuperAdmin"
        );
        
        isAdmin[_superAdmin] = false;
        delete superAdminToCompanyAdmin[_superAdmin];
        
        // Remove from company admin's list
        address[] storage superAdmins = companyAdminSuperAdmins[msg.sender];
        for (uint i = 0; i < superAdmins.length; i++) {
            if (superAdmins[i] == _superAdmin) {
                superAdmins[i] = superAdmins[superAdmins.length - 1];
                superAdmins.pop();
                break;
            }
        }
    }

    /**
    * @dev Get all super admins created by a company admin
    */
    function getSuperAdminsByCompanyAdmin(address _companyAdmin) 
        external 
        view 
        returns (address[] memory) 
    {
        return companyAdminSuperAdmins[_companyAdmin];
    }

    /**
    * @dev Get all agents of a specific super admin (for company admin)
    */
    function getAgentsBySuperAdmin(address _superAdmin) 
        external 
        view 
        returns (address[] memory) 
    {
        require(
            isCompanyAdmin[msg.sender] || msg.sender == _superAdmin,
            "Unauthorized"
        );
        
        uint count = 0;
        
        // Count agents
        for (uint i = 0; i < agentList.length; i++) {
            if (superAdminToCompanyAdmin[agents[agentList[i]].walletAddress] == superAdminToCompanyAdmin[_superAdmin]) {
                count++;
            }
        }
        
        // Build array
        address[] memory result = new address[](count);
        uint index = 0;
        
        for (uint i = 0; i < agentList.length; i++) {
            if (superAdminToCompanyAdmin[agents[agentList[i]].walletAddress] == superAdminToCompanyAdmin[_superAdmin]) {
                result[index] = agentList[i];
                index++;
            }
        }
        
        return result;
    }
    /**
    * @dev Check if caller can view agent data
    */
    function canViewAgentData(address _agent) public view returns (bool) {
        return (
            isCompanyAdmin[msg.sender] ||
            isDA[msg.sender] ||
            isAdmin[msg.sender] ||
            msg.sender == _agent
        );
    }

    /**
    * @dev Check if caller can modify agent
    */
    function canModifyAgent(address _agent) public view returns (bool) {
        return (
            isCompanyAdmin[msg.sender] ||
            isAdmin[msg.sender]
        );
    }

    /**
    * @dev Get user role info
    */
    function getUserRole(address _user) 
        external 
        view 
        returns (
            bool _isCompanyAdmin,
            bool _isSuperAdmin,
            bool _isDA,
            address _createdBy // if super admin
        ) 
    {
        _isCompanyAdmin = isCompanyAdmin[_user];
        _isSuperAdmin = isAdmin[_user];
        _isDA = isDA[_user];
        _createdBy = superAdminToCompanyAdmin[_user];
    }
    /**
     * @dev Set factory contract addresses
     */
    function setFactoryContracts(
        address _iqrFactory,
        address _loyaltyFactory,
        address _revenueManager,
        address _bmFactory,
        address _meosFactory,
        address _robotFactory,
        address _publicfullDB
    ) external onlySuperAdmin {
        iqrFactory = _iqrFactory;
        loyaltyFactory = _loyaltyFactory;
        revenueManager = _revenueManager;
        bmFactory = _bmFactory;
        meosFactory = _meosFactory;
        robotFactory = _robotFactory;
        publicfullDB = _publicfullDB;
    }
    
    function getSubLocationCount(address _agent) public view returns (uint256) {
        return agents[_agent].branches.length;
    }

    /**
     * @dev Grant permissions to agent
     */
    function _grantPermissions(address _agent, bool[4] memory _permissions, uint[] memory branchIds) internal {
        address branchMgmt = createBranchManagerSC(_agent,branchIds);
        if (_permissions[0]) {
            _grantIQRPermission(_agent,branchIds,branchMgmt,_permissions[2],_permissions[3]);
        }
        // Loyalty Permission  
        if (_permissions[1]) {
            require(_permissions[0],"need iqr permission also to set this permission");
            _grantLoyaltyPermission(_agent);
        }
        
        // MeOS Permission
        if (_permissions[2]) {
            _grantMeOSPermission(_agent,branchIds,branchMgmt,_permissions[0],_permissions[1]);
        }
         // Robot Permission
        if (_permissions[3]) {
            _grantRobotPermission(_agent,branchIds,branchMgmt,_permissions[0],_permissions[1]);
        }
    }
    function createBranchManagerSC(address _agent, uint[] memory branchIds) internal returns(address){
        address branchMgmt = agentBranchManagement[_agent];
        // Tạo BranchManagement contract nếu chưa có
        if (branchMgmt == address(0)) {
            branchMgmt = IBMFactory(bmFactory).createBranchManagement(_agent);
            agentBranchManagement[_agent]=branchMgmt;
        }
        // for(uint i; i < branchIds.length; i++){
        //     uint branchIdCount = branchIds[i];
        //     // Đăng ký branch vào BranchManagement
        //     BranchInfo memory branchInfo = mBranchIdToBranch[branchIdCount];
        //     IBranchManagement(branchMgmt).createBranch(
        //         branchIdCount,
        //         branchInfo.name,
        //         branchInfo.isMain
        //     );
        //     if(branchInfo.isMain){
        //         IBMFactory(bmFactory).addManagerMainBranch(branchMgmt,_agent,branchIds);
        //     }
        // }
        return branchMgmt;
    }
    function _grantIQRPermission(address _agent, uint[] memory branchIds, address branchMgmt,bool hasMeos,bool hasRobot) internal {
        if (iqrFactory == address(0)) {
            agents[_agent].permissions[0] = false;
            return;
        }
        // Tạo IQR contracts cho từng branch và đăng ký vào BranchManagement
        for(uint i; i < branchIds.length; i++){
            uint branchIdCount = branchIds[i];
            address agentIQR = IQRFactory(iqrFactory).getAgentIQRContract(_agent, branchIdCount);
            
            if(agentIQR != address(0) && agentIQRContracts[_agent][branchIdCount] != address(0)){
                IAgentIQR(agentIQR).reactivate();
            } else {
                agentIQR = IQRFactory(iqrFactory).createAgentIQR(_agent, branchIdCount);
                agentIQRContracts[_agent][branchIdCount] = agentIQR;
                 // Đăng ký branch vào BranchManagement
                BranchInfo memory branchInfo = mBranchIdToBranch[branchIdCount];
                IBranchManagement(branchMgmt).createBranch(
                    branchIdCount,
                    branchInfo.name,
                    branchInfo.isMain,
                    true,
                    hasMeos,
                    hasRobot
                );
                // if(branchInfo.isMain){
                    IBMFactory(bmFactory).addManagerMainBranch(branchMgmt,_agent,branchIds);
                // }
            }
            emit PermissionGranted(_agent, 0, block.timestamp);
        }
        
    }
    /**
     * @dev Grant Loyalty permission by deploying contract
     */
    function _grantLoyaltyPermission(address _agent) internal {
        if (loyaltyFactory == address(0)) {
            agents[_agent].permissions[1] = false;
            return;
        }
        address contractAddr = ILoyaltyFactory(loyaltyFactory).getAgentLoyaltyContract(_agent);
        if(contractAddr != address(0)){
            // IRestaurantLoyaltySystem(contractAddr).unpause();
        }else{
            contractAddr = ILoyaltyFactory(loyaltyFactory).createAgentLoyalty(_agent);
            agentLoyaltyContracts[_agent] = contractAddr;            // la contract Points
        }

        // for(uint i; i < branchIds.length; i++){
        //     uint branchIdCount = branchIds[i];
        //     address contractAddr = ILoyaltyFactory(loyaltyFactory).getAgentLoyaltyContract(_agent,branchIdCount);
        //     if(contractAddr != address(0)){
        //         // IRestaurantLoyaltySystem(contractAddr).unfreeze();
        //     }else{
        //         contractAddr = ILoyaltyFactory(loyaltyFactory).createAgentLoyalty(_agent,branchIdCount);
        //         agentLoyaltyContracts[_agent][branchIdCount] = contractAddr;            // la contract Points
        //     }
        //     emit PermissionGranted(_agent, 1, block.timestamp);
        // }
    }
    
    /**
     * @dev Grant Robot permission by generating license key
     */
    function _grantRobotPermission(address _agent, uint[] memory branchIds, address branchMgmt,bool hasIqr,bool hasMeos) internal {
        if (robotFactory == address(0)) {
            agents[_agent].permissions[3] = false;
            return;
        }
        // Tạo IQR contracts cho từng branch và đăng ký vào BranchManagement
        for(uint i; i < branchIds.length; i++){
            uint branchIdCount = branchIds[i];
            address agentRobot = RobotFactory(robotFactory).getAgentROBOTContract(_agent, branchIdCount);
            
            if(agentRobot != address(0) && agentROBOTContracts[_agent][branchIdCount] != address(0)){
                IAgentRobot(agentRobot).reactivate();
            } else {
                agentRobot = RobotFactory(robotFactory).createAgentRobot(_agent, branchIdCount,hasIqr,hasMeos);
                agentROBOTContracts[_agent][branchIdCount] = agentRobot;
                if(!hasIqr && !hasMeos){
                    BranchInfo memory branchInfo = mBranchIdToBranch[branchIdCount];
                    IBranchManagement(branchMgmt).createBranch(
                        branchIdCount,
                        branchInfo.name,
                        branchInfo.isMain,
                        hasIqr,
                        hasMeos,
                        true
                    );
                    IBMFactory(bmFactory).addManagerMainBranch(branchMgmt,_agent,branchIds);                    
                }                
            }
            emit PermissionGranted(_agent, 3, block.timestamp);
        }
    }
    function _grantMeOSPermission(address _agent, uint[] memory branchIds, address branchMgmt, bool hasIqr,bool hasRobot) internal {
        if (meosFactory == address(0)) {
            agents[_agent].permissions[2] = false;
            return;
        }

        // Tạo IQR contracts cho từng branch và đăng ký vào BranchManagement
        for(uint i; i < branchIds.length; i++){
            uint branchIdCount = branchIds[i];
            address agentMeos = MeosFactory(meosFactory).getAgentMEOSContract(_agent, branchIdCount);
            
            if(agentMeos != address(0) && agentMEOSContracts[_agent][branchIdCount] != address(0)){
                IAgentMeos(agentMeos).reactivate();
            } else {
                agentMeos = MeosFactory(meosFactory).createAgentMeos(_agent, branchIdCount,hasIqr);
                agentMEOSContracts[_agent][branchIdCount] = agentMeos;
                if(!hasIqr){
                    BranchInfo memory branchInfo = mBranchIdToBranch[branchIdCount];
                    IBranchManagement(branchMgmt).createBranch(
                        branchIdCount,
                        branchInfo.name,
                        branchInfo.isMain,
                        hasIqr,
                        true,
                        hasRobot
                    );
                    IBMFactory(bmFactory).addManagerMainBranch(branchMgmt,_agent,branchIds);                    
                }                
            }
            emit PermissionGranted(_agent, 2, block.timestamp);
        }
        
    }
    /**
     * @dev Generate unique license key for MeOS
     */
    function _generateLicenseKey(address _agent, uint branchIdCount) internal view returns (string memory) {
        return string(abi.encodePacked(
            "MEOS-",
            Strings.toHexString(uint160(_agent), 20),
            "-",
            Strings.toString(block.timestamp)
        ));
    }
    

/**
 * @dev Update agent information and permissions
 * @return newBranchIds Array of newly created branch IDs
 */
function updateAgent(
    address _agent,
    string memory _storeName,
    string memory _address,
    string memory _phone,
    string memory _note,
    bool[4] memory _permissions,
    string memory _domain,
    BranchInfo[] memory branchInfos
) external onlySuperAdmin validAgent(_agent) whenNotPaused nonReentrant returns (uint[] memory  newBranchIds) {
    Agent storage agent = agents[_agent];
    // Update basic info
    agent.storeName = _storeName;
    agent.storeAddress = _address;
    agent.phone = _phone;
    agent.note = _note;
    agent.updatedAt = block.timestamp;
    
    // Update main branch info
    uint mainBranchId = mAgentToMainBranchId[_agent];
    if (mainBranchId > 0) {
        BranchInfo storage mainBranch = mBranchIdToBranch[mainBranchId];
        mainBranch.name = _storeName;
        mainBranch.location = _address;
        mainBranch.phone = _phone;
        // Update domain if changed
        if (keccak256(abi.encodePacked(mainBranch.domain)) != keccak256(abi.encodePacked(_domain))) {
            require(mDomainToWallet[_domain] == address(0) || mDomainToWallet[_domain] == _agent, 
                    "Domain already in use");
            
            // Remove old domain mapping
            delete mDomainToWallet[mainBranch.domain];
            delete mDomainToBranchId[mainBranch.domain];
            
            // Set new domain
            mainBranch.domain = _domain;
            agent.domain = _domain;
            mDomainToWallet[_domain] = agent.walletAddress;
            mDomainToBranchId[_domain] = mainBranchId;
            mAgentToDomain[agent.walletAddress] = _domain;
        }
        // Update main branch in BranchManagement
        if (agentBranchManagement[_agent] != address(0)) {
            IBranchManagement(agentBranchManagement[_agent]).updateBranch(
                mainBranchId,
                _storeName
            );
        }
    }
    // Handle sub-branches update by branchId and get new branch IDs
    newBranchIds = _updateSubBranchesByIds(_agent, branchInfos);
     // Grant permissions for new branches if agent already has permissions
    if (newBranchIds.length > 0) {
        _grantPermissionsForNewBranches(_agent, newBranchIds, agent.permissions,agentBranchManagement[_agent]);
    }
    // Update permissions with current branch IDs
    uint[] memory branchIds = agentToBranchIds[_agent];
    _updatePermissions(_agent, _permissions, branchIds,agentBranchManagement[_agent]);
    emit AgentUpdated(_agent, block.timestamp);
    
    return newBranchIds;
}

/**
 * @dev Update sub-branches by branchId
 * Logic: 
 * - branchId = 0: create new branch
 * - branchId > 0: update existing branch
 * - branches not in input: delete them
 * @return newBranchIds Array of newly created branch IDs
 */
function _updateSubBranchesByIds(address _agent, BranchInfo[] memory branchInfos) internal returns (uint[] memory) {
    Agent storage agent = agents[_agent];
    uint[] storage currentBranchIds = agentToBranchIds[_agent];
    uint mainBranchId = mAgentToMainBranchId[_agent];
    address branchMgmt = agentBranchManagement[_agent];
    
    // Track which branch IDs are in the new input
    uint[] memory inputBranchIds = new uint[](branchInfos.length);
    uint inputBranchCount = 0;
    
    // Track new branch IDs created
    uint[] memory newBranchIds = new uint[](branchInfos.length);
    uint newBranchCount = 0;
    
    // Step 1: Process input - update existing or create new
    for (uint i = 0; i < branchInfos.length; i++) {
        BranchInfo memory input = branchInfos[i];
        
        if (input.branchId == 0) {
            // New branch - create it
            branchIdCount++;
            uint newBranchId = branchIdCount;
            
            // Create new branch
            mBranchIdToBranch[newBranchId] = BranchInfo({
                branchId: newBranchId,
                name: input.name,
                location: input.location,
                phone: input.phone,
                domain: input.domain,
                isActive: true,
                isMain: false,
                createdAt: block.timestamp
            });
            
            // Add to agent's branch list
            currentBranchIds.push(newBranchId);
            
            // Track this new branch ID
            inputBranchIds[inputBranchCount] = newBranchId;
            inputBranchCount++;
            
            // Add to new branch IDs array
            newBranchIds[newBranchCount] = newBranchId;
            newBranchCount++;
            mDomainToWallet[input.domain] = _agent;
            mDomainToBranchId[input.domain] = newBranchId;

            // // Register new branch in BranchManagement
            // if (branchMgmt != address(0)) {
            //     IBranchManagement(branchMgmt).createBranch(
            //         newBranchId,
            //         input.name,
            //         false  // isMain = false
            //     );
            // }
            
            
        } else {
            // Existing branch - update it
            uint branchId = input.branchId;
            
            // Verify this branch belongs to this agent
            bool belongsToAgent = false;
            for (uint j = 0; j < currentBranchIds.length; j++) {
                if (currentBranchIds[j] == branchId) {
                    belongsToAgent = true;
                    break;
                }
            }
            require(belongsToAgent, "Branch does not belong to this agent");
            require(branchId != mainBranchId, "Cannot modify main branch through sub-branches");
            
            // Update existing branch
            BranchInfo storage existingBranch = mBranchIdToBranch[branchId];
            existingBranch.name = input.name;
            existingBranch.location = input.location;
            existingBranch.phone = input.phone;
            existingBranch.domain = input.domain;
            existingBranch.isActive = true;
            // Keep original createdAt and isMain
            delete mDomainToWallet[input.domain];
            delete mDomainToBranchId[input.domain];

            mDomainToWallet[input.domain] = _agent;
            mDomainToBranchId[input.domain] = branchId;
            // Update branch in BranchManagement
            if (branchMgmt != address(0)) {
                IBranchManagement(branchMgmt).updateBranch(
                    branchId,
                    input.name
                );
            }
            
            // Track this branch ID
            inputBranchIds[inputBranchCount] = branchId;
            inputBranchCount++;
        }
    }
    
    // Step 2: Delete branches that are not in input (except main branch)
    uint writeIndex = 0;
    for (uint i = 0; i < currentBranchIds.length; i++) {
        uint branchId = currentBranchIds[i];
        
        // Check if this branch should be kept
        bool shouldKeep = (branchId == mainBranchId);
        
        if (!shouldKeep) {
            // Check if this branch ID is in the input
            for (uint j = 0; j < inputBranchCount; j++) {
                if (inputBranchIds[j] == branchId) {
                    shouldKeep = true;
                    break;
                }
            }
        }
        
        if (shouldKeep) {
            // Keep this branch
            if (writeIndex != i) {
                currentBranchIds[writeIndex] = branchId;
            }
            writeIndex++;
        } else {
            // Delete this branch
            _validateBranchDeletion(_agent, branchId);
            
            // Deactivate branch in BranchManagement
            if (branchMgmt != address(0)) {
                IBranchManagement(branchMgmt).deactivateBranch(branchId);
            }
            
            // Revoke permissions for this branch
            for (uint8 j = 0; j < 3; j++) {
                if (agent.permissions[j]) {
                    _revokePermission(_agent, branchId, j);
                }
            }
            
            // Deactivate branch
            mBranchIdToBranch[branchId].isActive = false;
        }
    }
    
    // Resize array to remove deleted branches
    while (currentBranchIds.length > writeIndex) {
        currentBranchIds.pop();
    }
    
    // Step 3: Rebuild agent.branches array from current branch IDs (excluding main branch)
    delete agent.branches;
    for (uint i = 0; i < currentBranchIds.length; i++) {
        uint branchId = currentBranchIds[i];
        if (branchId != mainBranchId) {
            BranchInfo memory branchInfo = mBranchIdToBranch[branchId];
            agent.branches.push(branchInfo);
        }
    }
    
    // Step 4: Return array of new branch IDs (resize to actual count)
    uint[] memory result = new uint[](newBranchCount);
    for (uint i = 0; i < newBranchCount; i++) {
        result[i] = newBranchIds[i];
    }
    
    return result;
}
/**
 * @dev Grant permissions for newly created branches (if agent already has those permissions)
 */
function _grantPermissionsForNewBranches(
    address _agent,
    uint[] memory _newBranchIds,
    bool[4] memory _currentPermissions,
    address _branchManagementSc
) internal {
    // If agent already has IQR permission, grant it to new branches
    if (_currentPermissions[0]) {
        _grantIQRPermission(_agent, _newBranchIds,_branchManagementSc,_currentPermissions[2],_currentPermissions[3]);
    }
    
    // If agent already has Loyalty permission, grant it to new branches
    if (_currentPermissions[1]) {
        _grantLoyaltyPermission(_agent);
    }
    
    // If agent already has MeOS permission, grant it to new branches
    if (_currentPermissions[2]) {
        _grantMeOSPermission(_agent, _newBranchIds,_branchManagementSc,_currentPermissions[0],_currentPermissions[3]);
    }
    // If agent already has Robot permission, grant it to new branches
    if (_currentPermissions[3]) {
        _grantRobotPermission(_agent, _newBranchIds,_branchManagementSc,_currentPermissions[0],_currentPermissions[1]);
    }
}
/**
 * @dev Validate if branch can be deleted (check loyalty tokens)
 */
function _validateBranchDeletion(address _agent, uint _branchId) internal view {
    // Cannot delete main branch
    require(!mBranchIdToBranch[_branchId].isMain, "Cannot delete main branch");
    
    // Check if has active loyalty tokens
    if (agents[_agent].permissions[1]) {
        address loyaltyContract = agentLoyaltyContracts[_agent];
        if (loyaltyContract != address(0)) {
            // uint256 supply = IRestaurantLoyaltySystem(loyaltyContract).totalSupply();
            // bool isFrozen = IRestaurantLoyaltySystem(loyaltyContract).isFrozen();
            // bool isRedeemOnly = IRestaurantLoyaltySystem(loyaltyContract).isRedeemOnly();
            
            // require(
            //     !(supply > 0 && !isFrozen && !isRedeemOnly),
            //     "Branch has active loyalty tokens"
            // );
        }
    }
}

/**
 * @dev Update agent permissions with branch support
 */
function _updatePermissions(
    address _agent, 
    bool[4] memory _newPermissions,
    uint[] memory _branchIds,
    address _branchManagementSc
) internal {
    Agent storage agent = agents[_agent];
    for (uint8 i = 0; i < 4; i++) {
        if (agent.permissions[i] != _newPermissions[i]) {
            if (_newPermissions[i]) {
                // Grant permission
                if (i == 0) {
                    _grantIQRPermission(_agent, _branchIds,_branchManagementSc,_newPermissions[2],_newPermissions[3]);
                } else if (i == 1) {
                    require(agent.permissions[0], "Need IQR permission to set Loyalty permission");
                    _grantLoyaltyPermission(_agent);
                } else if (i == 2) {
                    _grantMeOSPermission(_agent, _branchIds,_branchManagementSc,_newPermissions[0],_newPermissions[3]);
                }
                else if (i == 3) {
                    _grantRobotPermission(_agent, _branchIds,_branchManagementSc,_newPermissions[0],_newPermissions[1]);
                }
            } else {
                // Revoke permission for all branches
                for (uint j = 0; j < _branchIds.length; j++) {
                    _revokePermission(_agent, _branchIds[j], i);
                }
                
            }
            agent.permissions[i] = _newPermissions[i];

        }
    }
}
    /**
     * @dev Revoke specific permission
     */
    function _revokePermission(address _agent,uint _branchId, uint8 _permissionType) internal {
        if (_permissionType == 0) { // IQR
            address iqrContract = agentIQRContracts[_agent][_branchId];
            if (iqrContract != address(0)) {
                IAgentIQR(iqrContract).deactivate();
            }
        } else if (_permissionType == 1) { // Loyalty
            address loyaltyContract = agentLoyaltyContracts[_agent];
            if (loyaltyContract != address(0)) {
                // IRestaurantLoyaltySystem(loyaltyContract).pause();
            }
        } else if (_permissionType == 2) { // MeOS
            // address meosContract = agentMEOSContracts[_agent][_branchId];
            // if (meosContract != address(0)) {
            //     IAgentMeos(meosContract).deactivate();
            // }
            
        }else{
            // address robotContract = agentROBOTContracts[_agent][_branchId];
            // if (robotContract != address(0)) {
            //     IAgentRobot(robotContract).deactivate();
            // }
        }
        
        emit PermissionRevoked(_agent, _permissionType, block.timestamp);
    }
    
/**
 * @dev Delete agent with improved branch handling
 * @param _agent Agent address to delete
 */
function deleteAgent(address _agent) 
    external 
    onlySuperAdmin 
    validAgent(_agent) 
    whenNotPaused 
    nonReentrant 
{
    Agent storage agent = agents[_agent];
    uint[] memory branchIds = agentToBranchIds[_agent];
    
    // Check if has active loyalty tokens in ANY branch
    if (agent.permissions[1]) {
        for (uint i = 0; i < branchIds.length; i++) {
            address loyaltyContract = agentLoyaltyContracts[_agent];
            // if (loyaltyContract != address(0)) {
            //     uint256 supply = IRestaurantLoyaltySystem(loyaltyContract).totalSupply();
            //     bool isFrozen = IRestaurantLoyaltySystem(loyaltyContract).isFrozen();
            //     bool isRedeemOnly = IRestaurantLoyaltySystem(loyaltyContract).isRedeemOnly();
                
            //     require(
            //         !(supply > 0 && !isFrozen && !isRedeemOnly),
            //         "HasActiveLoyaltyTokens in one or more branches"
            //     );
            // }
        }
    }
    
    // Revoke all permissions for all branches
    bool[4] memory noPermissions = [false, false, false,false];
    _updatePermissions(_agent, noPermissions, branchIds,agentBranchManagement[_agent]);
    
    // Deactivate all branches
    for (uint i = 0; i < branchIds.length; i++) {
        if (mBranchIdToBranch[branchIds[i]].isActive) {
            mBranchIdToBranch[branchIds[i]].isActive = false;
        }
    }
    
    // Clear domain mappings
    if (bytes(agent.domain).length > 0) {
        delete mDomainToWallet[agent.domain];
        delete mAgentToDomain[_agent];
        delete mDomainToBranchId[agent.domain];
    }
    
    // Mark as deleted
    agent.isActive = false;
    agent.updatedAt = block.timestamp;
    agent.exists = false;
    
    // Store in deleted agents array
    deletedAgents.push(agent);
    
    emit AgentDeleted(_agent, block.timestamp);
}

function getDeletedAgentd() external view returns(Agent[] memory){
        return deletedAgents;
    }

/**
 * @dev Get deleted agents with pagination and search filter
 * @param _page Page number (starts from 1)
 * @param _pageSize Number of items per page
 * @param _searchTerm Search term for store name or wallet address (empty string for no filter)
 * @return agentArr Array of deleted agent information
 * @return totalCount Total number of matching deleted agents
 * @return totalPages Total number of pages
 * @return currentPage Current page number
 */
function getDeletedAgentsPaginated(
    uint256 _page,
    uint256 _pageSize,
    string memory _searchTerm
) external view returns (
    Agent[] memory agentArr,
    uint256 totalCount,
    uint256 totalPages,
    uint256 currentPage
) {
    // Filter deleted agents by search term
    Agent[] memory filtered;
    bytes memory searchBytes = bytes(_searchTerm);
    
    if (searchBytes.length > 0) {
        filtered = _filterDeletedAgentsBySearch(searchBytes);
    } else {
        filtered = deletedAgents;
    }
    
    totalCount = filtered.length;
    totalPages = totalCount > 0 ? (totalCount + _pageSize - 1) / _pageSize : 0;
    currentPage = _page;
    
    // Validate page number
    if (_page == 0 || _page > totalPages || totalCount == 0) {
        return (new Agent[](0), totalCount, totalPages, currentPage);
    }
    
    // Calculate pagination indices
    uint256 startIndex = (_page - 1) * _pageSize;
    uint256 endIndex = startIndex + _pageSize;
    if (endIndex > totalCount) {
        endIndex = totalCount;
    }
    
    // Build page result
    uint256 pageLength = endIndex - startIndex;
    Agent[] memory pageResult = new Agent[](pageLength);
    
    for (uint256 i = 0; i < pageLength; i++) {
        pageResult[i] = filtered[startIndex + i];
    }
    
    return (pageResult, totalCount, totalPages, currentPage);
}
/**
 * @dev Filter deleted agents by search term (store name or wallet address)
 * @param _searchBytes Search term in bytes
 * @return Agent[] Filtered array of deleted agents
 */
function _filterDeletedAgentsBySearch(
    bytes memory _searchBytes
) internal view returns (Agent[] memory) {
    // Count matching deleted agents
    uint256 count = 0;
    for (uint256 i = 0; i < deletedAgents.length; i++) {
        if (_matchesSearchDeletedAgent(deletedAgents[i], _searchBytes)) {
            count++;
        }
    }
    
    // Build filtered array
    Agent[] memory filtered = new Agent[](count);
    uint256 index = 0;
    
    for (uint256 i = 0; i < deletedAgents.length; i++) {
        if (_matchesSearchDeletedAgent(deletedAgents[i], _searchBytes)) {
            filtered[index] = deletedAgents[i];
            index++;
        }
    }
    
    return filtered;
}
/**
 * @dev Helper function to check if deleted agent matches search criteria
 * @param _agent Agent struct to check
 * @param _searchBytes Search term in bytes
 * @return bool True if agent matches search term
 */
function _matchesSearchDeletedAgent(
    Agent memory _agent,
    bytes memory _searchBytes
) internal pure returns (bool) {
    // Search in store name
    bytes memory storeNameBytes = bytes(_agent.storeName);
    if (_containsIgnoreCaseDeletedAgent(storeNameBytes, _searchBytes)) {
        return true;
    }
    
    // Search in wallet address
    // Convert address to hex string for comparison
    string memory walletStr = _addressToString(_agent.walletAddress);
    bytes memory walletBytes = bytes(walletStr);
    
    // Convert search term to lowercase
    bytes memory searchLower = _toLowerBytes(_searchBytes);
    
    if (_containsIgnoreCaseDeletedAgent(walletBytes, searchLower)) {
        return true;
    }
    
    return false;
}

/**
 * @dev Helper function to check if bytes contains substring (case-insensitive)
 * @param _haystack The string to search in
 * @param _needle The string to search for
 * @return bool True if needle is found in haystack
 */
function _containsIgnoreCaseDeletedAgent(
    bytes memory _haystack,
    bytes memory _needle
) internal pure returns (bool) {
    if (_needle.length > _haystack.length) return false;
    if (_needle.length == 0) return true;
    
    // Convert both to lowercase for comparison
    bytes memory haystackLower = _toLowerBytes(_haystack);
    bytes memory needleLower = _toLowerBytes(_needle);
    
    // Search for substring
    for (uint256 i = 0; i <= haystackLower.length - needleLower.length; i++) {
        bool isMatch = true;
        for (uint256 j = 0; j < needleLower.length; j++) {
            if (haystackLower[i + j] != needleLower[j]) {
                isMatch = false;
                break;
            }
        }
        if (isMatch) return true;
    }
    
    return false;
}

/**
 * @dev Convert bytes to lowercase
 * @param _input Bytes to convert
 * @return bytes Lowercase bytes
 */
function _toLowerBytes(bytes memory _input) internal pure returns (bytes memory) {
    bytes memory result = new bytes(_input.length);
    
    for (uint256 i = 0; i < _input.length; i++) {
        bytes1 char = _input[i];
        if (char >= 0x41 && char <= 0x5A) { // A-Z
            result[i] = bytes1(uint8(char) + 32);
        } else {
            result[i] = char;
        }
    }
    
    return result;
}

/**
 * @dev Convert address to lowercase hex string (without 0x prefix)
 * @param _addr Address to convert
 * @return string Lowercase hex string
 */
function _addressToString(address _addr) internal pure returns (string memory) {
    bytes memory alphabet = "0123456789abcdef";
    bytes memory str = new bytes(40); // 20 bytes * 2 chars per byte
    
    uint160 addrUint = uint160(_addr);
    
    for (uint256 i = 0; i < 20; i++) {
        str[i * 2] = alphabet[uint8(addrUint >> ((19 - i) * 8 + 4)) & 0xf];
        str[i * 2 + 1] = alphabet[uint8(addrUint >> ((19 - i) * 8)) & 0xf];
    }
    
    return string(str);
}
    // ========================================================================
    // LOYALTY TOKEN MANAGEMENT
    // ========================================================================
    
    // /**
    //  * @dev Unlock loyalty tokens for agent
    //  */
    // function unlockLoyaltyTokens(address _agent, uint _branchId) 
    //     external 
    //     onlySuperAdmin 
    //     validAgent(_agent) 
    //     whenNotPaused 
    //     nonReentrant 
    //     returns (uint256) 
    // {
    //     address loyaltyContract = agentLoyaltyContracts[_agent];
    //     if (loyaltyContract == address(0)) return 0;
    //     uint unlockedAmount =  IRestaurantLoyaltySystem(loyaltyContract).unlockTokens();
    //     emit LoyaltyTokensUnlocked(_agent, unlockedAmount);
    //     return unlockedAmount;

    // }
    
        // ============================================================================
    // UPDATED AGENT MANAGEMENT CONTRACT - MIGRATION FUNCTION
    // ============================================================================

    // /**
    // * @dev Migrate loyalty tokens from old agent to new agent (FULL IMPLEMENTATION)
    // * This handles complete migration including all user balances
    // */
    // function migrateLoyaltyTokens(
    //     address _oldAgent, 
    //     address _newAgent,
    //     uint _branchIdOldAgent,
    //     uint _branchIdNewAgent
    // ) 
    //     external 
    //     onlySuperAdmin 
    //     whenNotPaused 
    //     nonReentrant 
    //     returns (
    //         uint256 totalMigrated
    //         // uint256 userCount,
    //         // bool success
    //     ) 
    // {
    //     uint256 userCount;
    //     bool success;
    //     require(agents[_oldAgent].exists && agents[_newAgent].exists, "Agent not found");
    //     require(_oldAgent != _newAgent, "Cannot migrate to same agent");
        
    //     address oldContract = agentLoyaltyContracts[_oldAgent][_branchIdOldAgent];
    //     address newContract = agentLoyaltyContracts[_newAgent][_branchIdNewAgent];
        
    //     require(oldContract != address(0), "Old contract not found");
    //     require(newContract != address(0), "New contract not found");
    //     require(oldContract != newContract, "Contracts are the same");
        
    //     RestaurantLoyaltySystem oldLoyalty = RestaurantLoyaltySystem(oldContract);
    //     RestaurantLoyaltySystem newLoyalty = RestaurantLoyaltySystem(newContract);
        
    //     // // Verify old contract is not already migrated
    //     // require(!oldLoyalty.migrated(), "Old contract already migrated");
        
    //     // PHASE 1: Initiate migration on old contract
    //     // oldLoyalty.migrateTo(newContract);
            
    //     // PHASE 2: Get all token holders and their balances
    //     (address[] memory holders, uint256[] memory balances) = 
    //         oldLoyalty.getTokenHoldersWithBalances();
    //     if (holders.length == 0) {
    //         emit LoyaltyTokensMigrated(_oldAgent, _newAgent, 0);
    //         // return (0, 0, true);
    //         return 0;
    //     }
        
    //     // PHASE 3: Receive migration in new contract (batch process)
    //     uint256 received = newLoyalty.receiveMigration(oldContract, holders, balances) ;
    //         totalMigrated = received;
    //         userCount = holders.length;
    //         success = true;
            
    //         emit LoyaltyTokensMigrated(_oldAgent, _newAgent, totalMigrated);
            
    //         // return (totalMigrated, userCount, true);
    //         return totalMigrated;
                            
    // }

    // /**
    // * @dev Get migration status for an agent
    // */
    // function getLoyaltyMigrationStatus(address _agent,uint _branchId)
    //     external
    //     view
    //     validAgent(_agent)
    //     returns (
    //         bool hasMigrated,
    //         address migratedTo,
    //         uint256 totalMigrated,
    //         uint256 remainingSupply,
    //         uint256 tokenHolderCount
    //     )
    // {
    //     address loyaltyContract = agentLoyaltyContracts[_agent][_branchId];
    //     if (loyaltyContract == address(0)) {
    //         return (false, address(0), 0, 0, 0);
    //     }
        
    //     RestaurantLoyaltySystem loyalty = RestaurantLoyaltySystem(loyaltyContract);
        
    //     (bool migrated, address migratedToAddr, uint256 migrated_amount, uint256 remaining) = 
    //         loyalty.getMigrationInfo();
        
    //     address[] memory holders = loyalty.getTokenHolders();
        
    //     return (migrated, migratedToAddr, migrated_amount, remaining, holders.length);
    // }

    // /**
    // * @dev Verify migration completion
    // */
    // function verifyLoyaltyMigration(address _oldAgent, address _newAgent,uint _branchId)
    //     external
    //     view
    //     returns (
    //         bool oldContractMigrated,
    //         bool allUsersMigrated,
    //         uint256 oldContractSupply,
    //         uint256 newContractSupply,
    //         string memory status
    //     )
    // {
    //     address oldContract = agentLoyaltyContracts[_oldAgent][_branchId];
    //     address newContract = agentLoyaltyContracts[_newAgent][_branchId];
        
    //     if (oldContract == address(0) || newContract == address(0)) {
    //         return (false, false, 0, 0, "Contracts not found");
    //     }
        
    //     RestaurantLoyaltySystem oldLoyalty = RestaurantLoyaltySystem(oldContract);
    //     RestaurantLoyaltySystem newLoyalty = RestaurantLoyaltySystem(newContract);
        
    //     oldContractMigrated = oldLoyalty.migrated();
    //     // (,, uint256 migrated,) = oldLoyalty.getMigrationInfo();
    //     (uint256 oldSupply,,,,) = oldLoyalty.getTokenStats();
    //     (uint256 newSupply,,,,) = newLoyalty.getTokenStats();
        
    //     oldContractSupply = oldSupply;
    //     newContractSupply = newSupply;
        
    //     if (!oldContractMigrated) {
    //         status = "Migration not initiated";
    //         return (false, false, oldSupply, newSupply, status);
    //     }
        
    //     if (oldSupply == 0 && newSupply > 0) {
    //         allUsersMigrated = true;
    //         status = "Migration completed successfully";
    //     } else if (oldSupply > 0) {
    //         allUsersMigrated = false;
    //         status = "Migration incomplete - users still have balance in old contract";
    //     } else {
    //         status = "Unknown state";
    //     }
    // }   

    // /**
    //  * @dev Set loyalty contract to redeem-only mode
    //  */
    // function setLoyaltyRedeemOnly(address _agent,uint _branchId, uint256 _days) 
    //     external 
    //     onlySuperAdmin 
    //     validAgent(_agent) 
    //     whenNotPaused 
    // {
    //     address loyaltyContract = agentLoyaltyContracts[_agent][_branchId];
    //    require(loyaltyContract != address(0),"ContractNotSet");
        
    //     IRestaurantLoyaltySystem(loyaltyContract).setRedeemOnly(_days);
    // }
    
    // ========================================================================
    // DASHBOARD & ANALYTICS
    // ========================================================================
    
    /**
     * @dev Get dashboard metrics
     */
    function getDashboardMetrics() external view returns (
        MTDStats memory mtdStats,
        uint256[4] memory revenue, // [iqr, loyalty, meos, total]
        uint256 totalAgents,
        uint256 activeAgents
    ) {
        // MTD Stats
        if (mtdToken != address(0)) {
            uint256 supply = IMTDToken(mtdToken).totalSupply();
            mtdStats.totalSupply = supply;
            // uint256 balance = IMTDToken(mtdToken).balanceOf(address(this));
        }
        
        // Revenue Stats
        if (revenueManager != address(0)) {
            (uint256 iqr, uint256 loyalty, uint256 meos, uint256 total) = IRevenueManager(revenueManager).getSystemRevenue();               
                revenue[0] = iqr;
                revenue[1] = loyalty;
                revenue[2] = meos;
                revenue[3] = total;
        }
        
        // Agent Stats
        totalAgents = agentList.length;
        activeAgents = getActiveAgentsCount();
    }
    
    /**
     * @dev Get revenue details for specific agent
     */
    function getAgentRevenueDetail(address _agent) 
        external 
        view 
        validAgent(_agent)
        returns (uint256 iqr, uint256 loyalty, uint256 meos, uint256 total) 
    {
        if (revenueManager != address(0)) {
            try IRevenueManager(revenueManager).getAgentRevenue(_agent) returns (
                uint256 _iqr, uint256 _loyalty, uint256 _meos, uint256 _total
            ) {
                return (_iqr, _loyalty, _meos, _total);
            } catch {
                return (0, 0, 0, 0);
            }
        }
        return (0, 0, 0, 0);
    }
    
    // ========================================================================
    // VIEW FUNCTIONS
    // ========================================================================
    
    /**
     * @dev Get agent information
     */
    function getAgent(address _agent) external view returns (Agent memory) {
        return agents[_agent];
    }
    function getAgents(address[] memory agentAdds)external view returns (Agent[] memory agentArr) {
        agentArr = new Agent[](agentAdds.length);
        for(uint i=0; i<agentAdds.length; i++){
            agentArr[i] = agents[agentAdds[i]];
        }
    }
    /**
     * @dev Get all agents
     */
    function getAllAgents() external view returns (address[] memory) {
        return agentList;
    }
    
    /**
     * @dev Get active agents only
     */
    function getActiveAgents() public view returns (address[] memory) {
        uint256 activeCount = getActiveAgentsCount();
        address[] memory activeAgentsList = new address[](activeCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive) {
                activeAgentsList[index] = agentList[i];
                index++;
            }
        }
        
        return activeAgentsList;
    }
    
    /**
     * @dev Get count of active agents
     */
    function getActiveAgentsCount() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive) {
                count++;
            }
        }
        return count;
    }
    
    /**
     * @dev Get agents by specific permission
     */
    function getAgentsByPermission(uint8 _permissionType) 
        external 
        view 
        returns (address[] memory) 
    {
        require(_permissionType <= 2,"InvalidPermissionType");
        
        uint256 count = 0;
        
        // Count first
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive && agents[agentList[i]].permissions[_permissionType]) {
                count++;
            }
        }
        
        // Fill array
        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive && agents[agentList[i]].permissions[_permissionType]) {
                result[index] = agentList[i];
                index++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get agents with all permissions
     */
    function getFullPermissionAgents() external view returns (address[] memory) {
        uint256 count = 0;
        
        // Count first
        for (uint256 i = 0; i < agentList.length; i++) {
            Agent memory agent = agents[agentList[i]];
            if (agent.isActive && agent.permissions[0] && agent.permissions[1] && agent.permissions[2]) {
                count++;
            }
        }
        
        // Fill array
        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            Agent memory agent = agents[agentList[i]];
            if (agent.isActive && agent.permissions[0] && agent.permissions[1] && agent.permissions[2]) {
                result[index] = agentList[i];
                index++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get MeOS license for agent
     */
    function getMeOSLicense(address _agent,uint _branchId) 
        external 
        view 
        validAgent(_agent) 
        returns (MeOSLicense memory) 
    {
        return meosLicenses[_agent][_branchId];
    }
    
    /**
     * @dev Search agents by store name (simple contains search)
     */
    function searchAgentsByStoreName(string memory _searchTerm) 
        external 
        view 
        returns (address[] memory) 
    {
        bytes memory searchBytes = bytes(_searchTerm);
        if (searchBytes.length == 0) {
            return getActiveAgents();
        }
        
        // Count matching agents first
        uint256 matchCount = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive) {
                bytes memory storeNameBytes = bytes(agents[agentList[i]].storeName);
                if (_contains(storeNameBytes, searchBytes)) {
                    matchCount++;
                }
            }
        }
        
        // Build result array
        address[] memory results = new address[](matchCount);
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < agentList.length; i++) {
            if (agents[agentList[i]].isActive) {
                bytes memory storeNameBytes = bytes(agents[agentList[i]].storeName);
                if (_contains(storeNameBytes, searchBytes)) {
                    results[resultIndex] = agentList[i];
                    resultIndex++;
                }
            }
        }
        
        return results;
    }
    
    /**
     * @dev Helper function to check if bytes contains substring
     */
    function _contains(bytes memory _haystack, bytes memory _needle) 
        internal 
        pure 
        returns (bool) 
    {
        if (_needle.length > _haystack.length) return false;
        if (_needle.length == 0) return true;
        
        for (uint256 i = 0; i <= _haystack.length - _needle.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < _needle.length; j++) {
                if (_haystack[i + j] != _needle[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) return true;
        }
        return false;
    }
    
    /**
     * @dev Get contract version
     */
    function getVersion() external view returns (string memory) {
        return version;
    }
    
    /**
     * @dev Get contract status
     */
    function getContractStatus() external view returns (
        string memory _version,
        bool _paused,
        // bool _adminInitialized,
        // address _superAdmin,
        uint256 _totalAgents,
        uint256 _activeAgents
    ) {
        return (
            version,
            paused,
            // adminInitialized,
            // superAdmin,
            agentList.length,
            getActiveAgentsCount()
        );
    }
    
    // ========================================================================
    // EMERGENCY FUNCTIONS
    // ========================================================================
    
    /**
     * @dev Pause contract operations
     */
    function pause() external onlySuperAdmin {
        paused = true;
        emit ContractPausedEvent(block.timestamp);
    }
    
    /**
     * @dev Unpause contract operations
     */
    function unpause() external onlySuperAdmin {
        paused = false;
        emit ContractUnpaused(block.timestamp);
    }
    
    /**
     * @dev Check if contract is paused
     */
    function isPaused() external view returns (bool) {
        return paused;
    }
} 

