// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "../contracts/agentLoyalty.sol";
// import "../contracts/interfaces/IPoint.sol";
// import "./res_old.t.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// contract RestaurantLoyaltySystemTest is RestaurantTest {
//     // RestaurantLoyaltySystem public loyalty;
//     // RestaurantLoyaltySystem public loyaltyImplementation;
//     bytes32 public tierID_Silver;
//     bytes32 public tierID_Gold;
//     bytes32 public tierID_Platinum;
//     uint256 public eventId1;
//     uint256[] public eventIdArr;
//     function setUp() public {
//         vm.warp(currentTime); 
//     // //     // Deploy contract
//     //     vm.startPrank(Deployer);
//     //     loyalty = new RestaurantLoyaltySystem();
//     //     loyaltyImplementation = new RestaurantLoyaltySystem();
//     //     ERC1967Proxy loyaltyProxy = new ERC1967Proxy(
//     //         address(loyaltyImplementation),
//     //         abi.encodeWithSignature("initialize()")
//     //     );
//     //     loyalty = RestaurantLoyaltySystem(address(loyaltyProxy));
//     //     POINTS.setManagementSC(address(MANAGEMENT));

//     //     vm.stopPrank();
//         issuePoints();
//         setTierConfig();
//         createEvent();
//     }
//     function issuePoints() public {
//         vm.startPrank(admin);
//         uint256 _accumulationPercent = 120;
//         uint256 _maxPercentPerInvoice = 50; //han muc su dung diem de thanh toan tren moi bill
//         uint256 issuanceBefore = POINTS.totalSupply();
        
//         POINTS.issuePoints(100000, "Pho 24 point",true,_accumulationPercent,_maxPercentPerInvoice,10_000,false);
        
//         // Note: issuePoints only creates a record, doesn't automatically add to totalPointsIssued
//         // That happens when points are actually earned by members
        
//         vm.stopPrank();
//     }

//     function setTierConfig()public {
//         vm.startPrank(admin);
//         POINTS.createTierConfig("Silver",1000,110,"xanh");
//         POINTS.createTierConfig("Gold",3000,150,"do");
//         POINTS.createTierConfig("Platinum",7000,200,"vang");
//         TierConfig memory tier = POINTS.getTierConfigFromName("Silver");
//         tierID_Silver = tier.id;
//         tier = POINTS.getTierConfigFromName("Gold");
//         tierID_Gold = tier.id;
//         tier = POINTS.getTierConfigFromName("Platinum");
//         tierID_Platinum = tier.id;
//         //deleteTierConfig
//         POINTS.deleteTierConfig(tierID_Platinum);
//          vm.stopPrank();
//     }
//     function createEvent()public{
//         vm.startPrank(admin);
//         uint startTime = currentTime;
//         uint endTime = startTime + 180 days;
//         eventId1 = POINTS.createEvent(
//             "Tang new member",
//             startTime,
//             endTime,
//             200, //+200point
//             bytes32(0)
//         );
//         eventIdArr.push(eventId1);
//         vm.stopPrank();
//     }
//     // ============ TEST MEMBER REGISTRATION ============
    
//     // function testMemberRegistration() public {
//     //     vm.startPrank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     (
//     //         string memory memberId,
//     //         uint256 totalPoints,
//     //         uint256 lifetimePoints,
//     //         uint256 totalSpent,
//     //         bytes32 tierID,
//     //         string memory tierName,
//     //         bool isActive,
//     //         bool isLocked,,,,
//     //     ) = POINTS.getMember(customer1);
        
//     //     assertEq(memberId, "CUST0001");
//     //     assertEq(totalPoints, 0);
//     //     assertEq(lifetimePoints, 0);
//     //     assertEq(totalSpent, 0);
//     //     assertTrue(tierID == bytes32(0)); // bytes32(0)
//     //     assertTrue(isActive);
//     //     assertFalse(isLocked);
        
//     //     vm.stopPrank();
//     // }
    
//     // // ============ TEST EARN POINTS ============
    
//     // function testEarnPointsBasic() public {
//     //     // Register customer
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     // Staff helps customer earn points
//     //     // vm.startPrank(customer1);
        
//     //     uint256 amount = 100000; // 100k VND
//     //     uint256 expectedPoints = (amount / 10000)*120/100 +200; // = 10 points (exchangeRate = 10000)
                
//     //     POINTS.earnPoints("CUST0001", amount, keccak256("INV001"),eventId1);
        
//     //     (
//     //         ,
//     //         uint256 totalPoints,
//     //         uint256 lifetimePoints,
//     //         uint256 totalSpent,
//     //         ,,,,,,,
//     //     ) = POINTS.getMember(customer1);
        
//     //     assertEq(totalPoints, expectedPoints);
//     //     assertEq(lifetimePoints, expectedPoints);
//     //     assertEq(totalSpent, amount);
        
//     //     vm.stopPrank();
//     // }
    
//     // function testEarnPointsWithTierMultiplier() public {
//     //     // Register and reach Silver tier
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     // Earn enough to reach Silver (1000 points)
//     //     vm.startPrank(staff1);
//     //     POINTS.earnPoints("CUST0001", 10_000_000, keccak256("INV001"),eventId1); // 1000 points base
        
//     //     // Check tier upgraded to Silver
//     //     (,uint256 totalPoints,,, bytes32 tierID,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(tierID, tierID_Silver); // tierID_Silver
//     //     assertEq(totalPoints, 1400); //10_000_000/10_000 * 120/100 +200 = 1400

//     //     // Now earn more points with Silver multiplier (1.2x)
//     //     uint256 amount = 100_000; // 100k VND
//     //     uint256 basePoints = amount  * 120 /100/ 10_000; // 10 points
//     //     uint256 expectedPoints = (basePoints * 110) / 100 ; // 12 points with 1.2x
        
//     //     POINTS.earnPoints("CUST0001", amount, keccak256("INV002"),0);
        
//     //     Member memory member = POINTS.getEachMember(customer1);
        
//     //     assertEq(member.totalPoints, 1400 + expectedPoints);
//     //     assertEq(member.lifetimePoints, 1400 + expectedPoints);
        
//     //     vm.stopPrank();
//     // }
    
//     // function testCannotEarnPointsWithDuplicateInvoice() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.startPrank(staff1);
        
//     //     POINTS.earnPoints("CUST0001", 100000, keccak256("INV001"),eventId1);
        
//     //     vm.expectRevert("Invoice already processed");
//     //     POINTS.earnPoints("CUST0001", 100000, keccak256("INV001"),eventId1);
        
//     //     vm.stopPrank();
//     // }
    
//     // function testCannotEarnPointsForLockedMember() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     // Admin locks the member
//     //     vm.prank(admin);
//     //     POINTS.lockMember(customer1, "Suspicious activity");
        
//     //     // Staff tries to earn points
//     //     vm.prank(staff1);
//     //     vm.expectRevert("Account is locked");
//     //     POINTS.earnPoints("CUST0001", 100000, keccak256("INV001"),eventId1);
//     // }
    
//     // // ============ TEST TIER SYSTEM ============
    
//     // function testTierUpgrade() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.startPrank(staff1);
        
//     //     // Start at None tier
//     //     (,,,, bytes32 tierID,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(tierID,bytes32(0) ); // bytes32(0)
                
//     //     POINTS.earnPoints("CUST0001", 10000000, keccak256("INV001"),eventId1); // 1400 points
        
//     //     Member memory member = POINTS.getEachMember(customer1);
//     //     (string memory nameTier,,,) = POINTS.getTierConfig(member.tierID);
//     //     assertEq(nameTier, "Silver"); // tierID_Silver
        
//     //     // Earn more for Gold (3000 points total)
//     //     POINTS.earnPoints("CUST0001", 20000000, keccak256("INV002"),eventId1); // 2000 more points (with 1.2x = 2400)
//     //     member = POINTS.getEachMember(customer1);
//     //     (string memory nameTier1,,,) = POINTS.getTierConfig(member.tierID);
//     //     assertEq(nameTier1, "Gold");
        
//     //     vm.stopPrank();
//     // }
    
//     // // ============ TEST EVENTS & CAMPAIGNS ============
    
//     // function testCreateEvent() public {
//     //     vm.startPrank(admin);
        
//     //     uint256 startTime = block.timestamp;
//     //     uint256 endTime = block.timestamp + 7 days;
//     //     TierConfig memory tier = POINTS.getTierConfigFromName("Silver");
//     //     uint256 eventId = POINTS.createEvent(
//     //         "Tet 2025",
//     //         startTime,
//     //         endTime,
//     //         200, // 2x multiplier
//     //         tier.id
//     //     );
        
//     //     assertEq(eventId, 2);
        
//     //     (
//     //         string memory name,
//     //         uint256 start,
//     //         uint256 end,
//     //         uint256 pointPlus,
//     //         bytes32 tierID,
//     //         bool isActive
//     //     ) = POINTS.getEvent(eventId);
        
//     //     assertEq(name, "Tet 2025");
//     //     assertEq(start, startTime);
//     //     assertEq(end, endTime);
//     //     assertEq(pointPlus, 200);
//     //     (string memory nameTier,,,) = POINTS.getTierConfig(tierID);
//     //     assertEq(nameTier, "Silver"); // tierID_Silver
//     //     assertTrue(isActive);
        
//     //     vm.stopPrank();
//     //     GetByteCode2();
//     // }
    
//     // function testEarnPointsWithEvent() public {
//     //     // Setup: Register customer and reach Silver tier
//     //     vm.warp(currentTime);
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 10_000_000, keccak256("INV001"),eventId1); // Reach Silver
//     //     Member memory member = POINTS.getEachMember(customer1);
//     //     assertEq(member.tierID,tierID_Silver);
//     //     assertEq(member.totalPoints, 1400); //=10_000_000/10_000 *1,2 + 200
//     //     // Create event
//     //     TierConfig memory tier = POINTS.getTierConfigFromName("Silver");
//     //     vm.prank(admin);
//     //     uint eventId2 = POINTS.createEvent(
//     //         "Tet 2025",
//     //         currentTime,
//     //         currentTime + 300 days,
//     //         300, 
//     //         tier.id
//     //     );
//     //     // Earn points during event
//     //     vm.prank(staff1);
//     //     uint256 amount = 100_000 ; // 100k VND *accumulationPercent(120%)
//     //     uint256 basePoints = amount *120/100 / 10_000; // 10 points
//     //     uint256 tierPoints = (basePoints * 110) / 100; // 11 points (Silver 1.2x)
//     //     uint256 eventPoints = 300; // 24 points (Event 2x)
//     //     POINTS.earnPoints("CUST0001", amount, keccak256("INV002"),eventId2);
        
//     //    member = POINTS.getEachMember(customer1);
        
//     //     assertEq(member.totalPoints, 1400 + tierPoints + eventPoints);
//     // }
    
//     // // ============ TEST REWARDS ============
    
//     // function testRedeemPoints() public {
//     //     // Setup customer with points
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 20_000_000, keccak256("INV001"),eventId1); // ~2800 points
        
//     //     // Redeem
//     //     vm.startPrank(customer1);
//     //     (,uint256 totalCount) = POINTS.getMemberVouchersPagination(customer1,0,10);
//     //     assertEq(totalCount,0);
//     //     uint256 pointsBefore;
//     //     (
//     //         ,
//     //         pointsBefore,
//     //         ,,,,,,,,,
//     //     ) = POINTS.getMember(customer1);
//     //     POINTS.redeemVoucher("KM20");
        
//     //     uint256 pointsAfter;
//     //     (
//     //         ,
//     //         pointsAfter,
//     //         ,,,,,,,,,
//     //     ) = POINTS.getMember(customer1);
        
//     //     assertEq(pointsAfter, pointsBefore - 200);
//     //     (, totalCount) = POINTS.getMemberVouchersPagination(customer1,0,10);
//     //     assertEq(totalCount,1);

//     //     // // Check reward quantity decreased
//     //     // (,, , uint256 quantity,) = POINTS.getReward(rewardId);
//     //     // assertEq(quantity, 99);
        
//     //     vm.stopPrank();
//     // }
    
//     // function testCannotRedeemWithInsufficientPoints() public {
//     //     vm.warp(currentTime);
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 100_000, keccak256("INV001"),0); // 120 points
        
//     //     // vm.prank(admin);
//     //     // uint256 rewardId = POINTS.createReward("Expensive Gift", 1000, bytes32(0), 10, "Gift");
        
//     //     vm.prank(customer1);
//     //     vm.expectRevert("Insufficient points");
//     //     POINTS.redeemVoucher("KM20");
//     // }
        
//     // // ============ TEST MANUAL REQUESTS ============
    
//     // function testCreateManualRequest() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.startPrank(staff1);
                
//     //     uint256 requestId = POINTS.createManualRequest(
//     //         "CUST0001",
//     //         keccak256("INV001"),
//     //         100000,
//     //         RequestEarnPointType.OldBill,
//     //         "img"
//     //     );
        
//     //     assertEq(requestId, 1);
        
//     //     (
//     //         address member,
//     //         bytes32 invoiceId,
//     //         uint256 amount,
//     //         uint256 pointsToEarn,
//     //         address requestedBy,
//     //         RequestStatus status,
//     //         RequestEarnPointType typeRequest
//     //     ) = POINTS.getManualRequest(requestId);
        
//     //     assertEq(member, customer1);
//     //     assertEq(invoiceId, keccak256("INV001"));
//     //     assertEq(amount, 100000);
//     //     assertEq(pointsToEarn, 10);
//     //     assertEq(requestedBy, staff1);
//     //     assertEq(uint8(status), 0); // Pending
//     //     assertEq(uint8(typeRequest), 0);
        
//     //     vm.stopPrank();
//     // }
    
//     // function testStaffDailyRequestLimit() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.startPrank(staff1);
        
//     //     // Create 50 requests (the limit)
//     //     for (uint256 i = 1; i <= 50; i++) {
//     //         bytes32 invoiceId = keccak256(abi.encodePacked("INV", vm.toString(i)));
//     //         POINTS.createManualRequest("CUST0001", invoiceId, 100000, RequestEarnPointType.OldBill,"img");
//     //     }
        
//     //     // 51st should fail
//     //     vm.expectRevert("Daily request limit reached");
//     //     POINTS.createManualRequest("CUST0001", bytes32(0), 100000, RequestEarnPointType.OldBill,"img");
        
//     //     vm.stopPrank();
        
//     //     // Next day, limit resets
//     //     vm.warp(block.timestamp + 1 days);
        
//     //     vm.prank(staff1);
//     //     uint256 requestId = POINTS.createManualRequest("CUST0001", bytes32(0), 100000, RequestEarnPointType.OldBill,"img");
//     //     assertEq(requestId, 51);
//     // }
    
//     // function testApproveManualRequest() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     uint256 requestId = POINTS.createManualRequest("CUST0001", bytes32(0), 100000, RequestEarnPointType.OldBill,"img");
        
//     //     vm.startPrank(admin);
        
//     //     POINTS.approveManualRequest(requestId);
        
//     //     // Check points were added
//     //     (
//     //         ,
//     //         uint256 totalPoints,
//     //         ,,,,,,,,,
//     //     ) = POINTS.getMember(customer1);
        
//     //     assertEq(totalPoints, 10); // 100000 / 10000 = 10 points
        
//     //     // Check request status
//     //     (,,,,, RequestStatus status,) = POINTS.getManualRequest(requestId);
//     //     assertEq(uint8(status), 1); // Approved
        
//     //     vm.stopPrank();
//     // }
    
//     // function testRejectManualRequest() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     uint256 requestId = POINTS.createManualRequest("CUST0001", bytes32(0), 100000, RequestEarnPointType.OldBill,"img");
        
//     //     vm.startPrank(admin);
                
//     //     POINTS.rejectManualRequest(requestId, "Invalid invoice");
        
//     //     // Check points were NOT added
//     //     (
//     //         ,
//     //         uint256 totalPoints,
//     //         ,,,,,,,,,
//     //     ) = POINTS.getMember(customer1);
        
//     //     assertEq(totalPoints, 0);
        
//     //     // Check request status
//     //     (,,,,, RequestStatus status,) = POINTS.getManualRequest(requestId);
//     //     assertEq(uint8(status), 2); // Rejected
        
//     //     vm.stopPrank();
//     // }
    
//     // function testBatchApproveRequests() public {
//     //     // Register multiple customers
//     //     vm.prank(customer1);
//     //     POINTS.registerMember(RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     }));
        
//     //     vm.prank(customer2);
//     //     POINTS.registerMember(RegisterInPut({
//     //         _memberId :"CUST0002",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van B",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     }));
//     //     address customer3 = address(0x111111);
//     //     vm.prank(customer3);
//     //     POINTS.registerMember(RegisterInPut({
//     //         _memberId :"CUST0003",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van C",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     }));
        
//     //     // Staff creates multiple requests
//     //     vm.startPrank(staff1);
//     //     POINTS.createManualRequest("CUST0001", bytes32(0), 100000, RequestEarnPointType.OldBill,"img");
//     //     POINTS.createManualRequest("CUST0002", keccak256("INV002"), 200000, RequestEarnPointType.OldBill,"img");
//     //     POINTS.createManualRequest("CUST0003", keccak256("INV003"), 150000, RequestEarnPointType.OldBill,"img");
//     //     vm.stopPrank();
        
//     //     // Admin batch approves
//     //     vm.prank(admin);
//     //     uint256[] memory requestIds = new uint256[](3);
//     //     requestIds[0] = 1;
//     //     requestIds[1] = 2;
//     //     requestIds[2] = 3;
        
//     //     POINTS.batchApproveRequests(requestIds);
        
//     //     // Check all were approved and points added
//     //     (, uint256 points1,,,,,,,,,,) = POINTS.getMember(customer1);
//     //     (, uint256 points2,,,,,,,,,,) = POINTS.getMember(customer2);
//     //     (, uint256 points3,,,,,,,,,,) = POINTS.getMember(customer3);
        
//     //     assertEq(points1, 10);  // 100k / 10k
//     //     assertEq(points2, 20);  // 200k / 10k
//     //     assertEq(points3, 15);  // 150k / 10k
//     // }
    
//     // // ============ TEST ADMIN FUNCTIONS ============
    
//     // function testAdjustPointsManual() public {
//     //     vm.warp(currentTime); 
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 1_000_000, keccak256("INV001"),eventId1); // 100 points
//     //     (, uint256 points,,,,,,,,,,) = POINTS.getMember(customer1);
//     //     uint kq = 1_000_000 * 120/100/10_000+200 ;// =320;
//     //     assertEq(points, kq ); //320
//     //     vm.startPrank(admin);
        
//     //     // Add points manually
//     //     POINTS.adjustPoints(customer1, 50, "Compensation for service issue");
        
//     //     (, uint256 points1,,,,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(points1, kq + 50);
        
//     //     // Subtract points manually
//     //     POINTS.adjustPoints(customer1, -30, "Correction for duplicate entry");
        
//     //     (, uint256 points2,,,,,,,,,,)= POINTS.getMember(customer1);
//     //     assertEq(points2, kq + 50 - 30);
        
//     //     vm.stopPrank();
//     // }
    
//     // function testAdjustPointsRequiresReason() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(admin);
//     //     vm.expectRevert("Reason required");
//     //     POINTS.adjustPoints(customer1, 50, "");
//     // }
    
//     // function testRefundPoints() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 500_000, keccak256("INV001"),eventId1); // 50 points
        
//     //     (, uint256 pointsBefore,,,,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(pointsBefore, 260); //500_000*1,2/10_000
        
//     //     vm.startPrank(admin);
                
//     //     POINTS.refundPoints(customer1, keccak256("INV001"), "Customer cancelled order");
        
//     //     (, uint256 pointsAfter,,,,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(pointsAfter, 0);
        
//     //     // Invoice should be unmarked as processed
//     //     assertFalse(POINTS.isInvoiceProcessed(keccak256("INV001")));
        
//     //     vm.stopPrank();
//     // }
    
//     // function testLockAndUnlockMember() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.startPrank(admin);
        
//     //     // Lock member
//     //     POINTS.lockMember(customer1, "Suspicious activity");
        
//     //     (,,,,,, bool isLocked,,,,,) = POINTS.getMember(customer1);
//     //     assertTrue(isLocked);
        
//     //     // Unlock member
        
//     //     POINTS.unlockMember(customer1);
        
//     //     Member memory member = POINTS.getEachMember(customer1);
//     //     assertFalse(member.isLocked);
        
//     //     vm.stopPrank();
//     // }
    
//     // function testIssuePoints() public {
//     //     vm.startPrank(admin);
        
//     //     uint256 issuanceBefore = POINTS.totalPointsIssued();
        
//     //     POINTS.issuePoints(100000, "Pho 24 point",true,120,50,10_000,false);
        
//     //     // Note: issuePoints only creates a record, doesn't automatically add to totalPointsIssued
//     //     // That happens when points are actually earned by members
        
//     //     vm.stopPrank();
//     // }
    
//     // function testExpirePoints() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 1000000, keccak256("INV001"),eventId1); // 100 points
        
//     //     // Fast forward past expiry period (365 days)
//     //     vm.warp(block.timestamp + 366 days);
        
//     //     vm.startPrank(admin);
                
//     //     POINTS.expirePoints(customer1);
        
//     //     (, uint256 points,,,bytes32 tierID,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(points, 0);
//     //     assertEq(tierID, bytes32(0)); // Back to None
        
//     //     vm.stopPrank();
//     // }
        
//     // // ============ TEST STAFF PERMISSIONS ============
    
//     // function testStaffCanEarnPoints() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 100_000, keccak256("INV001"),eventId1);
        
//     //     (, uint256 points,,,,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(points, 212); //100_000*1,2/10_000 +200
//     // }
    
//     // function testStaffCanCreateManualRequest() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     uint256 requestId = POINTS.createManualRequest("CUST0001", bytes32(0), 100000, RequestEarnPointType.OldBill,"img");
//     //     assertEq(requestId, 1);
//     // }
    
//     // function testStaffCanRedeemPointsForCustomer() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 1000000, keccak256("INV001"),eventId1); // 100 points
        
//     //     vm.prank(staff2);
//     //     POINTS.redeemPointsForCustomer(customer1, 50, "Redeemed at counter");
        
//     //     (, uint256 points,,,,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(points, 270);
//     // }
    
//     // function testStaffCannotApproveRequests() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     uint256 requestId = POINTS.createManualRequest("CUST0001", bytes32(0), 100000, RequestEarnPointType.OldBill,"img");
        
//     //     address staff3 = address(0x2222);
//     //     vm.prank(staff3);
//     //     vm.expectRevert("Only admin");
//     //     POINTS.approveManualRequest(requestId);
//     // }
    
//     // function testStaffCannotLockMembers() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(staff1);
//     //     vm.expectRevert("Only admin");
//     //     POINTS.lockMember(customer1, "hoa don het han");
//     // }
    
//     // function testStaffCannotCreateEvents() public {
//     //     vm.prank(staff1);
//     //     vm.expectRevert("Only admin");
//     //     TierConfig memory tier = POINTS.getTierConfigFromName("Silver");
//     //     POINTS.createEvent(
//     //         "Test Event",
//     //         block.timestamp,
//     //         block.timestamp + 7 days,
//     //         200,
//     //         tier.id

//     //     );
//     // }
    
//     // // ============ TEST VIEW FUNCTIONS ============
    
//     // function testGetMemberByMemberId() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     (
//     //         address wallet,
//     //         uint256 totalPoints,
//     //         uint256 lifetimePoints,
//     //         bytes32 tierID,
//     //         bool isActive,
//     //         bool isLocked
//     //     ) = POINTS.getMemberByMemberId("CUST0001");
        
//     //     assertEq(wallet, customer1);
//     //     assertEq(totalPoints, 0);
//     //     assertEq(lifetimePoints, 0);
//     //     assertEq(tierID, bytes32(0));
//     //     assertTrue(isActive);
//     //     assertFalse(isLocked);
//     // }
    
//     function testGetMemberTransactions() public {
//         vm.prank(customer1);
//         RegisterInPut memory input = RegisterInPut({
//             _memberId :"CUST0001",
//             _phoneNumber:"0123456789",
//             _firstName: "Nguyen",
//             _lastName:"Van A",
//             _whatsapp:"+84365621276",
//             _email:"abc@gmail.com",
//             _avatar:"avatar"

//         });
//         POINTS.registerMember(input);
//         vm.startPrank(Deployer);
//         ORDER.setInvoiceAmountTest(keccak256("INV001"),100000,0); //for test only
//         ORDER.setInvoiceAmountTest(keccak256("INV002"),200000,0);
//         ORDER.setInvoiceAmountTest(keccak256("INV003"),150000,0);
//         vm.stopPrank();
//         vm.startPrank(staff1);
//         POINTS.earnPoints("CUST0001", 100000, keccak256("INV001"),eventIdArr);
//         POINTS.earnPoints("CUST0001", 200000, keccak256("INV002"),eventIdArr);
//         POINTS.earnPoints("CUST0001", 150000, keccak256("INV003"),eventIdArr);
//         vm.stopPrank();
        
//         uint256[] memory txIds = POINTS.getMemberTransactions(customer1);
//         assertEq(txIds.length, 3);
//         assertEq(txIds[0], 2); //tx dau tien la issue point
//         assertEq(txIds[1], 3);
//         assertEq(txIds[2], 4);
//         (Transaction[] memory result,uint256 totalCount) = POINTS.getMemberTransactionsPagination(customer1,0,10);
//         console.log("totalCount la:",totalCount);
//     }
    
//     function testGetTransaction() public {
//         vm.prank(customer1);
//         RegisterInPut memory input = RegisterInPut({
//             _memberId :"CUST0001",
//             _phoneNumber:"0123456789",
//             _firstName: "Nguyen",
//             _lastName:"Van A",
//             _whatsapp:"+84365621276",
//             _email:"abc@gmail.com",
//             _avatar:"avatar"

//         });
//         POINTS.registerMember(input);

//         vm.startPrank(Deployer);
//         ORDER.setInvoiceAmountTest(keccak256("INV001"),100000,0);        
//         vm.stopPrank();

//         vm.prank(staff1);
//         POINTS.earnPoints("CUST0001", 100000, keccak256("INV001"),eventIdArr);
        
//         (
//             address member,
//             TransactionType txType,
//             int256 points,
//             uint256 amount,
//             bytes32 invoiceId,
//             uint256 timestamp,
//             string memory note
//         ) = POINTS.getTransaction(2);
        
//         assertEq(member, customer1);
//         assertEq(uint8(txType), 1); // TransactionType.Earn
//         assertEq(points, 212);
//         assertEq(amount, 100000);
//         assertEq(invoiceId, keccak256("INV001"));
//         assertGt(timestamp, 0);
//     }
    
//     function testGetActiveEvents() public {
//         vm.startPrank(admin);
//         uint currentTime = 1760515357;
//         vm.warp(currentTime);
//         // Create active event
//         POINTS.createEvent(
//             "Active Event 1",
//             currentTime,
//             currentTime + 7 days,
//             200,
//             bytes32(0)
//         );
        
//         // Create future event (not yet started)
//         POINTS.createEvent(
//             "Future Event",
//             currentTime + 10 days,
//             currentTime + 20 days,
//             200,
//             bytes32(0)
//         );
        
//         // Create another active event
//         POINTS.createEvent(
//             "Active Event 2",
//             currentTime - 1 days,
//             currentTime + 5 days,
//             150,
//             bytes32(0)
//         );
        
//         vm.stopPrank();
        
//         uint256[] memory activeEvents = POINTS.getActiveEvents();
//         assertEq(activeEvents.length, 2);
//         assertEq(activeEvents[0], 2);
//         assertEq(activeEvents[1], 4);
//     }
    
//     function testGetPendingRequests() public {
//         vm.prank(customer1);
//         RegisterInPut memory input = RegisterInPut({
//             _memberId :"CUST0001",
//             _phoneNumber:"0123456789",
//             _firstName: "Nguyen",
//             _lastName:"Van A",
//             _whatsapp:"+84365621276",
//             _email:"abc@gmail.com",
//             _avatar:"avatar"

//         });
//         POINTS.registerMember(input);
        
//         vm.startPrank(staff1);
//         POINTS.createManualRequest("CUST0001", bytes32(0), 100000, RequestEarnPointType.OldBill,"img");
//         POINTS.createManualRequest("CUST0001", keccak256("INV002"), 200000, RequestEarnPointType.OldBill,"img");
//         POINTS.createManualRequest("CUST0001", keccak256("INV003"), 150000, RequestEarnPointType.OldBill,"img");
//         vm.stopPrank();
        
//         (ManualRequest[] memory pending,) = POINTS.getRequestsByStatusPagination(RequestStatus.Pending,0,10);
//         assertEq(pending.length, 3);
        
//         // Approve one
//         vm.prank(admin);
//         POINTS.approveManualRequest(1);
        
//         (pending,) = POINTS.getRequestsByStatusPagination(RequestStatus.Pending,0,10);
//         assertEq(pending.length, 2);
//         assertEq(pending[1].invoiceId,  keccak256("INV002"));
//         assertEq(pending[0].invoiceId, keccak256("INV003"));
//     }
    
//     // function testCalculatePointsFromAmount() public {
//     //     vm.prank(customer1);
//     //     RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     // Without tier (None)
//     //     uint256 points1 = POINTS.calculatePointsFromAmount(100000,customer1, eventId1);
//     //     assertEq(points1, 10); // 100k / 10k = 10
        
//     //     // Reach Silver tier
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 10000000, keccak256("INV001"),eventId1);
        
//     //     // With Silver tier (1.2x)
//     //     uint256 points2 = POINTS.calculatePointsFromAmount(100000,customer1, eventId1);
//     //     assertEq(points2, 12); // 10 * 1.2 = 12
        
//     //     // Create event with 2x multiplier
//     //     vm.prank(admin);
//     //     TierConfig memory tier = POINTS.getTierConfigFromName("Silver");
//     //     POINTS.createEvent(
//     //         "Double Points",
//     //         block.timestamp,
//     //         block.timestamp + 7 days,
//     //         200,
//     //         tier.id
//     //     );
        
//     //     // With event (1.2x tier * 2x event = 2.4x)
//     //     uint256 points3 = POINTS.calculatePointsFromAmount(100000, customer1, eventId1);
//     //     assertEq(points3, 24); // 10 * 1.2 * 2 = 24
//     // }
    
//     // function testGetTierConfig() public {
//     //     (
//     //         string memory nameTier,
//     //         uint256 pointsRequired,
//     //         uint256 multiplier,
//     //         uint256 pointsMax
//     //     ) = POINTS.getTierConfig(tierID_Gold);
        
//     //     assertEq(pointsRequired, 3000);
//     //     assertEq(multiplier, 150); // 1.5x
//     // }
    
//     // function testGetSystemStats() public {
//     //     // Register some members
//     //     vm.prank(customer1);
//     //      RegisterInPut memory input = RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van A",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     });
//     //     POINTS.registerMember(input);
        
//     //     vm.prank(customer2);
//     //     POINTS.registerMember(RegisterInPut({
//     //         _memberId :"CUST0002",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van B",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     }));
        
//     //     // Earn some points
//     //     vm.startPrank(staff1);
//     //     POINTS.earnPoints("CUST0001", 100000, keccak256("INV001"),eventId1);
//     //     POINTS.earnPoints("CUST0002", 200000, keccak256("INV002"),eventId1);
//     //     vm.stopPrank();
        
//     //     // // Create reward and redeem
//     //     // vm.prank(admin);
//     //     // uint256 rewardId = POINTS.createReward("Gift", 10, bytes32(0), 5, RequestEarnPointType.OldBill,"img");
        
//     //     // vm.prank(customer1);
//     //     // POINTS.redeemPoints(rewardId);
        
//     //     // (
//     //     //     uint256 totalIssued,
//     //     //     uint256 totalRedeemed,
//     //     //     ,
//     //     //     uint256 totalTransactions,
//     //     //     ,
//     //     // ) = POINTS.getSystemStats();
        
//     //     // assertEq(totalIssued, 30); // 10 + 20 from earnPoints
//     //     // assertEq(totalRedeemed, 10);
//     //     // assertEq(totalTransactions, 3); // 2 earn + 1 redeem
//     // }
    
//     // // ============ TEST SYSTEM SETTINGS ============
    
//     // function testUpdateExchangeRate() public {
//     //     uint256 oldRate = POINTS.exchangeRate();
//     //     assertEq(oldRate, 10000);
        
//     //     vm.prank(admin);
//     //     POINTS.updateExchangeRate(20000);
        
//     //     uint256 newRate = POINTS.exchangeRate();
//     //     assertEq(newRate, 20000);
        
//     //     // Test earning with new rate
//     //     vm.prank(customer1);
//     //     POINTS.registerMember(RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van B",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     }));        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 100000, keccak256("INV001"),eventId1);
        
//     //     (, uint256 points,,,,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(points, 5); // 100k / 20k = 5 points
//     // }
    
//     // function testUpdatePointExpiryPeriod() public {
//     //     vm.prank(admin);
//     //     POINTS.updatePointExpiryPeriod(180 days);
        
//     //     assertEq(POINTS.pointExpiryPeriod(), 180 days);
//     // }
    
//     // function testUpdateSessionDuration() public {
//     //     vm.prank(admin);
//     //     POINTS.updateSessionDuration(60 days);
        
//     //     assertEq(POINTS.sessionDuration(), 60 days);
//     // }
    
//     // function testUpdateTierConfig() public {
//     //     vm.prank(admin);
//     //     POINTS.updateTierConfig(
//     //         tierID_Silver,
//     //         "Siver D",
//     //         2000,  // New points requirement
//     //         130,   // New multiplier (1.3x)
//     //         3000,
//     //         "yealow"
//     //     );
        
//     //     (
//     //         string memory nameTier,
//     //         uint256 pointsRequired,
//     //         uint256 multiplier,
//     //         uint256 pointsMax
//     //     ) = POINTS.getTierConfig(tierID_Silver);
        
//     //     assertEq(pointsRequired, 2000);
//     //     assertEq(multiplier, 130);
//     // }
    
//     // function testToggleEvent() public {
//     //     vm.startPrank(admin);
        
//     //     uint256 eventId = POINTS.createEvent(
//     //         "Test Event",
//     //         block.timestamp,
//     //         block.timestamp + 7 days,
//     //         200,
//     //         bytes32(0)
//     //         // 0,
//     //         // 0,
//     //         // "Test"
//     //     );
        
//     //     (,,,,, bool isActive1) = POINTS.getEvent(eventId);
//     //     assertTrue(isActive1);
        
//     //     POINTS.toggleEvent(eventId, false);
        
//     //     (,,,,, bool isActive2) = POINTS.getEvent(eventId);
//     //     assertFalse(isActive2);
        
//     //     POINTS.toggleEvent(eventId, true);
        
//     //     (,,,,, bool isActive3) = POINTS.getEvent(eventId);
//     //     assertTrue(isActive3);
        
//     //     vm.stopPrank();
//     // }
    
    
//     // // ============ TEST EDGE CASES ============
    
//     // function testCannotEarnZeroPoints() public {
//     //     vm.prank(customer1);
//     //     POINTS.registerMember(RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van B",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     })); 
        
//     //     vm.prank(staff1);
//     //     vm.expectRevert("Invalid amount");
//     //     POINTS.earnPoints("CUST0001", 0, keccak256("INV001"),eventId1);
//     // }
    
//     // // function testCannotRedeemFromInactiveReward() public {
//     // //     vm.prank(customer1);
//     // //     POINTS.registerMember("CUST0001", "0123456789", "Customer");
        
//     // //     vm.prank(staff1);
//     // //     POINTS.earnPoints("CUST0001", 1000000, keccak256("INV001"),eventId1);
        
//     // //     vm.startPrank(admin);
//     // //     uint256 rewardId = POINTS.createReward("Test", 50, bytes32(0), 10, RequestEarnPointType.OldBill,"img");
//     // //     POINTS.toggleReward(rewardId, false);
//     // //     vm.stopPrank();
        
//     // //     vm.prank(customer1);
//     // //     vm.expectRevert("Reward not active");
//     // //     POINTS.redeemPoints(rewardId);
//     // // }
    
//     // // function testCannotRedeemOutOfStockReward() public {
//     // //     vm.prank(customer1);
//     // //     POINTS.registerMember("CUST0001", "0123456789", "Customer");
        
//     // //     vm.prank(staff1);
//     // //     POINTS.earnPoints("CUST0001", 1000000, keccak256("INV001"),eventId1);
        
//     // //     vm.startPrank(admin);
//     // //     uint256 rewardId = POINTS.createReward("Test", 50, bytes32(0), 0, RequestEarnPointType.OldBill,"img");
//     // //     vm.stopPrank();
        
//     // //     vm.prank(customer1);
//     // //     vm.expectRevert("Reward out of stock");
//     // //     POINTS.redeemPoints(rewardId);
//     // // }
    
//     // function testCannotSubtractMorePointsThanAvailable() public {
//     //     vm.prank(customer1);
//     //     POINTS.registerMember(RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van B",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     })); 
        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 500000, keccak256("INV001"),eventId1); // 50 points
        
//     //     vm.prank(admin);
//     //     vm.expectRevert("Insufficient points");
//     //     POINTS.adjustPoints(customer1, -100, "sai sot");
//     // }
    
//     // function testMultipleTierUpgradesInOneTransaction() public {
//     //     vm.prank(customer1);
//     //     POINTS.registerMember(RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van B",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     }));         
//     //     // Earn enough to jump from None to Gold directly
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 30000000, keccak256("INV001"),eventId1); // 3000 points
        
//     //     (,,,, bytes32 tierID,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(tierID, tierID_Gold); // Should be Gold
//     // }
    
//     // function testInvoiceCanBeReusedAfterRefund() public {
//     //     vm.prank(customer1);
//     //     POINTS.registerMember(RegisterInPut({
//     //         _memberId :"CUST0001",
//     //         _phoneNumber:"0123456789",
//     //         _firstName: "Nguyen",
//     //         _lastName:"Van B",
//     //         _whatsapp:"+84365621276",
//     //         _email:"abc@gmail.com",
//     //         _avatar:"avatar"

//     //     }));         
        
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 100000, keccak256("INV001"),eventId1);
        
//     //     assertTrue(POINTS.isInvoiceProcessed(keccak256("INV001")));
        
//     //     // Refund
//     //     vm.prank(admin);
//     //     POINTS.refundPoints(customer1, keccak256("INV001"), "Order cancelled");
        
//     //     assertFalse(POINTS.isInvoiceProcessed(keccak256("INV001")));
        
//     //     // Can use same invoice again
//     //     vm.prank(staff1);
//     //     POINTS.earnPoints("CUST0001", 100000, keccak256("INV001"),eventId1);
        
//     //     (, uint256 points,,,,,,,,,,) = POINTS.getMember(customer1);
//     //     assertEq(points, 10);
//     // }
    
//     // ============ TEST FULL USER JOURNEY ============
    
//     function testFullUserJourney() public {
//         console.log("=== Starting Full User Journey Test ===");
        
//         // 1. Customer registers
//         console.log("1. Customer registration");
//         vm.prank(customer1);
//         RegisterInPut memory input = RegisterInPut({
//             _memberId :"CUST0001",
//             _phoneNumber:"0123456789",
//             _firstName: "Nguyen",
//             _lastName:"Van A",
//             _whatsapp:"+84365621276",
//             _email:"abc@gmail.com",
//             _avatar:"avatar"

//         });
//         POINTS.registerMember(input);
        
//         // 2. Customer makes first purchase (100k VND)
//         vm.startPrank(Deployer);
//         ORDER.setInvoiceAmountTest(keccak256("INV001"),100_000,0);        
//         vm.stopPrank();

//         console.log("2. First purchase - earning points");
//         vm.prank(staff1);
//         POINTS.earnPoints("CUST0001", 100_000, keccak256("INV001"),eventIdArr);
        
//         (, uint256 points1,,,,,,,,,,) = POINTS.getMember(customer1);
//         console.log("Points after first purchase:", points1);
//         assertEq(points1, 212);
        
//         // 3. Customer accumulates points to reach Silver
//         console.log("3. Accumulating points to Silver tier");
//          vm.startPrank(Deployer);
//         ORDER.setInvoiceAmountTest(keccak256("INV002"),10_000_000,0); //for test only
//         vm.stopPrank();
//         vm.prank(staff1);
//         POINTS.earnPoints("CUST0001", 10_000_000, keccak256("INV002"),eventIdArr); // 1000 points
        
//         (,,,, bytes32 tierId,,,,,,,) = POINTS.getMember(customer1);
//         // console.log("Tier after accumulation:", tierId);
//         assertEq(tierId, tierID_Silver); // Silver
        
//         // 4. Admin creates double points event
//         console.log("4. Admin creates double points event");
//         vm.prank(admin);
//         TierConfig memory tier = POINTS.getTierConfigFromName("Silver");
//         vm.prank(admin);
//         uint256 eventId = POINTS.createEvent(
//             "Tet 2025",
//             block.timestamp,
//             block.timestamp + 7 days,
//             200, 
//             tier.id
//         );
        
//         // 5. Customer purchases during event
//         console.log("5. Purchase during event");
//         vm.startPrank(Deployer);
//         ORDER.setInvoiceAmountTest(keccak256("INV003"),1000_000,0); //for test only
//         vm.stopPrank();
//         vm.prank(staff1);
//         POINTS.earnPoints("CUST0001", 1000_000, keccak256("INV003"),eventIdArr); // Should get (100 * 1.2 * 2) = 240 points
        
//         (, uint256 points2,,,,,,,,,,) = POINTS.getMember(customer1);
//         console.log("Points after event purchase:", points2);
        
//         // 6. Customer forgets to scan QR, staff creates manual request
//         console.log("6. Manual request created");
//         vm.prank(staff2);
//         uint256 requestId = POINTS.createManualRequest("CUST0001", "INV004", 500000, RequestEarnPointType.OldBill,"img");
        
//         // 7. Admin approves manual request
//         console.log("7. Admin approves manual request");
//         vm.prank(admin);
//         POINTS.approveManualRequest(requestId);
        
//         // 8. Admin creates discount voucher

//         // 9. Customer redeems points for coffee cup
//         console.log("9. Customer redeems coffee cup");
//         vm.prank(customer1);
//         POINTS.redeemVoucher("KM20");
        
//         (, uint256 pointsAfterRedeem,,,,,,,,,,) = POINTS.getMember(customer1);
//         console.log("Points after redemption:", pointsAfterRedeem);
        
//         // 10. Customer continues shopping to reach Gold
//         console.log("10. Shopping to reach Gold tier");
//          vm.startPrank(Deployer);
//         ORDER.setInvoiceAmountTest(keccak256("INV005"),10_000_000,0); //for test only
//         vm.stopPrank();

//         vm.prank(staff1);
//         POINTS.earnPoints("CUST0001", 10_000_000, keccak256("INV005"),eventIdArr);
        
//         Member memory member = POINTS.getEachMember(customer1);
//         // console.log("Final tier:", member.tierId);
//         //11.customer order use voucher and point to pay

//         // 12. Check transaction history
//         console.log("11. Checking transaction history");
//         uint256[] memory txIds = POINTS.getMemberTransactions(customer1);
//         console.log("Total transactions:", txIds.length);
//         // assertGt(txIds.length, 5);
        
//         console.log("=== Full User Journey Test Completed Successfully ===");
//     }
//     function GetByteCode2()public {
//         //POINTS.deleteTierConfig(tierID_Platinum);
//         bytes memory bytesCodeCall = abi.encodeCall(
//         POINTS.deleteTierConfig,
//             (
//                 0x98c424df1d46775037f5859d8b6453ada1a055eb9234cfeb0c14478ae66428df
//             )
//         );
//         console.log("POINTS deleteTierConfig:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  
//         //getTierConfig
//         bytesCodeCall = abi.encodeCall(
//         POINTS.getTierConfig,
//             (
//                 0x98c424df1d46775037f5859d8b6453ada1a055eb9234cfeb0c14478ae66428df
//             )
//         );
//         console.log("POINTS getTierConfig:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  
//         //getAllTiers
//         bytesCodeCall = abi.encodeCall(
//         POINTS.getAllTiers,
//             (
//             )
//         );
//         console.log("POINTS getAllTiers:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  

//     }

// }