// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Robot_Role} from "../Constant.sol";
interface IStaffManagementV1 {
    // function hasFinanceRole(address wallet) external view returns (bool);
    // function isStaffActive(address wallet) external view returns (bool);
    function checkRole(
        Robot_Role role,
        address user
    ) external view returns (bool rightRole);
}
