// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IAgent.sol";
import "./interfaces/IPoint.sol";
import "./interfaces/IRobot.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
// import "forge-std/console.sol";

contract AgentRobot is OwnableUpgradeable {
    UpgradeableBeacon public RobotActiveBeacon;
    UpgradeableBeacon public RobotDashboadBeacon;
    UpgradeableBeacon public RobotLoadBeacon;
    UpgradeableBeacon public RobotLocationBeacon;
    UpgradeableBeacon public RobotQuestionBeacon;
    UpgradeableBeacon public RobotRegistryBeacon;
    UpgradeableBeacon public RobotTestingBeacon;
    UpgradeableBeacon public RobotObservationTrainingBeacon;
    address public agent;
    uint public branchId;
    uint256 public totalOrders;
    uint256 public totalRevenue;
    uint256 public completedOrders;
    bool public isActive = true;  
    mapping( bytes32 => AgentOrder) public orders;
    bytes32[] public orderIds;
    mapping(address =>mapping(uint => RobotContracts)) public mAgentToRobot;
    address public enhancedAgent;
    address public robotFactory;
    // address public revenueManager;
    address public StaffRobotSC;
    address public iqrFactory;
    address public meosFactory;

    // address public branchManagement; //proxy
    event OrderCreated(uint256 indexed orderId, address indexed customer, uint256 amount, uint256 timestamp);
    event OrderCompleted(uint256 indexed orderId, uint256 timestamp);
    event OrderCancelled(uint256 indexed orderId, uint256 timestamp);
    event ContractDeactivated(uint256 timestamp);
    constructor(
        address _agent,
        address _enhancedAgent,
        RobotInputsBeacon memory robotInputs,
        address _iqrFactory,
        address _meosFactory,
        uint _branchId,
        bool _hasIqr,
        bool _hasMeos
    ) {
        require(_agent != address(0), "Invalid agent address");
        agent = _agent;
        _transferOwnership(_agent);
        enhancedAgent = _enhancedAgent;
        // revenueManager = _revenueManager;
        iqrFactory = _iqrFactory;
        meosFactory = _meosFactory;
        initializeIQRSCS(
            _agent,
            robotInputs,

            _branchId,
            _hasIqr,
            _hasMeos
            );
        // ORDER = _ORDER;
        robotFactory = msg.sender;
        branchId = _branchId;
        
    }
    modifier onlyRobotFactory {
        require(msg.sender == robotFactory,"only RobotFactory can call");
        _;
    }

    modifier onlyActiveContract() {
        require(isActive, "Contract is not active");
        _;
    }


    function initializeIQRSCS(
        address _agent,
        RobotInputsBeacon memory robotInputs,
        uint _branchId,
        bool _hasIqr,
        bool _hasMeos
        ) internal {
        
        address StaffRobotSC_PROXY_ADD;
        if(_hasIqr){
            
            require(iqrFactory != address(0),"iqrFactory not set yet in initializeMEOSSCS");
            IQRContracts memory iqr = IIQRFactory(iqrFactory).getIQRSCByAgentFromFactory(_agent,_branchId);
            StaffRobotSC_PROXY_ADD = iqr.Management;
        }else if(!_hasIqr && _hasMeos) {
            require(iqrFactory != address(0),"iqrFactory not set yet in initializeMEOSSCS");
            MeosContracts memory meos = IMeosFactory(meosFactory).getMeosSCByAgentFromFactory(_agent,_branchId);
            StaffRobotSC_PROXY_ADD = meos.StaffMeosSC;

        }else{
            BeaconProxy StaffRobotSC_PROXY = new BeaconProxy(
                address(robotInputs.StaffRobotBeacon),
                abi.encodeWithSelector(IStaffRobot.initialize.selector)
            );
            StaffRobotSC_PROXY_ADD = address(StaffRobotSC_PROXY);
        }
        require(address(RobotRegistryBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        RobotRegistryBeacon = UpgradeableBeacon(robotInputs.RobotRegistryBeacon);

        BeaconProxy RobotRegistryV2_PROXY = new BeaconProxy(
            address(RobotRegistryBeacon),
            abi.encodeWithSelector(IRobotRegistryV2.initialize.selector,
            StaffRobotSC_PROXY_ADD)
        );
        require(address(RobotActiveBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        RobotActiveBeacon = UpgradeableBeacon(robotInputs.RobotActiveBeacon);
        BeaconProxy RobotActiveV2_PROXY = new BeaconProxy(
            address(RobotActiveBeacon),
            abi.encodeWithSelector(IRobotActiveV2.initialize.selector,
            StaffRobotSC_PROXY_ADD,
            address(RobotRegistryV2_PROXY)
            )
        );
        require(address(RobotLoadBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        RobotLoadBeacon = UpgradeableBeacon(robotInputs.RobotLoadBeacon);
        BeaconProxy RobotDataUploadTrainingV2_PROXY = new BeaconProxy(
            address(RobotLoadBeacon),
            abi.encodeWithSelector(IRobotDataUploadTrainingV2.initialize.selector,
            StaffRobotSC_PROXY_ADD,
            address(RobotRegistryV2_PROXY)
            )
        );
        require(address(RobotObservationTrainingBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        RobotObservationTrainingBeacon = UpgradeableBeacon(robotInputs.RobotObservationTrainingBeacon);
        BeaconProxy RobotObservationTrainingV2_PROXY = new BeaconProxy(
            address(RobotObservationTrainingBeacon), 
            abi.encodeWithSelector(IRobotObservationTrainingV2.initialize.selector, 
            StaffRobotSC_PROXY_ADD,
            address(RobotRegistryV2_PROXY)
            )
        );
        require(address(RobotTestingBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        RobotTestingBeacon = UpgradeableBeacon(robotInputs.RobotTestingBeacon);
        BeaconProxy RobotTestingV2_PROXY = new BeaconProxy(
            address(RobotTestingBeacon), 
            abi.encodeWithSelector(IRobotTestingV2.initialize.selector, 
            StaffRobotSC_PROXY_ADD,
            address(RobotRegistryV2_PROXY)
            )
        );
        require(address(RobotDashboadBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        RobotDashboadBeacon = UpgradeableBeacon(robotInputs.RobotDashboadBeacon);
        BeaconProxy RobotDashboadV2_PROXY = new BeaconProxy(
            address(RobotDashboadBeacon), 
            abi.encodeWithSelector(IRobotDashboadV2.initialize.selector, 
            StaffRobotSC_PROXY_ADD
            )
        );
        require(address(RobotLocationBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        RobotLocationBeacon = UpgradeableBeacon(robotInputs.RobotLocationBeacon);
        BeaconProxy RobotLocationV2_PROXY = new BeaconProxy(
            address(RobotLocationBeacon), 
            abi.encodeWithSelector(IRobotLocationV2.initialize.selector, 
            StaffRobotSC_PROXY_ADD,
            address(RobotRegistryV2_PROXY)
            )
        );
        require(address(RobotQuestionBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        RobotQuestionBeacon = UpgradeableBeacon(robotInputs.RobotQuestionBeacon);
        BeaconProxy RobotQuestionV2_PROXY = new BeaconProxy(
            address(RobotQuestionBeacon), 
            abi.encodeWithSelector(IRobotQuestionV2.initialize.selector)
        );
        RobotContracts memory robot = RobotContracts({
            StaffRobotSC: StaffRobotSC_PROXY_ADD,
            RobotRegistryV2: address(RobotRegistryV2_PROXY),
            RobotActiveV2: address(RobotActiveV2_PROXY),
            RobotDataUploadTrainingV2: address(RobotDataUploadTrainingV2_PROXY),
            RobotObservationTrainingV2: address(RobotObservationTrainingV2_PROXY),
            RobotTestingV2: address(RobotTestingV2_PROXY),
            RobotDashboadV2: address(RobotDashboadV2_PROXY),
            RobotLocationV2: address(RobotLocationV2_PROXY),
            RobotQuestionV2: address(RobotQuestionV2_PROXY),
            owner:  _agent,
            StaffAgentStore: robotInputs.StaffAgentStore,
            Points: address(0)
        });
        mAgentToRobot[_agent][_branchId] = robot;
        StaffRobotSC = StaffRobotSC_PROXY_ADD;

    }
    function setPointSC(address _POINTS_PROXY, address _agent, uint branchId) external onlyRobotFactory{
        RobotContracts storage robot = mAgentToRobot[_agent][branchId];
        robot.Points = _POINTS_PROXY;
        // require(robot.Management != address(0) && robot.Order != address(0),"robot not set yet");
        mAgentToRobot[msg.sender][branchId].Points = _POINTS_PROXY;
        IStaffRobot(robot.StaffRobotSC).setPoints(_POINTS_PROXY);
        // IORDER(robot.Order).setPointSC(_POINTS_PROXY);
    }

    function getRobotSCByAgent(address _agent,uint _branchId) external view returns(RobotContracts memory){
        return mAgentToRobot[_agent][_branchId];
    }
    // //tách ra gọi để FE không bị out of gas
    // function set(
    //     address _agent,
    //     address _StaffRobotSC,
    //     address _user,
    //     address _session,
    //     address _topup,
    //     address _spend,
    // //     address noti,
    //     address _StaffAgentStore,
    //     address _branchManagement //proxy
    // )external onlyRobotFactory{

    // }

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
    )external onlyRobotFactory{
        IStaffRobot(_StaffRobotSC).transferOwnership(_agent);
        IRobotRegistryV2(_RobotRegistryV2).transferOwnership(_agent);
        IRobotActiveV2(_RobotActiveV2).transferOwnership(_agent);
        IRobotDataUploadTrainingV2(_RobotDataUploadTrainingV2).transferOwnership(_agent);
        IRobotObservationTrainingV2(_RobotObservationTrainingV2).transferOwnership(_agent);
        IRobotTestingV2(_RobotTestingV2).transferOwnership(_agent);
        IRobotDashboadV2(_RobotDashboadV2).transferOwnership(_agent);
        IRobotLocationV2(_RobotLocationV2).transferOwnership(_agent);
        IRobotQuestionV2(_RobotQuestionV2).transferOwnership(_agent);
    }
    function deactivate() external {
        require(msg.sender == enhancedAgent , "Unauthorized");
        isActive = false;
        IStaffRobot(StaffRobotSC).setActive(false);
        emit ContractDeactivated(block.timestamp);
    }
    
    function reactivate() external  {
        require(msg.sender == enhancedAgent  , "Unauthorized");
        isActive = true;
        IStaffRobot(StaffRobotSC).setActive(true);
    }
    
}
