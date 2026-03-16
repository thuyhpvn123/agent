// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IAgent.sol";
import "./interfaces/IPoint.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
// import "forge-std/console.sol";

contract AgentIQR is OwnableUpgradeable {
    UpgradeableBeacon public ManagementBeacon;
    UpgradeableBeacon public OrderBeacon;
    UpgradeableBeacon public ReportBeacon;
    UpgradeableBeacon public TimekeepingBeacon;
    address public agent;
    uint public branchId;
    uint256 public totalOrders;
    uint256 public totalRevenue;
    uint256 public completedOrders;
    bool public isActive = true;  
    mapping( bytes32 => AgentOrder) public orders;
    bytes32[] public orderIds;
    address public ORDER;
    address public MANAGEMENT;
    mapping(address =>mapping(uint => IQRContracts)) public mAgentToIQR;
    address public enhancedAgent;
    address public iqrFactory;
    address public revenueManager;
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
        address _MANAGEMENTIMP,
        address _ORDERIMP,
        address _REPORTIMP,
        address _TIMEKEEPINGIMP,
        address _revenueManager,
        address _StaffAgentStore,
        // address _POINTSIMP,
        uint _branchId
    ) {
        require(_agent != address(0), "Invalid agent address");
        agent = _agent;
        _transferOwnership(_agent);
        enhancedAgent = _enhancedAgent;
        revenueManager = _revenueManager;
        initializeIQRSCS(_agent,_MANAGEMENTIMP,_ORDERIMP,_REPORTIMP,_TIMEKEEPINGIMP,_StaffAgentStore,_branchId);
        // ORDER = _ORDER;
        iqrFactory = msg.sender;
        branchId = _branchId;
        
    }
    modifier onlyIQRFactory {
        require(msg.sender == iqrFactory,"only iqrFactory can call");
        _;
    }

    modifier onlyActiveContract() {
        require(isActive, "Contract is not active");
        _;
    }
    modifier onlyOrder {
        require(msg.sender == ORDER,"only Order contract can call");
        _;
    }

    function upgradeBeacon(
        address _newImplManagement,
        address _newImplOrder,
        address _newImplReport,
        address _newImplTimekeeping
    ) external onlyOwner {
        
        if(_newImplManagement != address(0)){
            require(address(ManagementBeacon) != address(0), "Beacon not created yet");
            address oldImplManagement = ManagementBeacon.implementation();
            ManagementBeacon.upgradeTo(_newImplManagement);
            emit BeaconUpgraded(address(ManagementBeacon), oldImplManagement, _newImplManagement, block.timestamp);
        }
        if(_newImplOrder != address(0)){
            require(address(OrderBeacon) != address(0), "Beacon not created yet");
            address oldImplOrder = OrderBeacon.implementation();
            OrderBeacon.upgradeTo(_newImplOrder);
            emit BeaconUpgraded(address(OrderBeacon), oldImplOrder, _newImplOrder, block.timestamp);
        }
        if(_newImplReport != address(0)){
            require(address(ReportBeacon) != address(0), "Beacon not created yet");
            address oldImplReport = ReportBeacon.implementation();
            ReportBeacon.upgradeTo(_newImplReport);
            emit BeaconUpgraded(address(ReportBeacon), oldImplReport, _newImplReport, block.timestamp);
        }
        if(_newImplTimekeeping != address(0)){
            require(address(TimekeepingBeacon) != address(0), "Beacon not created yet");
            address oldImplTimekeeping = TimekeepingBeacon.implementation();
            TimekeepingBeacon.upgradeTo(_newImplTimekeeping);
            emit BeaconUpgraded(address(TimekeepingBeacon), oldImplTimekeeping, _newImplTimekeeping, block.timestamp);
        }

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
    function initializeIQRSCS(
        address _agent,
        address MANAGEMENT_IMP,
        address ORDER_IMP,
        address REPORT_IMP,
        address TIMEKEEPING_IMP,
        address _StaffAgentStore,
        uint _branchId
        ) internal {
        require(address(ManagementBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        ManagementBeacon = new UpgradeableBeacon(MANAGEMENT_IMP, address(this));

        BeaconProxy MANAGEMENT_PROXY = new BeaconProxy(
            address(ManagementBeacon),
            abi.encodeWithSelector(IMANAGEMENT.initialize.selector)
        );
        require(address(OrderBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        OrderBeacon = new UpgradeableBeacon(ORDER_IMP, address(this));
        BeaconProxy ORDER_PROXY = new BeaconProxy(
            address(OrderBeacon),
            abi.encodeWithSelector(IORDER.initialize.selector)
        );
        require(address(ReportBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        ReportBeacon = new UpgradeableBeacon(REPORT_IMP, address(this));
        BeaconProxy REPORT_PROXY = new BeaconProxy(
            address(ReportBeacon),
            abi.encodeWithSelector(IREPORT.initialize.selector,
            address(MANAGEMENT_PROXY))
        );
        require(address(TimekeepingBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
        TimekeepingBeacon = new UpgradeableBeacon(TIMEKEEPING_IMP, address(this));
        BeaconProxy TIMEKEEPING_PROXY = new BeaconProxy(
            address(TimekeepingBeacon), 
            abi.encodeWithSelector(ITIMEKEEPING.initialize.selector, 
            address(MANAGEMENT_PROXY))
        );
        IQRContracts memory iqr = IQRContracts({
            Management: address(MANAGEMENT_PROXY),
            Order: address(ORDER_PROXY),
            Report: address(REPORT_PROXY),
            TimeKeeping: address(TIMEKEEPING_PROXY),
            owner:  _agent,
            StaffAgentStore: _StaffAgentStore,
            Points: address(0)
        });
        mAgentToIQR[_agent][_branchId] = iqr;
        ORDER = address(ORDER_PROXY);
        MANAGEMENT = address(MANAGEMENT_PROXY);
        // set(_agent,cloneManagement,cloneOrder,cloneReport,cloneTimekeeping,cardVisa,noti);

    }
    function getIQRSCByAgent(address _agent,uint _branchId) external view returns(IQRContracts memory){
        return mAgentToIQR[_agent][_branchId];
    }
    //tách ra gọi để FE không bị out of gas
    function set(
        address _agent,
        address _MANAGEMENT,
        address _ORDER,
        address _REPORT,
        address _TIMEKEEPING,
        address cardVisa,
        address noti,
        address _StaffAgentStore,
        address _branchManagement //proxy
    )external onlyIQRFactory{
        bytes32 ROLE_ADMIN = keccak256("ROLE_ADMIN");
        IORDER(_ORDER).setIQRAgent(address(this),agent,revenueManager);
        IORDER(_ORDER).setConfig(_MANAGEMENT,_agent,cardVisa,10,noti,_REPORT);
        IMANAGEMENT(_MANAGEMENT).setRestaurantOrder(_ORDER);
        IMANAGEMENT(_MANAGEMENT).setReport(_REPORT);
        IMANAGEMENT(_MANAGEMENT).setTimeKeeping(_TIMEKEEPING);
        IMANAGEMENT(_MANAGEMENT).setStaffAgentStore(_StaffAgentStore);
        IMANAGEMENT(_MANAGEMENT).setAgentAdd(_agent,branchId);
        IMANAGEMENT(_MANAGEMENT).grantRole(ROLE_ADMIN,_agent);
        IStaffAgentStore(_StaffAgentStore).setManagement(_MANAGEMENT);
        IMANAGEMENT(_MANAGEMENT).setAgentIqrSC(address(this));
        IMANAGEMENT(_MANAGEMENT).setBranchManagement(_branchManagement);
    }
    function setPointSC(address _POINTS_PROXY, address _agent, uint branchId) external onlyIQRFactory{
        IQRContracts storage iqr = mAgentToIQR[_agent][branchId];
        iqr.Points = _POINTS_PROXY;
        require(iqr.Management != address(0) && iqr.Order != address(0),"iqr not set yet");
        mAgentToIQR[msg.sender][branchId].Points = _POINTS_PROXY;
        IMANAGEMENT(iqr.Management).setPoints(_POINTS_PROXY);
        IORDER(iqr.Order).setPointSC(_POINTS_PROXY);
    }
    function transferOwnerIQR(
        address _agent,
        address _MANAGEMENT,
        address _ORDER,
        address _REPORT,
        address _TIMEKEEPING
    )external onlyIQRFactory{
        IMANAGEMENT(_MANAGEMENT).transferOwnership(_agent);
        IORDER(_ORDER).transferOwnership(_agent);
        IREPORT(_REPORT).transferOwnership(_agent);
        ITIMEKEEPING(_TIMEKEEPING).transferOwnership(_agent);

    }
    function createOrder(
        bytes32 _paymentId,
        // address _customer,
        uint256 _amount
        // string memory _metadata
    ) external onlyOrder onlyActiveContract {
        // require(_customer != address(0), "Invalid customer");
        require(_amount > 0, "Amount must be greater than 0");
        require(orders[_paymentId].paymentId == 0, "Order already exists");
        
        orders[_paymentId] = AgentOrder({
            paymentId: _paymentId,
            // customer: _customer,
            amount: _amount,
            timestamp: block.timestamp
            // completed: false
            // metadata: _metadata
        });
        
        orderIds.push(_paymentId);
        totalOrders++;
        totalRevenue += orders[_paymentId].amount;
        completedOrders++;
        // emit OrderCreated(_paymentId, _customer, _amount, block.timestamp);
    }
    
    // function completeOrder(uint256 _paymentId) external onlyOrder onlyActiveContract {
    //     require(orders[_paymentId].orderId != 0, "Order not found");
    //     require(!orders[_paymentId].completed, "Order already completed");
        
    //     orders[_paymentId].completed = true;
    //     totalRevenue += orders[_paymentId].amount;
    //     completedOrders++;
        
    //     emit OrderCompleted(_paymentId, block.timestamp);
    // }
    
    function deactivate() external {
        require(msg.sender == enhancedAgent , "Unauthorized");
        isActive = false;
        IMANAGEMENT(MANAGEMENT).setActive(false);
        emit ContractDeactivated(block.timestamp);
    }
    
    function reactivate() external  {
        require(msg.sender == enhancedAgent  , "Unauthorized");
        isActive = true;
        IMANAGEMENT(MANAGEMENT).setActive(true);
    }
    
    function getTotalRevenue() external view returns (uint256) {
        return totalRevenue;
    }
    
    function getOrder(bytes32 _paymentId) external view returns (AgentOrder memory) {
        return orders[_paymentId];
    }
    
    function getAllOrderIds() external view returns (bytes32[] memory) {
        return orderIds;
    }
    
    function getStatistics() external view returns (
        uint256 _totalOrders,
        uint256 _completedOrders,
        uint256 _totalRevenue,
        uint256 _averageOrderValue,
        bool _isActive
    ) {
        _totalOrders = totalOrders;
        _completedOrders = completedOrders;
        _totalRevenue = totalRevenue;
        _averageOrderValue = completedOrders > 0 ? totalRevenue / completedOrders : 0;
        _isActive = isActive;
    }
}
