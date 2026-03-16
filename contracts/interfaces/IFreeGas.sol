// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFreeGas {
    function AddSC(
        address _agent,
        address[] memory contractAdds
    ) external;
    function registerSCAdmin(address contractAdd, bool agreed)external;
}