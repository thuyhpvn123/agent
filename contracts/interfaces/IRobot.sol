// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IStaffRobot {
    function initialize() external;
    function transferOwnership(address newOwner) external ;
    function deactivate() external;
    function reactivate() external;
    function setPoints(address _points) external;
    function setActive(bool _active) external;
    function setStaffAgentStore(address _staffAgentSC)external;
    function setAgentAdd(address _agent,uint _branchId) external;
    function grantRole(bytes32 role, address account) external;
    function setAgentRobotSC(address _agentRobotSC) external;
    function setBranchManagement(address _branchManagement) external ;
}
interface IRobotRegistryV2 {
    function initialize(address _staffContract) external;
    function transferOwnership(address newOwner) external ;
    function setModule(address module, bool allowed) external;
}
interface IRobotActiveV2 {
    function initialize(address _staffContract, address _robotRegistry) external;
    function transferOwnership(address newOwner) external ;
    function setModule(address module, bool allowed) external;
}
interface IRobotDataUploadTrainingV2 {
    function initialize(address _staffContract, address _robotRegistry) external;
    function transferOwnership(address newOwner) external ;
}
interface IRobotObservationTrainingV2 {
    function initialize(address _staffContract, address _robotRegistry) external;
    function transferOwnership(address newOwner) external ;
}
interface IRobotTestingV2 {
    function initialize(address _staffContract, address _robotRegistry) external;
    function transferOwnership(address newOwner) external ;
}
interface IRobotDashboadV2 {
    function initialize(address _staffContract) external;
    function transferOwnership(address newOwner) external ;
}
interface IRobotLocationV2 {
    function initialize(address _staffContract, address _robotRegistry) external;
    function transferOwnership(address newOwner) external ;
}
interface IRobotQuestionV2 {
    function initialize() external;
    function transferOwnership(address newOwner) external ;
}
