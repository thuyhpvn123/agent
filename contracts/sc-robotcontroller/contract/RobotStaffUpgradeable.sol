// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IStaffManagementV1} from "./interfaces/IStaffManagementV1.sol";
import {Robot_Role} from "./Constant.sol";

abstract contract RobotStaffUpgradeable is Initializable {
    IStaffManagementV1 public staffContract;

    function __RobotStaffUpgradeable_init(
        address _staffContract
    ) internal onlyInitializing {
        require(_staffContract != address(0), "Invalid staff contract");
        staffContract = IStaffManagementV1(_staffContract);
    }

    string constant message = "Not permission";
    modifier onlySuperAdmin() {
        // require(staffContract.hasFinanceRole(msg.sender), "Not finance staff");
        // require(staffContract.isStaffActive(msg.sender), "Staff inactive");
        require(
            staffContract.checkRole(
                Robot_Role.PLATFORM_SUPER_ADMIN,
                msg.sender
            ),
            message
        );
        _;
    }
    modifier onlyMerchantOwner() {
        require(
            staffContract.checkRole(Robot_Role.MERCHANT_OWNER, msg.sender) ||
                staffContract.checkRole(
                    Robot_Role.PLATFORM_SUPER_ADMIN,
                    msg.sender
                ),
            message
        );
        _;
    }

    modifier onlyManager() {
        require(
            staffContract.checkRole(Robot_Role.BRAND_MANAGER, msg.sender) ||
                staffContract.checkRole(
                    Robot_Role.PLATFORM_SUPER_ADMIN,
                    msg.sender
                ),
            message
        );
        _;
    }
    modifier onlyStaff() {
        require(
            staffContract.checkRole(Robot_Role.BRANCH_STAFF, msg.sender) ||
                staffContract.checkRole(
                    Robot_Role.PLATFORM_SUPER_ADMIN,
                    msg.sender
                ),
            message
        );
        _;
    }
    modifier onlyTrainer() {
        require(
            staffContract.checkRole(Robot_Role.ROBOT_TRAINER, msg.sender) ||
                staffContract.checkRole(
                    Robot_Role.PLATFORM_SUPER_ADMIN,
                    msg.sender
                ),
            message
        );
        _;
    }
    modifier onlyController() {
        require(
            staffContract.checkRole(Robot_Role.ROBOT_CONTROLLER, msg.sender) ||
                staffContract.checkRole(
                    Robot_Role.PLATFORM_SUPER_ADMIN,
                    msg.sender
                ),
            message
        );
        _;
    }
    modifier onlySupporter() {
        require(
            staffContract.checkRole(Robot_Role.ROBOT_SUPPORTER, msg.sender) ||
                staffContract.checkRole(
                    Robot_Role.PLATFORM_SUPER_ADMIN,
                    msg.sender
                ),
            message
        );
        _;
    }
    uint256[49] private __gap;
}
