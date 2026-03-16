// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IAgent.sol";
import "./interfaces/IPoint.sol";
import "./interfaces/IMeos.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
// import "forge-std/console.sol";

contract AgentMeos is OwnableUpgradeable {
    UpgradeableBeacon public StaffMeosBeacon;
    UpgradeableBeacon public NetCafeUserBeacon;
    UpgradeableBeacon public NetCafeSessionBeacon;
    UpgradeableBeacon public NetCafeTopUpBeacon;
    UpgradeableBeacon public NetCafeSpendBeacon;
    UpgradeableBeacon public NetCafeManagementBeacon;
    UpgradeableBeacon public NetCafeStationBeacon;
    address public agent;
    uint public branchId;
    uint256 public totalOrders;
    uint256 public totalRevenue;
    uint256 public completedOrders;
    bool public isActive = true;  
    mapping( bytes32 => AgentOrder) public orders;
    bytes32[] public orderIds;
    mapping(address =>mapping(uint => MeosContracts)) public mAgentToMeos;
    address public enhancedAgent;
    address public meosFactory;
    // address public revenueManager;
    address public StaffMeosSC;
    address public iqrFactory;
    // address public branchManagement; //proxy
    event OrderCreated(uint256 indexed orderId, address indexed customer, uint256 amount, uint256 timestamp);
    event OrderCompleted(uint256 indexed orderId, uint256 timestamp);
    event OrderCancelled(uint256 indexed orderId, uint256 timestamp);
    event ContractDeactivated(uint256 timestamp);
    event BeaconUpgraded(
        address indexed beacon,
        address oldImpl,
        address newImpl,
        uint256 timestamp
    );
    constructor(
        address _agent,
        address _enhancedAgent,
        address _StaffMeosSCIMP,
        address _NetCafeUserIMP,
        address _NetCafeSessionIMP,
        address _NetCafeTopUpIMP,
        address _NetCafeSpendIMP,
        address _NetCafeManagementIMP,
        address _NetCafeStationIMP,
        address _StaffAgentStore,
        address _iqrFactory,
        uint _branchId,
        bool _hasIqr
    ) {
        require(_agent != address(0), "Invalid agent address");
        agent = _agent;
        _transferOwnership(_agent);
        enhancedAgent = _enhancedAgent;
        // revenueManager = _revenueManager;
        iqrFactory = _iqrFactory;
        initializeMEOSSCS(
            _agent,
            _StaffMeosSCIMP,
            _NetCafeUserIMP,
            _NetCafeSessionIMP,
            _NetCafeTopUpIMP,
            _NetCafeSpendIMP,
            _NetCafeManagementIMP,
            _NetCafeStationIMP,
            _StaffAgentStore,
            _branchId,
            _hasIqr);
        meosFactory = msg.sender;
        
        
        branchId = _branchId;
        
    }
    modifier onlyMeosFactory {
        require(msg.sender == meosFactory,"only MeosFactory can call");
        _;
    }

    modifier onlyActiveContract() {
        require(isActive, "Contract is not active");
        _;
    }


    function initializeMEOSSCS(
        address _agent,
        address _StaffMeosSC_IMP,
        address _NetCafeUserIMP,
        address _NetCafeSessionIMP,
        address _NetCafeTopUpIMP,
        address _NetCafeSpendIMP,
        address _NetCafeManagementIMP,
        address _NetCafeStationIMP,
        address _StaffAgentStore,
        uint _branchId,
        bool _hasIqr
        ) internal {
        address StaffMeosSC_PROXY_ADD;
        if(_hasIqr){
            require(iqrFactory != address(0),"iqrFactory not set yet in initializeMEOSSCS");
            IQRContracts memory iqr = IIQRFactory(iqrFactory).getIQRSCByAgentFromFactory(_agent,_branchId);
            StaffMeosSC_PROXY_ADD = iqr.Management;
        }else{
            require(address(StaffMeosBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
            StaffMeosBeacon = new UpgradeableBeacon(_StaffMeosSC_IMP, address(this));

            BeaconProxy StaffMeosSC_PROXY = new BeaconProxy(
                address(StaffMeosBeacon),
                abi.encodeWithSelector(IStaffMeos.initialize.selector)
            );
            StaffMeosSC_PROXY_ADD = address(StaffMeosSC_PROXY);

        }

        require(address(NetCafeUserBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        NetCafeUserBeacon = new UpgradeableBeacon(_NetCafeUserIMP, address(this));
        BeaconProxy NetCafeUser_PROXY = new BeaconProxy(
            address(NetCafeUserBeacon),
            abi.encodeWithSelector(INetCafeUser.initialize.selector,
            StaffMeosSC_PROXY_ADD)
        );

        require(address(NetCafeSessionBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        NetCafeSessionBeacon = new UpgradeableBeacon(_NetCafeSessionIMP, address(this));
        BeaconProxy NetCafeSession_PROXY = new BeaconProxy(
            address(NetCafeSessionBeacon),
            abi.encodeWithSelector(INetCafeSession.initialize.selector,
            StaffMeosSC_PROXY_ADD,
            address(NetCafeUser_PROXY)
            )
        );

        require(address(NetCafeTopUpBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        NetCafeTopUpBeacon = new UpgradeableBeacon(_NetCafeTopUpIMP, address(this));
        BeaconProxy NetCafeTopUp_PROXY = new BeaconProxy(
            address(NetCafeTopUpBeacon), 
            abi.encodeWithSelector(INetCafeTopUp.initialize.selector, 
            StaffMeosSC_PROXY_ADD,
            address(NetCafeUser_PROXY)
            )
        );

        require(address(NetCafeSpendBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        NetCafeSpendBeacon = new UpgradeableBeacon(_NetCafeSpendIMP, address(this));
        BeaconProxy NetCafeSpend_PROXY = new BeaconProxy(
            address(NetCafeSpendBeacon), 
            abi.encodeWithSelector(INetCafeSpend.initialize.selector, 
            StaffMeosSC_PROXY_ADD,
            address(NetCafeUser_PROXY),
            address(NetCafeSession_PROXY)
            )
        );

        require(address(NetCafeManagementBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        NetCafeManagementBeacon = new UpgradeableBeacon(_NetCafeManagementIMP, address(this));
        BeaconProxy NetCafeManagement_PROXY = new BeaconProxy(
            address(NetCafeManagementBeacon), 
            abi.encodeWithSelector(INetCafeManagement.initialize.selector, 
            StaffMeosSC_PROXY_ADD)
        );

        require(address(NetCafeStationBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        NetCafeStationBeacon = new UpgradeableBeacon(_NetCafeStationIMP, address(this));
        BeaconProxy NetCafeStation_PROXY = new BeaconProxy(
            address(NetCafeStationBeacon), 
            abi.encodeWithSelector(INetCafeStation.initialize.selector, 
            StaffMeosSC_PROXY_ADD,
            address(NetCafeUser_PROXY),
            address(NetCafeSession_PROXY),
            address(NetCafeManagement_PROXY)
            )
        );

        MeosContracts memory meos = MeosContracts({
            StaffMeosSC: StaffMeosSC_PROXY_ADD,
            NetCafeUser: address(NetCafeUser_PROXY),
            NetCafeSession: address(NetCafeSession_PROXY),
            NetCafeTopUp: address(NetCafeTopUp_PROXY),
            NetCafeSpend: address(NetCafeSpend_PROXY),
            NetCafeManagement: address(NetCafeManagement_PROXY),
            NetCafeStation: address(NetCafeStation_PROXY),
            owner:  _agent,
            StaffAgentStore: _StaffAgentStore,
            Points: address(0)
        });
        mAgentToMeos[_agent][_branchId] = meos;
        StaffMeosSC = StaffMeosSC_PROXY_ADD;

    }
    function getMeosSCByAgent(address _agent,uint _branchId) external view returns(MeosContracts memory){
        return mAgentToMeos[_agent][_branchId];
    }
    //tách ra gọi để FE không bị out of gas
    function set(
        address _agent,
        address _StaffMeosSC,
        address _user,
        address _session,
        address _topup,
        address _spend,
    //     address noti,
        address _StaffAgentStore,
        address _branchManagement //proxy
    )external onlyMeosFactory{
        bytes32 ROLE_ADMIN = keccak256("ROLE_ADMIN");
        INetCafeUser(_user).setModule(_topup,true);
        INetCafeUser(_user).setModule(_spend,true);
        INetCafeSession(_session).setModule(_spend,true);
    }
    function setPointSC(address _POINTS_PROXY, address _agent, uint branchId) external onlyMeosFactory{
        MeosContracts storage meos = mAgentToMeos[_agent][branchId];
        meos.Points = _POINTS_PROXY;
        // require(meos.Management != address(0) && meos.Order != address(0),"meos not set yet");
        mAgentToMeos[msg.sender][branchId].Points = _POINTS_PROXY;
        address point = IStaffMeos(meos.StaffMeosSC).getPoints();
        if (point != address(0)){
            IStaffMeos(meos.StaffMeosSC).setPoints(_POINTS_PROXY);
        }
    }
    function transferOwnerMeos(
        address _agent,
        // address _StaffMeosSC,
        address _NetCafeUser,
        address _NetCafeSession,
        address _NetCafeTopUp,
        address _NetCafeSpend,
        address _NetCafeManagement,
        address _NetCafeStation
    )external onlyMeosFactory{
        // IStaffMeos(_StaffMeosSC).transferOwnership(_agent);
        INetCafeUser(_NetCafeUser).transferOwnership(_agent);
        INetCafeSession(_NetCafeSession).transferOwnership(_agent);
        INetCafeTopUp(_NetCafeTopUp).transferOwnership(_agent);
        INetCafeSpend(_NetCafeSpend).transferOwnership(_agent);
        INetCafeManagement(_NetCafeManagement).transferOwnership(_agent);
        INetCafeStation(_NetCafeStation).transferOwnership(_agent);
    }
    // function deactivate() external {
    //     require(msg.sender == enhancedAgent , "Unauthorized");
    //     isActive = false;
    //     IStaffMeos(StaffMeosSC).setActive(false);
    //     emit ContractDeactivated(block.timestamp);
    // }
    
    // function reactivate() external  {
    //     require(msg.sender == enhancedAgent  , "Unauthorized");
    //     isActive = true;
    //     IStaffMeos(StaffMeosSC).setActive(true);
    // }
    function upgradeBeacon(
        address _newImplStaffMeos,
        address _newImplNetCafeUser,
        address _newImplNetCafeSession,
        address _newImplNetCafeTopUp,
        address _newImplNetCafeSpend,
        address _newImplNetCafeManagement,
        address _newImplNetCafeStation
    ) external onlyOwner {
        if(_newImplStaffMeos != address(0)){
            require(address(StaffMeosBeacon) != address(0), "Beacon not created yet");
            address oldImplStaffMeos = StaffMeosBeacon.implementation();
            StaffMeosBeacon.upgradeTo(_newImplStaffMeos);
            emit BeaconUpgraded(address(StaffMeosBeacon), oldImplStaffMeos, _newImplStaffMeos, block.timestamp);
        }

        if(_newImplNetCafeUser != address(0)){
            require(address(NetCafeUserBeacon) != address(0), "Beacon not created yet");
            address oldImplManagement = NetCafeUserBeacon.implementation();
            NetCafeUserBeacon.upgradeTo(_newImplNetCafeUser);
            emit BeaconUpgraded(address(NetCafeUserBeacon), oldImplManagement, _newImplNetCafeUser, block.timestamp);
        }
        if(_newImplNetCafeSession != address(0)){
            require(address(NetCafeSessionBeacon) != address(0), "Beacon not created yet");
            address oldImplOrder = NetCafeSessionBeacon.implementation();
            NetCafeSessionBeacon.upgradeTo(_newImplNetCafeSession);
            emit BeaconUpgraded(address(NetCafeSessionBeacon), oldImplOrder, _newImplNetCafeSession, block.timestamp);
        }
        if(_newImplNetCafeTopUp != address(0)){
            require(address(NetCafeTopUpBeacon) != address(0), "Beacon not created yet");
            address oldImplNetCafeTopUp = NetCafeTopUpBeacon.implementation();
            NetCafeTopUpBeacon.upgradeTo(_newImplNetCafeTopUp);
            emit BeaconUpgraded(address(NetCafeTopUpBeacon), oldImplNetCafeTopUp, _newImplNetCafeTopUp, block.timestamp);
        }
        if(_newImplNetCafeSpend != address(0)){
            require(address(NetCafeSpendBeacon) != address(0), "Beacon not created yet");
            address oldImplNetCafeSpend = NetCafeSpendBeacon.implementation();
            NetCafeSpendBeacon.upgradeTo(_newImplNetCafeSpend);
            emit BeaconUpgraded(address(NetCafeSpendBeacon), oldImplNetCafeSpend, _newImplNetCafeSpend, block.timestamp);
        }
        if(_newImplNetCafeManagement != address(0)){
            require(address(NetCafeManagementBeacon) != address(0), "Beacon not created yet");
            address oldImplNetCafeManagement = NetCafeManagementBeacon.implementation();
            NetCafeManagementBeacon.upgradeTo(_newImplNetCafeManagement);
            emit BeaconUpgraded(address(NetCafeManagementBeacon), oldImplNetCafeManagement, _newImplNetCafeManagement, block.timestamp);
        }
        if(_newImplNetCafeStation != address(0)){
            require(address(NetCafeStationBeacon) != address(0), "Beacon not created yet");
            address oldImplNetCafeStation = NetCafeStationBeacon.implementation();
            NetCafeStationBeacon.upgradeTo(_newImplNetCafeStation);
            emit BeaconUpgraded(address(NetCafeStationBeacon), oldImplNetCafeStation, _newImplNetCafeStation, block.timestamp);
        }

    }
    /**
     * @dev Transfer beacon ownership sang địa chỉ khác nếu cần.
     *      Hiếm khi dùng — chỉ khi muốn trao quyền upgrade beacon cho bên khác.
     */
    function transferBeaconOwnership(address _newOwner) external onlyOwner {
        require(
            address(NetCafeUserBeacon) != address(0) &&
            address(NetCafeSessionBeacon) != address(0) &&
            address(NetCafeTopUpBeacon) != address(0) &&
            address(NetCafeSpendBeacon) != address(0) &&
            address(NetCafeManagementBeacon) != address(0) &&
            address(NetCafeStationBeacon) != address(0),
        "Beacon not created");
        require(_newOwner != address(0), "Invalid address");
        NetCafeUserBeacon.transferOwnership(_newOwner);
        NetCafeSessionBeacon.transferOwnership(_newOwner);
        NetCafeTopUpBeacon.transferOwnership(_newOwner);
        NetCafeSpendBeacon.transferOwnership(_newOwner);
        NetCafeManagementBeacon.transferOwnership(_newOwner);
        NetCafeStationBeacon.transferOwnership(_newOwner);
    }
    /**
     * @dev Lấy địa chỉ implementation hiện tại từ beacon
     */
    function currentImplementation() external view returns (address,address,address,address,address,address,address) {
        require(
            address(StaffMeosBeacon) != address(0) &&
            address(NetCafeUserBeacon) != address(0) && 
            address(NetCafeSessionBeacon) != address(0) &&
            address(NetCafeTopUpBeacon) != address(0) &&
            address(NetCafeSpendBeacon) != address(0) &&
            address(NetCafeManagementBeacon) != address(0) &&
            address(NetCafeStationBeacon) != address(0), 
            "Beacon not created"
        );
        return (
            StaffMeosBeacon.implementation(),
            NetCafeUserBeacon.implementation(),
            NetCafeSessionBeacon.implementation(),
            NetCafeTopUpBeacon.implementation(),
            NetCafeSpendBeacon.implementation(),
            NetCafeManagementBeacon.implementation(),
            NetCafeStationBeacon.implementation()
        );
    }

}
