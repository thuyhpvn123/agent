// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "./interfaces/IAgent.sol";
import "./interfaces/IPoint.sol";
import "./interfaces/IFreeGas.sol";
// import "forge-std/console.sol";
/**
 * @title LoyaltyFactory
 * @dev Factory tạo loyalty contracts dùng Beacon Proxy pattern.
 *
 * Tại sao Beacon thay vì ERC1967:
 *   - ERC1967: mỗi BeaconProxy tự lưu impl riêng → upgrade phải gọi từng proxy
 *   - Beacon:  tất cả proxies trỏ về 1 UpgradeableBeacon duy nhất
 *              → upgrade 1 lần beacon.upgradeTo(newImpl) = toàn bộ loyalty contracts được nâng cấp
 *
 * Flow:
 *   1. Deploy LoyaltyFactory (UUPS upgradeable)
 *   2. setPointsImp(impl) → factory tạo UpgradeableBeacon với impl này
 *   3. createAgentLoyalty() → deploy BeaconProxy trỏ vào beacon
 *   4. Upgrade tất cả: upgradeBeacon(newImpl) → một lần duy nhất
 */
contract LoyaltyFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    // ============ STATE ============
    /// @dev Beacon duy nhất cho tất cả loyalty proxies
    UpgradeableBeacon public loyaltyBeacon;

    /// agentAddress => BeaconProxy address
    mapping(address => address) public agentLoyaltyContracts;

    address[] public deployedContracts;
    address public enhancedAgent;
    address public freeGasSc;
    address public publicfullDB;

    uint256[50] private __gap;

    // ============ EVENTS ============

    event AgentLoyaltyCreated(
        address indexed agent,
        address indexed contractAddr,
        address beacon,
        uint256 timestamp
    );
    event BeaconUpgraded(
        address indexed beacon,
        address oldImpl,
        address newImpl,
        uint256 timestamp
    );

    // ============ CONSTRUCTOR ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============ INITIALIZER ============

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        // __UUPSUpgradeable_init() removed — deprecated/no-op in OZ v5
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ============ MODIFIERS ============

    modifier onlyEnhanceSC() {
        require(msg.sender == enhancedAgent, "Only enhancedAgent can call");
        _;
    }

    // ============ CONFIGURATION ============
    function setPublicfullDB(address _publicfullDB) external onlyOwner {
        require(_publicfullDB != address(0), "Invalid address");
        publicfullDB = _publicfullDB;
    }
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        require(_enhancedAgent != address(0), "Invalid address");
        enhancedAgent = _enhancedAgent;
    }

    function setFreeGasSc(address _freeGasSc) external onlyOwner {
        freeGasSc = _freeGasSc;
    }

    /**
     * @dev Thiết lập implementation và tạo UpgradeableBeacon.
     *      Chỉ gọi 1 lần. Nếu muốn upgrade impl sau, dùng upgradeBeacon().
     * @param _pointsImp Địa chỉ implementation contract (RestaurantLoyaltySystem hoặc Economy Layer)
     */
    function setPointsImp(address _pointsImp) external onlyOwner {
        require(_pointsImp != address(0), "Invalid implementation");
        require(address(loyaltyBeacon) == address(0), "Beacon already created, use upgradeBeacon()");

        // Factory (address(this)) là owner của beacon → có quyền upgrade sau
        loyaltyBeacon = new UpgradeableBeacon(_pointsImp, address(this));
    }

    /**
     * @dev Upgrade toàn bộ loyalty contracts bằng cách update beacon.
     *      Một lần gọi = tất cả BeaconProxy deploy từ factory đều dùng impl mới.
     * @param _newImpl Địa chỉ implementation mới đã deploy
     */
    function upgradeBeacon(address _newImpl) external onlyOwner {
        require(address(loyaltyBeacon) != address(0), "Beacon not created yet");
        require(_newImpl != address(0), "Invalid implementation");

        address oldImpl = loyaltyBeacon.implementation();
        loyaltyBeacon.upgradeTo(_newImpl);

        emit BeaconUpgraded(address(loyaltyBeacon), oldImpl, _newImpl, block.timestamp);
    }
    /**
     * @dev Transfer beacon ownership sang địa chỉ khác nếu cần.
     *      Hiếm khi dùng — chỉ khi muốn trao quyền upgrade beacon cho bên khác.
     */
    function transferBeaconOwnership(address _newOwner) external onlyOwner {
        require(address(loyaltyBeacon) != address(0), "Beacon not created");
        require(_newOwner != address(0), "Invalid address");
        loyaltyBeacon.transferOwnership(_newOwner);
    }
    /**
     * @dev Lấy địa chỉ implementation hiện tại từ beacon
     */
    function currentImplementation() external view returns (address) {
        require(address(loyaltyBeacon) != address(0), "Beacon not created");
        return loyaltyBeacon.implementation();
    }

    // ============ FACTORY FUNCTIONS ============

    /**
     * @dev Tạo loyalty contract mới cho agent/branch dưới dạng BeaconProxy.
     *      BeaconProxy không lưu impl — nó hỏi beacon mỗi khi cần → tự động nhận upgrade.
     */
    function createAgentLoyalty(address _agent)
        external
        onlyEnhanceSC
        returns (address)
    {
        require(_agent != address(0), "Invalid agent");
        require(agentLoyaltyContracts[_agent] == address(0), "Contract already exists");
        require(address(loyaltyBeacon) != address(0), "Beacon not created, call setPointsImp first");

        // Encode initialize call — sẽ được gọi trong constructor của BeaconProxy
        bytes memory initData = abi.encodeWithSelector(
            IPoint.initialize.selector,
            _agent,
            msg.sender  // enhancedAgent = msg.sender
        );

        // Deploy BeaconProxy trỏ vào loyaltyBeacon
        BeaconProxy proxy = new BeaconProxy(address(loyaltyBeacon), initData);
        address contractAddr = address(proxy);
        // console.log("Created AgentLoyalty BeaconProxy at:", contractAddr);
        // bytes32 ROLE_ADMIN = keccak256("ROLE_ADMIN");
        IPoint(address(proxy)).setSearchIndex(publicfullDB);
        agentLoyaltyContracts[_agent] = contractAddr;
        deployedContracts.push(contractAddr);

        // Register free gas nếu có
        if (freeGasSc != address(0)) {
            address[] memory addrs = new address[](1);
            addrs[0] = contractAddr;
            IFreeGas(freeGasSc).AddSC(_agent, addrs);
        }

        emit AgentLoyaltyCreated(_agent, contractAddr, address(loyaltyBeacon), block.timestamp);

        return contractAddr;
    }

    /**
     * @dev Gắn Management, Order, TopUp vào loyalty contract vừa tạo.
     *      Gọi ngay sau createAgentLoyalty nếu dùng loyalty.
     */
    function setPointsLoyaltyFactory(
        address _agent,
        address _management,
        address _order,
        address _topUp,
        uint _branchId
    ) external onlyEnhanceSC returns (address) {
        address loyaltyProxy = agentLoyaltyContracts[_agent];
        require(loyaltyProxy != address(0), "Loyalty contract not found");

        IPoint(loyaltyProxy).setManagementSC(_management);
        IPoint(loyaltyProxy).setOrder(_order, _branchId);
        IPoint(loyaltyProxy).setTopUp(_topUp, _branchId);

        return loyaltyProxy;
    }

    /**
     * @dev Transfer ownership của loyalty proxy cho agent.
     *      Lưu ý: chỉ ownership của loyalty contract — không phải ownership của beacon.
     */
    function transferOwnerPointSC(address _agent, address _loyaltyProxy)
        external
        onlyEnhanceSC
    {
        require(_loyaltyProxy != address(0), "Invalid proxy address");
        IPoint(_loyaltyProxy).transferOwnership(_agent);
    }

    // ============ VIEW FUNCTIONS ============

    function getAgentLoyaltyContract(address _agent)
        external
        view
        returns (address)
    {
        return agentLoyaltyContracts[_agent];
    }

    function getAllDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }

    function getBeaconAddress() external view returns (address) {
        return address(loyaltyBeacon);
    }


    /**
     * @dev Lấy danh sách contracts theo agent
     */
    function getContractsByAgent(address _agent)
        external
        view
        returns (address)
    {
        return agentLoyaltyContracts[_agent];
    }
}
