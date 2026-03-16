// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IStaffManagement} from "./interfaces/IStaffManagement.sol";
import {STAFF_ROLE} from "../../../interfaces/IRestaurant.sol";

abstract contract NetCafeStaffUpgradeable is Initializable {
    IStaffManagement public staffContract;

    function __NetCafeStaff_init(address _staffContract) internal onlyInitializing {
        require(_staffContract != address(0), "Invalid staff contract");
        staffContract = IStaffManagement(_staffContract);
    }

    modifier onlyFinanceStaff() {
        // require(staffContract.hasFinanceRole(msg.sender), "Not finance staff");
        // require(staffContract.isStaffActive(msg.sender), "Staff inactive");
        require(staffContract.checkRole(STAFF_ROLE.FINANCE,msg.sender));
        _;
    }

    uint256[49] private __gap;
}

