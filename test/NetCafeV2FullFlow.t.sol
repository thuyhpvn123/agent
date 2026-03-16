// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/net_repo/contracts/v2/NetCafeUserV2.sol";
import "../contracts/net_repo/contracts/v2/NetCafeSessionV2.sol";
import "../contracts/net_repo/contracts/v2/NetCafeManagementV2.sol";
import "../contracts/net_repo/contracts/v2/NetCafeStationV2.sol";
import "../contracts/net_repo/contracts/v2/NetCafeTopUpV2.sol";
import "../contracts/net_repo/contracts/v2/NetCafeSpendV2.sol";
import "../contracts/net_repo/contracts/v2/interfaces/IStaffManagement.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../contracts/interfaces/IMeos.sol";
import  "../contracts/ManagementDemo.sol";


contract NetCafeV2FullFlowTest is Test {
    Management public StaffMeosSC;
    Management public StaffMeosSC_IMP;
    NetCafeUserV2 public user;
    NetCafeUserV2 public user_IMP;
    NetCafeSessionV2 public session;
    NetCafeSessionV2 public session_IMP;
    NetCafeManagementV2 public managementMeos;
    NetCafeManagementV2 public management_IMP;
    NetCafeStationV2 public station;
    NetCafeStationV2 public station_IMP;
    NetCafeTopUpV2 public topup;
    NetCafeTopUpV2 public topup_IMP;
    NetCafeSpendV2 public spend;
    NetCafeSpendV2 public spend_IMP;

    // address finance;
    address userWallet;
    address sessionWallet;
    address public DeployerMeos ;
    bytes32 constant POLICY_ID = keccak256("POLICY_BASIC");
    bytes32 constant GROUP_ID = keccak256("GROUP_BASIC");
    bytes32 constant PC_ID = keccak256("PC_01");
    bytes32 constant SESSION_KEY = keccak256("SESSION_KEY");
    address staff4 = address(0x234);
    address staff5 = address(0x897);
    address staff6 = address(0x456);

    constructor() {
        vm.warp(1759724234);
        DeployerMeos = makeAddr("DeployerMeos");
        vm.startPrank(DeployerMeos);
        // Cac dia chi tham gia test
        // finance = makeAddr("finance");
        userWallet = makeAddr("user");
        sessionWallet = makeAddr("session");

        StaffMeosSC_IMP = new Management();
        // ERC1967Proxy StaffMeosSC_PROXY = new ERC1967Proxy(
        //     address(StaffMeosSC_IMP),
        //     abi.encodeWithSelector(IStaffMeos.initialize.selector)
        // );
        StaffMeosSC = Management(address(StaffMeosSC_IMP));
        StaffMeosSC.initialize();
        StaffMeosSC.setStaffAgentStore(address(0x123));

        user_IMP = new NetCafeUserV2();
        // ERC1967Proxy NetCafeUser_PROXY = new ERC1967Proxy(
        //     address(user_IMP),
        //     abi.encodeWithSelector(INetCafeUser.initialize.selector,
        //     address(StaffMeosSC_PROXY))
        // );
        user_IMP.initialize(address(StaffMeosSC_IMP));
        user = NetCafeUserV2(address(user_IMP));

        session_IMP = new NetCafeSessionV2();
        session_IMP.initialize(address(StaffMeosSC_IMP), address(user_IMP));
        // ERC1967Proxy NetCafeSession_PROXY = new ERC1967Proxy(
        //     address(session_IMP),
        //     abi.encodeWithSelector(INetCafeSession.initialize.selector,
        //     address(StaffMeosSC_PROXY),
        //     address(NetCafeUser_PROXY)
        //     )
        // );
        session = NetCafeSessionV2(address(session_IMP));

        topup_IMP = new NetCafeTopUpV2();
        topup_IMP.initialize(address(StaffMeosSC_IMP), address(user_IMP));
        // ERC1967Proxy NetCafeTopUp_PROXY = new ERC1967Proxy(
        //     address(topup_IMP), 
        //     abi.encodeWithSelector(INetCafeTopUp.initialize.selector, 
        //     address(session_IMP),
        //     address(user_IMP)
        //     )
        // );
        topup = NetCafeTopUpV2(address(topup_IMP));

        spend_IMP = new NetCafeSpendV2();
        spend_IMP.initialize(address(StaffMeosSC_IMP), address(user_IMP), address(session_IMP));
        // ERC1967Proxy NetCafeSpend_PROXY = new ERC1967Proxy(
        //     address(spend_IMP), 
        //     abi.encodeWithSelector(INetCafeSpend.initialize.selector, 
        //     address(StaffMeosSC_PROXY),
        //     address(NetCafeUser_PROXY),
        //     address(NetCafeSession_PROXY)
        //     )
        // );
        spend = NetCafeSpendV2(address(spend_IMP));

        management_IMP = new NetCafeManagementV2();
        management_IMP.initialize(address(StaffMeosSC_IMP));
        // ERC1967Proxy NetCafeManagement_PROXY = new ERC1967Proxy(
        //     address(management_IMP), 
        //     abi.encodeWithSelector(INetCafeManagement.initialize.selector, 
        //     address(StaffMeosSC_PROXY))
        // );
        managementMeos = NetCafeManagementV2(address(management_IMP));

        station_IMP = new NetCafeStationV2();
        station_IMP.initialize(address(StaffMeosSC_IMP), address(user_IMP), address(session_IMP), address(management_IMP));
        // ERC1967Proxy NetCafeStation_PROXY = new ERC1967Proxy(
        //     address(station_IMP), 
        //     abi.encodeWithSelector(INetCafeStation.initialize.selector, 
        //     address(StaffMeosSC_PROXY),
        //     address(NetCafeUser_PROXY),
        //     address(NetCafeSession_PROXY),
        //     address(NetCafeManagement_PROXY)
        //     )
        // );
        station = NetCafeStationV2(address(station_IMP));

        // Cap quyen module de tang giam so du va dong session
        user.setModule(address(topup), true);
        user.setModule(address(spend), true);
        session.setModule(address(spend), true);
        vm.stopPrank();

        SetUpStaffMeos();

    }
    function SetUpStaffMeos()public{
        bytes32 ROLE_ADMIN = keccak256("ROLE_ADMIN");
        bytes32 ROLE_STAFF = keccak256("ROLE_STAFF");

        vm.warp(1759724234);//11h17 -7/10/2025
        // vm.startPrank(DeployerMeos);
        // bytes32 role = StaffMeosSC.DEFAULT_ADMIN_ROLE();
        // StaffMeosSC.grantRole(role,admin);
        vm.startPrank(DeployerMeos);
        // StaffMeosSC.grantRole(ROLE_ADMIN,admin);
        //CreatePosition
        STAFF_ROLE[] memory staff4Roles = new STAFF_ROLE[](1);
        staff4Roles[0] = STAFF_ROLE.FINANCE;

        StaffMeosSC.CreatePosition("nv trong tiem net",staff4Roles);
        //CreateWorkingShift
        StaffMeosSC.CreateWorkingShift("ca sang",28800,43200); ////số giây tính từ 0h ngày hôm đó. vd 08:00 là 8*3600=28800
        StaffMeosSC.CreateWorkingShift("ca chieu",46800,61200); //tu 13:00 den 17:00

        WorkingShift[] memory shifts = StaffMeosSC.getWorkingShifts();
        assertEq(shifts[0].title,"ca sang","working shift title should equal");
        WorkingShift[] memory staff4Shifts = new WorkingShift[](2);
        staff4Shifts[0] = shifts[0];
        staff4Shifts[1] = shifts[1];

        Staff memory staff = Staff({
            wallet: staff4,
            name:"thuy",
            code:"NV1",
            phone:"0913088965",
            addr:"phu nhuan",
            position: "nv trong tiem net",
            role:ROLE.STAFF,
            active: true,
            linkImgSelfie: "linkImgSelfie",
            linkImgPortrait:"linkImgPortrait",
            shifts:staff4Shifts,
            roles: staff4Roles

        });
        StaffMeosSC.CreateStaff(staff);

        staff = Staff({
            wallet: staff5,
            name:"han",
            code:"NV2",
            phone:"0914526387",
            addr:"quan 7",
            position: "nv trong tiem net",
            role:ROLE.STAFF,
            active: true,
            linkImgSelfie: "linkImgSelfie",
            linkImgPortrait:"linkImgPortrait",
            shifts:staff4Shifts,
            roles: staff4Roles
        });
        StaffMeosSC.CreateStaff(staff);

        (Staff[] memory staffs,uint totalCount) = StaffMeosSC.GetStaffsPagination(0,100);

        assertEq(staffs.length,2,"should be equal");
        Staff memory staffInfo = StaffMeosSC.GetStaffInfo(staff4);
        assertEq(staffInfo.name,"thuy","should be equal");
        assertEq(staffInfo.phone,"0913088965","should be equal");
        StaffMeosSC.grantRole(ROLE_STAFF,staff4);
        StaffMeosSC.UpdateStaffInfo(staff4,"thanh thuy","NV1","1111111111","phu nhuan",staff4Roles,staff4Shifts,"linkImgSelfie","linkImgPortrait","nv trong tiem net",true);
        staffInfo = StaffMeosSC.GetStaffInfo(staff4);
        assertEq(staffInfo.name,"thanh thuy","should be equal");
        assertEq(staffInfo.phone,"1111111111","should be equal");
        bool kq = StaffMeosSC.isStaff(staff4);
        assertEq(kq,true,"should be equal"); 
        (staffs,totalCount) = StaffMeosSC.GetStaffsPagination(0,100);
        assertEq(staffs[0].name,"han","should be equal");
        assertEq(staffs[0].phone,"0914526387","should be equal");

        StaffMeosSC.grantRole(ROLE_ADMIN,staff5);
        
        vm.stopPrank();
        vm.prank(staff5);
        staff = Staff({
            wallet: staff6,
            name:"han",
            code:"NV3",
            phone:"11111111",
            addr:"quan 7",
            position: "nv trong tiem net",
            role:ROLE.STAFF,
            active: true,
            linkImgSelfie: "linkImgSelfie",
            linkImgPortrait:"linkImgPortrait",
            shifts:staff4Shifts,
            roles: staff4Roles
        });
        StaffMeosSC.CreateStaff(staff);
        StaffMeosSC.GetStaffsPagination(0,10);
        vm.prank(staff5);
        StaffMeosSC.removeStaff(staff6);
        
    }

    function test_FullFlowV2_Net() public {
        // Finance cau hinh: gia, may, group va dang ky user
        vm.startPrank(staff4);
        managementMeos.addPricePolicy(POLICY_ID, 10, "Basic");
        managementMeos.addStation(
            PC_ID,
            "PC 01",
            bytes32(0),
            "10.0.0.1",
            "AA:BB:CC:DD:EE:01",
            "cfg1"
        );
        console.logBytes32(POLICY_ID);
        console.logBytes32(GROUP_ID);
        console.logBytes32(PC_ID);
        console.logBytes32(SESSION_KEY);

        bytes32[] memory pcs = new bytes32[](1);
        pcs[0] = PC_ID;

        managementMeos.addGroup(GROUP_ID, "Group A", POLICY_ID, pcs, "Basic group");
        for (uint256 i = 0; i < pcs.length; i++) {
            console.log("pcs[", i, "]");
            console.logBytes32(pcs[i]);
        }

        user.registerUser(
            userWallet,
            "Alice",
            "CCCD-01",
            "0900000000",
            "alice@example.com",
            1000
        );
        vm.stopPrank();
        console.log();

        // User mo session va login
        vm.prank(userWallet);
        vm.warp(1759724234);
        session.openSession(
            sessionWallet,
            SESSION_KEY,
            PC_ID,
            uint64(1759724234 + 1 hours)
        );
        console.log(uint64(1759724234 + 1 hours));

        vm.prank(userWallet);
        user.loginUser(userWallet, "PC 01");
        // User gui yeu cau nap
        vm.prank(userWallet);
        topup.requestTopUp(userWallet, 200, NetCafeTopUpV2.PaymentMethod.CASH);

        // Finance duyet nap
        vm.prank(staff4);
        topup.approveTopUp(1);

        // So du tang len
        (, , , uint256 balanceAfterTopup) = user.getUserStatus(userWallet);
        assertEq(balanceAfterTopup, 1200);

        // Station lay trang thai tu session + user
        vm.prank(sessionWallet);
        station.setStatus(sessionWallet, PC_ID);

        // Gia lap 2 phut choi
        vm.warp(1759724234 + 2 minutes);

        // Finance tinh tien choi theo session key
        uint256 price = managementMeos.getStationPrice(PC_ID);
        console.log("price:", price);
        vm.prank(staff4);
        spend.chargePlayTime(sessionWallet, SESSION_KEY, PC_ID, price);

        // Session dong, user bi logout
        assertFalse(session.isSessionActive(sessionWallet));
        (, bool online, , uint256 balanceAfterSpend) = user.getUserStatus(
            userWallet
        );
        assertFalse(online);
        assertEq(balanceAfterSpend, 1180);

        // Lich su chi tieu duoc ghi lai
        (
            uint256 id,
            address historyUser,
            uint256 amountVND,
            NetCafeSpendV2.SpendType spendType,
            uint256 fromTime,
            uint256 toTime,
            uint256 createdAt
        ) = spend.spendHistories(1);
        assertEq(id, 1);
        assertEq(historyUser, userWallet);
        assertEq(amountVND, 20);
        assertEq(uint8(spendType), uint8(NetCafeSpendV2.SpendType.PLAY_TIME));
        assertGt(toTime, fromTime);
        assertGt(createdAt, 0);
    }
}
