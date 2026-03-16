// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./interfaces/IRestaurant.sol";
import "./interfaces/IAgent.sol";
import "./interfaces/IHistoryTracking.sol";
// import "forge-std/console.sol";
import "./interfaces/IFreeGas.sol";

/**
 * @title BranchManagement
 * @notice Quản lý đa chi nhánh và phân quyền cho hệ thống nhà hàng
 */
contract BranchManagement is 
    Initializable,
    UUPSUpgradeable
{
    
    // ==================== STATE VARIABLES ====================
    
    uint256 public mainMerchantId;
    string public merchantName;
    
    // Branch management
    uint256 public branchCounter;
    mapping(uint256 => Branch) public branches;
    uint256[] public branchIds;
    
    // Manager management
    mapping(address => ManagerInfo) public managers;
    address[] public managerAddresses;
    
    // Branch to Managers mapping
    mapping(uint256 => address[]) public branchManagers;
    mapping(uint256 => mapping(address => bool)) public isBranchManager;
    
    // Proposal management
    uint256 public proposalCounter;
    mapping(uint256 => Proposal) public proposals;
    uint256[] public proposalIds;
    
    // Proposal expiration (30 days in seconds)
    uint256 public constant PROPOSAL_EXPIRATION = 30 days;
    
    // Notification management
    uint256 public notificationCounter;
    mapping(address => uint256[]) public userNotifications;
    mapping(uint256 => Notification) public notifications;
    
    // Branch notifications
    mapping(uint256 => uint256[]) public branchNotifications;
    
    // Voting threshold (phần trăm cần thiết để thông qua - mặc định 51%)
    uint256 public votingThreshold;
    // address public Management; 
    PaymentInfo public paymentInfo;
    mapping(PaymentMethod => bool) public mPaymentMethodActive;
    uint8 public constant PAYMENT_METHOD_COUNT = 4; 
    PaymentOrder public paymentOrder; 
    Currency public currency;
    CurrencyDisplay public currencyDisplay;
    
    // proposalId => voter => hasVoted
    mapping(uint256 => mapping(address => bool)) public proposalHasVoted;
    // proposalId => voter => voteChoice (true = agree, false = disagree)
    mapping(uint256 => mapping(address => bool)) public proposalVoteChoice;
    mapping(address => bool) public isMainOwner;
    uint public mainBranchId;
    IStaffAgentStore public StaffAgentStore;
    address public agent;
    address public iqrFactorySc;
    address public meosFactorySc;
    address public robotFactorySc;
    // History Tracking Contract
    mapping(uint => address) public mBranchIdToHistoryTrack;
    address public historyTrackingIMP;
    address public freeGasSc;
    uint256[46] private __gap;
    
    // ==================== EVENTS ====================
    
    event BranchCreated(uint256 indexed branchId, string name);
    event BranchUpdated(uint256 indexed branchId, string name);
    event BranchDeactivated(uint256 indexed branchId);
    
    event ManagerAdded(address indexed manager, bool isCoOwner, uint256[] branchIds);
    event ManagerUpdated(address indexed manager);
    event ManagerRemoved(address indexed manager);
    
    event ProposalCreated(
        uint256 indexed proposalId, 
        address indexed proposer, 
        ProposalType proposalType,
        uint256 branchId
    );
    event ProposalVoted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId, ProposalStatus status);
    
    event NotificationSent(
        uint256 indexed notificationId,
        address indexed recipient,
        uint256 branchId
    );
    event HistoryTrackingUpdated(address indexed newHistoryTracking);
    // ==================== MODIFIERS ====================
    
    modifier onlyMainOwner() {
        require(isMainOwner[msg.sender], "Only main owner");
        _;
    }
    
    modifier onlyCoOwner() {
        require(
            isMainOwner[msg.sender] || 
            (managers[msg.sender].active && managers[msg.sender].isCoOwner),
            "Only co-owner"
        );
        _;
    }
    
    modifier onlyManagerOfBranch(uint256 branchId) {
        require(
            isMainOwner[msg.sender] ||
            _isManagerOfBranch(msg.sender, branchId),
            "Not manager of this branch"
        );
        _;
    }
    
    modifier canView(uint256 branchId) {
        require(
            isMainOwner[msg.sender] ||
            (managers[msg.sender].active && 
             managers[msg.sender].canViewData &&
             _isManagerOfBranch(msg.sender, branchId)),
            "No view permission"
        );
        _;
    }
    
    modifier canEdit(uint256 branchId) {
        require(
            isMainOwner[msg.sender] ||
            (managers[msg.sender].active && 
             managers[msg.sender].canEditData &&
             _isManagerOfBranch(msg.sender, branchId)),
            "No edit permission"
        );
        _;
    }
    
    modifier canPropose(uint256 branchId) {
        require(
            isMainOwner[msg.sender] ||
            (managers[msg.sender].active && 
             managers[msg.sender].canProposeAndVote &&
             _isManagerOfBranch(msg.sender, branchId)),
            "No propose permission"
        );
        _;
    }
    
    // ==================== INITIALIZATION ====================
    
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _agent,
        address _historyTrackingIMP,
        address _freeGasSc
    ) public initializer {
        __UUPSUpgradeable_init();
        
        votingThreshold = 51; // 51% mặc định
        isMainOwner[_agent] = true;
        isMainOwner[msg.sender] = true;
        agent = _agent;
        historyTrackingIMP = _historyTrackingIMP;
        freeGasSc = _freeGasSc;
    }
    
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override  
    {}
    // ==================== HISTORY TRACKING SETUP ====================
    /**
     * @notice Set History Tracking contract address
     * @dev Only main owner can set this
     */
    function setHistoryTracking(address _historyTracking) external onlyMainOwner {
        require(_historyTracking != address(0), "Invalid address");
        historyTrackingIMP = _historyTracking;
        emit HistoryTrackingUpdated(_historyTracking);
    }
    function setFreeGasSc(address _freeGasSc) external onlyMainOwner {
        require(_freeGasSc != address(0), "Invalid address");
        freeGasSc = _freeGasSc;
    }
    // ==================== BRANCH MANAGEMENT ====================
    
    function setMainOwner(address _agent) external onlyMainOwner{
        // require(isMainOwner[msg.sender],"only mainOwner");
        isMainOwner[_agent] = true;
    }
    function setStaffAgentStore(address _staffAgentStore)external onlyMainOwner{
        // require(isMainOwner[msg.sender],"only mainOwner");
        StaffAgentStore = IStaffAgentStore(_staffAgentStore);

    }
    function setIqrFactorySC(
        address _iqrFactorySc,
        address _meosFactorySc,
        address _robotFactorySc
    ) external {
        require(isMainOwner[msg.sender],"only mainOwner");
        iqrFactorySc = _iqrFactorySc;
        meosFactorySc = _meosFactorySc;
        robotFactorySc = _robotFactorySc;
    }
    function getMainBranchId()external view returns(uint){
        return mainBranchId;
    }
    /**
     * @notice Tạo chi nhánh mới
     */
    function createBranch(
        uint _newBranchId,
        string memory _name,
        bool _isMain,
        bool hasIqr,
        bool hasMeos,
        bool hasRobot
    ) external returns (uint256) {
        require(_newBranchId > 0, "Invalid branch ID");
        require(!branches[_newBranchId].active, "Branch already exists");
        require(bytes(_name).length > 0, "Branch name cannot be empty");
        
        branches[_newBranchId] = Branch({
            branchId: _newBranchId,
            name: _name,
            active: true,
            isMain: _isMain
        });
        if(_isMain){
            mainBranchId = _newBranchId;
        }
        branchIds.push(_newBranchId);
        
        // Auto-add all full-access managers to new branch
        for (uint256 i = 0; i < managerAddresses.length; i++) {
            address managerAddr = managerAddresses[i];
            if (managers[managerAddr].active && managers[managerAddr].hasFullAccess) {
                _addManagerToBranch(managerAddr, _newBranchId);
                managers[managerAddr].branchIds.push(_newBranchId);
            }
        }
        emit BranchCreated(_newBranchId, _name);
        //
        address management;
        if(hasIqr){
            IQRContracts memory iqrSC = IIQRFactory(iqrFactorySc).getIQRSCByAgentFromFactory(agent,_newBranchId);
            management = iqrSC.Management;
        }
        if(!hasIqr && hasMeos){
            MeosContracts memory meosSC = IMeosFactory(meosFactorySc).getMeosSCByAgentFromFactory(agent,_newBranchId);
            management = meosSC.StaffMeosSC;
        }
        if(!hasIqr && !hasMeos && hasRobot){
            RobotContracts memory robotSC = IRobotFactory(robotFactorySc).getRobotSCByAgentFromFactory(agent,_newBranchId);
            management = robotSC.StaffRobotSC;
        }
        require(management != address(0), "Management contract not set for this branch");
        ERC1967Proxy historyTrackingSC = new ERC1967Proxy(
            historyTrackingIMP,
            abi.encodeWithSelector(IHistoryTracking.initialize.selector,
            address(this),management,agent)
        );        
        mBranchIdToHistoryTrack[_newBranchId] = address(historyTrackingSC);
        IMANAGEMENT(management).setHistoryTracking(address(historyTrackingSC));
        address[] memory contracts = new address[](1);
        contracts[0] = address(historyTrackingSC);
        if(freeGasSc != address(0)){
            IFreeGas(freeGasSc).AddSC(agent,contracts);
        }
        return _newBranchId;
    }
    
    /**
     * @notice Cập nhật thông tin chi nhánh
     */
    function updateBranch(
        uint256 branchId,
        string memory _name
    ) external {
        require(branches[branchId].active, "Branch not found");
        require(bytes(_name).length > 0, "Branch name cannot be empty"); 

        Branch storage branch = branches[branchId];
        branch.name = _name;
        emit BranchUpdated(branchId, _name);
    }
    
    /**
     * @notice Vô hiệu hóa chi nhánh
     */
    function deactivateBranch(uint256 branchId) external {
        require(branches[branchId].active, "Branch already inactive");
    
        // Remove all managers from this branch
        address[] memory branchMgrs = branchManagers[branchId];
        for (uint256 i = 0; i < branchMgrs.length; i++) {
            address mgr = branchMgrs[i];
            
            // Remove branchId from manager's branchIds array
            ManagerInfo storage manager = managers[mgr];
            for (uint256 j = 0; j < manager.branchIds.length; j++) {
                if (manager.branchIds[j] == branchId) {
                    manager.branchIds[j] = manager.branchIds[manager.branchIds.length - 1];
                    manager.branchIds.pop();
                    break;
                }
            }
            
            _removeManagerFromBranch(mgr, branchId);
        }
        
        branches[branchId].active = false;
        emit BranchDeactivated(branchId);
    }
    
    /**
     * @notice Lấy tất cả chi nhánh
     */
    function getAllBranches() external view returns (Branch[] memory) {
        Branch[] memory result = new Branch[](branchIds.length);
        for (uint256 i = 0; i < branchIds.length; i++) {
            result[i] = branches[branchIds[i]];
        }
        return result;
    }
    
    /**
     * @notice Lấy chi nhánh của một manager
     */
    function getManagerBranches(address manager) 
        external 
        view 
        returns (Branch[] memory) 
    {
        ManagerInfo memory managerInfo = managers[manager];
        require(managerInfo.active, "Manager not found");
        
        if (managerInfo.hasFullAccess) {
            return this.getAllBranches();
        }
        
        Branch[] memory result = new Branch[](managerInfo.branchIds.length);
        for (uint256 i = 0; i < managerInfo.branchIds.length; i++) {
            result[i] = branches[managerInfo.branchIds[i]];
        }
        return result;
    }
    
    // ==================== MANAGER MANAGEMENT ====================
    
    /**
     * @notice Thêm mới hoặc cập nhật thông tin quản lý
     * @dev Tạo proposal để vote, không execute trực tiếp
     */
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
    ) external onlyCoOwner() {
        require(_wallet != address(0), "Invalid wallet");
        // require(!isMainOwner[_wallet], "Cannot modify main owner");
        require(_canViewData || _canEditData, "Must have at least one permission");
        
        // Validate branches
        if (!_isAllBranches) {
            require(_branchIds.length > 0, "Branch ids cannot be empty");
            for (uint256 i = 0; i < _branchIds.length; i++) {
                require(branches[_branchIds[i]].active, "Invalid branch");
            }
        }
        // Determine assigned branches
        uint256[] memory assignedBranches;
        if (_isAllBranches) {
            assignedBranches = new uint256[](branchIds.length);
            assignedBranches = branchIds;
            if(assignedBranches.length>0){

            }

        } else {
            assignedBranches = new uint256[](_branchIds.length);
            assignedBranches = _branchIds;
            if(assignedBranches.length>0){
            }
        }
        if(managerAddresses.length == 0){
            managers[_wallet] = ManagerInfo({
                wallet: _wallet,
                name: _name,
                phone: _phone,
                image: _image,
                isCoOwner: true,
                branchIds: assignedBranches,
                hasFullAccess: _hasFullAccess,
                canViewData: _canViewData,
                canEditData: _canEditData,
                canProposeAndVote: _canProposeAndVote,
                createdAt: block.timestamp,
                active: true
            });
            managerAddresses.push(_wallet);
            StaffAgentStore.setAgentForCoOwner(_wallet,agent,assignedBranches);
            // Record history for first manager (no voting needed)
            if (address(historyTrackingIMP) != address(0)) {
                address historyTrack = mBranchIdToHistoryTrack[mainBranchId];
                IHistoryTracking(historyTrack).recordManagerCreate(
                    _wallet,
                    managers[_wallet],
                    "First manager created"
                );
            }
            return;
        }

        bool isExisting = managers[_wallet].active;
        
        // Encode old data (current state)
        bytes memory oldData;
        if (isExisting) {
            ManagerInfo memory currentManager = managers[_wallet];
            oldData = abi.encode(
                currentManager.wallet,
                currentManager.name,
                currentManager.phone,
                currentManager.image,
                currentManager.branchIds,
                currentManager.hasFullAccess,
                currentManager.canViewData,
                currentManager.canEditData,
                currentManager.canProposeAndVote
            );
        } else {
            // New manager - empty old data
            oldData = abi.encode(address(0), "", "", "", new uint256[](0), false, false, false, false);
        }
        
        // Encode new data
        bytes memory newData = abi.encode(
            _wallet,
            _name,
            _phone,
            _image,
            assignedBranches,
            _hasFullAccess,
            _canViewData,
            _canEditData,
            _canProposeAndVote
        );
        // Create proposal instead of direct execution
        uint256 proposalId = createProposal(ProposalType.ADD_MANAGER, mainBranchId, oldData, newData);
        voteProposal(proposalId, true);
    }
    
    /**
     * @notice Xóa quản lý - Tạo proposal để vote
     */
    function removeManager(address _wallet) external onlyCoOwner {
        require(managers[_wallet].active, "Manager not found");
        require(!isMainOwner[_wallet], "Cannot remove main owner");
        
        ManagerInfo memory currentManager = managers[_wallet];
        
        // Encode old data (current manager info)
        bytes memory oldData = abi.encode(
            currentManager.wallet,
            currentManager.name,
            currentManager.phone,
            currentManager.image,
            currentManager.branchIds,
            currentManager.hasFullAccess,
            currentManager.canViewData,
            currentManager.canEditData,
            currentManager.canProposeAndVote
        );
        
        // Encode new data (empty - indicates removal)
        bytes memory newData = abi.encode(address(0), "", "", "", new uint256[](0), false, false, false, false);
        
        // Create proposal
        uint256 proposalId = createProposal(ProposalType.REMOVE_MANAGER, mainBranchId, oldData, newData);
        voteProposal(proposalId, true);
    }
    
    /**
     * @notice Lấy thông tin tất cả managers
     */
    function getAllManagers() external view returns (ManagerInfo[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < managerAddresses.length; i++) {
            if (managers[managerAddresses[i]].active) {
                activeCount++;
            }
        }
        ManagerInfo[] memory result = new ManagerInfo[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < managerAddresses.length; i++) {
            if (managers[managerAddresses[i]].active) {
                result[index] = managers[managerAddresses[i]];
                index++;
            }
        }
        return result;
    }
    /**
    * @notice Lấy tất cả managers có isCoOwner = true
    * @return ManagerInfo[] Danh sách co-owner managers
    */
    function getAllCoOwnerManagers() 
        external 
        view 
        returns (ManagerInfo[] memory) 
    {
        uint256 coOwnerCount = 0;
        for (uint256 i = 0; i < managerAddresses.length; i++) {
            ManagerInfo memory mgr = managers[managerAddresses[i]];
            if (mgr.active && mgr.isCoOwner) {
                coOwnerCount++;
            }
        }
        
        ManagerInfo[] memory result = new ManagerInfo[](coOwnerCount);
        uint256 index = 0;
        for (uint256 i = 0; i < managerAddresses.length; i++) {
            ManagerInfo memory mgr = managers[managerAddresses[i]];
            if (mgr.active && mgr.isCoOwner) {
                result[index] = mgr;
                index++;
            }
        }
        return result;
    }
    /**
     * @notice Lấy managers của một chi nhánh
     */
    function getBranchManagers(uint256 branchId) 
        external 
        view 
        returns (ManagerInfo[] memory) 
    {
        address[] memory managerAddrs = branchManagers[branchId];
        ManagerInfo[] memory result = new ManagerInfo[](managerAddrs.length);
        
        for (uint256 i = 0; i < managerAddrs.length; i++) {
            result[i] = managers[managerAddrs[i]];
        }
        return result;
    }
    /**
    * @notice Lấy tất cả managers với pagination
    * @param _page Số trang (bắt đầu từ 1)
    * @param _pageSize Số lượng managers mỗi trang
    * @return managerList Danh sách managers
    * @return total Tổng số managers
    * @return totalPages Tổng số trang
    */
    function getAllManagersPagination(
        uint256 _page,
        uint256 _pageSize
    ) external view returns (
        ManagerInfo[] memory managerList,
        uint256 total,
        uint256 totalPages
    ) {
        require(_page > 0, "Page must be greater than 0");
        require(_pageSize > 0 && _pageSize <= 100, "Page size must be between 1 and 100");

        // Đếm active managers
        uint256 activeCount = 0;
        for (uint256 i = 0; i < managerAddresses.length; i++) {
            if (managers[managerAddresses[i]].active) {
                activeCount++;
            }
        }

        total = activeCount;
        totalPages = total > 0 ? (total + _pageSize - 1) / _pageSize : 0;

        if (_page > totalPages && totalPages > 0) {
            _page = totalPages;
        }

        uint256 startIndex = (_page - 1) * _pageSize;
        uint256 endIndex = startIndex + _pageSize;
        if (endIndex > total) endIndex = total;

        uint256 resultSize = endIndex > startIndex ? endIndex - startIndex : 0;
        managerList = new ManagerInfo[](resultSize);

        uint256 activeIndex = 0;
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < managerAddresses.length && resultIndex < resultSize; i++) {
            ManagerInfo memory mgr = managers[managerAddresses[i]];
            if (mgr.active) {
                if (activeIndex >= startIndex && activeIndex < endIndex) {
                    managerList[resultIndex] = mgr;
                    resultIndex++;
                }
                activeIndex++;
            }
        }

        return (managerList, total, totalPages);
    }

    /**
    * @notice Lấy tất cả managers của một chi nhánh với pagination
    * @param _branchId ID của chi nhánh
    * @param _page Số trang (bắt đầu từ 1)
    * @param _pageSize Số lượng managers mỗi trang
    * @return managerList Danh sách managers
    * @return total Tổng số managers
    * @return totalPages Tổng số trang
    */
    function getAllManagersByBranchPagination(
        uint256 _branchId,
        uint256 _page,
        uint256 _pageSize
    ) external view returns (
        ManagerInfo[] memory managerList,
        uint256 total,
        uint256 totalPages
    ) {
        require(_page > 0, "Page must be greater than 0");
        require(_pageSize > 0 && _pageSize <= 100, "Page size must be between 1 and 100");
        require(branches[_branchId].active, "Branch not found");

        address[] memory branchMgrAddrs = branchManagers[_branchId];

        uint256 activeCount = 0;
        for (uint256 i = 0; i < branchMgrAddrs.length; i++) {
            if (managers[branchMgrAddrs[i]].active) {
                activeCount++;
            }
        }

        total = activeCount;
        totalPages = total > 0 ? (total + _pageSize - 1) / _pageSize : 0;

        if (_page > totalPages && totalPages > 0) {
            _page = totalPages;
        }

        uint256 startIndex = (_page - 1) * _pageSize;
        uint256 endIndex = startIndex + _pageSize;
        if (endIndex > total) endIndex = total;

        uint256 resultSize = endIndex > startIndex ? endIndex - startIndex : 0;
        managerList = new ManagerInfo[](resultSize);

        uint256 activeIndex = 0;
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < branchMgrAddrs.length && resultIndex < resultSize; i++) {
            ManagerInfo memory mgr = managers[branchMgrAddrs[i]];
            if (mgr.active) {
                if (activeIndex >= startIndex && activeIndex < endIndex) {
                    managerList[resultIndex] = mgr;
                    resultIndex++;
                }
                activeIndex++;
            }
        }

        return (managerList, total, totalPages);
    }

    /**
    * @notice Lấy tất cả managers có isCoOwner = true với pagination
    * @param _page Số trang (bắt đầu từ 1)
    * @param _pageSize Số lượng managers mỗi trang
    * @return managerList Danh sách co-owner managers
    * @return total Tổng số co-owner managers
    * @return totalPages Tổng số trang
    */
    function getAllCoOwnerManagersPagination(
        uint256 _page,
        uint256 _pageSize
    ) external view returns (
        ManagerInfo[] memory managerList,
        uint256 total,
        uint256 totalPages
    ) {
        require(_page > 0, "Page must be greater than 0");
        require(_pageSize > 0 && _pageSize <= 100, "Page size must be between 1 and 100");

        uint256 coOwnerCount = 0;
        for (uint256 i = 0; i < managerAddresses.length; i++) {
            ManagerInfo memory mgr = managers[managerAddresses[i]];
            if (mgr.active && mgr.isCoOwner) {
                coOwnerCount++;
            }
        }

        total = coOwnerCount;
        totalPages = total > 0 ? (total + _pageSize - 1) / _pageSize : 0;

        if (_page > totalPages && totalPages > 0) {
            _page = totalPages;
        }

        uint256 startIndex = (_page - 1) * _pageSize;
        uint256 endIndex = startIndex + _pageSize;
        if (endIndex > total) endIndex = total;

        uint256 resultSize = endIndex > startIndex ? endIndex - startIndex : 0;
        managerList = new ManagerInfo[](resultSize);

        uint256 coOwnerIndex = 0;
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < managerAddresses.length && resultIndex < resultSize; i++) {
            ManagerInfo memory mgr = managers[managerAddresses[i]];
            if (mgr.active && mgr.isCoOwner) {
                if (coOwnerIndex >= startIndex && coOwnerIndex < endIndex) {
                    managerList[resultIndex] = mgr;
                    resultIndex++;
                }
                coOwnerIndex++;
            }
        }

        return (managerList, total, totalPages);
    }
    // ==================== PROPOSAL MANAGEMENT ====================
    
    /**
     * @notice Tạo proposal mới
     */
    function createProposal(
        ProposalType _proposalType,
        uint256 _branchId,
        bytes memory _oldData,
        bytes memory _newData
    ) public canPropose(_branchId) returns (uint256) {
        
        if(_proposalType == ProposalType.EDIT_BANKACCOUNT){
            require(_branchId == mainBranchId, "EDIT_BANKACCOUNT with main branch only ");
        }
        
        proposalCounter++;
        uint256 newProposalId = proposalCounter;
        
        Proposal storage proposal = proposals[newProposalId];
        proposal.proposalId = newProposalId;
        proposal.proposer = msg.sender;
        proposal.proposalType = _proposalType;
        proposal.branchId = _branchId;
        proposal.oldData = _oldData;
        proposal.newData = _newData;
        proposal.status = ProposalStatus.PENDING;
        proposal.createdAt = block.timestamp;
        
        // Calculate total voters
        if (_branchId == mainBranchId) {
            proposal.totalVoters = _countCoOwnersWithFullAccess();
        } else {
            proposal.totalVoters = _countCoOwnersForBranch(_branchId);
        }
        
        proposalIds.push(newProposalId);
        
        emit ProposalCreated(newProposalId, msg.sender, _proposalType, _branchId);
        return newProposalId;
    }
    
    /**
     * @notice Biểu quyết cho proposal
     */
    function voteProposal(uint256 proposalId, bool support) public {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.PENDING, "Proposal not pending");
        
        // Check if proposal is expired
        require(block.timestamp < proposal.createdAt + PROPOSAL_EXPIRATION, "Proposal expired");
        
        require(!proposalHasVoted[proposalId][msg.sender], "Already voted");
        uint branchId = proposal.branchId;
        require(
            isMainOwner[msg.sender] ||
            (managers[msg.sender].active && 
             managers[msg.sender].canProposeAndVote &&
             _isManagerOfBranch(msg.sender, branchId)),
            "No voting permission"
        );
        
        proposalHasVoted[proposalId][msg.sender] = true;
        proposalVoteChoice[proposalId][msg.sender] = support;
        
        if (support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }
        
        emit ProposalVoted(proposalId, msg.sender, support);
        
        // Check if proposal can be executed
        _checkAndExecuteProposal(proposalId);
    }
    
    /**
     * @notice Thực thi proposal nếu đạt ngưỡng
     */
    function _checkAndExecuteProposal(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];

        // Check if proposal is expired (30 days)
        if (block.timestamp >= proposal.createdAt + PROPOSAL_EXPIRATION) {
            if (proposal.status == ProposalStatus.PENDING) {
                proposal.status = ProposalStatus.EXPIRED;
                proposal.executedAt = block.timestamp;
                emit ProposalExecuted(proposalId, ProposalStatus.EXPIRED);
                return;
            }
        }
        
        uint256 totalVoted = proposal.votesFor + proposal.votesAgainst;
        if (proposal.totalVoters == 0) {
            return;
        }
        
        // Check if all voted or passed threshold
        bool allVoted = (totalVoted == proposal.totalVoters);
        bool passedThreshold = (proposal.votesFor * 100 / proposal.totalVoters >= votingThreshold);
        if (allVoted || passedThreshold) {
            if (proposal.votesFor > proposal.votesAgainst) {
                proposal.status = ProposalStatus.APPROVED;
                
                // TỰ ĐỘNG EXECUTE PROPOSAL DỰA TRÊN TYPE
                if (proposal.proposalType == ProposalType.EDIT_BANKACCOUNT) {
                    _executePaymentAccountProposal(proposalId);
                // } else if (proposal.proposalType == ProposalType.EDIT_STAFF) {
                    // _executeStaffWalletUpdateProposal(proposalId);
                // } else if (proposal.proposalType == ProposalType.MERCHANT_INFO_CHANGE){
                //     _executeUpdateMerchantProposal(proposalId);
                } else if (proposal.proposalType == ProposalType.ADD_MANAGER){
                    _executeAddManagerProposal(proposalId);
                } else if (proposal.proposalType == ProposalType.REMOVE_MANAGER){
                    _executeRemoveManagerProposal(proposalId);
                }
            } else {
                proposal.status = ProposalStatus.REJECTED;
            }
            
            proposal.executedAt = block.timestamp;
            emit ProposalExecuted(proposalId, proposal.status);
        }
    }
    
    // function _executeStaffWalletUpdateProposal(uint256 proposalId) internal {       
    // }
    
    // function _executeUpdateMerchantProposal(uint256 proposalId) internal {       
    // }
    function decodeAbiAddManager(bytes memory data) external view returns(
        address _wallet,
        string memory _name,
        string memory _phone,
        string memory _image,
        uint256[] memory assignedBranches,
        bool _hasFullAccess,
        bool _canViewData,
        bool _canEditData,
        bool _canProposeAndVote
    )
    {
        (
            _wallet,
            _name,
            _phone,
            _image,
            assignedBranches,
            _hasFullAccess,
            _canViewData,
            _canEditData,
            _canProposeAndVote
        ) = abi.decode(data, (address, string, string, string, uint256[], bool, bool, bool, bool));
    }
    /**
     * @notice Execute ADD/UPDATE Manager proposal
     * @dev Tự động thêm hoặc cập nhật manager sau khi proposal được approve
     */
    function _executeAddManagerProposal(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.APPROVED, "Proposal not approved");
        require(proposal.proposalType == ProposalType.ADD_MANAGER, "Wrong proposal type");
        
        // Decode new data
        (
            address _wallet,
            string memory _name,
            string memory _phone,
            string memory _image,
            uint256[] memory assignedBranches,
            bool _hasFullAccess,
            bool _canViewData,
            bool _canEditData,
            bool _canProposeAndVote
        ) = abi.decode(proposal.newData, (address, string, string, string, uint256[], bool, bool, bool, bool));
        
        bool _isCoOwner = _hasFullAccess;
        bool isExisting = managers[_wallet].active;
        
        if (isExisting) {
            // UPDATE existing manager
            ManagerInfo storage manager = managers[_wallet];
            
            // Remove from old branches
            for (uint256 i = 0; i < manager.branchIds.length; i++) {
                _removeManagerFromBranch(_wallet, manager.branchIds[i]);
            }
            
            // Update info
            manager.name = _name;
            manager.phone = _phone;
            manager.image = _image;
            manager.isCoOwner = _isCoOwner;
            manager.branchIds = assignedBranches;
            manager.hasFullAccess = _hasFullAccess;
            manager.canViewData = _canViewData;
            manager.canEditData = _canEditData;
            manager.canProposeAndVote = _canProposeAndVote;
            
            emit ManagerUpdated(_wallet);
            
        } else {
            // ADD new manager
            managers[_wallet] = ManagerInfo({
                wallet: _wallet,
                name: _name,
                phone: _phone,
                image: _image,
                isCoOwner: _isCoOwner,
                branchIds: assignedBranches,
                hasFullAccess: _hasFullAccess,
                canViewData: _canViewData,
                canEditData: _canEditData,
                canProposeAndVote: _canProposeAndVote,
                createdAt: block.timestamp,
                active: true
            });
            
            managerAddresses.push(_wallet);
            StaffAgentStore.setAgentForCoOwner(_wallet,agent,assignedBranches);
            require(iqrFactorySc != address(0),"iqrFactorySc not set yet");
            (address[] memory managementIQRScs, uint countIQR) = IIQRFactory(iqrFactorySc).getManagementSCByAgentsFromFactory(agent,assignedBranches);
            if(countIQR>0){
                for(uint i=0; i< managementIQRScs.length; i++){
                    IMANAGEMENT(managementIQRScs[i]).setRoleForCoOwner(_wallet);
                }
            }
            require(meosFactorySc != address(0),"meosFactorySc not set yet");
            (address[] memory managementMeosScs, uint countMeos) = IMeosFactory(meosFactorySc).getManagementSCByAgentsFromFactory(agent,assignedBranches);
            
            if(countMeos>0){

                for(uint i=0; i< managementMeosScs.length; i++){
                    IMANAGEMENT(managementMeosScs[i]).setRoleForCoOwner(_wallet);
                }
            }
            require(robotFactorySc != address(0),"robotFactorySc not set yet");
            (address[] memory managementRobotScs, uint countRobot) = IRobotFactory(robotFactorySc).getManagementSCByAgentsFromFactory(agent,assignedBranches);
            if(countRobot>0){
                for(uint i=0; i< managementRobotScs.length; i++){
                    IMANAGEMENT(managementRobotScs[i]).setRoleForCoOwner(_wallet);
                }
            }
            // Record history
            if (address(historyTrackingIMP) != address(0)) {
               address historyTrack = mBranchIdToHistoryTrack[mainBranchId];
                IHistoryTracking(historyTrack).recordManagerCreate(
                    _wallet,
                    managers[_wallet],
                    string(abi.encodePacked("Manager added via proposal"))
                );
            }            
            emit ManagerAdded(_wallet, _isCoOwner, assignedBranches);
        }
        
        // Add to new branches
        for (uint256 i = 0; i < assignedBranches.length; i++) {
            _addManagerToBranch(_wallet, assignedBranches[i]);
        }
        
        proposal.status = ProposalStatus.EXECUTED;
    }
    function decodeAbiRemoveManager(bytes memory data) external view returns(
        address _wallet
    ){
        (
            _wallet,
            ,,,,,,,
        ) = abi.decode(data, (address, string, string, string, uint256[], bool, bool, bool, bool));
    }
    /**
     * @notice Execute REMOVE Manager proposal
     * @dev Tự động xóa manager sau khi proposal được approve
     */
    function _executeRemoveManagerProposal(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.APPROVED, "Proposal not approved");
        require(proposal.proposalType == ProposalType.REMOVE_MANAGER, "Wrong proposal type");
        
        // Decode old data to get wallet address
        (
            address _wallet,
            ,,,,,,,
        ) = abi.decode(proposal.oldData, (address, string, string, string, uint256[], bool, bool, bool, bool));
        
        require(managers[_wallet].active, "Manager not found");
        
        ManagerInfo storage manager = managers[_wallet];
        // Record state before deletion
        ManagerInfo memory deletedManager = manager;
        // Remove from branches
        for (uint256 i = 0; i < manager.branchIds.length; i++) {
            _removeManagerFromBranch(_wallet, manager.branchIds[i]);
        }
        
        // Mark as inactive
        manager.active = false;
        // Record history
        if (address(historyTrackingIMP) != address(0)) {
            address historyTrack = mBranchIdToHistoryTrack[mainBranchId];
                IHistoryTracking(historyTrack).recordManagerDelete(
                _wallet,
                deletedManager,
                string(abi.encodePacked("Manager removed via proposal"))
            );
        }
        emit ManagerRemoved(_wallet);
        
        proposal.status = ProposalStatus.EXECUTED;
    }
    
    /**
     * @notice Lấy proposals của một chi nhánh
     */
    function getBranchProposals(uint256 branchId) 
        external 
        view 
        returns (uint256[] memory) 
    {
        uint256 count = 0;
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (proposals[proposalIds[i]].branchId == branchId) {
                count++;
            }
        }
        
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (proposals[proposalIds[i]].branchId == branchId) {
                result[index] = proposalIds[i];
                index++;
            }
        }
        return result;
    }
    
    /**
     * @notice Lấy chi tiết proposal
     */
    function getProposalDetails(uint256 proposalId) 
        external 
        view 
        returns (
            address proposer,
            ProposalType proposalType,
            uint256 branchId,
            ProposalStatus status,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 totalVoters,
            uint256 createdAt
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.proposalType,
            proposal.branchId,
            proposal.status,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.totalVoters,
            proposal.createdAt
        );
    }
    
    // ==================== NOTIFICATION MANAGEMENT ====================
    
    /**
     * @notice Gửi thông báo đến người dùng
     */
    function sendNotification(
        address recipient,
        uint256 branchId,
        string memory title,
        string memory message,
        uint256 proposalId
    ) external onlyCoOwner returns (uint256) {
        notificationCounter++;
        uint256 newNotificationId = notificationCounter;
        
        notifications[newNotificationId] = Notification({
            notificationId: newNotificationId,
            branchId: branchId,
            recipient: recipient,
            title: title,
            message: message,
            proposalId: proposalId,
            isRead: false,
            createdAt: block.timestamp
        });
        
        userNotifications[recipient].push(newNotificationId);
        branchNotifications[branchId].push(newNotificationId);
        
        emit NotificationSent(newNotificationId, recipient, branchId);
        return newNotificationId;
    }
    
    /**
     * @notice Đánh dấu thông báo đã đọc
     */
    function markNotificationAsRead(uint256 notificationId) external {
        Notification storage notification = notifications[notificationId];
        require(notification.recipient == msg.sender, "Not your notification");
        notification.isRead = true;
    }
    
    /**
     * @notice Lấy thông báo của user theo chi nhánh
     */
    function getUserNotificationsByBranch(address user, uint256 branchId) 
        external 
        view 
        returns (Notification[] memory) 
    {
        uint256[] memory userNotifIds = userNotifications[user];
        uint256 count = 0;
        
        for (uint256 i = 0; i < userNotifIds.length; i++) {
            if (notifications[userNotifIds[i]].branchId == branchId) {
                count++;
            }
        }
        
        Notification[] memory result = new Notification[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < userNotifIds.length; i++) {
            if (notifications[userNotifIds[i]].branchId == branchId) {
                result[index] = notifications[userNotifIds[i]];
                index++;
            }
        }
        return result;
    }
    
    // ==================== INTERNAL HELPER FUNCTIONS ====================
    
    function _addManagerToBranch(address manager, uint256 branchId) internal {
        if (!isBranchManager[branchId][manager]) {
            branchManagers[branchId].push(manager);
            isBranchManager[branchId][manager] = true;
        }
    }
    
    function _removeManagerFromBranch(address manager, uint256 branchId) internal {
        if (isBranchManager[branchId][manager]) {
            address[] storage managerArr = branchManagers[branchId];
            for (uint256 i = 0; i < managerArr.length; i++) {
                if (managerArr[i] == manager) {
                    managerArr[i] = managerArr[managerArr.length - 1];
                    managerArr.pop();
                    break;
                }
            }
            isBranchManager[branchId][manager] = false;
        }
    }
    
    function _isManagerOfBranch(address manager, uint256 branchId) 
        internal 
        view 
        returns (bool) 
    {
        if (isMainOwner[manager]) return true;
        
        ManagerInfo memory managerInfo = managers[manager];
        if (!managerInfo.active) return false;
        
        if (managerInfo.hasFullAccess) return true;
        
        for (uint256 i = 0; i < managerInfo.branchIds.length; i++) {
            if (managerInfo.branchIds[i] == branchId) return true;
        }
        return false;
    }
    
    function _canVoteOnProposal(address voter, uint256 branchId) 
        internal 
        view 
        returns (bool) 
    {
        if (isMainOwner[voter]) return true;
        
        ManagerInfo memory manager = managers[voter];
        if (!manager.active || !manager.isCoOwner) return false;
        
        if (branchId == mainBranchId) {
            // Main merchant - only full access co-owners can vote
            return manager.hasFullAccess;
        } else {
            // Branch - co-owners with access to this branch can vote
            return _isManagerOfBranch(voter, branchId);
        }
    }
    
    function _countCoOwnersWithFullAccess() internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < managerAddresses.length; i++) {
            ManagerInfo memory manager = managers[managerAddresses[i]];
            if (manager.active && manager.isCoOwner && manager.hasFullAccess) {
                count++;
            }
        }
        return count;
    }
    
    function _countCoOwnersForBranch(uint256 branchId) 
        internal 
        view 
        returns (uint256) 
    {
        uint256 count = 0;
        for (uint256 i = 0; i < managerAddresses.length; i++) {
            ManagerInfo memory manager = managers[managerAddresses[i]];
            if (manager.active && manager.isCoOwner && 
                _isManagerOfBranch(managerAddresses[i], branchId)) {
                count++;
            }
        }
        return count;
    }
    
    // function _sendProposalNotifications(uint256 proposalId, uint256 branchId) 
    //     internal 
    // {
    //     // Send to main owner
    //     this.sendNotification(
    //         mainOwner,
    //         branchId,
    //         "New Proposal",
    //         "A new proposal has been created",
    //         proposalId
    //     );
        
    //     // Send to relevant managers
    //     for (uint256 i = 0; i < managerAddresses.length; i++) {
    //         address manager = managerAddresses[i];
    //         if (_canVoteOnProposal(manager, branchId)) {
    //             this.sendNotification(
    //                 manager,
    //                 branchId,
    //                 "New Proposal - Vote Required",
    //                 "A new proposal requires your vote",
    //                 proposalId
    //             );
    //         } else if (_isManagerOfBranch(manager, branchId)) {
    //             // Branch managers get notification but can't vote
    //             this.sendNotification(
    //                 manager,
    //                 branchId,
    //                 "New Proposal - Info",
    //                 "A new proposal has been created for your branch",
    //                 proposalId
    //             );
    //         }
    //     }
    // }
    
    // function _sendProposalResultNotifications(uint256 proposalId) internal {
    //     Proposal storage proposal = proposals[proposalId];
    //     string memory status = proposal.status == ProposalStatus.APPROVED 
    //         ? "Approved" 
    //         : "Rejected";
        
    //     // Notify proposer
    //     this.sendNotification(
    //         proposal.proposer,
    //         proposal.branchId,
    //         string(abi.encodePacked("Proposal ", status)),
    //         string(abi.encodePacked("Your proposal has been ", status)),
    //         proposalId
    //     );
        
    //     // Notify all relevant managers
    //     for (uint256 i = 0; i < managerAddresses.length; i++) {
    //         address manager = managerAddresses[i];
    //         if (manager != proposal.proposer && 
    //             _isManagerOfBranch(manager, proposal.branchId)) {
    //             this.sendNotification(
    //                 manager,
    //                 proposal.branchId,
    //                 string(abi.encodePacked("Proposal ", status)),
    //                 string(abi.encodePacked("A proposal has been ", status)),
    //                 proposalId
    //             );
    //         }
    //     }
    // }
    
    // ==================== SETTINGS ====================
    
    /**
     * @notice Cập nhật voting threshold
     */
    function updateVotingThreshold(uint256 _threshold) external onlyMainOwner {
        require(_threshold > 0 && _threshold <= 100, "Invalid threshold");
        votingThreshold = _threshold;
    }
    
    /**
     * @notice Kiểm tra quyền của user
     */
    function checkPermissions(address user, uint256 branchId) 
        external 
        view 
        returns (
            bool isManager,
            bool _canView,
            bool _canEdit,
            bool _canProposeAndVote
        ) 
    {
        if (isMainOwner[user]) {
            return (true, true, true, true);
        }
        
        ManagerInfo memory manager = managers[user];
        if (!manager.active) {
            return (false, false, false, false);
        }
        
        isManager = _isManagerOfBranch(user, branchId);
        _canView = isManager && manager.canViewData;
        _canEdit = isManager && manager.canEditData;
        _canProposeAndVote = isManager && manager.canProposeAndVote;
        
        return (isManager, _canView, _canEdit, _canProposeAndVote);
    }
    
    /**
     * @notice Lấy thống kê hệ thống
     */
    function getSystemStats() 
        external 
        view 
        returns (
            uint256 totalBranches,
            uint256 totalManagers,
            uint256 totalCoOwners,
            uint256 totalBranchManagers,
            uint256 totalProposals,
            uint256 pendingProposals
        ) 
    {
        totalBranches = branchIds.length;
        
        for (uint256 i = 0; i < managerAddresses.length; i++) {
            ManagerInfo memory manager = managers[managerAddresses[i]];
            if (manager.active) {
                totalManagers++;
                if (manager.isCoOwner) {
                    totalCoOwners++;
                } else {
                    totalBranchManagers++;
                }
            }
        }
        
        totalProposals = proposalIds.length;
        
        for (uint256 i = 0; i < proposalIds.length; i++) {
            if (proposals[proposalIds[i]].status == ProposalStatus.PENDING) {
                pendingProposals++;
            }
        }
        
        return (
            totalBranches,
            totalManagers,
            totalCoOwners,
            totalBranchManagers,
            totalProposals,
            pendingProposals
        );
    }
    
    /**
     * @notice Lấy dashboard data cho manager
     */
    function getManagerDashboard(address manager) 
        external 
        view 
        returns (
            ManagerInfo memory managerInfo,
            Branch[] memory accessibleBranches,
            uint256[] memory pendingProposals,
            uint256 unreadNotifications
        ) 
    {
        require(managers[manager].active, "Manager not found");
        
        managerInfo = managers[manager];
        
        // Get accessible branches
        if (managerInfo.hasFullAccess) {
            accessibleBranches = this.getAllBranches();
        } else {
            accessibleBranches = new Branch[](managerInfo.branchIds.length);
            for (uint256 i = 0; i < managerInfo.branchIds.length; i++) {
                accessibleBranches[i] = branches[managerInfo.branchIds[i]];
            }
        }
        
        // Get pending proposals
        uint256 pendingCount = 0;
        for (uint256 i = 0; i < proposalIds.length; i++) {
            Proposal storage proposal = proposals[proposalIds[i]];
            if (proposal.status == ProposalStatus.PENDING && 
                !proposalHasVoted[proposalIds[i]][manager] &&
                _canVoteOnProposal(manager, proposal.branchId)) {
                pendingCount++;
            }
        }
        
        pendingProposals = new uint256[](pendingCount);
        uint256 index = 0;
        for (uint256 i = 0; i < proposalIds.length; i++) {
            Proposal storage proposal = proposals[proposalIds[i]];
            if (proposal.status == ProposalStatus.PENDING && 
                !proposalHasVoted[proposalIds[i]][manager] &&
                _canVoteOnProposal(manager, proposal.branchId)) {
                pendingProposals[index] = proposalIds[i];
                index++;
            }
        }
        
        // Count unread notifications
        uint256[] memory notifIds = userNotifications[manager];
        for (uint256 i = 0; i < notifIds.length; i++) {
            if (!notifications[notifIds[i]].isRead) {
                unreadNotifications++;
            }
        }
        
        return (managerInfo, accessibleBranches, pendingProposals, unreadNotifications);
    }
    /**
    * @notice Set hoặc update payment account
    * - Lần đầu: Set trực tiếp
    * - Các lần sau: Phải tạo proposal và vote
    */
    function setPaymentAccount(
        string memory _bankAccount,
        string memory _nameAccount,
        string memory _nameOfBank,
        string memory _taxCode,
        string memory _wallet
    ) external onlyCoOwner {
        bool isFirstTime = bytes(paymentInfo.bankAccount).length == 0;
        bytes memory oldData;
        if(isFirstTime ){
            oldData = abi.encode("","","","");
        }else{
            oldData = abi.encode(
                paymentInfo.bankAccount,
                paymentInfo.nameAccount,
                paymentInfo.nameOfBank,
                paymentInfo.taxCode,
                paymentInfo.wallet
            );
            
        }
        bytes memory newData = abi.encode(
            _bankAccount,
            _nameAccount,
            _nameOfBank,
            _taxCode,
            _wallet
        );        
        uint256 proposalId = createProposal(ProposalType.EDIT_BANKACCOUNT, mainBranchId, oldData, newData);
        voteProposal(proposalId, true);

    }
    function decodeAbiPaymentAccount(bytes memory data) external view returns(
        string memory _bankAccount,
        string memory _nameAccount,
        string memory _nameOfBank,
        string memory _taxCode,
        string memory _wallet
    ){
        (
            _bankAccount,
            _nameAccount,
            _nameOfBank,
            _taxCode,
            _wallet
        ) = abi.decode(data, (string, string, string, string, string));
    }
    /**
    * @notice Execute approved payment account proposal
    * @dev Chỉ được gọi tự động khi proposal APPROVED
    */
    function _executePaymentAccountProposal(uint256 proposalId) internal {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.APPROVED, "Proposal not approved");
        require(proposal.proposalType == ProposalType.EDIT_BANKACCOUNT, "Wrong proposal type");
        // Decode old and new data
        PaymentInfo memory oldPayment;
        if (bytes(paymentInfo.bankAccount).length > 0) {
            oldPayment = paymentInfo;
        }
        // Decode new data
        (
            string memory _bankAccount,
            string memory _nameAccount,
            string memory _nameOfBank,
            string memory _taxCode,
            string memory _wallet
        ) = abi.decode(proposal.newData, (string, string, string, string, string));
        
        // Update payment info
        paymentInfo = PaymentInfo({
            bankAccount: _bankAccount,
            nameAccount: _nameAccount,
            nameOfBank: _nameOfBank,
            taxCode: _taxCode,
            wallet: _wallet
        });
        // Record history
        if (address(historyTrackingIMP) != address(0)) {
            address historyTrack = mBranchIdToHistoryTrack[mainBranchId];
                IHistoryTracking(historyTrack).recordPaymentInfoUpdate(
                oldPayment,
                paymentInfo,
                string(abi.encodePacked("Payment info updated via proposal"))
            );
        }
        proposal.status = ProposalStatus.EXECUTED;
    }
    
    function setPaymentMethodStatuses(PaymentMethod[] memory _paymentMethods, bool[] memory _statuses)external onlyCoOwner  {
        require(_paymentMethods.length == _statuses.length,"number of paymentMethod need equal to status");
        for(uint i; i<_paymentMethods.length; i++){
            mPaymentMethodActive[_paymentMethods[i]] = _statuses[i];
        }
    }
    function getAllPaymentMethodStatus() external view returns(bool[] memory statuses){
        statuses = new bool[](PAYMENT_METHOD_COUNT); 
        for(uint i; i < PAYMENT_METHOD_COUNT; i++){
            statuses[i] = mPaymentMethodActive[PaymentMethod(i)];
        }
    }
    function setPaymentOrder(PaymentOrder  _option)external onlyCoOwner {
        paymentOrder = _option;
    }
    function setCurrency(Currency   _currency,CurrencyDisplay  _currencyDisplay)external onlyCoOwner {
        currency = _currency;
        currencyDisplay = _currencyDisplay;
    }
    function getCurrentDisplay() external view returns(Currency,CurrencyDisplay){
        return(currency,currencyDisplay);
    }
    // ==================== PROPOSAL PAGINATION FUNCTIONS ====================

/**
 * @notice Lấy tất cả proposals với pagination
 * @param _page Số trang (bắt đầu từ 1)
 * @param _pageSize Số lượng proposals mỗi trang
 * @return PaginatedProposals Dữ liệu proposals đã phân trang
 */
function getAllProposalsPaginated(
    uint256 _page,
    uint256 _pageSize
) external view returns (PaginatedProposals memory) {
    require(_page > 0, "Page must be greater than 0");
    require(_pageSize > 0 && _pageSize <= 100, "Page size must be between 1 and 100");
    
    uint256 total = proposalIds.length;
    uint256 totalPages = (total + _pageSize - 1) / _pageSize;
    
    // Nếu page vượt quá totalPages, trả về trang cuối
    if (_page > totalPages && totalPages > 0) {
        _page = totalPages;
    }
    
    uint256 startIndex = (_page - 1) * _pageSize;
    uint256 endIndex = startIndex + _pageSize;
    
    if (endIndex > total) {
        endIndex = total;
    }
    
    uint256 resultSize = endIndex > startIndex ? endIndex - startIndex : 0;
    Proposal[] memory proposalViews = new Proposal[](resultSize);
    
    for (uint256 i = 0; i < resultSize; i++) {
        uint256 proposalId = proposalIds[startIndex + i];
        Proposal storage proposal = proposals[proposalId];
        
        proposalViews[i] = Proposal({
            proposalId: proposal.proposalId,
            proposer: proposal.proposer,
            proposalType: proposal.proposalType,
            branchId: proposal.branchId,
            oldData: proposal.oldData,
            newData: proposal.newData,
            status: proposal.status,
            votesFor: proposal.votesFor,
            votesAgainst: proposal.votesAgainst,
            totalVoters: proposal.totalVoters,
            createdAt: proposal.createdAt,
            executedAt: proposal.executedAt
        });
    }
    
    return PaginatedProposals({
        proposals: proposalViews,
        total: total,
        page: _page,
        pageSize: _pageSize,
        totalPages: totalPages
    });
}
/**
 * @notice Lấy tất cả proposals theo branch với pagination
 * @param _branchId ID của branch
 * @param _page Số trang (bắt đầu từ 1)
 * @param _pageSize Số lượng proposals mỗi trang
 * @return PaginatedProposals Dữ liệu proposals đã phân trang
 */
function getBranchProposalsPaginated(
    uint256 _branchId,
    uint256 _page,
    uint256 _pageSize
) external view returns (PaginatedProposals memory) {
    require(_page > 0, "Page must be greater than 0");
    require(_pageSize > 0 && _pageSize <= 100, "Page size must be between 1 and 100");
    
    // Đếm tổng số proposals có branchId phù hợp
    uint256 total = 0;
    for (uint256 i = 0; i < proposalIds.length; i++) {
        if (proposals[proposalIds[i]].branchId == _branchId) {
            total++;
        }
    }
    
    uint256 totalPages = total > 0 ? (total + _pageSize - 1) / _pageSize : 0;
    
    if (_page > totalPages && totalPages > 0) {
        _page = totalPages;
    }
    
    // Tạo mảng tạm
    uint256[] memory filteredIds = new uint256[](total);
    uint256 filteredIndex = 0;
    
    for (uint256 i = 0; i < proposalIds.length; i++) {
        if (proposals[proposalIds[i]].branchId == _branchId) {
            filteredIds[filteredIndex] = proposalIds[i];
            filteredIndex++;
        }
    }
    
    // Pagination
    uint256 startIndex = (_page - 1) * _pageSize;
    uint256 endIndex = startIndex + _pageSize;
    
    if (endIndex > total) {
        endIndex = total;
    }
    
    uint256 resultSize = endIndex > startIndex ? endIndex - startIndex : 0;
    Proposal[] memory proposalResults = new Proposal[](resultSize);
    
    for (uint256 i = 0; i < resultSize; i++) {
        proposalResults[i] = proposals[filteredIds[startIndex + i]];
    }
    
    return PaginatedProposals({
        proposals: proposalResults,
        total: total,
        page: _page,
        pageSize: _pageSize,
        totalPages: totalPages
    });
}
/**
 * @notice Lấy proposals theo status với pagination
 * @param _status Status của proposal cần lọc
 * @param _page Số trang (bắt đầu từ 1)
 * @param _pageSize Số lượng proposals mỗi trang
 * @return PaginatedProposals Dữ liệu proposals đã phân trang theo status
 */
function getProposalsByStatusPaginated(
    ProposalStatus _status,
    uint256 _page,
    uint256 _pageSize
) external view returns (PaginatedProposals memory) {
    require(_page > 0, "Page must be greater than 0");
    require(_pageSize > 0 && _pageSize <= 100, "Page size must be between 1 and 100");
    
    // Đếm tổng số proposals có status phù hợp
    uint256 total = 0;
    for (uint256 i = 0; i < proposalIds.length; i++) {
        if (proposals[proposalIds[i]].status == _status) {
            total++;
        }
    }
    
    uint256 totalPages = total > 0 ? (total + _pageSize - 1) / _pageSize : 0;
    
    // Nếu page vượt quá totalPages, trả về trang cuối
    if (_page > totalPages && totalPages > 0) {
        _page = totalPages;
    }
    
    // Tạo mảng tạm để lưu proposalIds có status phù hợp
    uint256[] memory filteredIds = new uint256[](total);
    uint256 filteredIndex = 0;
    
    for (uint256 i = 0; i < proposalIds.length; i++) {
        if (proposals[proposalIds[i]].status == _status) {
            filteredIds[filteredIndex] = proposalIds[i];
            filteredIndex++;
        }
    }
    
    // Tính toán pagination
    uint256 startIndex = (_page - 1) * _pageSize;
    uint256 endIndex = startIndex + _pageSize;
    
    if (endIndex > total) {
        endIndex = total;
    }
    
    uint256 resultSize = endIndex > startIndex ? endIndex - startIndex : 0;
    Proposal[] memory proposalViews = new Proposal[](resultSize);
    
    for (uint256 i = 0; i < resultSize; i++) {
        uint256 proposalId = filteredIds[startIndex + i];
        Proposal storage proposal = proposals[proposalId];
        
        proposalViews[i] = Proposal({
            proposalId: proposal.proposalId,
            proposer: proposal.proposer,
            proposalType: proposal.proposalType,
            branchId: proposal.branchId,
            oldData: proposal.oldData,
            newData: proposal.newData,
            status: proposal.status,
            votesFor: proposal.votesFor,
            votesAgainst: proposal.votesAgainst,
            totalVoters: proposal.totalVoters,
            createdAt: proposal.createdAt,
            executedAt: proposal.executedAt
        });
    }
    
    return PaginatedProposals({
        proposals: proposalViews,
        total: total,
        page: _page,
        pageSize: _pageSize,
        totalPages: totalPages
    });
}

/**
 * @notice Lấy proposals theo branch và status với pagination
 * @param _branchId ID của branch
 * @param _status Status của proposal (optional - dùng PENDING để lấy tất cả nếu cần logic riêng)
 * @param _page Số trang (bắt đầu từ 1)
 * @param _pageSize Số lượng proposals mỗi trang
 * @return PaginatedProposals Dữ liệu proposals đã phân trang
 */
function getBranchProposalsByStatusPaginated(
    uint256 _branchId,
    ProposalStatus _status,
    uint256 _page,
    uint256 _pageSize
) external view returns (PaginatedProposals memory) {
    require(_page > 0, "Page must be greater than 0");
    require(_pageSize > 0 && _pageSize <= 100, "Page size must be between 1 and 100");
    
    // Đếm tổng số proposals có branchId và status phù hợp
    uint256 total = 0;
    for (uint256 i = 0; i < proposalIds.length; i++) {
        Proposal storage proposal = proposals[proposalIds[i]];
        if (proposal.branchId == _branchId && proposal.status == _status) {
            total++;
        }
    }
    
    uint256 totalPages = total > 0 ? (total + _pageSize - 1) / _pageSize : 0;
    
    if (_page > totalPages && totalPages > 0) {
        _page = totalPages;
    }
    
    // Tạo mảng tạm
    uint256[] memory filteredIds = new uint256[](total);
    uint256 filteredIndex = 0;
    
    for (uint256 i = 0; i < proposalIds.length; i++) {
        Proposal storage proposal = proposals[proposalIds[i]];
        if (proposal.branchId == _branchId && proposal.status == _status) {
            filteredIds[filteredIndex] = proposalIds[i];
            filteredIndex++;
        }
    }
    
    // Pagination
    uint256 startIndex = (_page - 1) * _pageSize;
    uint256 endIndex = startIndex + _pageSize;
    
    if (endIndex > total) {
        endIndex = total;
    }
    
    uint256 resultSize = endIndex > startIndex ? endIndex - startIndex : 0;
    Proposal[] memory proposalViews = new Proposal[](resultSize);
    
    for (uint256 i = 0; i < resultSize; i++) {
        uint256 proposalId = filteredIds[startIndex + i];
        Proposal storage proposal = proposals[proposalId];
        
        proposalViews[i] = Proposal({
            proposalId: proposal.proposalId,
            proposer: proposal.proposer,
            proposalType: proposal.proposalType,
            branchId: proposal.branchId,
            oldData: proposal.oldData,
            newData: proposal.newData,
            status: proposal.status,
            votesFor: proposal.votesFor,
            votesAgainst: proposal.votesAgainst,
            totalVoters: proposal.totalVoters,
            createdAt: proposal.createdAt,
            executedAt: proposal.executedAt
        });
    }
    
    return PaginatedProposals({
        proposals: proposalViews,
        total: total,
        page: _page,
        pageSize: _pageSize,
        totalPages: totalPages
    });
}
/**
 * @notice Lấy dashboard proposals của manager với pagination
 * @param _manager Địa chỉ của manager
 * @param _page Số trang (bắt đầu từ 1)
 * @param _pageSize Số lượng proposals mỗi trang
 * @return ManagerProposalDashboard Dữ liệu proposals đã phân trang
 */
function getManagerDashboardProposal(
    address _manager,
    uint256 _page,
    uint256 _pageSize
) external view returns (ManagerProposalDashboard memory) {
    require(_page > 0, "Page must be greater than 0");
    require(_pageSize > 0 && _pageSize <= 100, "Page size must be between 1 and 100");
    
    // Kiểm tra manager có quyền vote không
    bool isOwner = isMainOwner[_manager];
    ManagerInfo memory managerInfo = managers[_manager];
    
    // Tạo mảng tạm để lưu proposalIds
    uint256[] memory votedIds = new uint256[](proposalIds.length);
    uint256[] memory unvotedIds = new uint256[](proposalIds.length);
    uint256[] memory allIds = new uint256[](proposalIds.length);
    
    uint256 votedCount = 0;
    uint256 unvotedCount = 0;
    uint256 allCount = 0;
    
    // Phân loại proposals
    for (uint256 i = 0; i < proposalIds.length; i++) {
        uint256 proposalId = proposalIds[i];
        Proposal storage proposal = proposals[proposalId];
        
        // Kiểm tra xem manager có quyền vote proposal này không
        bool canVote = _canVoteOnProposal(_manager, proposal.branchId);
        
        if (canVote) {
            allIds[allCount] = proposalId;
            allCount++;
            
            if (proposalHasVoted[proposalId][_manager]) {
                votedIds[votedCount] = proposalId;
                votedCount++;
            } else if (proposal.status == ProposalStatus.PENDING) {
                // Chỉ tính proposals chưa vote nếu còn PENDING
                unvotedIds[unvotedCount] = proposalId;
                unvotedCount++;
            }
        }
    }
    
    // Tính toán pagination
    uint256 totalPagesVoted = votedCount > 0 ? (votedCount + _pageSize - 1) / _pageSize : 0;
    uint256 totalPagesUnvoted = unvotedCount > 0 ? (unvotedCount + _pageSize - 1) / _pageSize : 0;
    uint256 totalPagesAll = allCount > 0 ? (allCount + _pageSize - 1) / _pageSize : 0;
    
    // Điều chỉnh page nếu vượt quá
    uint256 currentPage = _page;
    if (currentPage > totalPagesAll && totalPagesAll > 0) {
        currentPage = totalPagesAll;
    }
    
    uint256 startIndex = (currentPage - 1) * _pageSize;
    uint256 endIndex = startIndex + _pageSize;
    
    // Lấy voted proposals với pagination
    Proposal[] memory votedProposals = _getPaginatedProposals(votedIds, votedCount, startIndex, endIndex);
    
    // Lấy unvoted proposals với pagination
    Proposal[] memory unvotedProposals = _getPaginatedProposals(unvotedIds, unvotedCount, startIndex, endIndex);
    
    // Lấy all proposals với pagination
    Proposal[] memory allProposals = _getPaginatedProposals(allIds, allCount, startIndex, endIndex);
    
    return ManagerProposalDashboard({
        votedProposals: votedProposals,
        unvotedProposals: unvotedProposals,
        allProposals: allProposals,
        totalVoted: votedCount,
        totalUnvoted: unvotedCount,
        totalAll: allCount,
        page: currentPage,
        pageSize: _pageSize,
        totalPagesVoted: totalPagesVoted,
        totalPagesUnvoted: totalPagesUnvoted,
        totalPagesAll: totalPagesAll
    });
}

/**
 * @notice Helper function để lấy proposals theo pagination từ array IDs
 * @param _proposalIds Mảng proposal IDs
 * @param _total Tổng số proposals trong mảng
 * @param _startIndex Index bắt đầu
 * @param _endIndex Index kết thúc
 * @return Proposal[] Mảng proposals đã phân trang
 */
function _getPaginatedProposals(
    uint256[] memory _proposalIds,
    uint256 _total,
    uint256 _startIndex,
    uint256 _endIndex
) internal view returns (Proposal[] memory) {
    if (_total == 0 || _startIndex >= _total) {
        return new Proposal[](0);
    }
    
    uint256 actualEndIndex = _endIndex > _total ? _total : _endIndex;
    uint256 resultSize = actualEndIndex > _startIndex ? actualEndIndex - _startIndex : 0;
    
    Proposal[] memory result = new Proposal[](resultSize);
    
    for (uint256 i = 0; i < resultSize; i++) {
        uint256 proposalId = _proposalIds[_startIndex + i];
        Proposal storage proposal = proposals[proposalId];
        
        result[i] = Proposal({
            proposalId: proposal.proposalId,
            proposer: proposal.proposer,
            proposalType: proposal.proposalType,
            branchId: proposal.branchId,
            oldData: proposal.oldData,
            newData: proposal.newData,
            status: proposal.status,
            votesFor: proposal.votesFor,
            votesAgainst: proposal.votesAgainst,
            totalVoters: proposal.totalVoters,
            createdAt: proposal.createdAt,
            executedAt: proposal.executedAt
        });
    }
    
    return result;
}

/**
 * @notice Lấy thống kê chi tiết về proposals của manager
 * @param _manager Địa chỉ của manager
 * @return votedCount Số proposals đã vote
 * @return unvotedCount Số proposals chưa vote
 * @return approvedCount Số proposals đã được approve (manager đã vote)
 * @return rejectedCount Số proposals đã bị reject (manager đã vote)
 */
function getManagerProposalStats(address _manager) 
    external 
    view 
    returns (
        uint256 votedCount,
        uint256 unvotedCount,
        uint256 approvedCount,
        uint256 rejectedCount
    ) 
{
    for (uint256 i = 0; i < proposalIds.length; i++) {
        uint256 proposalId = proposalIds[i];
        Proposal storage proposal = proposals[proposalId];
        
        // Kiểm tra xem manager có quyền vote proposal này không
        bool canVote = _canVoteOnProposal(_manager, proposal.branchId);
        
        if (canVote) {
            if (proposalHasVoted[proposalId][_manager]) {
                votedCount++;
                
                if (proposal.status == ProposalStatus.APPROVED || 
                    proposal.status == ProposalStatus.EXECUTED) {
                    approvedCount++;
                } else if (proposal.status == ProposalStatus.REJECTED) {
                    rejectedCount++;
                }
            } else if (proposal.status == ProposalStatus.PENDING) {
                unvotedCount++;
            }
        }
    }
    
    return (votedCount, unvotedCount, approvedCount, rejectedCount);
}

/**
 * @notice Lấy dashboard proposals của manager theo branch với pagination
 * @param _manager Địa chỉ của manager
 * @param _branchId ID của chi nhánh (0 = proposals cấp merchant)
 * @param _page Số trang (bắt đầu từ 1)
 * @param _pageSize Số lượng proposals mỗi trang
 * @return ManagerProposalByBranchDashboard Dữ liệu proposals theo branch đã phân trang
 */
function getManagerDashboardProposalByBranch(
    address _manager,
    uint256 _branchId,
    uint256 _page,
    uint256 _pageSize
) external view returns (ManagerProposalByBranchDashboard memory) {
    require(_page > 0, "Page must be greater than 0");
    require(_pageSize > 0 && _pageSize <= 100, "Page size must be between 1 and 100");
    
    // Lấy tên chi nhánh
    string memory branchName = "";
    if ( branches[_branchId].active) {
        branchName = branches[_branchId].name;
    } 
    
    // Kiểm tra manager có quyền truy cập branch này không
    require(
        isMainOwner[_manager] || _isManagerOfBranch(_manager, _branchId),
        "Manager has no access to this branch"
    );
    
    // Tạo mảng tạm để lưu proposalIds theo branch
    uint256[] memory votedIds = new uint256[](proposalIds.length);
    uint256[] memory unvotedIds = new uint256[](proposalIds.length);
    uint256[] memory allIds = new uint256[](proposalIds.length);
    
    uint256 votedCount = 0;
    uint256 unvotedCount = 0;
    uint256 allCount = 0;
    
    // Phân loại proposals theo branch
    for (uint256 i = 0; i < proposalIds.length; i++) {
        uint256 proposalId = proposalIds[i];
        Proposal storage proposal = proposals[proposalId];
        
        // Chỉ lấy proposals của branch này
        if (proposal.branchId != _branchId) {
            continue;
        }
        
        // Kiểm tra xem manager có quyền vote proposal này không
        bool canVote = _canVoteOnProposal(_manager, proposal.branchId);
        
        if (canVote) {
            allIds[allCount] = proposalId;
            allCount++;
            
            if (proposalHasVoted[proposalId][_manager]) {
                votedIds[votedCount] = proposalId;
                votedCount++;
            } else if (proposal.status == ProposalStatus.PENDING) {
                // Chỉ tính proposals chưa vote nếu còn PENDING
                unvotedIds[unvotedCount] = proposalId;
                unvotedCount++;
            }
        }
    }
    
    // Tính toán pagination
    uint256 totalPagesVoted = votedCount > 0 ? (votedCount + _pageSize - 1) / _pageSize : 0;
    uint256 totalPagesUnvoted = unvotedCount > 0 ? (unvotedCount + _pageSize - 1) / _pageSize : 0;
    uint256 totalPagesAll = allCount > 0 ? (allCount + _pageSize - 1) / _pageSize : 0;
    
    // Điều chỉnh page nếu vượt quá
    uint256 currentPage = _page;
    if (currentPage > totalPagesAll && totalPagesAll > 0) {
        currentPage = totalPagesAll;
    }
    
    uint256 startIndex = (currentPage - 1) * _pageSize;
    uint256 endIndex = startIndex + _pageSize;
    
    // Lấy voted proposals với pagination
    Proposal[] memory votedProposals = _getPaginatedProposals(votedIds, votedCount, startIndex, endIndex);
    
    // Lấy unvoted proposals với pagination
    Proposal[] memory unvotedProposals = _getPaginatedProposals(unvotedIds, unvotedCount, startIndex, endIndex);
    
    // Lấy all proposals với pagination
    Proposal[] memory allProposals = _getPaginatedProposals(allIds, allCount, startIndex, endIndex);
    
    return ManagerProposalByBranchDashboard({
        branchId: _branchId,
        branchName: branchName,
        votedProposals: votedProposals,
        unvotedProposals: unvotedProposals,
        allProposals: allProposals,
        totalVoted: votedCount,
        totalUnvoted: unvotedCount,
        totalAll: allCount,
        page: currentPage,
        pageSize: _pageSize,
        totalPagesVoted: totalPagesVoted,
        totalPagesUnvoted: totalPagesUnvoted,
        totalPagesAll: totalPagesAll
    });
}

/**
 * @notice Lấy dashboard proposals của manager cho tất cả branches
 * @dev Trả về mảng dashboard data cho từng branch mà manager có quyền truy cập
 * @param _manager Địa chỉ của manager
 * @param _page Số trang (bắt đầu từ 1)
 * @param _pageSize Số lượng proposals mỗi trang
 * @return ManagerProposalByBranchDashboard[] Mảng dashboard data theo từng branch
 */
function getManagerDashboardProposalAllBranches(
    address _manager,
    uint256 _page,
    uint256 _pageSize
) external view returns (ManagerProposalByBranchDashboard[] memory) {
    require(_page > 0, "Page must be greater than 0");
    require(_pageSize > 0 && _pageSize <= 100, "Page size must be between 1 and 100");
    
    // Lấy danh sách branches mà manager có quyền truy cập
    uint256[] memory accessibleBranches;
    uint256 branchCount;
    
    if (isMainOwner[_manager]) {
        // Main owner có quyền truy cập tất cả branches + merchant level (branchId = 0)
        branchCount = branchIds.length + 1; // +1 cho merchant level
        accessibleBranches = new uint256[](branchCount);
        accessibleBranches[0] = 0; // Merchant level
        for (uint256 i = 0; i < branchIds.length; i++) {
            accessibleBranches[i + 1] = branchIds[i];
        }
    } else {
        ManagerInfo memory managerInfo = managers[_manager];
        require(managerInfo.active, "Manager not active");
        
        if (managerInfo.hasFullAccess) {
            // Full access manager - tất cả branches + merchant level
            branchCount = branchIds.length + 1;
            accessibleBranches = new uint256[](branchCount);
            accessibleBranches[0] = 0;
            for (uint256 i = 0; i < branchIds.length; i++) {
                accessibleBranches[i + 1] = branchIds[i];
            }
        } else {
            // Limited access - chỉ branches được assign
            branchCount = managerInfo.branchIds.length;
            accessibleBranches = managerInfo.branchIds;
        }
    }
    
    // Tạo mảng kết quả
    ManagerProposalByBranchDashboard[] memory results = new ManagerProposalByBranchDashboard[](branchCount);
    
    // Lấy dashboard cho từng branch
    for (uint256 i = 0; i < branchCount; i++) {
        uint256 currentBranchId = accessibleBranches[i];
        
        // Lấy tên chi nhánh
        string memory branchName = "";
        if ( branches[currentBranchId].active) {
            branchName = branches[currentBranchId].name;
        } 
        
        // Tạo mảng tạm
        uint256[] memory votedIds = new uint256[](proposalIds.length);
        uint256[] memory unvotedIds = new uint256[](proposalIds.length);
        uint256[] memory allIds = new uint256[](proposalIds.length);
        
        uint256 votedCount = 0;
        uint256 unvotedCount = 0;
        uint256 allCount = 0;
        
        // Phân loại proposals
        for (uint256 j = 0; j < proposalIds.length; j++) {
            uint256 proposalId = proposalIds[j];
            Proposal storage proposal = proposals[proposalId];
            
            if (proposal.branchId != currentBranchId) {
                continue;
            }
            
            bool canVote = _canVoteOnProposal(_manager, proposal.branchId);
            
            if (canVote) {
                allIds[allCount] = proposalId;
                allCount++;
                
                if (proposalHasVoted[proposalId][_manager]) {
                    votedIds[votedCount] = proposalId;
                    votedCount++;
                } else if (proposal.status == ProposalStatus.PENDING) {
                    unvotedIds[unvotedCount] = proposalId;
                    unvotedCount++;
                }
            }
        }
        
        // Tính toán pagination
        uint256 totalPagesVoted = votedCount > 0 ? (votedCount + _pageSize - 1) / _pageSize : 0;
        uint256 totalPagesUnvoted = unvotedCount > 0 ? (unvotedCount + _pageSize - 1) / _pageSize : 0;
        uint256 totalPagesAll = allCount > 0 ? (allCount + _pageSize - 1) / _pageSize : 0;
        
        uint256 currentPage = _page;
        if (currentPage > totalPagesAll && totalPagesAll > 0) {
            currentPage = totalPagesAll;
        }
        
        uint256 startIndex = (currentPage - 1) * _pageSize;
        uint256 endIndex = startIndex + _pageSize;
        
        // Lấy proposals với pagination
        Proposal[] memory votedProposals = _getPaginatedProposals(votedIds, votedCount, startIndex, endIndex);
        Proposal[] memory unvotedProposals = _getPaginatedProposals(unvotedIds, unvotedCount, startIndex, endIndex);
        Proposal[] memory allProposals = _getPaginatedProposals(allIds, allCount, startIndex, endIndex);
        
        results[i] = ManagerProposalByBranchDashboard({
            branchId: currentBranchId,
            branchName: branchName,
            votedProposals: votedProposals,
            unvotedProposals: unvotedProposals,
            allProposals: allProposals,
            totalVoted: votedCount,
            totalUnvoted: unvotedCount,
            totalAll: allCount,
            page: currentPage,
            pageSize: _pageSize,
            totalPagesVoted: totalPagesVoted,
            totalPagesUnvoted: totalPagesUnvoted,
            totalPagesAll: totalPagesAll
        });
    }
    
    return results;
}
}