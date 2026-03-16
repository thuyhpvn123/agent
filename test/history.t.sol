// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "../src/HistoryTracking.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// contract HistoryTrackingTest is Test {
//     HistoryTracking public historyTrackingImpl;
//     HistoryTracking public historyTracking;
    
//     address public agent = address(0x1);
//     address public branchManagement = address(0x2);
//     address public management = address(0x3);
//     address public writer = address(0x4);
    
//     address public staff1 = address(0x100);
//     address public staff2 = address(0x101);
//     address public manager1 = address(0x102);

//     event HistoryRecorded(
//         EntityType indexed entityType,
//         string indexed entityId,
//         ActionType actionType,
//         uint256 timestamp,
//         address actor
//     );
    
//     event SnapshotSaved(
//         EntityType indexed entityType,
//         string indexed entityId,
//         uint256 timestamp
//     );

//     function setUp() public {
//         // Deploy implementation
//         historyTrackingImpl = new HistoryTracking();
        
//         // Deploy proxy
//         bytes memory initData = abi.encodeWithSelector(
//             HistoryTracking.initialize.selector,
//             branchManagement,
//             management,
//             agent
//         );
        
//         ERC1967Proxy proxy = new ERC1967Proxy(
//             address(historyTrackingImpl),
//             initData
//         );
        
//         historyTracking = HistoryTracking(address(proxy));
        
//         // Grant writer role to test writer
//         vm.prank(agent);
//         historyTracking.grantWriterRole(writer);
//     }

//     // ==================== STAFF HISTORY TESTS ====================
    
//     function test_RecordStaffCreate() public {
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         vm.expectEmit(true, true, false, true);
//         emit HistoryRecorded(
//             EntityType.STAFF,
//             _addressToString(staff1),
//             ActionType.CREATE,
//             block.timestamp,
//             writer
//         );
        
//         historyTracking.recordStaffCreate(staff1, staff, "Initial staff creation");
        
//         vm.stopPrank();
        
//         // Verify snapshot saved
//         (StaffSnapshot memory oldSnap, StaffSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getStaffSnapshots(staff1);
        
//         assertTrue(hasNew);
//         assertFalse(hasOld);
//         assertEq(newSnap.staff.name, "Staff 1");
//         assertEq(newSnap.staff.wallet, staff1);
//     }
    
//     function test_RecordStaffUpdate() public {
//         Staff memory staff1Data = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         // Create first
//         historyTracking.recordStaffCreate(staff1, staff1Data, "Initial creation");
        
//         // Update
//         staff1Data.name = "Updated Staff 1";
//         staff1Data.phone = "9999999999";
        
//         vm.expectEmit(true, true, false, true);
//         emit HistoryRecorded(
//             EntityType.STAFF,
//             _addressToString(staff1),
//             ActionType.UPDATE,
//             block.timestamp,
//             writer
//         );
        
//         historyTracking.recordStaffUpdate(staff1, staff1Data, "Staff info updated");
        
//         vm.stopPrank();
        
//         // Verify both snapshots
//         (StaffSnapshot memory oldSnap, StaffSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getStaffSnapshots(staff1);
        
//         assertTrue(hasNew);
//         assertTrue(hasOld);
//         assertEq(oldSnap.staff.name, "Staff 1");
//         assertEq(newSnap.staff.name, "Updated Staff 1");
//         assertEq(oldSnap.staff.phone, "1234567890");
//         assertEq(newSnap.staff.phone, "9999999999");
//     }
    
//     function test_RecordStaffDelete() public {
//         Staff memory staff1Data = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         historyTracking.recordStaffCreate(staff1, staff1Data, "Initial creation");
        
//         staff1Data.active = false;
//         historyTracking.recordStaffDelete(staff1, staff1Data, "Staff deleted");
        
//         vm.stopPrank();
        
//         // Verify history entries
//         (HistoryEntry[] memory entries, uint256 total) = historyTracking.getHistoryByEntity(
//             EntityType.STAFF,
//             _addressToString(staff1),
//             0,
//             10
//         );
        
//         assertEq(total, 2);
//         assertTrue(entries[0].actionType == ActionType.DELETE); // Most recent first
//         assertTrue(entries[1].actionType == ActionType.CREATE);
//     }
    
//     function test_GetStaffUpdateSnapshots() public {
//         Staff memory staffData = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         // Create
//         historyTracking.recordStaffCreate(staff1, staffData, "Initial creation");
        
//         // First update
//         staffData.name = "Updated Staff 1";
//         historyTracking.recordStaffUpdate(staff1, staffData, "First update");
        
//         // Second update
//         staffData.phone = "9999999999";
//         historyTracking.recordStaffUpdate(staff1, staffData, "Second update");
        
//         vm.stopPrank();
        
//         // Get only UPDATE snapshots
//         (StaffSnapshot memory oldUpdate, StaffSnapshot memory newUpdate, bool hasOld, bool hasNew) = 
//             historyTracking.getStaffUpdateSnapshots(staff1);
        
//         assertTrue(hasNew);
//         assertTrue(hasOld);
//         assertEq(oldUpdate.staff.name, "Updated Staff 1");
//         assertEq(oldUpdate.staff.phone, "1234567890");
//         assertEq(newUpdate.staff.name, "Updated Staff 1");
//         assertEq(newUpdate.staff.phone, "9999999999");
//     }

//     // ==================== MANAGER HISTORY TESTS ====================
    
//     function test_RecordManagerCreate() public {
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = 1;
        
//         ManagerInfo memory managerInfo = ManagerInfo({
//             wallet: manager1,
//             name: "Manager 1",
//             phone: "1234567890",
//             image: "manager1.jpg",
//             isCoOwner: true,
//             branchIds: branchIds,
//             hasFullAccess: true,
//             canViewData: true,
//             canEditData: true,
//             canProposeAndVote: true,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         vm.expectEmit(true, true, false, true);
//         emit HistoryRecorded(
//             EntityType.MANAGER,
//             _addressToString(manager1),
//             ActionType.CREATE,
//             block.timestamp,
//             writer
//         );
        
//         historyTracking.recordManagerCreate(manager1, managerInfo, "Manager created");
        
//         vm.stopPrank();
        
//         // Verify snapshot
//         (ManagerSnapshot memory oldSnap, ManagerSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getManagerSnapshots(manager1);
        
//         assertTrue(hasNew);
//         assertFalse(hasOld);
//         assertEq(newSnap.manager.name, "Manager 1");
//         assertTrue(newSnap.manager.isCoOwner);
//     }
    
//     function test_RecordManagerUpdate() public {
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = 1;
        
//         ManagerInfo memory managerInfo = ManagerInfo({
//             wallet: manager1,
//             name: "Manager 1",
//             phone: "1234567890",
//             image: "manager1.jpg",
//             isCoOwner: true,
//             branchIds: branchIds,
//             hasFullAccess: true,
//             canViewData: true,
//             canEditData: true,
//             canProposeAndVote: true,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         historyTracking.recordManagerCreate(manager1, managerInfo, "Manager created");
        
//         // Update
//         managerInfo.name = "Updated Manager 1";
//         managerInfo.phone = "9999999999";
        
//         historyTracking.recordManagerUpdate(manager1, managerInfo, "Manager updated");
        
//         vm.stopPrank();
        
//         // Verify snapshots
//         (ManagerSnapshot memory oldSnap, ManagerSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getManagerSnapshots(manager1);
        
//         assertTrue(hasNew);
//         assertTrue(hasOld);
//         assertEq(oldSnap.manager.name, "Manager 1");
//         assertEq(newSnap.manager.name, "Updated Manager 1");
//     }

//     // ==================== PAYMENT INFO HISTORY TESTS ====================
    
//     function test_RecordPaymentInfoUpdate_FirstTime() public {
//         PaymentInfo memory oldInfo; // Empty
        
//         PaymentInfo memory newInfo = PaymentInfo({
//             bankAccount: "123456789",
//             nameAccount: "John Doe",
//             nameOfBank: "ABC Bank",
//             taxCode: "TAX123",
//             wallet: "0xWallet"
//         });
        
//         vm.startPrank(writer);
        
//         vm.expectEmit(true, true, false, true);
//         emit HistoryRecorded(
//             EntityType.PAYMENT_INFO,
//             "0",
//             ActionType.CREATE,
//             block.timestamp,
//             writer
//         );
        
//         historyTracking.recordPaymentInfoUpdate(oldInfo, newInfo, "First payment info");
        
//         vm.stopPrank();
        
//         // Verify snapshot
//         (PaymentInfoSnapshot memory oldSnap, PaymentInfoSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getPaymentInfoSnapshots(0);
        
//         assertTrue(hasNew);
//         assertFalse(hasOld);
//         assertEq(newSnap.paymentInfo.bankAccount, "123456789");
//     }
    
//     function test_RecordPaymentInfoUpdate_SecondTime() public {
//         PaymentInfo memory firstInfo = PaymentInfo({
//             bankAccount: "123456789",
//             nameAccount: "John Doe",
//             nameOfBank: "ABC Bank",
//             taxCode: "TAX123",
//             wallet: "0xWallet"
//         });
        
//         PaymentInfo memory secondInfo = PaymentInfo({
//             bankAccount: "987654321",
//             nameAccount: "Jane Doe",
//             nameOfBank: "XYZ Bank",
//             taxCode: "TAX456",
//             wallet: "0xNewWallet"
//         });
        
//         vm.startPrank(writer);
        
//         // First time
//         PaymentInfo memory empty;
//         historyTracking.recordPaymentInfoUpdate(empty, firstInfo, "First payment info");
        
//         // Second time - update
//         vm.expectEmit(true, true, false, true);
//         emit HistoryRecorded(
//             EntityType.PAYMENT_INFO,
//             "0",
//             ActionType.UPDATE,
//             block.timestamp,
//             writer
//         );
        
//         historyTracking.recordPaymentInfoUpdate(firstInfo, secondInfo, "Updated payment info");
        
//         vm.stopPrank();
        
//         // Verify snapshots
//         (PaymentInfoSnapshot memory oldSnap, PaymentInfoSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getPaymentInfoSnapshots(0);
        
//         assertTrue(hasNew);
//         assertTrue(hasOld);
//         assertEq(oldSnap.paymentInfo.bankAccount, "123456789");
//         assertEq(newSnap.paymentInfo.bankAccount, "987654321");
//     }

//     // ==================== DISH HISTORY TESTS ====================
    
//     function test_RecordDishCreate() public {
//         Dish memory dish = Dish({
//             code: "DISH001",
//             name: "Pizza",
//             description: "Delicious pizza",
//             categoryCode: "CAT001",
//             image: "pizza.jpg",
//             price: 100000,
//             isAvailable: true,
//             dishType: DishType.FOOD,
//             orderCount: 0,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         Variant[] memory variants = new Variant[](1);
//         variants[0] = Variant({
//             name: "Large",
//             price: 150000
//         });
        
//         Attribute[][] memory attributes = new Attribute[][](1);
//         attributes[0] = new Attribute[](1);
//         attributes[0][0] = Attribute({
//             name: "Spicy Level",
//             options: new string[](2)
//         });
        
//         vm.startPrank(writer);
        
//         vm.expectEmit(true, true, false, true);
//         emit HistoryRecorded(
//             EntityType.DISH,
//             "DISH001",
//             ActionType.CREATE,
//             block.timestamp,
//             writer
//         );
        
//         historyTracking.recordDishCreate("DISH001", dish, variants, attributes, "Dish created");
        
//         vm.stopPrank();
        
//         // Verify snapshot
//         (DishSnapshot memory oldSnap, DishSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getDishSnapshots("DISH001");
        
//         assertTrue(hasNew);
//         assertFalse(hasOld);
//         assertEq(newSnap.dish.name, "Pizza");
//         assertEq(newSnap.variants.length, 1);
//     }
    
//     function test_RecordDishUpdate() public {
//         Dish memory dish = Dish({
//             code: "DISH001",
//             name: "Pizza",
//             description: "Delicious pizza",
//             categoryCode: "CAT001",
//             image: "pizza.jpg",
//             price: 100000,
//             isAvailable: true,
//             dishType: DishType.FOOD,
//             orderCount: 0,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         Variant[] memory variants = new Variant[](1);
//         variants[0] = Variant({
//             name: "Large",
//             price: 150000
//         });
        
//         Attribute[][] memory attributes = new Attribute[][](0);
        
//         vm.startPrank(writer);
        
//         // Create
//         historyTracking.recordDishCreate("DISH001", dish, variants, attributes, "Dish created");
        
//         // Update
//         dish.name = "Updated Pizza";
//         dish.price = 120000;
        
//         historyTracking.recordDishUpdate("DISH001", dish, variants, attributes, "Dish updated");
        
//         vm.stopPrank();
        
//         // Verify snapshots
//         (DishSnapshot memory oldSnap, DishSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getDishSnapshots("DISH001");
        
//         assertTrue(hasNew);
//         assertTrue(hasOld);
//         assertEq(oldSnap.dish.name, "Pizza");
//         assertEq(oldSnap.dish.price, 100000);
//         assertEq(newSnap.dish.name, "Updated Pizza");
//         assertEq(newSnap.dish.price, 120000);
//     }

//     // ==================== CATEGORY HISTORY TESTS ====================
    
//     function test_RecordCategoryCreate() public {
//         Category memory category = Category({
//             code: "CAT001",
//             name: "Main Course",
//             description: "Main dishes",
//             image: "main.jpg",
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         historyTracking.recordCategoryCreate("CAT001", category, "Category created");
        
//         vm.stopPrank();
        
//         // Verify snapshot
//         (CategorySnapshot memory oldSnap, CategorySnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getCategorySnapshots("CAT001");
        
//         assertTrue(hasNew);
//         assertFalse(hasOld);
//         assertEq(newSnap.category.name, "Main Course");
//     }

//     // ==================== DISCOUNT HISTORY TESTS ====================
    
//     function test_RecordDiscountCreate() public {
//         Discount memory discount = Discount({
//             code: "DISC001",
//             name: "Summer Sale",
//             description: "10% off",
//             discountType: DiscountType.PERCENTAGE,
//             value: 10,
//             startDate: block.timestamp,
//             endDate: block.timestamp + 30 days,
//             minOrderValue: 50000,
//             maxDiscountValue: 100000,
//             usageLimit: 100,
//             usageCount: 0,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         historyTracking.recordDiscountCreate("DISC001", discount, "Discount created");
        
//         vm.stopPrank();
        
//         // Verify snapshot
//         (DiscountSnapshot memory oldSnap, DiscountSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getDiscountSnapshots("DISC001");
        
//         assertTrue(hasNew);
//         assertFalse(hasOld);
//         assertEq(newSnap.discount.name, "Summer Sale");
//     }

//     // ==================== TABLE HISTORY TESTS ====================
    
//     function test_RecordTableCreate() public {
//         Table memory table = Table({
//             tableNumber: 1,
//             areaId: 1,
//             capacity: 4,
//             status: TableStatus.AVAILABLE,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         historyTracking.recordTableCreate(1, table, "Table created");
        
//         vm.stopPrank();
        
//         // Verify snapshot
//         (TableSnapshot memory oldSnap, TableSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTracking.getTableSnapshots(1);
        
//         assertTrue(hasNew);
//         assertFalse(hasOld);
//         assertEq(newSnap.table.capacity, 4);
//     }

//     // ==================== PAGINATION TESTS ====================
    
//     function test_GetAllHistory_Pagination() public {
//         vm.startPrank(writer);
        
//         // Create multiple history entries
//         for (uint i = 0; i < 5; i++) {
//             Staff memory staff = Staff({
//                 wallet: address(uint160(0x200 + i)),
//                 name: string(abi.encodePacked("Staff ", i)),
//                 phone: "1234567890",
//                 image: "staff.jpg",
//                 positionName: "Waiter",
//                 workingShiftId: 1,
//                 createdAt: block.timestamp,
//                 active: true
//             });
            
//             historyTracking.recordStaffCreate(
//                 address(uint160(0x200 + i)),
//                 staff,
//                 "Staff created"
//             );
//         }
        
//         vm.stopPrank();
        
//         // Test pagination
//         (HistoryEntry[] memory page1, uint256 total1) = historyTracking.getAllHistory(0, 3);
//         assertEq(page1.length, 3);
//         assertEq(total1, 5);
        
//         (HistoryEntry[] memory page2, uint256 total2) = historyTracking.getAllHistory(3, 3);
//         assertEq(page2.length, 2);
//         assertEq(total2, 5);
//     }
    
//     function test_GetHistoryByType_Pagination() public {
//         vm.startPrank(writer);
        
//         // Create staff history
//         for (uint i = 0; i < 3; i++) {
//             Staff memory staff = Staff({
//                 wallet: address(uint160(0x200 + i)),
//                 name: string(abi.encodePacked("Staff ", i)),
//                 phone: "1234567890",
//                 image: "staff.jpg",
//                 positionName: "Waiter",
//                 workingShiftId: 1,
//                 createdAt: block.timestamp,
//                 active: true
//             });
            
//             historyTracking.recordStaffCreate(
//                 address(uint160(0x200 + i)),
//                 staff,
//                 "Staff created"
//             );
//         }
        
//         // Create manager history
//         for (uint i = 0; i < 2; i++) {
//             uint256[] memory branchIds = new uint256[](1);
//             branchIds[0] = 1;
            
//             ManagerInfo memory managerInfo = ManagerInfo({
//                 wallet: address(uint160(0x300 + i)),
//                 name: string(abi.encodePacked("Manager ", i)),
//                 phone: "1234567890",
//                 image: "manager.jpg",
//                 isCoOwner: false,
//                 branchIds: branchIds,
//                 hasFullAccess: false,
//                 canViewData: true,
//                 canEditData: false,
//                 canProposeAndVote: false,
//                 createdAt: block.timestamp,
//                 active: true
//             });
            
//             historyTracking.recordManagerCreate(
//                 address(uint160(0x300 + i)),
//                 managerInfo,
//                 "Manager created"
//             );
//         }
        
//         vm.stopPrank();
        
//         // Get only STAFF history
//         (HistoryEntry[] memory staffEntries, uint256 staffTotal) = 
//             historyTracking.getHistoryByType(EntityType.STAFF, 0, 10);
        
//         assertEq(staffTotal, 3);
//         assertEq(staffEntries.length, 3);
        
//         // Get only MANAGER history
//         (HistoryEntry[] memory managerEntries, uint256 managerTotal) = 
//             historyTracking.getHistoryByType(EntityType.MANAGER, 0, 10);
        
//         assertEq(managerTotal, 2);
//         assertEq(managerEntries.length, 2);
//     }
    
//     function test_GetHistoryByEntity() public {
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         // Create
//         historyTracking.recordStaffCreate(staff1, staff, "Created");
        
//         // Update multiple times
//         for (uint i = 0; i < 3; i++) {
//             staff.name = string(abi.encodePacked("Updated Staff ", i));
//             historyTracking.recordStaffUpdate(staff1, staff, "Updated");
//         }
        
//         vm.stopPrank();
        
//         // Get history for this specific staff
//         (HistoryEntry[] memory entries, uint256 total) = historyTracking.getHistoryByEntity(
//             EntityType.STAFF,
//             _addressToString(staff1),
//             0,
//             10
//         );
        
//         assertEq(total, 4); // 1 CREATE + 3 UPDATE
//         assertTrue(entries[0].actionType == ActionType.UPDATE); // Most recent
//         assertTrue(entries[3].actionType == ActionType.CREATE); // Oldest
//     }

//     // ==================== TIME RANGE TESTS ====================
    
//     function test_GetHistoryByTimeRange() public {
//         uint256 startTime = block.timestamp;
        
//         vm.startPrank(writer);
        
//         // Create entries at different times
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         historyTracking.recordStaffCreate(staff1, staff, "Created");
        
//         vm.warp(block.timestamp + 1 days);
//         staff.name = "Updated Staff 1";
//         historyTracking.recordStaffUpdate(staff1, staff, "Updated day 1");
        
//         vm.warp(block.timestamp + 2 days);
//         staff.name = "Updated Staff 2";
//         historyTracking.recordStaffUpdate(staff1, staff, "Updated day 3");
        
//         vm.stopPrank();
        
//         // Get history in first 2 days
//         (HistoryEntry[] memory entries, uint256 total) = historyTracking.getHistoryByTimeRange(
//             EntityType.STAFF,
//             startTime,
//             startTime + 1 days + 1 hours,
//             0,
//             10
//         );
        
//         assertEq(total, 2); // CREATE + first UPDATE
//     }

//     // ==================== STATS TESTS ====================
    
//     function test_GetHistoryStats() public {
//         vm.startPrank(writer);
        
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         // CREATE
//         historyTracking.recordStaffCreate(staff1, staff, "Created");
        
//         // UPDATE (3 times)
//         for (uint i = 0; i < 3; i++) {
//             staff.name = string(abi.encodePacked("Updated ", i));
//             historyTracking.recordStaffUpdate(staff1, staff, "Updated");
//         }
        
//         // DELETE
//         staff.active = false;
//         historyTracking.recordStaffDelete(staff1, staff, "Deleted");
        
//         vm.stopPrank();
        
//         // Get stats
//         (
//             uint256 totalEntries,
//             uint256 createCount,
//             uint256 updateCount,
//             uint256 deleteCount
//         ) = historyTracking.getHistoryStats(EntityType.STAFF);
        
//         assertEq(totalEntries, 5);
//         assertEq(createCount, 1);
//         assertEq(updateCount, 3);
//         assertEq(deleteCount, 1);
//     }
    
//     function test_GetUpdateCount() public {
//         vm.startPrank(writer);
        
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         historyTracking.recordStaffCreate(staff1, staff, "Created");
        
//         for (uint i = 0; i < 5; i++) {
//             staff.name = string(abi.encodePacked("Updated ", i));
//             historyTracking.recordStaffUpdate(staff1, staff, "Updated");
//         }
        
//         vm.stopPrank();
        
//         uint256 updateCount = historyTracking.getUpdateCount(
//             EntityType.STAFF,
//             _addressToString(staff1)
//         );
        
//         assertEq(updateCount, 5);
//     }
    
//     function test_GetUpdateTimeline() public {
//         vm.startPrank(writer);
        
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         historyTracking.recordStaffCreate(staff1, staff, "Created");
        
//         uint256[] memory expectedTimestamps = new uint256[](3);
        
//         for (uint i = 0; i < 3; i++) {
//             vm.warp(block.timestamp + 1 days);
//             expectedTimestamps[i] = block.timestamp;
//             staff.name = string(abi.encodePacked("Updated ", i));
//             historyTracking.recordStaffUpdate(staff1, staff, "Updated");
//         }
        
//         vm.stopPrank();
        
//         uint256[] memory timeline = historyTracking.getUpdateTimeline(
//             EntityType.STAFF,
//             _addressToString(staff1)
//         );
        
//         assertEq(timeline.length, 3);
//         for (uint i = 0; i < 3; i++) {
//             assertEq(timeline[i], expectedTimestamps[i]);
//         }
//     }

//     // ==================== PERMISSION TESTS ====================
    
//     function test_RevertRecordHistory_NoWriterRole() public {
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(user1);
        
//         vm.expectRevert();
//         historyTracking.recordStaffCreate(staff1, staff, "Created");
        
//         vm.stopPrank();
//     }
    
//     function test_GrantAndRevokeWriterRole() public {
//         address newWriter = address(0x999);
        
//         // Grant writer role
//         vm.prank(agent);
//         historyTracking.grantWriterRole(newWriter);
        
//         // New writer should be able to write
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.prank(newWriter);
//         historyTracking.recordStaffCreate(staff1, staff, "Created by new writer");
        
//         // Revoke writer role
//         vm.prank(agent);
//         historyTracking.revokeWriterRole(newWriter);
        
//         // Should not be able to write anymore
//         vm.startPrank(newWriter);
//         vm.expectRevert();
//         historyTracking.recordStaffUpdate(staff1, staff, "Should fail");
//         vm.stopPrank();
//     }

//     // ==================== ENTITY EXISTS TESTS ====================
    
//     function test_EntityExists() public {
//         assertFalse(historyTracking.entityExists(EntityType.STAFF, _addressToString(staff1)));
        
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.prank(writer);
//         historyTracking.recordStaffCreate(staff1, staff, "Created");
        
//         assertTrue(historyTracking.entityExists(EntityType.STAFF, _addressToString(staff1)));
//     }

//     // ==================== RECENT HISTORY TESTS ====================
    
//     function test_GetRecentHistoryByEntity() public {
//         vm.startPrank(writer);
        
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         historyTracking.recordStaffCreate(staff1, staff, "Created");
        
//         for (uint i = 0; i < 5; i++) {
//             staff.name = string(abi.encodePacked("Updated ", i));
//             historyTracking.recordStaffUpdate(staff1, staff, "Updated");
//         }
        
//         vm.stopPrank();
        
//         // Get only 3 most recent entries
//         HistoryEntry[] memory recentEntries = historyTracking.getRecentHistoryByEntity(
//             EntityType.STAFF,
//             _addressToString(staff1),
//             3
//         );
        
//         assertEq(recentEntries.length, 3);
//         assertTrue(recentEntries[0].actionType == ActionType.UPDATE); // Most recent
//         assertEq(recentEntries[0].reason, "Updated");
//     }

//     // ==================== SNAPSHOT HISTORY TESTS ====================
    
//     function test_GetAllDishSnapshots_Pagination() public {
//         Dish memory dish = Dish({
//             code: "DISH001",
//             name: "Pizza",
//             description: "Delicious pizza",
//             categoryCode: "CAT001",
//             image: "pizza.jpg",
//             price: 100000,
//             isAvailable: true,
//             dishType: DishType.FOOD,
//             orderCount: 0,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         Variant[] memory variants = new Variant[](0);
//         Attribute[][] memory attributes = new Attribute[][](0);
        
//         vm.startPrank(writer);
        
//         // Create
//         historyTracking.recordDishCreate("DISH001", dish, variants, attributes, "Created");
        
//         // Update multiple times
//         for (uint i = 0; i < 5; i++) {
//             dish.price = 100000 + (i * 10000);
//             historyTracking.recordDishUpdate("DISH001", dish, variants, attributes, "Updated");
//         }
        
//         vm.stopPrank();
        
//         // Get all snapshots with pagination
//         (DishSnapshot[] memory snapshots, uint256 total) = 
//             historyTracking.getAllDishSnapshots("DISH001", 0, 3);
        
//         assertEq(total, 6); // 1 CREATE + 5 UPDATE
//         assertEq(snapshots.length, 3);
        
//         // Most recent first
//         assertEq(snapshots[0].dish.price, 150000); // Last update
//     }

//     // ==================== COMPLEX WORKFLOW TESTS ====================
    
//     function test_CompleteStaffLifecycle() public {
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
        
//         vm.startPrank(writer);
        
//         // 1. Create
//         historyTracking.recordStaffCreate(staff1, staff, "Hired");
        
//         // 2. Multiple updates
//         staff.positionName = "Senior Waiter";
//         historyTracking.recordStaffUpdate(staff1, staff, "Promoted");
        
//         staff.phone = "9999999999";
//         historyTracking.recordStaffUpdate(staff1, staff, "Phone updated");
        
//         staff.workingShiftId = 2;
//         historyTracking.recordStaffUpdate(staff1, staff, "Shift changed");
        
//         // 3. Delete
//         staff.active = false;
//         historyTracking.recordStaffDelete(staff1, staff, "Resigned");
        
//         vm.stopPrank();
        
//         // Verify complete history
//         (HistoryEntry[] memory entries, uint256 total) = historyTracking.getHistoryByEntity(
//             EntityType.STAFF,
//             _addressToString(staff1),
//             0,
//             10
//         );
        
//         assertEq(total, 5);
//         assertTrue(entries[0].actionType == ActionType.DELETE);
//         assertTrue(entries[1].actionType == ActionType.UPDATE);
//         assertTrue(entries[2].actionType == ActionType.UPDATE);
//         assertTrue(entries[3].actionType == ActionType.UPDATE);
//         assertTrue(entries[4].actionType == ActionType.CREATE);
        
//         // Verify stats
//         (uint256 totalEntries, uint256 createCount, uint256 updateCount, uint256 deleteCount) = 
//             historyTracking.getHistoryStats(EntityType.STAFF);
        
//         assertEq(createCount, 1);
//         assertEq(updateCount, 3);
//         assertEq(deleteCount, 1);
//     }
    
//     function test_MultipleEntitiesTracking() public {
//         vm.startPrank(writer);
        
//         // Track staff
//         Staff memory staff = Staff({
//             wallet: staff1,
//             name: "Staff 1",
//             phone: "1234567890",
//             image: "staff1.jpg",
//             positionName: "Waiter",
//             workingShiftId: 1,
//             createdAt: block.timestamp,
//             active: true
//         });
//         historyTracking.recordStaffCreate(staff1, staff, "Staff created");
        
//         // Track manager
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = 1;
        
//         ManagerInfo memory manager = ManagerInfo({
//             wallet: manager1,
//             name: "Manager 1",
//             phone: "1234567890",
//             image: "manager1.jpg",
//             isCoOwner: true,
//             branchIds: branchIds,
//             hasFullAccess: true,
//             canViewData: true,
//             canEditData: true,
//             canProposeAndVote: true,
//             createdAt: block.timestamp,
//             active: true
//         });
//         historyTracking.recordManagerCreate(manager1, manager, "Manager created");
        
//         // Track payment info
//         PaymentInfo memory payment = PaymentInfo({
//             bankAccount: "123456789",
//             nameAccount: "John Doe",
//             nameOfBank: "ABC Bank",
//             taxCode: "TAX123",
//             wallet: "0xWallet"
//         });
//         PaymentInfo memory empty;
//         historyTracking.recordPaymentInfoUpdate(empty, payment, "Payment set");
        
//         vm.stopPrank();
        
//         // Verify each entity type has history
//         (HistoryEntry[] memory staffEntries, uint256 staffTotal) = 
//             historyTracking.getHistoryByType(EntityType.STAFF, 0, 10);
//         assertEq(staffTotal, 1);
        
//         (HistoryEntry[] memory managerEntries, uint256 managerTotal) = 
//             historyTracking.getHistoryByType(EntityType.MANAGER, 0, 10);
//         assertEq(managerTotal, 1);
        
//         (HistoryEntry[] memory paymentEntries, uint256 paymentTotal) = 
//             historyTracking.getHistoryByType(EntityType.PAYMENT_INFO, 0, 10);
//         assertEq(paymentTotal, 1);
        
//         // All history
//         (HistoryEntry[] memory allEntries, uint256 allTotal) = 
//             historyTracking.getAllHistory(0, 10);
//         assertEq(allTotal, 3);
//     }

//     // ==================== HELPER FUNCTIONS ====================
    
//     function _addressToString(address _addr) internal pure returns (string memory) {
//         bytes32 value = bytes32(uint256(uint160(_addr)));
//         bytes memory alphabet = "0123456789abcdef";
//         bytes memory str = new bytes(42);
//         str[0] = '0';
//         str[1] = 'x';
//         for (uint256 i = 0; i < 20; i++) {
//             str[2+i*2] = alphabet[uint8(value[i + 12] >> 4)];
//             str[3+i*2] = alphabet[uint8(value[i + 12] & 0x0f)];
//         }
//         return string(str);
//     }
    
//     address constant user1 = address(0x888);
// }