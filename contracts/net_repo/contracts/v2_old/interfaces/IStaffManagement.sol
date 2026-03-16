// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {STAFF_ROLE} from "../../../../interfaces/IRestaurant.sol";
interface IStaffManagement {
    // function hasFinanceRole(address wallet) external view returns (bool);
    // function isStaffActive(address wallet) external view returns (bool);
    function checkRole(STAFF_ROLE role,address user)external view returns(bool rightRole);
}
