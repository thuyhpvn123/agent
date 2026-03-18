pragma solidity ^0.8.20;
import {NET_STAFF_ROLE} from "../Constant.sol";
interface IStaffManagement {
    // function hasFinanceRole(address wallet) external view returns (bool);
    // function isStaffActive(address wallet) external view returns (bool);
    function checkRole(
        NET_STAFF_ROLE role,
        address user
    ) external view returns (bool rightRole);
}
