// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
// import "forge-std/console.sol";
import "./interfaces/IFreeGas.sol";
import {BranchManagement} from "./branchManager.sol";

contract BMFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    UpgradeableBeacon public branchManagementBeacon;
    mapping(address => address) public agentBranchManagement;
    address public enhancedAgent;
    address public BRANCH_MANAGEMENT_IMP;
    address public HISTORY_TRACKING_IMP;
    address public freeGasSc;
    address public StaffAgentStore;
    address public iqrFactory;
    address public meosFactory;
    address public robotFactory;
    uint256[47] private __gap;
   event BeaconUpgraded(
        address indexed beacon,
        address oldImpl,
        address newImpl,
        uint256 timestamp
    );
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    modifier onlyEnhanceSC {
        require(msg.sender == enhancedAgent,"only enhancedAgent contract can call-BM Factory");
        _;
    }
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }
    function setBranchManagerSC(
        address _BRANCH_MANAGEMENT_IMP,
        address _HISTORY_TRACKING_IMP,
        // address _freeGasSc,
        address _StaffAgentStore,
        address _iqrFactory,
        address _meosFactory,
        address _robotFactory,
        address _enhancedAgent
    )external onlyOwner {
        if(_BRANCH_MANAGEMENT_IMP != address(0))
        {
            require(address(branchManagementBeacon) == address(0), "Beacon already created, use upgradeBeacon()");
            // BRANCH_MANAGEMENT_IMP = _BRANCH_MANAGEMENT_IMP;
            branchManagementBeacon = new UpgradeableBeacon(_BRANCH_MANAGEMENT_IMP, address(this));
        } 
        if(_HISTORY_TRACKING_IMP != address(0)){HISTORY_TRACKING_IMP = _HISTORY_TRACKING_IMP;} 
        // if(_freeGasSc != address(0)){freeGasSc = _freeGasSc;} 
        if(_iqrFactory != address(0)){iqrFactory = _iqrFactory;}
        if(_StaffAgentStore != address(0)){StaffAgentStore = _StaffAgentStore;}
        if(_meosFactory != address(0)){meosFactory = _meosFactory;}
        if(_robotFactory != address(0)){robotFactory = _robotFactory;}
        // IIQRFactory(iqrFactory).setFreeGasSC(_freeGasSc);
        if(_enhancedAgent != address(0)){enhancedAgent = _enhancedAgent;}
    }


    /**
     * @dev Upgrade toàn bộ loyalty contracts bằng cách update beacon.
     *      Một lần gọi = tất cả BeaconProxy deploy từ factory đều dùng impl mới.
     * @param _newImpl Địa chỉ implementation mới đã deploy
     */
    function upgradeBeacon(address _newImpl) external onlyOwner {
        require(address(branchManagementBeacon) != address(0), "Beacon not created yet");
        require(_newImpl != address(0), "Invalid implementation");

        address oldImpl = branchManagementBeacon.implementation();
        branchManagementBeacon.upgradeTo(_newImpl);

        emit BeaconUpgraded(address(branchManagementBeacon), oldImpl, _newImpl, block.timestamp);
    }
    /**
     * @dev Transfer beacon ownership sang địa chỉ khác nếu cần.
     *      Hiếm khi dùng — chỉ khi muốn trao quyền upgrade beacon cho bên khác.
     */
    function transferBeaconOwnership(address _newOwner) external onlyOwner {
        require(address(branchManagementBeacon) != address(0), "Beacon not created");
        require(_newOwner != address(0), "Invalid address");
        branchManagementBeacon.transferOwnership(_newOwner);
    }
    /**
     * @dev Lấy địa chỉ implementation hiện tại từ beacon
     */
    function currentImplementation() external view returns (address) {
        require(address(branchManagementBeacon) != address(0), "Beacon not created");
        return branchManagementBeacon.implementation();
    }


    // function createBranchManagement(address _agent) external onlyEnhanceSC returns (address) {
    function createBranchManagement(address _agent) external  returns (address) {
        
        require(_agent != address(0), "Invalid agent");
        require(agentBranchManagement[_agent] == address(0), "BranchManagement already exists");
        require(HISTORY_TRACKING_IMP != address(0), "HISTORY_TRACKING not set yet");
        // Deploy BranchManagement contract
        // BranchManagement branchMgmt = new BranchManagement();
        BeaconProxy BRANCH_MANAGEMENT_PROXY = new BeaconProxy(
            address(branchManagementBeacon),
            abi.encodeWithSelector(IBranchManagement.initialize.selector,
            _agent,HISTORY_TRACKING_IMP,freeGasSc)
        );

        address contractAddr = address(BRANCH_MANAGEMENT_PROXY);
        agentBranchManagement[_agent] = contractAddr;
        IBranchManagement(contractAddr).setStaffAgentStore(StaffAgentStore);
        IBranchManagement(contractAddr).setIqrFactorySC(iqrFactory,meosFactory,robotFactory);
        IStaffAgentStore(StaffAgentStore).setBranchManagement(contractAddr);
        address[] memory iqrAdds= new address[](1);
        iqrAdds[0] = address(BRANCH_MANAGEMENT_PROXY);
        if(freeGasSc != address(0)){
            IFreeGas(freeGasSc).AddSC(_agent,iqrAdds);
            IFreeGas(freeGasSc).registerSCAdmin(address(BRANCH_MANAGEMENT_PROXY),true);
        }
        return contractAddr;
    }
    // function addManagerMainBranch(address _branchManagerProxy,address _agent, uint256[] memory branchIds)external onlyEnhanceSC {
    function addManagerMainBranch(address _branchManagerProxy,address _agent, uint256[] memory branchIds)external  {
        IBranchManagement(_branchManagerProxy).AddAndUpdateManager(_agent,"main owner","phone","image",true,branchIds,true,true,true,true);

    }
    function getBranchManagement(address _agent) external view returns (address) {
        return agentBranchManagement[_agent];
    }
}


