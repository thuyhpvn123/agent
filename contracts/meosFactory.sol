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
    uint256[49] private __gap;
    event AgentMeosCreated(address indexed agent,uint indexed branchId ,address indexed contractAddr, uint256 timestamp);

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
    )external onlyOwner {
        if(_StaffMeosSC != address(0)){StaffMeosSC = _StaffMeosSC;} 
        if(_NetCafeUserIMP != address(0)){NetCafeUserIMP = _NetCafeUserIMP;} 
        if(_NetCafeSessionIMP != address(0)){NetCafeSessionIMP = _NetCafeSessionIMP;} 
        if(_NetCafeTopUpIMP != address(0)){NetCafeTopUpIMP = _NetCafeTopUpIMP;} 
        if(_NetCafeSpendIMP != address(0)){NetCafeSpendIMP = _NetCafeSpendIMP;} 
        if(_NetCafeManagementIMP != address(0)){NetCafeManagementIMP = _NetCafeManagementIMP;} 
        if(_NetCafeStationIMP != address(0)){NetCafeStationIMP = _NetCafeStationIMP;} 
        if(_freeGasSc != address(0)){freeGasSc = _freeGasSc;} 
        if(_StaffAgentStore != address(0)){StaffAgentStore = _StaffAgentStore;}  
        if(_iqrFactory != address(0)){iqrFactory = _iqrFactory;}
    }
    function createAgentMeos(address _agent, uint _branchId, bool _hasIqr) external onlyEnhanceSC returns (address) {
        require(
            StaffMeosSC != address(0) && 
            NetCafeUserIMP != address(0) && 
            NetCafeSessionIMP != address(0) && 
            NetCafeTopUpIMP != address(0)&& 
            NetCafeSpendIMP != address(0) &&
            NetCafeManagementIMP != address(0) &&
            NetCafeStationIMP != address(0) ,
            "addresses of meos can be address(0)"
        );
        require(_agent != address(0), "Invalid agent");
        require(agentMeosContracts[_agent][_branchId] == address(0), "Contract already exists");
        
        AgentMeos newContract = new AgentMeos(_agent,enhancedAgent,StaffMeosSC,NetCafeUserIMP,NetCafeSessionIMP,NetCafeTopUpIMP,NetCafeSpendIMP,NetCafeManagementIMP,NetCafeStationIMP,StaffAgentStore,iqrFactory,_branchId,_hasIqr);
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
    
}


