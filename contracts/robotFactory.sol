// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
import {AgentRobot} from "./agentRobot.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import "forge-std/console.sol";
import "./interfaces/IFreeGas.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
contract RobotFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    
    mapping(address =>mapping(uint => address)) public agentRobotContracts;
    mapping(address => address) public agentBranchManagement;
    address[] public deployedContracts;
    address public enhancedAgent;
    address public StaffRobotSC; //chỉ là implement, not proxy
    address public RobotRegistryV2IMP;
    address public RobotActiveV2IMP;
    address public RobotDataUploadTrainingV2IMP;
    address public RobotObservationTrainingV2IMP;
    address public RobotLocationV2IMP;
    address public RobotQuestionV2IMP;
    address public RobotDashboadV2IMP;
    address public RobotTestingV2IMP;
    address public StaffAgentStore;
    address public POINTS;
    address public freeGasSc;
    address public iqrFactory;
    address public meosFactory;
    UpgradeableBeacon public StaffRobotBeacon;
    UpgradeableBeacon public RobotActiveBeacon;
    UpgradeableBeacon public RobotDashboadBeacon;
    UpgradeableBeacon public RobotLoadBeacon;
    UpgradeableBeacon public RobotLocationBeacon;
    UpgradeableBeacon public RobotQuestionBeacon;
    UpgradeableBeacon public RobotRegistryBeacon;
    UpgradeableBeacon public RobotTestingBeacon;
    UpgradeableBeacon public RobotObservationTrainingBeacon;
    mapping(address => bool) public isAdminRobot;
    uint256[49] private __gap;
    event AgentRobotCreated(address indexed agent,uint indexed branchId ,address indexed contractAddr, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        isAdminRobot[msg.sender];
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    modifier onlyEnhanceSC {
        require(msg.sender == enhancedAgent,"only enhancedAgent contract can call");
        _;
    }
    modifier onlyAdminRobot() {
        require(isAdminRobot[msg.sender] || msg.sender == owner(), "only adminMeos can call");
        _;
    }
    function setAdminRobot(address admin, bool isAdmin) external onlyOwner {
        require(admin != address(0), "Invalid address");
        isAdminRobot[admin] = isAdmin;
    }  
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }
    function setRobot( 
        RobotInputs memory robotInputs,
        address _freeGasSc,
        address _iqrFactory,
        address _meosFactory
    )external onlyOwner {
        if(robotInputs._StaffRobotSC != address(0)){StaffRobotSC = robotInputs._StaffRobotSC;} 
        if(robotInputs._RobotRegistryV2IMP != address(0)){RobotRegistryV2IMP = robotInputs._RobotRegistryV2IMP;} 
        if(robotInputs._RobotActiveV2IMP != address(0)){RobotActiveV2IMP = robotInputs._RobotActiveV2IMP;} 
        if(robotInputs._RobotDataUploadTrainingV2IMP != address(0)){RobotDataUploadTrainingV2IMP = robotInputs._RobotDataUploadTrainingV2IMP;} 
        if(robotInputs._RobotObservationTrainingV2IMP != address(0)){RobotObservationTrainingV2IMP = robotInputs._RobotObservationTrainingV2IMP;} 
        if(robotInputs._RobotLocationV2IMP != address(0)){RobotLocationV2IMP = robotInputs._RobotLocationV2IMP;} 
        if(robotInputs._RobotQuestionV2IMP != address(0)){RobotQuestionV2IMP = robotInputs._RobotQuestionV2IMP;} 
        if(robotInputs._RobotDashboadV2IMP != address(0)){RobotDashboadV2IMP = robotInputs._RobotDashboadV2IMP;} 
        if(robotInputs._RobotTestingV2IMP != address(0)){RobotTestingV2IMP = robotInputs._RobotTestingV2IMP;} 
        if(_freeGasSc != address(0)){freeGasSc = _freeGasSc;} 
        if(robotInputs._StaffAgentStore != address(0)){StaffAgentStore = robotInputs._StaffAgentStore;}  
        if(_iqrFactory != address(0)){iqrFactory = _iqrFactory;}
        if(_meosFactory != address(0)){meosFactory = _meosFactory;}
        initBeacons(
            robotInputs
        );
    }
    function initBeacons(
        RobotInputs memory robotInputs
    )internal {
        StaffRobotBeacon = new UpgradeableBeacon(robotInputs._StaffRobotSC, address(this));
        RobotActiveBeacon = new UpgradeableBeacon(robotInputs._RobotActiveV2IMP, address(this));
        RobotDashboadBeacon= new UpgradeableBeacon(robotInputs._RobotDashboadV2IMP, address(this));
        RobotLoadBeacon= new UpgradeableBeacon(robotInputs._RobotDataUploadTrainingV2IMP, address(this));
        RobotLocationBeacon= new UpgradeableBeacon(robotInputs._RobotLocationV2IMP, address(this));
        RobotQuestionBeacon= new UpgradeableBeacon(robotInputs._RobotQuestionV2IMP, address(this));
        RobotRegistryBeacon= new UpgradeableBeacon(robotInputs._RobotRegistryV2IMP, address(this));
        RobotTestingBeacon= new UpgradeableBeacon(robotInputs._RobotTestingV2IMP, address(this));
        RobotObservationTrainingBeacon= new UpgradeableBeacon(robotInputs._RobotObservationTrainingV2IMP, address(this));

    }

    function createAgentRobot(
        address _agent, 
        uint _branchId, 
        bool _hasIqr,
        bool _hasMeos
    ) external onlyEnhanceSC returns (address) {
        require(
            address(StaffRobotBeacon) != address(0) && 
            address(RobotRegistryBeacon) != address(0) && 
            address(RobotActiveBeacon) != address(0) && 
            address(RobotLoadBeacon) != address(0)&& 
            address(RobotObservationTrainingBeacon) != address(0) &&
            address(RobotLocationBeacon) != address(0) &&
            address(RobotQuestionBeacon) != address(0) &&
            address(RobotDashboadBeacon) != address(0) &&
            address(RobotTestingBeacon) != address(0) ,
            "addresses of robot can be address(0)"
        );
        require(_agent != address(0), "Invalid agent");
        require(agentRobotContracts[_agent][_branchId] == address(0), "Contract already exists");
        RobotInputsBeacon memory robotInputs = RobotInputsBeacon({
            StaffRobotBeacon: address(StaffRobotBeacon),
            RobotRegistryBeacon: address(RobotRegistryBeacon),
            RobotActiveBeacon: address(RobotActiveBeacon),
            RobotLoadBeacon: address(RobotLoadBeacon),
            RobotObservationTrainingBeacon: address(RobotObservationTrainingBeacon),
            RobotLocationBeacon: address(RobotLocationBeacon),
            RobotQuestionBeacon: address(RobotQuestionBeacon),
            RobotDashboadBeacon: address(RobotDashboadBeacon),
            RobotTestingBeacon: address(RobotTestingBeacon),
            StaffAgentStore: StaffAgentStore
        });
        AgentRobot newContract = new AgentRobot(
            _agent,
            enhancedAgent,
            robotInputs,
            iqrFactory,
            meosFactory,
            _branchId,
            _hasIqr,
            _hasMeos
        );
        RobotContracts memory robot = newContract.getRobotSCByAgent(_agent,_branchId);
        address[] memory robotAdds= new address[](9);
        robotAdds[0] = robot.StaffRobotSC;
        robotAdds[1] = robot.RobotRegistryV2;
        robotAdds[2] = robot.RobotActiveV2;
        robotAdds[3] = robot.RobotDataUploadTrainingV2;
        robotAdds[4] = robot.RobotObservationTrainingV2;
        robotAdds[5] = robot.RobotTestingV2;
        robotAdds[6] = robot.RobotDashboadV2;
        robotAdds[7] = robot.RobotLocationV2;
        robotAdds[8] = robot.RobotQuestionV2;
        if(freeGasSc != address(0)){
            IFreeGas(freeGasSc).AddSC(_agent,robotAdds);
        }
        address contractAddr = address(newContract);
        
        agentRobotContracts[_agent][_branchId] = contractAddr;
        deployedContracts.push(contractAddr);
        emit AgentRobotCreated(_agent,_branchId, contractAddr, block.timestamp);
        return contractAddr;
    }
    //admin gọi ngay sau gọi createAgent neu chon robot
    function setAgentRobot( address _agent, uint _branchId, address _branchManagement)external onlyEnhanceSC{
        require(_agent != address(0), "Invalid agent");
        require(agentRobotContracts[_agent][_branchId] != address(0), "Contract does not exist");
        AgentRobot agentRobot = AgentRobot(agentRobotContracts[_agent][_branchId]);
        // RobotContracts memory robotScs = agentRobot.getRobotSCByAgent(_agent,_branchId);
        // agentRobot.set(_agent,robotScs.StaffRobotSC,robotScs.RobotRegistryV2,robotScs.RobotActiveV2,robotScs.RobotDataUploadTrainingV2,robotScs.RobotObservationTrainingV2,robotScs.StaffAgentStore,_branchManagement);
    }
    //admin gọi ngay sau gọi createAgent nếu có dùng loyalty
    function setPointsRobotFactory(address _agent, address _Points, uint _branchId) external onlyEnhanceSC {
        require(_Points != address(0),"Points contract not set yet");
        AgentRobot agentRobot = AgentRobot(agentRobotContracts[_agent][_branchId]);
        agentRobot.setPointSC(_Points,_agent,_branchId);

        POINTS = _Points;
    }
    function transferOwnerRobotContracts(address _agent, uint _branchId)external onlyEnhanceSC {
        address agentRobot = agentRobotContracts[_agent][_branchId];
        RobotContracts memory robot = IAgentRobot(agentRobot).getRobotSCByAgent(_agent,_branchId);
        IAgentRobot(agentRobot).transferOwnerRobot(
            _agent,
            robot.StaffRobotSC,
            robot.RobotRegistryV2,
            robot.RobotActiveV2,
            robot.RobotDataUploadTrainingV2,
            robot.RobotObservationTrainingV2,
            robot.RobotTestingV2,
            robot.RobotDashboadV2,
            robot.RobotLocationV2,
            robot.RobotQuestionV2
        );
    }
    function getAgentROBOTContract(address _agent, uint _branchId) external view returns (address) {
        return agentRobotContracts[_agent][_branchId];
    }
    function getRobotSCByAgentFromFactory(address _agent, uint _branchId) external view returns (RobotContracts memory) {
        address agentRobot = agentRobotContracts[_agent][_branchId];
        RobotContracts memory robotContracts = IAgentRobot(agentRobot).getRobotSCByAgent(_agent,_branchId);
        return robotContracts;
    }
    function getManagementSCByAgentsFromFactory(address _agent, uint[] memory _branchIds) external view returns (address[] memory managementScs,uint count) {
        managementScs = new address[](_branchIds.length);
        count = 0;
        for(uint i=0; i< _branchIds.length;i++){
            address agentRobot = agentRobotContracts[_agent][_branchIds[i]];
            RobotContracts memory robotContracts = IAgentRobot(agentRobot).getRobotSCByAgent(_agent,_branchIds[i]);
            managementScs[i] = robotContracts.StaffRobotSC;
            if(robotContracts.StaffRobotSC != address(0)){
                count++;
            }
        }
    }
    function getAllDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }
    function upgradeBeaconGlobal(
        address _newImplRobotActive,
        address _newImplRobotDashboad,
        address _newImplRobotLoad,
        address _newImplRobotLocation,
        address _newImplRobotQuestion,
        address _newImplRobotRegistry,
        address _newImplRobotTesting,
        address _newImplRobotObservationTraining
    ) external onlyAdminRobot {
        
        if(_newImplRobotActive != address(0)){
            RobotActiveBeacon.upgradeTo(_newImplRobotActive);
        }
        if(_newImplRobotDashboad != address(0)){
            RobotDashboadBeacon.upgradeTo(_newImplRobotDashboad);
        }
        if(_newImplRobotLoad != address(0)){
            RobotLoadBeacon.upgradeTo(_newImplRobotLoad);
        }
        if(_newImplRobotLocation != address(0)){
            RobotLocationBeacon.upgradeTo(_newImplRobotLocation);
        }
        if(_newImplRobotQuestion != address(0)){
            RobotQuestionBeacon.upgradeTo(_newImplRobotQuestion);
        }
        if(_newImplRobotRegistry != address(0)){
            RobotRegistryBeacon.upgradeTo(_newImplRobotRegistry);
        }

        if(_newImplRobotTesting != address(0)){
            RobotTestingBeacon.upgradeTo(_newImplRobotTesting);
        }
        if(_newImplRobotObservationTraining != address(0)){
            RobotObservationTrainingBeacon.upgradeTo(_newImplRobotObservationTraining);
        }

    }
            /**
     * @dev Transfer beacon ownership sang địa chỉ khác nếu cần.
     *      Hiếm khi dùng — chỉ khi muốn trao quyền upgrade beacon cho bên khác.
     */
    function transferBeaconOwnership(address _newOwner) external onlyOwner {
        require(
            address(RobotActiveBeacon) != address(0) &&
            address(RobotDashboadBeacon) != address(0) &&
            address(RobotLoadBeacon) != address(0) &&
            address(RobotLocationBeacon) != address(0)&& 
            address(RobotQuestionBeacon) != address(0)&& 
            address(RobotRegistryBeacon) != address(0)&& 
            address(RobotTestingBeacon) != address(0)&& 
            address(RobotObservationTrainingBeacon) != address(0),
        "Beacon not created");
        require(_newOwner != address(0), "Invalid address");
        RobotActiveBeacon.transferOwnership(_newOwner);
        RobotDashboadBeacon.transferOwnership(_newOwner);
        RobotLoadBeacon.transferOwnership(_newOwner);
        RobotLocationBeacon.transferOwnership(_newOwner);
        RobotQuestionBeacon.transferOwnership(_newOwner);
        RobotRegistryBeacon.transferOwnership(_newOwner);
        RobotTestingBeacon.transferOwnership(_newOwner);
        RobotObservationTrainingBeacon.transferOwnership(_newOwner);
    }
    /**
     * @dev Lấy địa chỉ implementation hiện tại từ beacon
     */
    function currentImplementation() external view returns (
        address,address,address,address,address,address,address,address) {
        require(
            address(RobotActiveBeacon) != address(0) &&
            address(RobotDashboadBeacon) != address(0) &&
            address(RobotLoadBeacon) != address(0) &&
            address(RobotLocationBeacon) != address(0)&& 
            address(RobotQuestionBeacon) != address(0)&& 
            address(RobotRegistryBeacon) != address(0)&& 
            address(RobotTestingBeacon) != address(0)&& 
            address(RobotObservationTrainingBeacon) != address(0),
            "Beacon not created"
        );
        return (
            RobotActiveBeacon.implementation(),
            RobotDashboadBeacon.implementation(),
            RobotLoadBeacon.implementation(),
            RobotLocationBeacon.implementation(),
            RobotQuestionBeacon.implementation(),
            RobotRegistryBeacon.implementation(),
            RobotTestingBeacon.implementation(),
            RobotObservationTrainingBeacon.implementation()

        );
    }

}


