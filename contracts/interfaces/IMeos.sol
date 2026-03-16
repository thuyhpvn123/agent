// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
interface IStaffMeos {
    function initialize() external;
    function transferOwnership(address newOwner) external ;
    function deactivate() external;
    function reactivate() external;
    function setPoints(address _points) external;
    function setActive(bool _active) external;
    function setStaffAgentStore(address _staffAgentSC)external;
    function setAgentAdd(address _agent,uint _branchId) external;
    function grantRole(bytes32 role, address account) external;
    function setAgentMeosSC(address _agentMeosSC) external;
    function setBranchManagement(address _branchManagement) external ;
    function getPoints() external view returns(address);

}
interface INetCafeUser {
    function initialize(address _staffContract) external;
    function transferOwnership(address newOwner) external ;
    function setModule(address module, bool allowed) external;
}
interface INetCafeSession {
    function initialize(
        address _staffContract,
        address _userContract
    ) external;
    function transferOwnership(address newOwner) external ;
    function setModule(address module, bool allowed) external;
}
interface INetCafeTopUp {
    function initialize(address _staffContract, address _userContract) external;
    function transferOwnership(address newOwner) external ;
    function isValidAmount(bytes32 paymentId,uint amount) view external returns(bool);
}
interface INetCafeSpend {
    function initialize(
        address _staffContract,
        address _userContract,
        address _sessionContract
    ) external;
    function transferOwnership(address newOwner) external ;
}
interface INetCafeManagement {
    function initialize(address _staffContract) external;
    function transferOwnership(address newOwner) external ;
}

interface INetCafeStation {
    function initialize(
        address _staffContract,
        address _userContract,
        address _sessionContract,
        address _managementContract
    ) external;
    function transferOwnership(address newOwner) external ;
}
