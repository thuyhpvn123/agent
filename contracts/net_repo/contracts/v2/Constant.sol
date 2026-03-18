// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Renamed to avoid conflict with legacy STAFF_ROLE in contracts/interfaces/IRestaurant.sol
enum NET_STAFF_ROLE {
    UPDATE_STATUS_DISH,
    PAYMENT_CONFIRM,
    TC_MANAGE,
    TABLE_MANAGE,
    MENU_MANAGE,
    STAFF_MANAGE,
    FINANCE,
    ACCOUNT_MANAGE,
    PC_MANAGE
}
// struct Staff {
//     address wallet;
//     string name;
//     string code;
//     string phone;
//     string addr;
//     string position;
//     // ROLE role;
//     bool active;
//     string linkImgSelfie;
//     string linkImgPortrait;
//     WorkingShift[] shifts;
//     STAFF_ROLE[] roles;
// }
