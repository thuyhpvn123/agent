// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
import {AgentIQR} from "./agentIqr.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import "forge-std/console.sol";
import "./interfaces/IFreeGas.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
contract IQRFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    string public version;
    
    mapping(address =>mapping(uint => address)) public agentIQRContracts;
    mapping(address => address) public agentBranchManagement;
    address[] public deployedContracts;
    address public enhancedAgent;
    address public MANAGEMENT; //chỉ là implement, not proxy
    address public ORDER;
    address public REPORT;
    address public TIMEKEEPING;
    address public cardVisa;
    address public noti;
    address public revenueManager;
    address public StaffAgentStore;
    address public POINTS;
    // address public BRANCH_MANAGEMENT_IMP;
    // address public HISTORY_TRACKING_IMP;
    address public freeGasSc;
    UpgradeableBeacon public ManagementBeacon;
    UpgradeableBeacon public OrderBeacon;
    UpgradeableBeacon public ReportBeacon;
    UpgradeableBeacon public TimekeepingBeacon;
    mapping(address => bool) public isAdminIqr;
    LastUpdateData public lastUpdateIqr;
    uint256[49] private __gap;
    event AgentIQRCreated(address indexed agent,uint indexed branchId ,address indexed contractAddr, uint256 timestamp);
    event ContractUpgraded(string oldVersion, string newVersion, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        version = "1.0.0";
        isAdminIqr[msg.sender] = true;
    }
    modifier onlyAdminIqr() {
        require(isAdminIqr[msg.sender] || msg.sender == owner(), "only adminMeos can call");
        _;
    }
    function setAdminIqr(address admin, bool isAdmin) external onlyOwner {
        require(admin != address(0), "Invalid address");
        isAdminIqr[admin] = isAdmin;
    }  
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    modifier onlyEnhanceSC {
        require(msg.sender == enhancedAgent,"only enhancedAgent contract can call-IQR Factory");
        _;
    }
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }
    // function setFreeGasSC( address _freeGasSc) external onlyEnhanceSC{
    //     require(_freeGasSc != address(0),"_freeGasSc can be address(0)");
    //     freeGasSc = _freeGasSc;
    // }
    function setIQRSC(
        address _MANAGEMENT_IMP, //implement ,not proxy
        address _ORDER_IMP,
        address _REPORT_IMP,
        address _TIMEKEEPING_IMP,
        address _cardVisa,
        address _noti,
        address _revenueManager, //proxy dùng cho từng agent
        address _StaffAgentStore, //proxy dùng cho tất cả agent
        address _freeGasSc
    )external onlyOwner {
        if(_MANAGEMENT_IMP != address(0)){
            // MANAGEMENT = _MANAGEMENT_IMP;
            require(address(ManagementBeacon) == address(0),"Already initialized Beacon Iqr");
            ManagementBeacon = new UpgradeableBeacon(_MANAGEMENT_IMP, address(this));
        } 
        if(_ORDER_IMP != address(0)){
            // ORDER = _ORDER_IMP;
            require(address(OrderBeacon) == address(0),"Already initialized Beacon Iqr");
            OrderBeacon = new UpgradeableBeacon(_ORDER_IMP, address(this));
        } 
        if(_REPORT_IMP != address(0)){
            // REPORT = _REPORT_IMP;
            require(address(ReportBeacon) == address(0),"Already initialized Beacon Iqr");
            ReportBeacon = new UpgradeableBeacon(_REPORT_IMP, address(this));
        } 
        if(_TIMEKEEPING_IMP != address(0)){
            // TIMEKEEPING = _TIMEKEEPING_IMP;
            require(address(TimekeepingBeacon) == address(0),"Already initialized Beacon Iqr");
            TimekeepingBeacon = new UpgradeableBeacon(_TIMEKEEPING_IMP, address(this));
        } 
        if(_cardVisa != address(0)){cardVisa = _cardVisa;} 
        if(_noti != address(0)){noti = _noti;} 
        if(_revenueManager != address(0)){revenueManager = _revenueManager;} 
        if(_freeGasSc != address(0)){freeGasSc = _freeGasSc;} 
        if(_StaffAgentStore != address(0)){StaffAgentStore = _StaffAgentStore;}  
        
    }
    function createAgentIQR(address _agent, uint _branchId) external onlyEnhanceSC returns (address) {
        require(
            address(ManagementBeacon) != address(0) && 
            address(OrderBeacon) != address(0) && 
            address(ReportBeacon) != address(0) && 
            address(TimekeepingBeacon) != address(0), //Points có thể để là address(0)
            "addresses of iqr can be address(0)"
        );
        require(_agent != address(0), "Invalid agent");
        require(agentIQRContracts[_agent][_branchId] == address(0), "Contract already exists");
        
        AgentIQR newContract = new AgentIQR(
            _agent,
            enhancedAgent,
            address(ManagementBeacon),
            address(OrderBeacon),
            address(ReportBeacon),
            address(TimekeepingBeacon),
            revenueManager,
            StaffAgentStore,
            _branchId);
        IQRContracts memory iqr = newContract.getIQRSCByAgent(_agent,_branchId);
        address[] memory iqrAdds= new address[](4);
        iqrAdds[0] = iqr.Management;
        iqrAdds[1] = iqr.Order;
        iqrAdds[2] = iqr.Report;
        iqrAdds[3] = iqr.TimeKeeping;

        if(freeGasSc != address(0)){
            IFreeGas(freeGasSc).AddSC(_agent,iqrAdds);
        }
        address contractAddr = address(newContract);
        
        agentIQRContracts[_agent][_branchId] = contractAddr;
        deployedContracts.push(contractAddr);
        
        emit AgentIQRCreated(_agent,_branchId, contractAddr, block.timestamp);
        return contractAddr;
    }
    //admin gọi ngay sau gọi createAgent
    function setAgentIQR( address _agent, uint _branchId, address _branchManagement)external onlyEnhanceSC{
        require(_agent != address(0), "Invalid agent");
        require(agentIQRContracts[_agent][_branchId] != address(0), "Contract does not exist");
        AgentIQR agentIQR = AgentIQR(agentIQRContracts[_agent][_branchId]);
        IQRContracts memory iqrScs = agentIQR.getIQRSCByAgent(_agent,_branchId);
        agentIQR.set(_agent,iqrScs.Management,iqrScs.Order,iqrScs.Report,iqrScs.TimeKeeping,cardVisa,noti,iqrScs.StaffAgentStore,_branchManagement);
    }
    //admin gọi ngay sau gọi createAgent nếu có dùng loyalty
    function setPointsIQRFactory(address _agent, address _Points, uint _branchId) external onlyEnhanceSC {
        require(_Points != address(0),"Points contract not set yet");
        AgentIQR agentIQR = AgentIQR(agentIQRContracts[_agent][_branchId]);
        agentIQR.setPointSC(_Points,_agent,_branchId);

        POINTS = _Points;
    }
    function transferOwnerIQRContracts(address _agent, uint _branchId)external onlyEnhanceSC {
        address agentIQR = agentIQRContracts[_agent][_branchId];
        IQRContracts memory iqr = IAgentIQR(agentIQR).getIQRSCByAgent(_agent,_branchId);
        IAgentIQR(agentIQR).transferOwnerIQR(_agent,iqr.Management,iqr.Order,iqr.Report,iqr.TimeKeeping);
    }
    function getAgentIQRContract(address _agent, uint _branchId) external view returns (address) {
        return agentIQRContracts[_agent][_branchId];
    }
    function getIQRSCByAgentFromFactory(address _agent, uint _branchId) external view returns (IQRContracts memory) {
        address agentIqr = agentIQRContracts[_agent][_branchId];
        IQRContracts memory iqrContracts = IAgentIQR(agentIqr).getIQRSCByAgent(_agent,_branchId);
        return iqrContracts;
    }
    function getManagementSCByAgentsFromFactory(address _agent, uint[] memory _branchIds) external view returns (address[] memory managementScs, uint count) {
        managementScs = new address[](_branchIds.length);
        count = 0;
        for(uint i=0; i< _branchIds.length;i++){
            address agentIqr = agentIQRContracts[_agent][_branchIds[i]];
            IQRContracts memory iqrContracts = IAgentIQR(agentIqr).getIQRSCByAgent(_agent,_branchIds[i]);
            managementScs[i] = iqrContracts.Management;
            if(iqrContracts.Management != address(0)){
                count++;
            }
        }

    }
    function getAllDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }
    
    function getVersion() external view returns (string memory) {
        return version;
    }

    function upgradeBeaconGlobal(
        address _newImplManagement,
        address _newImplOrder,
        address _newImplReport,
        address _newImplTimekeeping
    ) external onlyAdminIqr {
        
        if(_newImplManagement != address(0)){
            ManagementBeacon.upgradeTo(_newImplManagement);
        }
        if(_newImplOrder != address(0)){
            OrderBeacon.upgradeTo(_newImplOrder);
        }
        if(_newImplReport != address(0)){
            ReportBeacon.upgradeTo(_newImplReport);
        }
        if(_newImplTimekeeping != address(0)){
            TimekeepingBeacon.upgradeTo(_newImplTimekeeping);
        }
        lastUpdateIqr = LastUpdateData({
            admin: msg.sender,
            updateAt: block.timestamp
        });
        
    }
        /**
     * @dev Transfer beacon ownership sang địa chỉ khác nếu cần.
     *      Hiếm khi dùng — chỉ khi muốn trao quyền upgrade beacon cho bên khác.
     */
    function transferBeaconOwnership(address _newOwner) external onlyOwner {
        require(
            address(ManagementBeacon) != address(0) &&
            address(OrderBeacon) != address(0) &&
            address(ReportBeacon) != address(0) &&
            address(TimekeepingBeacon) != address(0), 
        "Beacon not created");
        require(_newOwner != address(0), "Invalid address");
        ManagementBeacon.transferOwnership(_newOwner);
        OrderBeacon.transferOwnership(_newOwner);
        ReportBeacon.transferOwnership(_newOwner);
        TimekeepingBeacon.transferOwnership(_newOwner);
    }
    /**
     * @dev Lấy địa chỉ implementation hiện tại từ beacon
     */
    function currentImplementation() external view returns (address,address,address,address) {
        require(
            address(ManagementBeacon) != address(0) && 
            address(OrderBeacon) != address(0) &&
            address(ReportBeacon) != address(0) &&
            address(TimekeepingBeacon) != address(0), 
            "Beacon not created"
        );
        return (
            ManagementBeacon.implementation(),
            OrderBeacon.implementation(),
            ReportBeacon.implementation(),
            TimekeepingBeacon.implementation()
        );
    }

}


