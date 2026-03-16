// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IAgent.sol";
// import "forge-std/console.sol";
contract StaffAgentStore is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address =>bool) public isManagement;
    mapping(address =>bool) public isBranchManagement;
    mapping(address => address) public mUserToAgent;
    mapping(address => uint) public mUserToBranchId;
    address public iqrFactory;
    address public enhancedAgent;
    mapping(address =>address[]) public mCoOwnerToAgent;
    mapping(address => mapping(address => uint256[])) public mCoOwnerToAgentToBranchIds;

    uint256[48] private __gap;
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initialize the contract (replaces constructor)
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
    }
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    modifier onlyBranchManger {
        require(isBranchManagement[msg.sender], "Only branchManager can call this function");
        _;
 
    }
    modifier onlyManagement {
        require(isManagement[msg.sender], "Only management can call this function");
        _;
    }

    function setManagement(address _management) external  {
        isManagement[ _management] = true;
    }
    function setBranchManagement(address _branchManger)external {
        isBranchManagement[_branchManger]= true;
    }
    function setEnhancedAgent(address _enhancedAgent) external onlyOwner {
        enhancedAgent = _enhancedAgent;
    }
    function setIqrFactory(address _iqrFactory) external onlyOwner {
        iqrFactory = _iqrFactory;
    }
    function setAgent(address user, address agent, uint branchId) onlyManagement external{
        //kiểm tra agent có tồn tại không
        require((CheckAgentCreated(agent)),"agent not exist");
        mUserToAgent[user] = agent;
        mUserToBranchId[user] = branchId;
    }
    function setAgentForCoOwner(address _coOwner, address agent, uint[] memory branchIds) external onlyBranchManger{
        mCoOwnerToAgent[_coOwner].push(agent);
        mCoOwnerToAgentToBranchIds[_coOwner][agent] = branchIds;
    }
    function getAgentsCoOwner(address _coOwner) external view returns(address[] memory){
        return mCoOwnerToAgent[_coOwner];
    }
    function getBranchIdsCoOwner(address _coOwner, address agent) external view returns(uint[] memory){
        return mCoOwnerToAgentToBranchIds[_coOwner][agent];
    }
    function CheckAgentCreated(address _agent)public view returns(bool){
        return IEnhancedAgent(enhancedAgent).CheckAgentExisted(_agent);
    }
    function checkUserAgentExist(address user) public view returns(bool){
        return (mUserToAgent[user] != address(0));
    }
    function getUserAgetSCs(address user) external view returns(IQRContracts memory iQRContracts){
        require(iqrFactory != address(0),"iqrFactory not set yet");
        address agent = mUserToAgent[user];
        uint branchId = mUserToBranchId[user];
        if (agent != address(0)) {
            address iqrAgentAdd = IIQRFactory(iqrFactory).getAgentIQRContract(agent,branchId);
            iQRContracts = IAgentIQR(iqrAgentAdd).getIQRSCByAgent(agent,branchId);
        }
    }


}