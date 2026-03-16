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
    uint256[49] private __gap;
    event AgentRobotCreated(address indexed agent,uint indexed branchId ,address indexed contractAddr, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    modifier onlyEnhanceSC {
        require(msg.sender == enhancedAgent,"only enhancedAgent contract can call");
        _;
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
        // address _StaffRobotSC, //implement ,not proxy
        // address _RobotRegistryV2IMP,
        // address _RobotActiveV2IMP,
        // address _RobotDataUploadTrainingV2IMP,
        // address _RobotObservationTrainingV2IMP,
        // address _RobotTestingV2IMP,
        // address _RobotDashboadV2IMP,
        // address _RobotLocationV2IMP,
        // address _RobotQuestionV2IMP,        
        // address _StaffAgentStore, //proxy dùng cho tất cả agent
        // address _freeGasSc,
        // address _iqrFactory,
        // address _meosFactory
    // )external onlyOwner {
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

        
    }
    function createAgentRobot(address _agent, uint _branchId, bool _hasIqr,bool _hasMeos) external onlyEnhanceSC returns (address) {
        require(
            StaffRobotSC != address(0) && 
            RobotRegistryV2IMP != address(0) && 
            RobotActiveV2IMP != address(0) && 
            RobotDataUploadTrainingV2IMP != address(0)&& 
            RobotObservationTrainingV2IMP != address(0) &&
            RobotLocationV2IMP != address(0) &&
            RobotQuestionV2IMP != address(0) &&
            RobotDashboadV2IMP != address(0) &&
            RobotTestingV2IMP != address(0) ,
            "addresses of robot can be address(0)"
        );
        require(_agent != address(0), "Invalid agent");
        require(agentRobotContracts[_agent][_branchId] == address(0), "Contract already exists");
        RobotInputs memory robotInputs = RobotInputs({
            _StaffRobotSC: StaffRobotSC,
            _RobotRegistryV2IMP: RobotRegistryV2IMP,
            _RobotActiveV2IMP: RobotActiveV2IMP,
            _RobotDataUploadTrainingV2IMP: RobotDataUploadTrainingV2IMP,
            _RobotObservationTrainingV2IMP: RobotObservationTrainingV2IMP,
            _RobotLocationV2IMP: RobotLocationV2IMP,
            _RobotQuestionV2IMP: RobotQuestionV2IMP,
            _RobotDashboadV2IMP: RobotDashboadV2IMP,
            _RobotTestingV2IMP: RobotTestingV2IMP,
            _StaffAgentStore: StaffAgentStore
        });
        AgentRobot newContract = new AgentRobot(
            _agent,
            enhancedAgent,
            robotInputs,
            // StaffRobotSC,
            // RobotRegistryV2IMP,
            // RobotActiveV2IMP,
            // RobotDataUploadTrainingV2IMP,
            // RobotObservationTrainingV2IMP,
            // RobotTestingV2IMP,
            // RobotDashboadV2IMP,
            // RobotLocationV2IMP,
            // RobotQuestionV2IMP,
            // StaffAgentStore,
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
    
}


