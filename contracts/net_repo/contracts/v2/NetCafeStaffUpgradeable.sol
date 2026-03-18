// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IStaffManagement} from "./interfaces/IStaffManagement.sol";
import {NET_STAFF_ROLE} from "./Constant.sol";

abstract contract NetCafeStaffUpgradeable is Initializable {
    IStaffManagement public staffContract;

    function __NetCafeStaff_init(
        address _staffContract
    ) internal onlyInitializing {
        require(_staffContract != address(0), "Invalid staff contract");
        staffContract = IStaffManagement(_staffContract);
    }

    modifier onlyFinanceStaff() {
        // require(staffContract.hasFinanceRole(msg.sender), "Not finance staff");
        // require(staffContract.isStaffActive(msg.sender), "Staff inactive");
        require(
            staffContract.checkRole(NET_STAFF_ROLE.FINANCE, msg.sender),
            "Not finace staff"
        );
        _;
    }
    modifier onlyUpdateStatusDish() {
        require(
            staffContract.checkRole(NET_STAFF_ROLE.UPDATE_STATUS_DISH, msg.sender),
            "Not update_satuts_dish"
        );
        _;
    }
    modifier onlyPaymentConfirm() {
        require(
            staffContract.checkRole(NET_STAFF_ROLE.PAYMENT_CONFIRM, msg.sender),
            "Not payment_confirm"
        );
        _;
    }

    modifier onlyTcManage() {
        require(
            staffContract.checkRole(NET_STAFF_ROLE.TC_MANAGE, msg.sender),
            "Not tc_manage"
        );
        _;
    }
    modifier onlyTableManage() {
        require(
            staffContract.checkRole(NET_STAFF_ROLE.TABLE_MANAGE, msg.sender),
            "Not table_manage"
        );
        _;
    }
    modifier onlyMenuManage() {
        require(
            staffContract.checkRole(NET_STAFF_ROLE.MENU_MANAGE, msg.sender),
            "Not menu_manage"
        );
        _;
    }
    modifier onlyStaffManage() {
        require(
            staffContract.checkRole(NET_STAFF_ROLE.STAFF_MANAGE, msg.sender),
            "Not staff_manage"
        );
        _;
    }

    modifier onlyAccountManage() {
        require(
            staffContract.checkRole(NET_STAFF_ROLE.ACCOUNT_MANAGE, msg.sender),
            "Not account_manage"
        );
        _;
    }

    modifier onlyPcManage() {
        require(
            staffContract.checkRole(NET_STAFF_ROLE.PC_MANAGE, msg.sender),
            "Not pc_manage"
        );
        _;
    }
    // function getStaffInfo(
    //     address wallet
    // )
    //     external
    //     view
    //     returns (string memory name, string memory position, uint256 branchId)
    // {
    //     Staff memory staff = staffContract.GetStaffInfo(wallet);
    //     branchId = staffContract.branchId();
    //     return (staff.name, staff.position, branchId);
    // }
    uint256[49] private __gap;
}
