// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IStaffManagement} from "./interfaces/IStaffManagement.sol";
import {STAFF_ROLE,Staff} from "../../../interfaces/IRestaurant.sol";

abstract contract NetCafeStaffUpgradeable is Initializable {
    IStaffManagement public staffContract;

    function __NetCafeStaff_init(address _staffContract) internal onlyInitializing {
        require(_staffContract != address(0), "Invalid staff contract");
        staffContract = IStaffManagement(_staffContract);
    }

    modifier onlyFinanceStaff() {
        require(staffContract.checkRole(STAFF_ROLE.FINANCE,msg.sender));
        _;
    }
    modifier onlyAccountManageStaff() {
        require(staffContract.checkRole(STAFF_ROLE.ACCOUNT_MANAGE,msg.sender));
        _;
    }
    modifier onlyPcManageStaff() {
        require(staffContract.checkRole(STAFF_ROLE.PC_MANAGE,msg.sender));
        _;
    }
    function getStaffInfo(address wallet) external view returns (string memory name,string memory position,uint256 branchId) {
        Staff memory staff = staffContract.GetStaffInfo(wallet);
        branchId = staffContract.branchId();
        return (staff.name, staff.position, branchId);
    }
    uint256[49] private __gap;
}

