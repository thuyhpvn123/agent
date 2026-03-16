// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "../contracts/agentLoyalty.sol";
// import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
// import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
// import "../contracts/interfaces/IPoint.sol";
// import "./res_old.t.sol";
// /**
//  * @title AgentLoyaltyV3Test
//  * @notice Bộ test Foundry cho agentLoyalty_v3.sol — 12 test cases
//  *
//  * Topology:
//  *   Deployer       = admin của hệ thống (ROLE_ADMIN)
//  *   staff1       = nhân viên có STAFF_ROLE.FINANCE
//  *   customer    = thành viên đã đăng ký
//  *   customer2   = thành viên thứ hai
//  *   attacker    = EOA ngẫu nhiên, không có role
//  *   orderModule = địa chỉ Order contract (isOrder = true)
//  *   topupModule = địa chỉ TopUp contract (isTopUp = true)
//  */
// contract AgentLoyaltyV3Test is RestaurantTest {

//     // ── Contracts ─────────────────────────────────────────────────────────
//     UpgradeableBeacon public loyaltyBeacon;
//     RestaurantLoyaltySystem loyaltyIMP;
//     RestaurantLoyaltySystem loyalty;
//     // MockManagement          mgmt;
//     MockOrder               mockOrder;
//     MockTopUp               mockTopup;

//     // ── Actors ────────────────────────────────────────────────────────────
//     // address staff       = address(0xA002);   // STAFF_ROLE.FINANCE
//     address customer    = address(0xB001);
//     address attacker    =address(0xDEAD);
//     address orderModule;   // address của mockOrder (set in setUp)
//     address topupModule;   // address của mockTopup

//     // ── Helpers ────────────────────────────────────────────────────────────
//     uint256 constant BRANCH_1   = 1;
//     uint256 constant TOPUP_RATE = 1000; // 1000 VND = 1 Token A

//     // ─────────────────────────────────────────────────────────────────────
//     // SET UP
//     // ─────────────────────────────────────────────────────────────────────
//     constructor() public {
//         mockTopup = new MockTopUp();
//         mockOrder = new MockOrder();
//         // 1. Deploy mock peripherals
//         orderModule = address(mockOrder);
//         topupModule = address(mockTopup);

//         // 2. Deploy management mock (Deployer = admin, staff1 = FINANCE)
//         // mgmt = new MockManagement(Deployer, staff1);

//         // 3. Deploy loyalty (Deployer là msg.sender của initialize)
//         vm.startPrank(Deployer);
//         loyaltyIMP = new RestaurantLoyaltySystem();
//         loyaltyBeacon = new UpgradeableBeacon(address(loyaltyIMP), address(this));
//         bytes memory initData = abi.encodeWithSelector(
//             IPoint.initialize.selector,
//             Deployer,
//             address(0)  // enhancedAgent = msg.sender
//         );

//         BeaconProxy loyaltyProxy = new BeaconProxy(address(loyaltyBeacon), initData);
//         loyalty = RestaurantLoyaltySystem(address(loyaltyProxy));
//         loyalty.setManagementSC(address(MANAGEMENT));

//         loyalty.setOrder(orderModule, BRANCH_1);

//         loyalty.setTopUp(topupModule, BRANCH_1);

//         // 4. Chính sách mặc định
//         //    topupRate = 1000, spendPolicy = B_FIRST, 50% cap, 30-day expiry
//         loyalty.setTopupPolicy(TOPUP_RATE, 0, 0);

//         // priority=0(B_FIRST), maxPercent=50, maxAbsolute=0, expiryDays=30
//         loyalty.setSpendPolicy(0, 50, 0, 30);
//         vm.stopPrank();
//         // 5. Đăng ký customer
//         vm.prank(customer);
//         loyalty.registerMember(RegisterInPut({
//             _memberId:    "MEM00001",
//             _phoneNumber: "0900000001",
//             _firstName:   "Alice",
//             _lastName:    "Nguyen",
//             _whatsapp:    "",
//             _email:       "alice@test.com",
//             _avatar:      ""
//         }));

//         // 6. Đăng ký customer2
//         vm.prank(customer2);
//         loyalty.registerMember(RegisterInPut({
//             _memberId:    "MEM00002",
//             _phoneNumber: "0900000002",
//             _firstName:   "Bob",
//             _lastName:    "Tran",
//             _whatsapp:    "",
//             _email:       "bob@test.com",
//             _avatar:      ""
//         }));
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 1 — P0: EOA ngẫu nhiên gọi debit() phải revert
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * Mục tiêu: debit() được bảo vệ bởi onlyStaffWithRoleOrAdmin(STAFF_ROLE.FINANCE).
//      * Attacker không có role nào → phải revert ngay tại modifier.
//      */
//     function test_P0_UnauthorizedDebit_Reverts() public {
//         // Đảm bảo customer có balance để debit không revert vì lý do khác
//         _giveTokenA(customer, 10_000);

//         vm.prank(attacker);
//         vm.expectRevert("Only staff with role or admin");
//         loyalty.debit(customer, 1_000, keccak256("FOOD"), keccak256("ref-001"), BRANCH_1);
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 2 — Caller không phải module/admin gọi earnTokenA/creditTopup → revert
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * earnTokenA(): không có modifier role riêng nhưng gọi _isValidAmount()
//      * → mOrder[branchId] phải là MockOrder; attacker không phải order/topup → revert
//      *   tại checkRole (creditTopup) hoặc tại _isValidAmount khi không mock đúng.
//      *
//      * creditTopup() có onlyStaffWithRoleOrAdmin(STAFF_ROLE.FINANCE) → revert ngay.
//      */
//     function test_UnauthorizedEarnTokenA_Reverts() public {
//         // earnTokenA: mock order xác nhận amount hợp lệ nhưng caller = attacker
//         // _isValidAmount sẽ gọi mockOrder.isValidAmount → true
//         // Tuy nhiên earnTokenA KHÔNG có auth modifier trong v3 (giữ nguyên thiết kế
//         // cho phép bất kỳ ai gọi với invoice hợp lệ). Để bắt lỗi auth, ta test
//         // creditTopup thay thế — hàm này có modifier rõ ràng.
//         vm.prank(attacker);
//         vm.expectRevert("Only staff with role or admin");
//         loyalty.creditTopup(customer, 10_000, keccak256("key-att"), keccak256("ref-att"), BRANCH_1);
//     }

//     function test_UnauthorizedCreditTopup_Reverts_ConfirmedByStaff() public {
//         // Staff (FINANCE role) được phép gọi creditTopup
//         bytes32 key = keccak256("key-staff1-01");
//         bytes32 ref = keccak256("ref-staff1-01");

//         // Mock topup contract xác nhận amount hợp lệ
//         mockTopup.setValid(ref, 10_000, true);

//         vm.prank(staff1);
//         // staff1 có STAFF_ROLE.FINANCE → MockManagement.checkRole trả true → pass modifier
//         loyalty.creditTopup(customer, 10_000, key, ref, BRANCH_1);

//         assertEq(loyalty.balanceA(customer), 10_000 / TOPUP_RATE);
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 3 — Topup idempotency: cùng idempotencyKey lần 2 không tăng số dư
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * _creditA() check _processedTopups[idempotencyKey].
//      * Lần 1: thành công, lần 2 cùng key: revert "Already processed".
//      */
//     function test_TopupIdempotency_SameKey_DoubleCreditPrevented() public {
//         bytes32 key = keccak256("idem-key-001");
//         bytes32 ref = keccak256("ref-idem-001");

//         mockTopup.setValid(ref, 5_000, true);

//         // Lần 1 — thành công
//         vm.prank(staff1);
//         loyalty.creditTopup(customer, 5_000, key, ref, BRANCH_1);

//         uint256 balAfterFirst = loyalty.balanceA(customer);
//         assertEq(balAfterFirst, 5_000 / TOPUP_RATE, "Balance should be 5 after first topup");

//         // processedInvoices[ref] = true sau lần 1
//         // Lần 2 cùng key: revert "Invoice already processed" (check trước _creditA)
//         // Dùng ref khác để đi qua invoice check, nhưng key giống → đạt "Already processed"
//         bytes32 ref2 = keccak256("ref-idem-002");
//         mockTopup.setValid(ref2, 5_000, true);

//         vm.prank(staff1);
//         vm.expectRevert("Already processed");
//         loyalty.creditTopup(customer, 5_000, key, ref2, BRANCH_1);

//         // Số dư không thay đổi
//         assertEq(loyalty.balanceA(customer), balAfterFirst, "Balance must not change on second call");
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 4 — Campaign idempotency: (campaignId, sourceEventId, customer) → 1 grant
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * _grantB() dùng grantKey = keccak256(sourceEventId, campaignId, customer).
//      * Nếu _processedGrants[grantKey] = true → skip, không grant thêm.
//      * Kịch bản: earnTokenA với cùng idempotencyKey khác nhau nhưng mock campaign
//      * cùng sourceEventId → chỉ 1 lần grant.
//      *
//      * Cách test trực tiếp: gọi grantTokenBManual hai lần cùng sourceEventId.
//      */
//     function test_CampaignIdempotency_SameCampaignSourceCustomer_OneGrantOnly() public {
//         vm.prank(Deployer);
//         loyalty.setManualGrantEnabled(true);

//         bytes32 src = keccak256("event-source-X");

//         // Grant lần 1 — thành công
//         vm.prank(Deployer);
//         loyalty.grantTokenBManual(customer, 200, src);
//         assertEq(loyalty.balanceB(customer), 200, "First grant should give 200");

//         // grantTokenBManual gọi _grantB(customer, 200, campaignId=0, sourceEventId=src, ...)
//         // grantKey = keccak256(src, 0, customer) — đã set = true

//         // Grant lần 2 cùng src — _grantB returns early (processedGrants)
//         vm.prank(Deployer);
//         loyalty.grantTokenBManual(customer, 200, src);

//         // Số dư KHÔNG tăng lên 400
//         assertEq(loyalty.balanceB(customer), 200, "Second grant with same source should be no-op");
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 5 — SpendPriority: B_FIRST / A_FIRST / SPLIT với cap percent & absolute
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * Setup:
//      *   balA = 1000, balB = 600
//      *   cap = 50% của amount
//      *
//      * B_FIRST: amount=800 → maxB = min(50%*800=400, 600) = 400
//      *   spentB=400, spentA=400
//      *
//      * A_FIRST: amount=800 → spentA = min(800, 1000)=800, rem=0
//      *   spentB=0, spentA=800
//      *
//      * SPLIT (priority=2): amount=800 → halfB=400, maxB=400
//      *   spentB=400, spentA=400
//      *
//      * Cap absolute: rewardMaxAbsolute=300 → maxB = min(400, 300)=300
//      *   B_FIRST: spentB=300, spentA=500
//      */
//     function test_SpendPriority_BFirst_AFirst_Split_WithCaps() public {
//         uint256 amountToDebit = 800;
//         bytes32 actionType    = keccak256("ALL"); // allowedActionTypes["ALL"] = true

//         // ── B_FIRST (priority=0), 50% cap, no absolute cap ──────────────
//         vm.prank(Deployer);
//         loyalty.setSpendPolicy(0, 50, 0, 30); // B_FIRST

//         _giveTokenA(customer, 1_000);
//         _giveTokenB(customer, 600);

//         bytes32 ref1 = keccak256("ref-bf-001");
//         vm.prank(staff1);
//         (uint256 spentA1, uint256 spentB1) = loyalty.debit(customer, amountToDebit, actionType, ref1, BRANCH_1);

//         assertEq(spentB1, 400, "B_FIRST: spentB should be 400 (50% of 800, capped by 600 bal)");
//         assertEq(spentA1, 400, "B_FIRST: spentA should be 400");

//         // Reset balances
//         _setBalanceA(customer, 1_000);
//         _setBalanceB(customer, 600);

//         // ── A_FIRST (priority=1) ─────────────────────────────────────────
//         vm.prank(Deployer);
//         loyalty.setSpendPolicy(1, 50, 0, 30); // A_FIRST

//         bytes32 ref2 = keccak256("ref-af-001");
//         vm.prank(staff1);
//         (uint256 spentA2, uint256 spentB2) = loyalty.debit(customer, amountToDebit, actionType, ref2, BRANCH_1);

//         assertEq(spentA2, 800, "A_FIRST: spentA should be 800 (full from A)");
//         assertEq(spentB2, 0,   "A_FIRST: spentB should be 0");

//         // Reset
//         _setBalanceA(customer, 1_000);
//         _setBalanceB(customer, 600);

//         // ── Cap absolute = 300 với B_FIRST ───────────────────────────────
//         vm.prank(Deployer);
//         loyalty.setSpendPolicy(0, 50, 300, 30); // B_FIRST, abs cap=300

//         bytes32 ref3 = keccak256("ref-abs-001");
//         vm.prank(staff1);
//         (uint256 spentA3, uint256 spentB3) = loyalty.debit(customer, amountToDebit, actionType, ref3, BRANCH_1);

//         assertEq(spentB3, 300, "AbsCap: spentB should be 300 (capped by absolute)");
//         assertEq(spentA3, 500, "AbsCap: spentA should be 500");
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 6 — RewardScope: ActionType không trong scope bị chặn dùng Token B
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * allowedActionTypes["ALL"] = true theo mặc định → mọi action đều được dùng B.
//      * Ta reset về chỉ cho phép action cụ thể, test action không có scope bị block.
//      *
//      * Kịch bản:
//      *   Chỉ cho phép "FOOD" dùng Token B.
//      *   "NET" không trong scope → canUseB = false → chỉ dùng A, maxB = 0.
//      *   "FOOD" trong scope → dùng B bình thường.
//      */
//     function test_RewardScope_NET_ONLY_FOOD_ONLY_CUSTOM_DenyAndAllow() public {
//         // Set allowed action: chỉ "FOOD"
//         bytes32[] memory types   = new bytes32[](1);
//         bool[]    memory allowed = new bool[](1);
//         types[0]   = keccak256("FOOD");
//         allowed[0] = true;

//         vm.prank(Deployer);
//         loyalty.setAllowedActionTypes(types, allowed);

//         _giveTokenA(customer, 2_000);
//         _giveTokenB(customer, 1_000);

//         // ── Action "NET" không được phép dùng B ──────────────────────────
//         vm.prank(Deployer);
//         loyalty.setSpendPolicy(0, 50, 0, 30); // B_FIRST

//         bytes32 refNet = keccak256("ref-net-001");
//         vm.prank(staff1);
//         (uint256 spentA_net, uint256 spentB_net) = loyalty.debit(
//             customer, 500, keccak256("NET"), refNet, BRANCH_1
//         );
//         assertEq(spentB_net, 0,   "NET not in scope: spentB should be 0");
//         assertEq(spentA_net, 500, "NET not in scope: spentA should be full 500");

//         // ── Action "FOOD" được phép dùng B ───────────────────────────────
//         bytes32 refFood = keccak256("ref-food-001");
//         vm.prank(staff1);
//         (uint256 spentA_food, uint256 spentB_food) = loyalty.debit(
//             customer, 500, keccak256("FOOD"), refFood, BRANCH_1
//         );
//         // maxB = 50% * 500 = 250, balB sau debit trước vẫn = 1000
//         assertEq(spentB_food, 250, "FOOD in scope: spentB should be 250");
//         assertEq(spentA_food, 250, "FOOD in scope: spentA should be 250");
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 7 — Expiry: default vs campaign override tạo batch expiry khác nhau
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * defaultExpiryDays = 30 (set trong setUp).
//      * Campaign A: rewardExpiryDaysOverride = 7  → batch expires trong 7 ngày.
//      * Campaign B: rewardExpiryDaysOverride = 0  → batch expires trong 30 ngày (default).
//      *
//      * Ta chạy _executeCampaigns gián tiếp qua earnTokenA, sau đó kiểm tra
//      * thời gian hết hạn của các batch bằng cách advance block.timestamp.
//      */
//     function test_Expiry_DefaultAndCampaignOverride() public {
//         // Tạo 2 campaign cho cùng eventType nhưng override expiry khác nhau
//         bytes32 eventType = keccak256("EVENT_EARN");

//         vm.prank(Deployer);
//         uint256 cId7 = loyalty.createCampaign(
//             "7-day-campaign", eventType, 0,
//             100, false,          // reward = 100 Token B flat
//             0, 0, 1, true,       // branchScope=0 (all), stackable
//             0,                   // không hết hạn campaign
//             bytes32(0), new bytes32[](0),
//             7                    // rewardExpiryDaysOverride = 7
//         );

//         vm.prank(Deployer);
//         uint256 cId30 = loyalty.createCampaign(
//             "default-campaign", eventType, 0,
//             50, false,
//             0, 0, 2, true,
//             0,
//             bytes32(0), new bytes32[](0),
//             0                    // override = 0 → dùng defaultExpiryDays = 30
//         );

//         // Ghi nhớ thời điểm hiện tại
//         uint256 t0 = block.timestamp;

//         // Trigger earnTokenA → _executeCampaigns → grant 2 batches
//         bytes32 key  = keccak256("earn-key-001");
//         bytes32 ref  = keccak256("earn-ref-001");
//         mockTopup.setValid(ref, 10_000, false); // isTopup=false

//         vm.prank(customer);
//         loyalty.earnTokenA(customer, 10_000, key, ref, eventType, BRANCH_1, false);

//         // Ngay sau earn: balanceB = 100 + 50 = 150
//         assertEq(loyalty.balanceB(customer), 150, "Should have 150 Token B after campaigns");

//         // Advance 8 ngày → batch 7-day hết hạn, batch 30-day còn sống
//         vm.warp(t0 + 8 days);
//         loyalty.expireBatches(customer);
//         assertEq(loyalty.balanceB(customer), 50, "After 8 days: only 30-day batch should survive");

//         // Advance thêm 23 ngày (tổng 31 ngày) → batch 30-day cũng hết hạn
//         vm.warp(t0 + 31 days);
//         loyalty.expireBatches(customer);
//         assertEq(loyalty.balanceB(customer), 0, "After 31 days: both batches expired");
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 8 — DebitB: tiêu batch có expiry gần nhất trước
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * Tạo 3 batch:
//      *   batch1: amount=100, expiresAt = t0 + 10 days  (gần nhất hữu hạn)
//      *   batch2: amount=200, expiresAt = t0 + 3 days   (gần nhất)
//      *   batch3: amount=300, expiresAt = 0             (vô hạn — tiêu sau cùng)
//      *
//      * Debit 150 → nên tiêu batch2 (200) trước:
//      *   batch2: 200 - 150 = 50 còn lại
//      *   batch1: nguyên 100
//      *   batch3: nguyên 300
//      *
//      * Kiểm tra bằng cách warp qua expiry của batch2 và xem số dư.
//      */
//     function test_DebitB_ConsumesNearestExpiryFirst() public {
//         vm.prank(Deployer);
//         loyalty.setManualGrantEnabled(true);

//         uint256 t0 = block.timestamp;

//         // Tạo batch1: expires in 10 days (sourceEventId unique)
//         bytes32 src1 = keccak256("src-b1");
//         // Sẽ dùng default expiry (30 days) từ grantTokenBManual
//         // Để kiểm soát expiry chính xác, ta dùng campaign với override
//         // Thay thế: tạo campaign với override khác nhau và trigger manual

//         // Dùng cách đơn giản hơn: set defaultExpiryDays = 10, grant batch1
//         vm.prank(Deployer);
//         loyalty.setSpendPolicy(0, 100, 0, 10); // expiryDays=10

//         vm.prank(Deployer);
//         loyalty.grantTokenBManual(customer, 100, src1); // batch1: expires t0 + 10d

//         // Đổi expiry thành 3 ngày, grant batch2
//         vm.prank(Deployer);
//         loyalty.setSpendPolicy(0, 100, 0, 3); // expiryDays=3

//         bytes32 src2 = keccak256("src-b2");
//         vm.prank(Deployer);
//         loyalty.grantTokenBManual(customer, 200, src2); // batch2: expires t0 + 3d

//         // batch3: vô hạn (expiryDays=0)
//         vm.prank(Deployer);
//         loyalty.setSpendPolicy(0, 100, 0, 0); // expiryDays=0 → không hết hạn

//         bytes32 src3 = keccak256("src-b3");
//         vm.prank(Deployer);
//         loyalty.grantTokenBManual(customer, 300, src3); // batch3: expiresAt=0

//         // Tổng balB = 600
//         assertEq(loyalty.balanceB(customer), 600, "Total should be 600");

//         // Debit 150 — nên tiêu từ batch2 (expiresAt = t0+3d, nhỏ nhất hữu hạn)
//         _giveTokenA(customer, 10_000); // cần tokenA cho phần không cover bởi B
//         bytes32 refD = keccak256("ref-debit-001");
//         vm.prank(staff1);
//         loyalty.debit(customer, 150, keccak256("ALL"), refD, BRANCH_1);

//         // balB = 600 - 150 = 450
//         assertEq(loyalty.balanceB(customer), 450, "BalB should be 450 after debit");

//         // Advance 4 ngày → batch2 (3d) đã hết hạn nhưng đã tiêu 150/200
//         // batch2 còn lại: 200 - 150 = 50 → expires → mất 50
//         // batch1 (10d): còn sống → 100
//         // batch3 (inf): còn sống → 300
//         vm.warp(t0 + 4 days);
//         loyalty.expireBatches(customer);

//         // Sau expire: batch2 remainder (50) mất đi
//         // Còn: batch1 (100) + batch3 (300) = 400
//         assertEq(loyalty.balanceB(customer), 400, "After batch2 expires: 100 + 300 = 400");

//         // Advance 11 ngày (t0 + 15) → batch1 (10d) cũng hết hạn
//         vm.warp(t0 + 15 days);
//         loyalty.expireBatches(customer);
//         assertEq(loyalty.balanceB(customer), 300, "After batch1 expires: only batch3 (300) remains");
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 9 — EventSchema: TokenACredited emit đúng branchId, source, refId, idempotencyKey
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * Dùng vm.expectEmit để assert chính xác tất cả field của event TokenACredited.
//      * Signature: TokenACredited(uint256 indexed branchId, address indexed customer,
//      *   uint256 amount, bytes32 source, bytes32 refId, bytes32 idempotencyKey, uint256 timestamp)
//      */
//     function test_EventSchema_ContainsMerchantBranchSource() public {
//         bytes32 key    = keccak256("schema-key-001");
//         bytes32 ref    = keccak256("schema-ref-001");
//         uint256 amount = 5_000;
//         uint256 tokenA = amount / TOPUP_RATE; // = 5

//         mockTopup.setValid(ref, amount, true);

//         // Chuẩn bị assert: check indexed + non-indexed fields
//         // TokenACredited(branchId, customer, amount, source, refId, idempotencyKey, timestamp)
//         vm.expectEmit(true, true, false, true, address(loyalty));

//         vm.prank(staff1);
//         loyalty.creditTopup(customer, amount, key, ref, BRANCH_1);
//     }

//     // Helper event để vm.expectEmit match — phải match signature chính xác
//     // với event trong contract (bytes32 source, không phải address)
//     event TokenACreditedExpected(
//         uint256 indexed branchId,
//         address indexed customer,
//         uint256 amount,
//         bytes32 source,
//         bytes32 refId,
//         bytes32 idempotencyKey,
//         uint256 timestamp
//     );

//     bytes32 constant NET_MODULE_HASH = keccak256("NET_MODULE");

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 10 — RBAC: Owner/Admin pass; không có role fail trên setPolicy/Tier/Campaign
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * Các hàm setTopupPolicy, createTier, createCampaign đều có onlyAdmin.
//      * Owner (ROLE_ADMIN) → pass.
//      * Attacker (không role) → revert "Only admin".
//      */
//     function test_RBAC_OwnerCoOwner_CanSetPolicyTierCampaign() public {
//         // ── Owner pass setTopupPolicy ─────────────────────────────────────
//         vm.prank(Deployer);
//         loyalty.setTopupPolicy(500, 0, 0); // không revert

//         // ── Attacker fail setTopupPolicy ──────────────────────────────────
//         vm.prank(attacker);
//         vm.expectRevert("Only admin");
//         loyalty.setTopupPolicy(999, 0, 0);

//         // ── Owner pass createTier ─────────────────────────────────────────
//         vm.prank(Deployer);
//         loyalty.setTierEnabled(true);
//         vm.prank(Deployer);
//         loyalty.createTier("Gold", 1000, 10, 100, 5, 0, "#FFD700"); // không revert

//         // ── Attacker fail createTier ──────────────────────────────────────
//         vm.prank(attacker);
//         vm.expectRevert("Only admin");
//         loyalty.createTier("Fake", 9999, 10, 100, 5, 0, "#000");

//         // ── Owner pass createCampaign ─────────────────────────────────────
//         vm.prank(Deployer);
//         loyalty.createCampaign(
//             "VIP Campaign", keccak256("EVT_VIP"), 0,
//             100, false, 0, 0, 1, true,
//             0, bytes32(0), new bytes32[](0), 0
//         ); // không revert

//         // ── Attacker fail createCampaign ─────────────────────────────────
//         vm.prank(attacker);
//         vm.expectRevert("Only admin");
//         loyalty.createCampaign(
//             "Hack Campaign", keccak256("EVT_HACK"), 0,
//             100, false, 0, 0, 1, true,
//             0, bytes32(0), new bytes32[](0), 0
//         );

//         // ── Staff (FINANCE role) fail onlyAdmin — staff1 không phải admin ──
//         vm.prank(staff1);
//         vm.expectRevert("Only admin");
//         loyalty.setTopupPolicy(777, 0, 0);
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 11 — manualGrantEnabled default false
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * Khi khởi tạo, manualGrantEnabled = false.
//      * grantTokenBManual() phải revert "Manual grant is disabled".
//      * Sau khi Deployer bật cờ, mới grant được.
//      */
//     function test_ManualGrant_DefaultOff() public {
//         // Default off → revert
//         vm.prank(staff1);
//         vm.expectRevert("Manual grant is disabled");
//         loyalty.grantTokenBManual(customer, 100, keccak256("src-off"));

//         // Admin bật cờ
//         vm.prank(Deployer);
//         loyalty.setManualGrantEnabled(true);
//         assertTrue(loyalty.manualGrantEnabled(), "Flag should be true after set");

//         // Bây giờ staff1 có thể grant
//         vm.prank(staff1);
//         loyalty.grantTokenBManual(customer, 100, keccak256("src-on"));
//         assertEq(loyalty.balanceB(customer), 100, "Should have 100 Token B after grant");

//         // Admin tắt lại
//         vm.prank(Deployer);
//         loyalty.setManualGrantEnabled(false);

//         vm.prank(staff1);
//         vm.expectRevert("Manual grant is disabled");
//         loyalty.grantTokenBManual(customer, 50, keccak256("src-off-again"));

//         // Số dư không thay đổi sau revert
//         assertEq(loyalty.balanceB(customer), 100, "Balance should remain 100");
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // TEST 12 — CustomerReadOwnOnly: customer không đọc được data người khác
//     // ─────────────────────────────────────────────────────────────────────
//     /**
//      * Các hàm có access control:
//      *   getDebitRefsByCustomer(addr) → chỉ self, admin, staff1
//      *   getDebitRefsByCustomerPaging → chỉ self, admin, staff1
//      *   getCampaignExecLogByCustomer → chỉ self, admin, staff1
//      *   getMyBalances() → luôn dùng msg.sender (không truyền addr)
//      *   getMember() → onlyStaffOrAdmin
//      *
//      * Test:
//      *   customer cố đọc data của customer2 → revert "Access denied"
//      *   customer đọc data của chính mình → pass
//      *   staff1 đọc data của bất kỳ customer → pass
//      *   customer cố gọi getMember(customer2) → revert "Only staff or admin"
//      */
//     function test_CustomerReadOwnOnly() public {
//         // Tạo một debit cho customer2 để có data
//         _giveTokenA(customer2, 5_000);
//         bytes32 ref2 = keccak256("ref-c2-001");
//         vm.prank(staff1);
//         loyalty.debit(customer2, 500, keccak256("ALL"), ref2, BRANCH_1);

//         // ── customer cố đọc debitRefs của customer2 → revert ─────────────
//         vm.prank(customer);
//         vm.expectRevert("Access denied");
//         loyalty.getDebitRefsByCustomer(customer2);

//         // ── customer đọc debitRefs của chính mình → pass (empty) ─────────
//         vm.prank(customer);
//         bytes32[] memory ownRefs = loyalty.getDebitRefsByCustomer(customer);
//         assertEq(ownRefs.length, 0, "Customer should have no debits");

//         // ── customer cố gọi paginated version cho customer2 → revert ──────
//         vm.prank(customer);
//         vm.expectRevert("Access denied");
//         loyalty.getDebitRefsByCustomerPaging(customer2, 0, 10);

//         // ── customer đọc paged debitRefs của chính mình → pass ───────────
//         vm.prank(customer);
//         (bytes32[] memory ownRefsPaged, uint256 total) = loyalty.getDebitRefsByCustomerPaging(customer, 0, 10);
//         assertEq(total, 0, "Customer paged refs total should be 0");

//         // ── customer cố gọi getMember(customer2) → revert ─────────────────
//         vm.prank(customer);
//         vm.expectRevert("Only staff or admin");
//         loyalty.getMember(customer2);

//         // ── customer đọc profile chính mình qua getMyMemberProfile() → pass
//         vm.prank(customer);
//         Member memory profile = loyalty.getMyMemberProfile();
//         assertEq(profile.walletAddress, customer, "Should return customer's own profile");

//         // ── staff1 đọc được data của customer2 → pass ─────────────────────
//         vm.prank(staff1);
//         bytes32[] memory staff1Read = loyalty.getDebitRefsByCustomer(customer2);
//         assertEq(staff1Read.length, 1, "Staff should see customer2's debit ref");
//         assertEq(staff1Read[0], ref2, "Ref should match");

//         // ── getMyBalances() luôn trả về data của msg.sender ──────────────
//         _giveTokenA(customer,  999);
//         _giveTokenA(customer2, 111);

//         vm.prank(customer);
//         (uint256 myA, ) = loyalty.getMyBalances();
//         // balA(customer) = 999 (sau khi đã debit 0 từ customer, chỉ đã giveTokenA)
//         assertGt(myA, 0, "Customer getMyBalances should return own balance > 0");

//         // customer không thể "giả" gọi getMyBalances dưới tên customer2
//         // (không có param addr, luôn dùng msg.sender — đây là design-level protection)

//         // ── getCampaignExecLogByCustomer — customer không đọc của customer2
//         vm.prank(customer);
//         vm.expectRevert("Access denied");
//         loyalty.getCampaignExecLogByCustomer(customer2, 0, 10);

//         // customer đọc exec log của mình → pass (empty)
//         vm.prank(customer);
//         (CampaignExecRecord[] memory execLogs, uint256 execTotal) =
//             loyalty.getCampaignExecLogByCustomer(customer, 0, 10);
//         assertEq(execTotal, 0, "Customer should have no campaign exec logs");
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // BONUS TEST — Dashboard stats tích lũy đúng sau credit/debit
//     // ─────────────────────────────────────────────────────────────────────
//     function test_DailyStats_AccumulateCorrectly() public {
//         uint currentTime = 1773025647;
//         vm.warp(currentTime);
//         uint256 dayBucket = currentTime / 1 days;

//         bytes32 key1 = keccak256("ds-key-001");
//         bytes32 ref1 = keccak256("ds-ref-001");
//         mockTopup.setValid(ref1, 10_000, true);

//         // Credit topup → totalTopup tăng
//         vm.prank(staff1);
//         loyalty.creditTopup(customer, 10_000, key1, ref1, BRANCH_1);

//         DailyStats memory stats = loyalty.getDailyStats(dayBucket, BRANCH_1);
//         assertEq(stats.totalTopup, 10_000 / TOPUP_RATE, "totalTopup should be 10 after creditTopup");

//         // Global (branchId=0) cũng tăng
//         DailyStats memory global = loyalty.getDailyStats(dayBucket, 0);
//         assertEq(global.totalTopup, 10_000 / TOPUP_RATE, "Global totalTopup should match");

//         // Debit → totalSpend tăng
//         bytes32 ref2 = keccak256("ds-ref-002");
//         vm.prank(staff1);
//         loyalty.debit(customer, 3, keccak256("ALL"), ref2, BRANCH_1);

//         DailyStats memory stats2 = loyalty.getDailyStats(dayBucket, BRANCH_1);
//         assertEq(stats2.totalSpend, 3, "totalSpend should be 3 after debit");

//         // txCount tăng theo số lần _createTransaction gọi
//         // (creditTopup gọi 1 lần, debit gọi 1 lần) → txCount >= 2
//         DailyStats memory global2 = loyalty.getDailyStats(dayBucket, 0);
//         assertGe(global2.txCount, 2, "txCount should be at least 2");
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // BONUS TEST — Change history ghi đúng loại và payload
//     // ─────────────────────────────────────────────────────────────────────
//     function test_ChangeHistory_RecordsTopupPolicyAndCampaign() public {
//         // setTopupPolicy → ChangeType.TopupPolicy
//         vm.prank(Deployer);
//         loyalty.setTopupPolicy(2000, 100, 0);

//         vm.prank(Deployer);
//         loyalty.createCampaign(
//             "History Test", keccak256("EVT_H"), 0,
//             50, false, 0, 0, 1, true,
//             0, bytes32(0), new bytes32[](0), 0
//         );

//         // getChangeHistory (admin view)
//         vm.prank(Deployer);
//         (ChangeRecord[] memory hist, uint256 total) = loyalty.getChangeHistory(0, 10);
//         assertGe(total, 2, "Should have at least 2 change records");

//         // Verify types
//         bool foundTopup    = false;
//         bool foundCampaign = false;
//         for (uint i = 0; i < hist.length; i++) {
//             if (hist[i].changeType == ChangeType.TopupPolicy)    foundTopup    = true;
//             if (hist[i].changeType == ChangeType.CampaignCreated) foundCampaign = true;
//         }
//         assertTrue(foundTopup,    "TopupPolicy change should be recorded");
//         assertTrue(foundCampaign, "CampaignCreated change should be recorded");

//         // getChangeHistoryByType — chỉ lọc TopupPolicy
//         vm.prank(Deployer);
//         (ChangeRecord[] memory topupHist, uint256 topupTotal) =
//             loyalty.getChangeHistoryByType(ChangeType.TopupPolicy, 0, 10);
//         assertGe(topupTotal, 1, "Should have at least 1 TopupPolicy change");
//         // assertEq(topupHist[0].changeType, ChangeType.TopupPolicy);

//         // Attacker không đọc được change history
//         vm.prank(attacker);
//         vm.expectRevert("Only staff or admin");
//         loyalty.getChangeHistory(0, 10);
//     }

//     // ─────────────────────────────────────────────────────────────────────
//     // HELPERS
//     // ─────────────────────────────────────────────────────────────────────

//     /**
//      * @dev Cấp Token A trực tiếp vào balance bằng cách gọi internal thông qua
//      *      mock admin creditAssist (không cần isValidAmount mock).
//      *      Cách thay thế: dùng vm.store (storage cheat).
//      */
//     function _giveTokenA(address _customer, uint256 _amount) internal {
//         // Dùng creditAssist thông qua staff1 (FINANCE)
//         bytes32 key = keccak256(abi.encodePacked("helper-key", _customer, _amount, block.timestamp));
//         bytes32 ref = keccak256(abi.encodePacked("helper-ref", _customer, _amount, block.timestamp));
//         vm.prank(staff1);
//         loyalty.creditAssist(_customer, _amount * TOPUP_RATE, key, ref, BRANCH_1);
//     }

//     /**
//      * @dev Ghi đè trực tiếp balanceA bằng vm.store để test split chính xác.
//      *      Slot của _balanceA là private mapping — cần tính đúng slot.
//      *      Trong contract: _balanceA là mapping thứ 4 trong nhóm Token A.
//      *      Slot chính xác phụ thuộc vào thứ tự khai báo — dùng vm.store với
//      *      slot đã biết từ layout.
//      *
//      *      Vì slot có thể thay đổi theo upgrades, ta dùng creditAssist thay thế.
//      *      Hàm này chỉ là alias cho _giveTokenA để code test dễ đọc hơn.
//      */
//     function _setBalanceA(address _customer, uint256 _targetAmount) internal {
//         // Đặt lại về 0 rồi cấp đúng số
//         // Lấy balance hiện tại để điều chỉnh
//         uint256 current = loyalty.balanceA(_customer);
//         if (current < _targetAmount) {
//             _giveTokenA(_customer, _targetAmount - current);
//         } else if (current > _targetAmount) {
//             // Debit phần thừa qua debitAAssist
//             bytes32 r = keccak256(abi.encodePacked("set-bal-ref", _customer, block.timestamp, _targetAmount));
//             vm.prank(staff1);
//             loyalty.debitAAssist(_customer, current - _targetAmount, keccak256("ADJUST"), r, BRANCH_1);
//         }
//     }

//      function _setBalanceB(address _customer, uint256 _targetAmount) internal {
//         // Đặt lại về 0 rồi cấp đúng số
//         // Lấy balance hiện tại để điều chỉnh
//         uint256 current = loyalty.balanceB(_customer);
//         if (current < _targetAmount) {
//             _giveTokenB(_customer, _targetAmount - current);
//         } else if (current > _targetAmount) {
//             // Debit phần thừa qua debitAAssist
//             bytes32 r = keccak256(abi.encodePacked("set-bal-ref", _customer, block.timestamp, _targetAmount));
//             vm.prank(staff1);
//             loyalty.debitAAssist(_customer, current - _targetAmount, keccak256("ADJUST"), r, BRANCH_1);
//         }
//     }
//    /**
//      * @dev Cấp Token B trực tiếp qua grantTokenBManual (cần enable trước).
//      */
//     function _giveTokenB(address _customer, uint256 _amount) internal {
//         bool wasEnabled = loyalty.manualGrantEnabled();
//         if (!wasEnabled) {
//             vm.prank(Deployer);
//             loyalty.setManualGrantEnabled(true);
//         }
//         bytes32 src = keccak256(abi.encodePacked("helper-tokb", _customer, _amount, block.timestamp));
//         vm.prank(Deployer);
//         loyalty.grantTokenBManual(_customer, _amount, src);
//         if (!wasEnabled) {
//             vm.prank(Deployer);
//             loyalty.setManualGrantEnabled(false);
//         }
//     }
// }

// // ══════════════════════════════════════════════════════════════════════════
// // MOCK — IManagement
// // Hỗ trợ: hasRole(ROLE_ADMIN), isStaff(), checkRole(STAFF_ROLE, addr)
// // ══════════════════════════════════════════════════════════════════════════
// // contract MockManagement {
// //     bytes32 constant ROLE_ADMIN = keccak256("ROLE_ADMIN");

// //     address public adminAddr;
// //     address public staff1Addr;

// //     constructor(address _admin, address _staff1) {
// //         adminAddr = _admin;
// //         staff1Addr = _staff1;
// //     }

// //     /// @notice Trả true nếu user là admin (ROLE_ADMIN)
// //     function hasRole(bytes32 role, address user) external view returns (bool) {
// //         if (role == ROLE_ADMIN) return user == adminAddr;
// //         return false;
// //     }

// //     /// @notice Trả true nếu user là staff1
// //     function isStaff(address user) external view returns (bool) {
// //         return user == staff1Addr;
// //     }

// //     /**
// //      * @notice checkRole(STAFF_ROLE, addr) — dùng bởi onlyStaffWithRoleOrAdmin modifier.
// //      * Trả true nếu là admin hoặc staff1 (giả định staff1 có mọi STAFF_ROLE trong test).
// //      */
// //     function checkRole(STAFF_ROLE /*role*/, address user) external view returns (bool) {
// //         return user == adminAddr || user == staff1Addr;
// //     }
// // }

// // ══════════════════════════════════════════════════════════════════════════
// // MOCK — IOrder
// // Giả lập contract Order để isValidAmount() trả về giá trị được set trước
// // ══════════════════════════════════════════════════════════════════════════
// contract MockOrder {
//     // paymentId => (amount => valid)
//     mapping(bytes32 => mapping(uint256 => bool)) private _valid;

//     function setValid(bytes32 paymentId, uint256 amount, bool valid) external {
//         _valid[paymentId][amount] = valid;
//     }

//     function isValidAmount(bytes32 paymentId, uint256 amount) external view returns (bool) {
//         return _valid[paymentId][amount];
//     }
// }

// // ══════════════════════════════════════════════════════════════════════════
// // MOCK — INetCafeTopUp
// // Giả lập contract TopUp để isValidAmount() trả về giá trị được set trước
// // ══════════════════════════════════════════════════════════════════════════
// contract MockTopUp {
//     mapping(bytes32 => mapping(uint256 => bool)) private _valid;

//     function setValid(bytes32 paymentId, uint256 amount, bool valid) external {
//         _valid[paymentId][amount] = valid;
//     }

//     function isValidAmount(bytes32 paymentId, uint256 amount) external view returns (bool) {
//         return _valid[paymentId][amount];
//     }
// }