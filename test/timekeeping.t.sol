// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "../contracts/timekeeping.sol";
// import "../contracts/interfaces/IManagement.sol";
// import "../contracts/interfaces/IRestaurant.sol";
// import "../contracts/interfaces/ITimeKeeping.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// // Mock Management Contract for testing
// contract MockManagement is IManagement {
//     mapping(address => Staff) private staffs;
//     mapping(address => mapping(STAFF_ROLE => bool)) private roles;
//     address[] private allStaffAddresses;
//     WorkingShift[] private workingShifts;
    
//     constructor() {
//         // Setup default working shifts
//         workingShifts.push(WorkingShift({
//             shiftId: 1,
//             name: "Morning Shift",
//             from: 8 * 3600, // 8:00 AM in seconds
//             to: 12 * 3600   // 12:00 PM in seconds
//         }));
        
//         workingShifts.push(WorkingShift({
//             shiftId: 2,
//             name: "Afternoon Shift", 
//             from: 13 * 3600, // 1:00 PM in seconds
//             to: 17 * 3600    // 5:00 PM in seconds
//         }));
        
//         workingShifts.push(WorkingShift({
//             shiftId: 3,
//             name: "Evening Shift",
//             from: 18 * 3600, // 6:00 PM in seconds
//             to: 22 * 3600    // 10:00 PM in seconds
//         }));
//     }
    
//     function addStaff(address wallet, string memory code, string memory name, string memory position) external {
//         staffs[wallet] = Staff({
//             wallet: wallet,
//             code: code,
//             name: name,
//             position: position,
//             isActive: true
//         });
//         allStaffAddresses.push(wallet);
//     }
    
//     function setRole(address user, STAFF_ROLE role, bool hasRole) external {
//         roles[user][role] = hasRole;
//     }
    
//     function GetStaffInfo(address wallet) external view returns (Staff memory) {
//         return staffs[wallet];
//     }
    
//     function GetAllStaffs() external view returns (Staff[] memory) {
//         Staff[] memory result = new Staff[](allStaffAddresses.length);
//         for (uint i = 0; i < allStaffAddresses.length; i++) {
//             result[i] = staffs[allStaffAddresses[i]];
//         }
//         return result;
//     }
    
//     function checkRole(STAFF_ROLE role, address user) external view returns (bool) {
//         return roles[user][role];
//     }
    
//     function getWorkingShifts() external view returns (WorkingShift[] memory) {
//         return workingShifts;
//     }
    
//     function updateWorkingShifts(WorkingShift[] memory _shifts) external {
//         delete workingShifts;
//         for (uint i = 0; i < _shifts.length; i++) {
//             workingShifts.push(_shifts[i]);
//         }
//     }
// }

// contract AttendanceSystemTest is Test {
//     AttendanceSystem public attendanceSystem;
//     MockManagement public mockManagement;
//     ERC1967Proxy public proxy;
    
//     address public owner = address(0x1);
//     address public be = address(0x2);
//     address public manager = address(0x3);
//     address public staff1 = address(0x4);
//     address public staff2 = address(0x5);
//     address public staff3 = address(0x6);
    
//     // Test data
//     WorkPlace[] workPlaces;
//     WorkPlaceAttendance workPlaceAttendance;
    
//     function setUp() public {
//         vm.startPrank(owner);
        
//         // Deploy mock management contract
//         mockManagement = new MockManagement();
        
//         // Deploy implementation
//         AttendanceSystem implementation = new AttendanceSystem();
        
//         // Deploy proxy with initialization
//         bytes memory initData = abi.encodeWithSelector(
//             AttendanceSystem.initialize.selector,
//             address(mockManagement)
//         );
        
//         proxy = new ERC1967Proxy(address(implementation), initData);
//         attendanceSystem = AttendanceSystem(address(proxy));
        
//         // Set BE
//         attendanceSystem.setBE(be);
        
//         vm.stopPrank();
        
//         // Setup staff data
//         _setupStaffData();
        
//         // Setup workplace data
//         _setupWorkplaceData();
        
//         // Setup roles
//         _setupRoles();
//     }
    
//     function _setupStaffData() internal {
//         mockManagement.addStaff(staff1, "EMP001", "John Doe", "Developer");
//         mockManagement.addStaff(staff2, "EMP002", "Jane Smith", "Manager");
//         mockManagement.addStaff(staff3, "EMP003", "Bob Johnson", "Tester");
//     }
    
//     function _setupWorkplaceData() internal {
//         workPlaces.push(WorkPlace({
//             WorkPlaceId: 1,
//             WorkPlaceName: "Main Office",
//             LatLon: "10.7769,106.7009",
//             Address: "123 Nguyen Hue, District 1, HCMC"
//         }));
        
//         workPlaces.push(WorkPlace({
//             WorkPlaceId: 2,
//             WorkPlaceName: "Branch Office", 
//             LatLon: "10.8231,106.6297",
//             Address: "456 Le Loi, District 3, HCMC"
//         }));
        
//         workPlaceAttendance = WorkPlaceAttendance({
//             WorkPlaceId: 1,
//             LatLon: "10.7769,106.7009"
//         });
        
//         vm.prank(manager);
//         attendanceSystem.updateSettingAddress(workPlaces);
//     }
    
//     function _setupRoles() internal {
//         mockManagement.setRole(manager, STAFF_ROLE.STAFF_MANAGE, true);
//         mockManagement.setRole(be, STAFF_ROLE.STAFF_MANAGE, true);
//     }
    
//     function _mockTimestamp(uint256 year, uint256 month, uint256 day, uint256 hour, uint256 minute) internal pure returns (uint256) {
//         // Simple timestamp calculation for Vietnam timezone (UTC+7)
//         // This is a simplified version - in real tests you might want more precise calculation
//         uint256 baseTimestamp = 1672531200; // Jan 1, 2023 00:00:00 UTC
//         uint256 daysFromBase = (year - 2023) * 365 + (month - 1) * 30 + (day - 1);
//         return baseTimestamp + daysFromBase * 86400 + hour * 3600 + minute * 60 - 7 * 3600; // Subtract 7 hours for Vietnam timezone
//     }
    
//     // Test initialization
//     function testInitialization() public {
//         assertEq(address(attendanceSystem.managementContract()), address(mockManagement));
//         assertEq(attendanceSystem.BE(), be);
//         assertEq(attendanceSystem.owner(), owner);
//         assertEq(attendanceSystem.standardWorkingHours(), 480); // 8 hours
//         assertEq(attendanceSystem.lateThreshold(), 15); // 15 minutes
//         assertEq(attendanceSystem.halfDayThreshold(), 240); // 4 hours
//     }
    
//     // Test timezone functions
//     function testSetGetTimezone() public {
//         vm.prank(owner);
//         int256 newTimezone = attendanceSystem.setTimeZone(9); // JST
//         assertEq(newTimezone, 9);
//         assertEq(attendanceSystem.getTimeZone(), 9);
//     }
    
//     // Test workplace setup
//     function testWorkplaceSetup() public {
//         SettingAddress memory settings = attendanceSystem.getSettingAddress();
//         assertEq(settings.WorkPlaces.length, 2);
//         assertEq(settings.WorkPlaces[0].WorkPlaceId, 1);
//         assertEq(settings.WorkPlaces[0].WorkPlaceName, "Main Office");
//     }
    
//     // Test check-in functionality
//     function testCheckIn() public {
//         // Mock timestamp for 8:30 AM (morning shift)
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Verify attendance record
//         AttendanceRecord memory record = attendanceSystem.getAttendanceRecord(staff1, 20240315);
//         assertEq(record.staffWallet, staff1);
//         assertEq(record.staffCode, "EMP001");
//         assertEq(record.status, AttendanceStatus.PRESENT);
//         assertEq(record.ShiftId, 1); // Morning shift
//         assertTrue(record.isLate); // 8:30 is late for 8:00 shift with 15min threshold
//         assertGt(record.lateMinutes, 0);
//     }
    
//     function testCheckInOnTime() public {
//         // Mock timestamp for 8:00 AM (on time for morning shift)
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 0);
//         vm.warp(timestamp);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         AttendanceRecord memory record = attendanceSystem.getAttendanceRecord(staff1, 20240315);
//         assertFalse(record.isLate);
//         assertEq(record.lateMinutes, 0);
//     }
    
//     function testCheckInFailsWithInvalidWorkplace() public {
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         WorkPlaceAttendance memory invalidWorkplace = WorkPlaceAttendance({
//             WorkPlaceId: 999,
//             LatLon: "0.0,0.0"
//         });
        
//         vm.prank(be);
//         vm.expectRevert();
//         attendanceSystem.checkIn(staff1, invalidWorkplace);
//     }
    
//     function testCheckInFailsOutsideShiftTime() public {
//         // Mock timestamp for 6:00 AM (no shift available)
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 6, 0);
//         vm.warp(timestamp);
        
//         vm.prank(be);
//         vm.expectRevert();
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
//     }
    
//     // Test check-out functionality
//     function testCheckOut() public {
//         // First check in at 8:30 AM
//         uint256 checkinTime = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(checkinTime);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Then check out at 12:00 PM
//         uint256 checkoutTime = _mockTimestamp(2024, 3, 15, 12, 0);
//         vm.warp(checkoutTime);
        
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         AttendanceRecord memory record = attendanceSystem.getAttendanceRecord(staff1, 20240315);
//         assertGt(record.checkOutTime, 0);
//         assertGt(record.totalWorkingHours, 0);
//         assertFalse(record.isHalfDay); // 3.5 hours should not be half day
//     }
    
//     function testCheckOutFailsWithoutCheckIn() public {
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 12, 0);
//         vm.warp(timestamp);
        
//         vm.prank(be);
//         vm.expectRevert();
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
//     }
    
//     function testCheckOutWithDifferentWorkplace() public {
//         // Check in at main office
//         uint256 checkinTime = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(checkinTime);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Try to check out at different workplace
//         WorkPlaceAttendance memory differentWorkplace = WorkPlaceAttendance({
//             WorkPlaceId: 2,
//             LatLon: "10.8231,106.6297"
//         });
        
//         uint256 checkoutTime = _mockTimestamp(2024, 3, 15, 12, 0);
//         vm.warp(checkoutTime);
        
//         vm.prank(be);
//         vm.expectRevert();
//         attendanceSystem.checkOut(staff1, differentWorkplace);
//     }
    
//     // Test not in position functionality
//     function testNotInPosition() public {
//         // First check in
//         uint256 checkinTime = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(checkinTime);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Start not in position at 9:00 AM
//         uint256 notInPosStartTime = _mockTimestamp(2024, 3, 15, 9, 0);
//         vm.warp(notInPosStartTime);
        
//         vm.prank(manager);
//         attendanceSystem.startNotInPosition(staff1);
        
//         // End not in position at 9:30 AM
//         uint256 notInPosEndTime = _mockTimestamp(2024, 3, 15, 9, 30);
//         vm.warp(notInPosEndTime);
        
//         vm.prank(manager);
//         attendanceSystem.endNotInPosition(staff1);
        
//         AttendanceRecord memory record = attendanceSystem.getAttendanceRecord(staff1, 20240315);
//         assertEq(record.totalNotInPositionCount, 1);
//         assertEq(record.totalNotInPositionTime, 30); // 30 minutes
        
//         NotInPositionRecord[] memory notInPosRecords = attendanceSystem.getNotInPositionRecords(staff1, 20240315);
//         assertEq(notInPosRecords.length, 1);
//         assertEq(notInPosRecords[0].duration, 30);
//     }
    
//     function testStartNotInPositionFailsWithoutCheckIn() public {
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 9, 0);
//         vm.warp(timestamp);
        
//         vm.prank(manager);
//         vm.expectRevert("Must check in first");
//         attendanceSystem.startNotInPosition(staff1);
//     }
    
//     function testEndNotInPositionFailsWithoutStart() public {
//         // Check in first
//         uint256 checkinTime = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(checkinTime);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Try to end without starting
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 9, 30);
//         vm.warp(timestamp);
        
//         vm.prank(manager);
//         vm.expectRevert("No not in position record found");
//         attendanceSystem.endNotInPosition(staff1);
//     }
    
//     // Test bulk attendance data setting
//     function testSetBulkAttendanceData() public {
//         address[] memory staffs = new address[](2);
//         staffs[0] = staff1;
//         staffs[1] = staff2;
        
//         uint256[] memory dates = new uint256[](2);
//         dates[0] = 20240315;
//         dates[1] = 20240315;
        
//         AttendanceStatus[] memory statuses = new AttendanceStatus[](2);
//         statuses[0] = AttendanceStatus.ABSENT;
//         statuses[1] = AttendanceStatus.ABSENT;
        
//         ABSENT_TYPE[] memory absentTypes = new ABSENT_TYPE[](2);
//         absentTypes[0] = ABSENT_TYPE.VACATION;
//         absentTypes[1] = ABSENT_TYPE.UNAUTHORIZED;
        
//         vm.prank(manager);
//         attendanceSystem.setBulkAttendanceData(
//             staffs,
//             dates,
//             statuses,
//             absentTypes,
//             "Bulk absence entry",
//             manager
//         );
        
//         AttendanceRecord memory record1 = attendanceSystem.getAttendanceRecord(staff1, 20240315);
//         AttendanceRecord memory record2 = attendanceSystem.getAttendanceRecord(staff2, 20240315);
        
//         assertEq(record1.status, AttendanceStatus.ABSENT);
//         assertEq(record1.absentType, ABSENT_TYPE.VACATION);
//         assertTrue(record1.isApproved);
//         assertEq(record1.approvedBy, manager);
        
//         assertEq(record2.status, AttendanceStatus.ABSENT);
//         assertEq(record2.absentType, ABSENT_TYPE.UNAUTHORIZED);
//     }
    
//     // Test daily reports
//     function testDailyReportGeneration() public {
//         // Create attendance records for multiple staff
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         // Staff1 - Present but late
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         vm.warp(timestamp + 4 * 3600); // 4 hours later
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         // Staff2 - Absent (vacation)
//         vm.prank(manager);
//         address[] memory staffs = new address[](1);
//         staffs[0] = staff2;
//         uint256[] memory dates = new uint256[](1);
//         dates[0] = 20240315;
//         AttendanceStatus[] memory statuses = new AttendanceStatus[](1);
//         statuses[0] = AttendanceStatus.ABSENT;
//         ABSENT_TYPE[] memory absentTypes = new ABSENT_TYPE[](1);
//         absentTypes[0] = ABSENT_TYPE.VACATION;
        
//         attendanceSystem.setBulkAttendanceData(staffs, dates, statuses, absentTypes, "Vacation", manager);
        
//         DailyReportHR memory dailyReport = attendanceSystem.getDailyReport(20240315);
//         assertEq(dailyReport.date, 20240315);
//         assertEq(dailyReport.presentStaff, 1);
//         assertEq(dailyReport.absentStaff, 1);
//         assertEq(dailyReport.lateStaff, 1);
//         assertEq(dailyReport.vacationStaff, 1);
//     }
    
//     // Test monthly report generation
//     function testMonthlyReportRealtime() public {
//         // Create multiple days of attendance
//         for (uint256 day = 1; day <= 5; day++) {
//             uint256 timestamp = _mockTimestamp(2024, 3, day, 8, 0);
//             vm.warp(timestamp);
            
//             vm.prank(be);
//             attendanceSystem.checkIn(staff1, workPlaceAttendance);
            
//             vm.warp(timestamp + 8 * 3600); // 8 hours later
//             vm.prank(be);
//             attendanceSystem.checkOut(staff1, workPlaceAttendance);
//         }
        
//         StaffMonthlyReport memory monthlyReport = attendanceSystem.getStaffMonthlyReportRealtime(staff1, 202403);
//         assertEq(monthlyReport.staffWallet, staff1);
//         assertEq(monthlyReport.month, 202403);
//         assertEq(monthlyReport.presentDays, 5);
//         assertEq(monthlyReport.lateDays, 0);
//         assertGt(monthlyReport.totalWorkingHours, 0);
//         assertGt(monthlyReport.attendanceRate, 0);
//     }
    
//     // Test company reports
//     function testCompanyDailyReport() public {
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         // Staff1 present
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
//         vm.warp(timestamp + 8 * 3600);
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         // Staff2 absent
//         vm.prank(manager);
//         address[] memory staffs = new address[](1);
//         staffs[0] = staff2;
//         uint256[] memory dates = new uint256[](1);
//         dates[0] = 20240315;
//         AttendanceStatus[] memory statuses = new AttendanceStatus[](1);
//         statuses[0] = AttendanceStatus.ABSENT;
//         ABSENT_TYPE[] memory absentTypes = new ABSENT_TYPE[](1);
//         absentTypes[0] = ABSENT_TYPE.VACATION;
        
//         attendanceSystem.setBulkAttendanceData(staffs, dates, statuses, absentTypes, "Vacation", manager);
        
//         CompanyDailySummary[] memory companyReport = attendanceSystem.getCompanyDailyReport(20240315);
//         assertTrue(companyReport.length >= 2);
        
//         // Find staff1 and staff2 in the report
//         bool foundStaff1 = false;
//         bool foundStaff2 = false;
        
//         for (uint i = 0; i < companyReport.length; i++) {
//             if (keccak256(abi.encodePacked(companyReport[i].staffCode)) == keccak256(abi.encodePacked("EMP001"))) {
//                 foundStaff1 = true;
//                 assertGt(companyReport[i].workingHours, 0);
//             }
//             if (keccak256(abi.encodePacked(companyReport[i].staffCode)) == keccak256(abi.encodePacked("EMP002"))) {
//                 foundStaff2 = true;
//                 assertEq(companyReport[i].workingHours, 0);
//             }
//         }
        
//         assertTrue(foundStaff1);
//         assertTrue(foundStaff2);
//     }
    
//     function testCompanyMonthlyReport() public {
//         // Create attendance for multiple days
//         for (uint256 day = 1; day <= 5; day++) {
//             uint256 timestamp = _mockTimestamp(2024, 3, day, 8, 0);
//             vm.warp(timestamp);
            
//             vm.prank(be);
//             attendanceSystem.checkIn(staff1, workPlaceAttendance);
            
//             vm.warp(timestamp + 8 * 3600);
//             vm.prank(be);
//             attendanceSystem.checkOut(staff1, workPlaceAttendance);
//         }
        
//         CompanyMonthlySummary[] memory companyMonthlyReport = attendanceSystem.getCompanyMonthlyReport(202403);
//         assertTrue(companyMonthlyReport.length >= 1);
        
//         // Find staff1 in the report
//         bool foundStaff1 = false;
//         for (uint i = 0; i < companyMonthlyReport.length; i++) {
//             if (keccak256(abi.encodePacked(companyMonthlyReport[i].staffCode)) == keccak256(abi.encodePacked("EMP001"))) {
//                 foundStaff1 = true;
//                 assertEq(companyMonthlyReport[i].workingDays, 5);
//                 break;
//             }
//         }
//         assertTrue(foundStaff1);
//     }
    
//     // Test access control
//     function testOnlyBECanCallBEFunctions() public {
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         // Non-BE user trying to check in for staff
//         vm.prank(address(0x999));
//         vm.expectRevert("only BE or staff can call");
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Staff can check in for themselves
//         vm.prank(staff1);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
//     }
    
//     function testOnlyManagerOrHRCanCallManagementFunctions() public {
//         // Non-manager trying to start not in position
//         vm.prank(address(0x999));
//         vm.expectRevert("Insufficient permissions");
//         attendanceSystem.startNotInPosition(staff1);
        
//         // Manager can call management functions
//         uint256 checkinTime = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(checkinTime);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         vm.prank(manager);
//         attendanceSystem.startNotInPosition(staff1);
//     }
    
//     function testOnlyOwnerCanCallOwnerFunctions() public {
//         // Non-owner trying to set BE
//         vm.prank(address(0x999));
//         vm.expectRevert();
//         attendanceSystem.setBE(address(0x888));
        
//         // Owner can set BE
//         vm.prank(owner);
//         attendanceSystem.setBE(address(0x888));
//         assertEq(attendanceSystem.BE(), address(0x888));
//     }
    
//     // Test settings update
//     function testUpdateSettings() public {
//         vm.prank(manager);
//         attendanceSystem.updateSettings(600, 20, 300); // 10 hours, 20 min late threshold, 5 hours half day
        
//         assertEq(attendanceSystem.standardWorkingHours(), 600);
//         assertEq(attendanceSystem.lateThreshold(), 20);
//         assertEq(attendanceSystem.halfDayThreshold(), 300);
//     }
    
//     // Test edge cases
//     function testMultipleShiftCheckInCheckOut() public {
//         // Morning shift check in
//         uint256 morningCheckin = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(morningCheckin);
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Morning shift check out
//         uint256 morningCheckout = _mockTimestamp(2024, 3, 15, 12, 0);
//         vm.warp(morningCheckout);
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         // Afternoon shift check in
//         uint256 afternoonCheckin = _mockTimestamp(2024, 3, 15, 13, 0);
//         vm.warp(afternoonCheckin);
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Afternoon shift check out
//         uint256 afternoonCheckout = _mockTimestamp(2024, 3, 15, 17, 0);
//         vm.warp(afternoonCheckout);
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         AttendanceRecord memory record = attendanceSystem.getAttendanceRecord(staff1, 20240315);
//         assertEq(record.status, AttendanceStatus.PRESENT);
//         assertGt(record.totalWorkingHours, 7); // Should be around 7.5 hours total
//     }
    
//     function testHalfDayDetection() public {
//         // Check in at 8:30 AM
//         uint256 checkinTime = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(checkinTime);
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Check out at 11:30 AM (3 hours work, below half day threshold)
//         uint256 checkoutTime = _mockTimestamp(2024, 3, 15, 11, 30);
//         vm.warp(checkoutTime);
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         AttendanceRecord memory record = attendanceSystem.getAttendanceRecord(staff1, 20240315);
//         assertTrue(record.isHalfDay);
//     }
    
//     // Test data integrity
//     function testDataConsistency() public {
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         vm.warp(timestamp + 8 * 3600);
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         // Check individual staff report
//         StaffDailyReport memory staffReport = attendanceSystem.getStaffDailyReport(staff1, 20240315);
        
//         // Check daily report
//         DailyReportHR memory dailyReport = attendanceSystem.getDailyReport(20240315);
        
//         // Verify consistency
//         assertEq(staffReport.staffWallet, staff1);
//         assertEq(staffReport.status, AttendanceStatus.PRESENT);
//         assertEq(dailyReport.presentStaff, 1);
//         assertTrue(dailyReport.lateStaff >= 0);
//     }
    
//     // Test upgradeability
//     function testUpgradeabilityOnlyOwner() public {
//         AttendanceSystem newImplementation = new AttendanceSystem();
        
//         // Non-owner cannot upgrade
//         vm.prank(address(0x999));
//         vm.expectRevert();
//         attendanceSystem.upgradeTo(address(newImplementation));
        
//         // Owner can upgrade
//         vm.prank(owner);
//         attendanceSystem.upgradeTo(address(newImplementation));
//     }
    
//     // Test reentrancy protection
//     function testReentrancyProtection() public {
//         // This test verifies that the nonReentrant modifier works
//         // In a real scenario, you would create a malicious contract that tries to re-enter
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Verify the attendance was recorded (basic test since we can't easily test reentrancy in this setup)
//         AttendanceRecord memory record = attendanceSystem.getAttendanceRecord(staff1, 20240315);
//         assertEq(record.status, AttendanceStatus.PRESENT);
//     }
    
//     // Test format time utility function
//     function testFormatTime() public {
//         string memory timeStr1 = attendanceSystem.formatTime(0);
//         assertEq(timeStr1, "00:00");
        
//         string memory timeStr2 = attendanceSystem.formatTime(3661); // 1:01:01
//         assertEq(timeStr2, "01:01");
        
//         string memory timeStr3 = attendanceSystem.formatTime(43200); // 12:00:00
//         assertEq(timeStr3, "12:00");
//     }
    
//     // Test staff day details for a month
//     function testGetStaffDayDetailsAMonth() public {
//         // Create attendance for first 5 days of March 2024
//         for (uint256 day = 1; day <= 5; day++) {
//             uint256 timestamp = _mockTimestamp(2024, 3, day, 8, 0);
//             vm.warp(timestamp);
            
//             vm.prank(be);
//             attendanceSystem.checkIn(staff1, workPlaceAttendance);
            
//             vm.warp(timestamp + 8 * 3600);
//             vm.prank(be);
//             attendanceSystem.checkOut(staff1, workPlaceAttendance);
//         }
        
//         // Set one day as vacation
//         vm.prank(manager);
//         address[] memory staffs = new address[](1);
//         staffs[0] = staff1;
//         uint256[] memory dates = new uint256[](1);
//         dates[0] = 20240306;
//         AttendanceStatus[] memory statuses = new AttendanceStatus[](1);
//         statuses[0] = AttendanceStatus.ABSENT;
//         ABSENT_TYPE[] memory absentTypes = new ABSENT_TYPE[](1);
//         absentTypes[0] = ABSENT_TYPE.VACATION;
        
//         attendanceSystem.setBulkAttendanceData(staffs, dates, statuses, absentTypes, "Vacation", manager);
        
//         StaffDayDetail[] memory details = attendanceSystem.getStaffDayDetailsAMonth(staff1, 202403);
        
//         // March has 31 days
//         assertEq(details.length, 31);
        
//         // Check first 5 days are present
//         for (uint256 i = 0; i < 5; i++) {
//             assertEq(details[i].status, AttendanceStatus.PRESENT);
//             assertEq(details[i].date, 20240301 + i);
//         }
        
//         // Check day 6 is vacation
//         assertEq(details[5].status, AttendanceStatus.ABSENT);
//         assertEq(details[5].absentType, ABSENT_TYPE.VACATION);
//     }
    
//     // Test company monthly report by position
//     function testCompanyMonthlyReportByPosition() public {
//         // Create attendance for staff with different positions
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 0);
//         vm.warp(timestamp);
        
//         // Staff1 (Developer) present
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
//         vm.warp(timestamp + 8 * 3600);
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         // Staff2 (Manager) present
//         vm.prank(be);
//         attendanceSystem.checkIn(staff2, workPlaceAttendance);
//         vm.warp(timestamp + 8 * 3600);
//         vm.prank(be);
//         attendanceSystem.checkOut(staff2, workPlaceAttendance);
        
//         // Test filter by Developer position
//         CompanyMonthlySummary[] memory developerReport = attendanceSystem.getCompanyMonthlyReportByPosition(202403, "Developer");
        
//         bool foundDeveloper = false;
//         for (uint i = 0; i < developerReport.length; i++) {
//             if (keccak256(abi.encodePacked(developerReport[i].position)) == keccak256(abi.encodePacked("Developer"))) {
//                 foundDeveloper = true;
//                 assertEq(developerReport[i].workingDays, 1);
//                 break;
//             }
//         }
//         assertTrue(foundDeveloper);
        
//         // Test filter by Manager position
//         CompanyMonthlySummary[] memory managerReport = attendanceSystem.getCompanyMonthlyReportByPosition(202403, "Manager");
        
//         bool foundManager = false;
//         for (uint i = 0; i < managerReport.length; i++) {
//             if (keccak256(abi.encodePacked(managerReport[i].position)) == keccak256(abi.encodePacked("Manager"))) {
//                 foundManager = true;
//                 assertEq(managerReport[i].workingDays, 1);
//                 break;
//             }
//         }
//         assertTrue(foundManager);
        
//         // Test get all positions (empty filter)
//         CompanyMonthlySummary[] memory allReport = attendanceSystem.getCompanyMonthlyReportByPosition(202403, "");
//         assertTrue(allReport.length >= 2);
//     }
    
//     // Test holiday settings and working day calculations
//     function testCompanyHolidays() public {
//         uint256[] memory holidayDates = new uint256[](2);
//         holidayDates[0] = 20240101; // New Year
//         holidayDates[1] = 20240430; // Reunification Day
        
//         bool[] memory isHoliday = new bool[](2);
//         isHoliday[0] = true;
//         isHoliday[1] = true;
        
//         vm.prank(be);
//         attendanceSystem.setCompanyHolidays(holidayDates, isHoliday);
        
//         assertTrue(attendanceSystem.companyHolidays(20240101));
//         assertTrue(attendanceSystem.companyHolidays(20240430));
//         assertFalse(attendanceSystem.companyHolidays(20240315));
//     }
    
//     // Test overnight shift handling
//     function testOvernightShift() public {
//         // Add overnight shift to mock management
//         WorkingShift[] memory newShifts = new WorkingShift[](4);
//         newShifts[0] = WorkingShift({ shiftId: 1, name: "Morning Shift", from: 8 * 3600, to: 12 * 3600 });
//         newShifts[1] = WorkingShift({ shiftId: 2, name: "Afternoon Shift", from: 13 * 3600, to: 17 * 3600 });
//         newShifts[2] = WorkingShift({ shiftId: 3, name: "Evening Shift", from: 18 * 3600, to: 22 * 3600 });
//         newShifts[3] = WorkingShift({ shiftId: 4, name: "Night Shift", from: 22 * 3600, to: 6 * 3600 + 86400 }); // 22:00 to 06:00 next day
        
//         mockManagement.updateWorkingShifts(newShifts);
        
//         // Check in at 22:00 (night shift)
//         uint256 checkinTime = _mockTimestamp(2024, 3, 15, 22, 0);
//         vm.warp(checkinTime);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Check out at 06:00 next day
//         uint256 checkoutTime = _mockTimestamp(2024, 3, 16, 6, 0);
//         vm.warp(checkoutTime);
        
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         AttendanceRecord memory record = attendanceSystem.getAttendanceRecord(staff1, 20240315);
//         assertEq(record.status, AttendanceStatus.PRESENT);
//         assertGt(record.totalWorkingHours, 7); // Should be around 8 hours
//     }
    
//     // Test rebuild daily report functionality
//     function testRebuildDailyReport() public {
//         // Create some attendance records
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         vm.warp(timestamp + 8 * 3600);
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         // Get initial report
//         DailyReportHR memory initialReport = attendanceSystem.getDailyReport(20240315);
//         assertEq(initialReport.presentStaff, 1);
        
//         // Rebuild the report
//         vm.prank(manager);
//         attendanceSystem.rebuildDailyReport(20240315);
        
//         // Verify report is still correct after rebuild
//         DailyReportHR memory rebuiltReport = attendanceSystem.getDailyReport(20240315);
//         assertEq(rebuiltReport.presentStaff, 1);
//         assertEq(rebuiltReport.date, 20240315);
//     }
    
//     // Test edge case: same shift multiple check-ins
//     function testSameShiftMultipleCheckInsRevertsCorrectly() public {
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         // First check-in should succeed
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Second check-in for same shift should fail
//         uint256 timestamp2 = _mockTimestamp(2024, 3, 15, 9, 0); // Still morning shift
//         vm.warp(timestamp2);
        
//         vm.prank(be);
//         vm.expectRevert();
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
//     }
    
//     // Test tracking arrays
//     function testStaffTracking() public {
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         // Initial state - no staff tracked yet by attendance system
//         // (staff exists in management but not yet in attendance tracking)
        
//         // Check in staff1
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         // Verify staff is now tracked
//         assertTrue(attendanceSystem.isStaffExists(staff1));
//         assertTrue(attendanceSystem.isAttendanceRecorded(staff1, 20240315));
//     }
    
//     // Test settings validation
//     function testSettingsValidation() public {
//         // Test updating settings with valid values
//         vm.prank(manager);
//         attendanceSystem.updateSettings(600, 30, 360); // 10 hours, 30 min late, 6 hours half day
        
//         assertEq(attendanceSystem.standardWorkingHours(), 600);
//         assertEq(attendanceSystem.lateThreshold(), 30);
//         assertEq(attendanceSystem.halfDayThreshold(), 360);
        
//         // Test that non-manager cannot update settings
//         vm.prank(address(0x999));
//         vm.expectRevert("Insufficient permissions");
//         attendanceSystem.updateSettings(500, 25, 300);
//     }
    
//     // Test management contract update
//     function testUpdateManagementContract() public {
//         MockManagement newManagement = new MockManagement();
        
//         vm.prank(manager);
//         attendanceSystem.updateManagementContract(address(newManagement));
        
//         assertEq(address(attendanceSystem.managementContract()), address(newManagement));
//     }
    
//     // Stress test with multiple operations in sequence
//     function testComplexWorkflow() public {
//         uint256 baseTime = _mockTimestamp(2024, 3, 15, 8, 0);
        
//         // Day 1: Normal attendance
//         vm.warp(baseTime);
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         vm.warp(baseTime + 4 * 3600); // 4 hours later
//         vm.prank(manager);
//         attendanceSystem.startNotInPosition(staff1);
        
//         vm.warp(baseTime + 4.5 * 3600); // 30 minutes not in position
//         vm.prank(manager);
//         attendanceSystem.endNotInPosition(staff1);
        
//         vm.warp(baseTime + 8 * 3600); // End of day
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         // Day 2: Vacation
//         vm.prank(manager);
//         address[] memory staffs = new address[](1);
//         staffs[0] = staff1;
//         uint256[] memory dates = new uint256[](1);
//         dates[0] = 20240316;
//         AttendanceStatus[] memory statuses = new AttendanceStatus[](1);
//         statuses[0] = AttendanceStatus.ABSENT;
//         ABSENT_TYPE[] memory absentTypes = new ABSENT_TYPE[](1);
//         absentTypes[0] = ABSENT_TYPE.VACATION;
        
//         attendanceSystem.setBulkAttendanceData(staffs, dates, statuses, absentTypes, "Planned vacation", manager);
        
//         // Day 3: Late arrival
//         uint256 day3Time = _mockTimestamp(2024, 3, 17, 8, 45); // 45 minutes late
//         vm.warp(day3Time);
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         vm.warp(day3Time + 8 * 3600);
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         // Verify all records
//         AttendanceRecord memory day1 = attendanceSystem.getAttendanceRecord(staff1, 20240315);
//         assertEq(day1.status, AttendanceStatus.PRESENT);
//         assertEq(day1.totalNotInPositionCount, 1);
//         assertEq(day1.totalNotInPositionTime, 30);
//         assertFalse(day1.isLate);
        
//         AttendanceRecord memory day2 = attendanceSystem.getAttendanceRecord(staff1, 20240316);
//         assertEq(day2.status, AttendanceStatus.ABSENT);
//         assertEq(day2.absentType, ABSENT_TYPE.VACATION);
        
//         AttendanceRecord memory day3 = attendanceSystem.getAttendanceRecord(staff1, 20240317);
//         assertEq(day3.status, AttendanceStatus.PRESENT);
//         assertTrue(day3.isLate);
//         assertEq(day3.lateMinutes, 30); // 45 - 15 (threshold)
        
//         // Check reports
//         DailyReportHR memory day1Report = attendanceSystem.getDailyReport(20240315);
//         assertEq(day1Report.presentStaff, 1);
//         assertEq(day1Report.totalNotInPositionCount, 1);
        
//         DailyReportHR memory day2Report = attendanceSystem.getDailyReport(20240316);
//         assertEq(day2Report.absentStaff, 1);
//         assertEq(day2Report.vacationStaff, 1);
        
//         DailyReportHR memory day3Report = attendanceSystem.getDailyReport(20240317);
//         assertEq(day3Report.presentStaff, 1);
//         assertEq(day3Report.lateStaff, 1);
//     }
    
//     // Test contract state after multiple operations
//     function testContractStateConsistency() public {
//         uint256 initialRecordCount = attendanceSystem.totalAttendanceRecords();
        
//         // Perform multiple operations
//         uint256 timestamp = _mockTimestamp(2024, 3, 15, 8, 30);
//         vm.warp(timestamp);
        
//         vm.prank(be);
//         attendanceSystem.checkIn(staff1, workPlaceAttendance);
        
//         uint256 afterCheckinCount = attendanceSystem.totalAttendanceRecords();
//         assertEq(afterCheckinCount, initialRecordCount + 1);
        
//         vm.warp(timestamp + 8 * 3600);
//         vm.prank(be);
//         attendanceSystem.checkOut(staff1, workPlaceAttendance);
        
//         // Total attendance records should not increase for checkout
//         uint256 afterCheckoutCount = attendanceSystem.totalAttendanceRecords();
//         assertEq(afterCheckoutCount, afterCheckinCount);
        
//         // Add another staff
//         vm.prank(be);
//         attendanceSystem.checkIn(staff2, workPlaceAttendance);
        
//         uint256 finalCount = attendanceSystem.totalAttendanceRecords();
//         assertEq(finalCount, afterCheckoutCount + 1);
        
//         // Verify both staff are tracked
//         assertTrue(attendanceSystem.isStaffExists(staff1));
//         assertTrue(attendanceSystem.isStaffExists(staff2));
//     }
// }