// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
import {AgentMeos} from "./agentMeos.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import "forge-std/console.sol";
import "./interfaces/IFreeGas.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract MeosFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    
    mapping(address =>mapping(uint => address)) public agentMeosContracts;
    mapping(address => address) public agentBranchManagement;
    address[] public deployedContracts;
    address public enhancedAgent;
    address public StaffMeosSC; //chỉ là implement, not proxy
    address public NetCafeUserIMP;
    address public NetCafeSessionIMP;
    address public NetCafeTopUpIMP;
    address public NetCafeSpendIMP;
    address public NetCafeManagementIMP;
    address public NetCafeStationIMP;
    address public StaffAgentStore;
    address public POINTS;
    address public freeGasSc;
    address public iqrFactory;
    // === Shared Beacons (thêm vào) ===
    UpgradeableBeacon public StaffMeosBeacon;
    UpgradeableBeacon public NetCafeUserBeacon;
    UpgradeableBeacon public NetCafeSessionBeacon;
    UpgradeableBeacon public NetCafeTopUpBeacon;
    UpgradeableBeacon public NetCafeSpendBeacon;
    UpgradeableBeacon public NetCafeManagementBeacon;
    UpgradeableBeacon public NetCafeStationBeacon;
    mapping(address => bool) public isAdminMeos;
    LastUpdateData public lastUpdateMeos;

    uint256[47] private __gap;
    event AgentMeosCreated(address indexed agent,uint indexed branchId ,address indexed contractAddr, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        isAdminMeos[msg.sender] == true;
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    modifier onlyEnhanceSC {
        require(msg.sender == enhancedAgent,"only enhancedAgent contract can call");
        _;
    }
    modifier onlyAdminMeos() {
        require(isAdminMeos[msg.sender] || msg.sender == owner(), "only adminMeos can call");
        _;
    }
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }
    function setMeos(
        address _StaffMeosSC, //implement ,not proxy
        address _NetCafeUserIMP,
        address _NetCafeSessionIMP,
        address _NetCafeTopUpIMP,
        address _NetCafeSpendIMP,
        address _NetCafeManagementIMP,
        address _NetCafeStationIMP, //proxy dùng cho từng agent
        address _StaffAgentStore, //proxy dùng cho tất cả agent
        address _freeGasSc,
        address _iqrFactory
    )external onlyAdminMeos {
        if(_StaffMeosSC != address(0)){
            // StaffMeosSC = _StaffMeosSC;
            require(address(StaffMeosBeacon) == address(0), "Already initialized Beacon Meos");
            StaffMeosBeacon = new UpgradeableBeacon(_StaffMeosSC, address(this));
        } 
        if(_NetCafeUserIMP != address(0)){
            // NetCafeUserIMP = _NetCafeUserIMP;
            require(address(NetCafeUserBeacon) == address(0), "Already initialized Beacon Meos");
            NetCafeUserBeacon     = new UpgradeableBeacon(_NetCafeUserIMP, address(this));
        } 
        if(_NetCafeSessionIMP != address(0)){
            // NetCafeSessionIMP = _NetCafeSessionIMP;
            require(address(NetCafeSessionBeacon) == address(0), "Already initialized Beacon Meos");
            NetCafeSessionBeacon  = new UpgradeableBeacon(_NetCafeSessionIMP, address(this));
        } 
        if(_NetCafeTopUpIMP != address(0)){
            // NetCafeTopUpIMP = _NetCafeTopUpIMP;
            require(address(NetCafeTopUpBeacon) == address(0), "Already initialized Beacon Meos");
            NetCafeTopUpBeacon    = new UpgradeableBeacon(_NetCafeTopUpIMP, address(this));
        } 
        if(_NetCafeSpendIMP != address(0)){
            // NetCafeSpendIMP = _NetCafeSpendIMP;
            require(address(NetCafeSpendBeacon) == address(0), "Already initialized Beacon Meos");
            NetCafeSpendBeacon    = new UpgradeableBeacon(_NetCafeSpendIMP, address(this));
        } 
        if(_NetCafeManagementIMP != address(0)){
            // NetCafeManagementIMP = _NetCafeManagementIMP;
            require(address(NetCafeManagementBeacon) == address(0), "Already initialized Beacon Meos");
            NetCafeManagementBeacon = new UpgradeableBeacon(_NetCafeManagementIMP, address(this));
        } 
        if(_NetCafeStationIMP != address(0)){
            // NetCafeStationIMP = _NetCafeStationIMP;
            require(address(NetCafeStationBeacon) == address(0), "Already initialized Beacon Meos");
            NetCafeStationBeacon  = new UpgradeableBeacon(_NetCafeStationIMP, address(this));
        } 
        if(_freeGasSc != address(0)){freeGasSc = _freeGasSc;} 
        if(_StaffAgentStore != address(0)){StaffAgentStore = _StaffAgentStore;}  
        if(_iqrFactory != address(0)){iqrFactory = _iqrFactory;}
    }
    //     function initBeacons(
    //     address _StaffMeosSC,
    //     address _NetCafeUserIMP,
    //     address _NetCafeSessionIMP,
    //     address _NetCafeTopUpIMP,
    //     address _NetCafeSpendIMP,
    //     address _NetCafeManagementIMP,
    //     address _NetCafeStationIMP
    // ) internal {
    //     require(address(NetCafeUserBeacon) == address(0), "Already initialized Beacon Meos");
        
    //     StaffMeosBeacon       = new UpgradeableBeacon(_StaffMeosSC, address(this));
    //     NetCafeUserBeacon     = new UpgradeableBeacon(_NetCafeUserIMP, address(this));
    //     NetCafeSessionBeacon  = new UpgradeableBeacon(_NetCafeSessionIMP, address(this));
    //     NetCafeTopUpBeacon    = new UpgradeableBeacon(_NetCafeTopUpIMP, address(this));
    //     NetCafeSpendBeacon    = new UpgradeableBeacon(_NetCafeSpendIMP, address(this));
    //     NetCafeManagementBeacon = new UpgradeableBeacon(_NetCafeManagementIMP, address(this));
    //     NetCafeStationBeacon  = new UpgradeableBeacon(_NetCafeStationIMP, address(this));
    // }

    function createAgentMeos(address _agent, uint _branchId, bool _hasIqr) external onlyEnhanceSC returns (address) {
        require(
            address(StaffMeosBeacon) != address(0) && 
            address(NetCafeUserBeacon) != address(0) && 
            address(NetCafeSessionBeacon) != address(0) && 
            address(NetCafeTopUpBeacon) != address(0)&& 
            address(NetCafeSpendBeacon) != address(0) &&
            address(NetCafeManagementBeacon) != address(0) &&
            address(NetCafeStationBeacon) != address(0) ,
            "addresses of meos can be address(0)"
        );
        require(_agent != address(0), "Invalid agent");
        require(agentMeosContracts[_agent][_branchId] == address(0), "Contract already exists");
        
        AgentMeos newContract = new AgentMeos(
            _agent,
            enhancedAgent,
            address(StaffMeosBeacon),     // truyền beacon address
            address(NetCafeUserBeacon),
            address(NetCafeSessionBeacon),
            address(NetCafeTopUpBeacon),
            address(NetCafeSpendBeacon),
            address(NetCafeManagementBeacon),
            address(NetCafeStationBeacon),
            StaffAgentStore,
            iqrFactory,
            _branchId,
            _hasIqr
        );
        MeosContracts memory meos = newContract.getMeosSCByAgent(_agent,_branchId);
        address[] memory meosAdds= new address[](7);
        meosAdds[0] = meos.StaffMeosSC;
        meosAdds[1] = meos.NetCafeUser;
        meosAdds[2] = meos.NetCafeSession;
        meosAdds[3] = meos.NetCafeTopUp;
        meosAdds[4] = meos.NetCafeSpend;
        meosAdds[5] = meos.NetCafeManagement;
        meosAdds[6] = meos.NetCafeStation;
        if(freeGasSc != address(0)){
            IFreeGas(freeGasSc).AddSC(_agent,meosAdds);
        }
        address contractAddr = address(newContract);
        
        agentMeosContracts[_agent][_branchId] = contractAddr;
        deployedContracts.push(contractAddr);
        
        emit AgentMeosCreated(_agent,_branchId, contractAddr, block.timestamp);
        return contractAddr;
    }
    //admin gọi ngay sau gọi createAgent neu chon meos
    function setAgentMeos( address _agent, uint _branchId, address _branchManagement)external onlyEnhanceSC{
        require(_agent != address(0), "Invalid agent");
        require(agentMeosContracts[_agent][_branchId] != address(0), "Contract does not exist");
        AgentMeos agentMeos = AgentMeos(agentMeosContracts[_agent][_branchId]);
        MeosContracts memory meosScs = agentMeos.getMeosSCByAgent(_agent,_branchId);
        agentMeos.set(_agent,meosScs.StaffMeosSC,meosScs.NetCafeUser,meosScs.NetCafeSession,meosScs.NetCafeTopUp,meosScs.NetCafeSpend,meosScs.StaffAgentStore,_branchManagement);
    }
    //admin gọi ngay sau gọi createAgent nếu có dùng loyalty
    function setPointsMeosFactory(address _agent, address _Points, uint _branchId) external onlyEnhanceSC {
        require(_Points != address(0),"Points contract not set yet");
        AgentMeos agentMeos = AgentMeos(agentMeosContracts[_agent][_branchId]);
        agentMeos.setPointSC(_Points,_agent,_branchId);

        POINTS = _Points;
    }
    function transferOwnerMeosContracts(address _agent, uint _branchId)external onlyEnhanceSC {
        address agentMeos = agentMeosContracts[_agent][_branchId];
        MeosContracts memory meos = IAgentMeos(agentMeos).getMeosSCByAgent(_agent,_branchId);
        IAgentMeos(agentMeos).transferOwnerMeos(
            _agent,
            meos.StaffMeosSC,
            meos.NetCafeUser,
            meos.NetCafeSession,
            meos.NetCafeTopUp,
            meos.NetCafeSpend,
            meos.NetCafeManagement,
            meos.NetCafeStation
        );
    }
    function getAgentMEOSContract(address _agent, uint _branchId) external view returns (address) {
        return agentMeosContracts[_agent][_branchId];
    }
    function getMeosSCByAgentFromFactory(address _agent, uint _branchId) external view returns (MeosContracts memory) {
        address agentMeos = agentMeosContracts[_agent][_branchId];
        MeosContracts memory meosContracts = IAgentMeos(agentMeos).getMeosSCByAgent(_agent,_branchId);
        return meosContracts;
    }
    function getManagementSCByAgentsFromFactory(address _agent, uint[] memory _branchIds) external view returns (address[] memory managementScs, uint count) {
        managementScs = new address[](_branchIds.length);
        for(uint i=0; i< _branchIds.length;i++){
            address agentMeos = agentMeosContracts[_agent][_branchIds[i]];
            MeosContracts memory meosContracts = IAgentMeos(agentMeos).getMeosSCByAgent(_agent,_branchIds[i]);
            managementScs[i] = meosContracts.StaffMeosSC;
            if(meosContracts.StaffMeosSC != address(0)){
                count++;
            }
        }
    }
    function getAllDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }

    function setAdminMeos(address admin, bool isAdmin) external onlyOwner {
        require(admin != address(0), "Invalid address");
        isAdminMeos[admin] = isAdmin;
    }    

    // Hàm khởi tạo beacons (gọi 1 lần sau deploy)

    // Upgrade global: 1 lần → tất cả agent được upgrade
    function upgradeBeaconGlobal(
        address _newImplStaffMeos,
        address _newImplNetCafeUser,
        address _newImplNetCafeSession,
        address _newImplNetCafeTopUp,
        address _newImplNetCafeSpend,
        address _newImplNetCafeManagement,
        address _newImplNetCafeStation
    ) external onlyAdminMeos {
        if (_newImplStaffMeos != address(0))       StaffMeosBeacon.upgradeTo(_newImplStaffMeos);
        if (_newImplNetCafeUser != address(0))     NetCafeUserBeacon.upgradeTo(_newImplNetCafeUser);
        if (_newImplNetCafeSession != address(0))  NetCafeSessionBeacon.upgradeTo(_newImplNetCafeSession);
        if (_newImplNetCafeTopUp != address(0))    NetCafeTopUpBeacon.upgradeTo(_newImplNetCafeTopUp);
        if (_newImplNetCafeSpend != address(0))    NetCafeSpendBeacon.upgradeTo(_newImplNetCafeSpend);
        if (_newImplNetCafeManagement != address(0)) NetCafeManagementBeacon.upgradeTo(_newImplNetCafeManagement);
        if (_newImplNetCafeStation != address(0))  NetCafeStationBeacon.upgradeTo(_newImplNetCafeStation);
        lastUpdateMeos = LastUpdateData({
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


