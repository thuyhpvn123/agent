// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "../src/BranchManagement.sol";
// import "../src/HistoryTracking.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// /**
//  * @title Integration Test
//  * @notice Test full flow between BranchManagement and HistoryTracking contracts
//  */
// contract IntegrationTest is Test {
//     BranchManagement public branchManagementImpl;
//     BranchManagement public branchManagement;
//     HistoryTracking public historyTrackingImpl;
    
//     address public agent = address(0x1);
//     address public mainOwner = address(0x2);
//     address public coOwner1 = address(0x3);
//     address public coOwner2 = address(0x4);
//     address public coOwner3 = address(0x5);
    
//     address public mockStaffAgentStore = address(0x100);
//     address public mockIqrFactory = address(0x101);
//     address public mockManagement = address(0x102);
    
//     uint256 public constant MAIN_BRANCH_ID = 1;
//     uint256 public constant BRANCH_2_ID = 2;

//     function setUp() public {
//         // Deploy implementations
//         branchManagementImpl = new BranchManagement();
//         historyTrackingImpl = new HistoryTracking();
        
//         // Deploy BranchManagement proxy
//         bytes memory initData = abi.encodeWithSelector(
//             BranchManagement.initialize.selector,
//             agent,
//             address(historyTrackingImpl)
//         );
        
//         ERC1967Proxy proxy = new ERC1967Proxy(
//             address(branchManagementImpl),
//             initData
//         );
        
//         branchManagement = BranchManagement(address(proxy));
        
//         // Setup
//         vm.prank(agent);
//         branchManagement.setMainOwner(mainOwner);
        
//         // Setup mocks
//         _setupMocks();
        
//         vm.startPrank(mainOwner);
//         branchManagement.setStaffAgentStore(mockStaffAgentStore);
//         branchManagement.setIqrFactorySC(mockIqrFactory);
//         vm.stopPrank();
//     }
    
//     function _setupMocks() internal {
//         vm.mockCall(
//             mockStaffAgentStore,
//             abi.encodeWithSignature("setAgentForCoOwner(address,address,uint256[])"),
//             abi.encode()
//         );
        
//         vm.mockCall(
//             mockIqrFactory,
//             abi.encodeWithSignature("getIQRSCByAgentFromFactory(address,uint256)"),
//             abi.encode(IQRContracts({
//                 Management: mockManagement,
//                 Restaurant: address(0),
//                 QR: address(0)
//             }))
//         );
        
//         vm.mockCall(
//             mockIqrFactory,
//             abi.encodeWithSignature("getManagementSCByAgentsFromFactory(address,uint256[])"),
//             abi.encode(new address[](1))
//         );
        
//         vm.mockCall(
//             mockManagement,
//             abi.encodeWithSignature("setHistoryTracking(address)"),
//             abi.encode()
//         );
        
//         vm.mockCall(
//             mockManagement,
//             abi.encodeWithSignature("setRoleForCoOwner(address)"),
//             abi.encode()
//         );
//     }

//     // ==================== INTEGRATION TEST: BRANCH CREATION WITH HISTORY ====================
    
//     function testIntegration_BranchCreationWithHistoryTracking() public {
//         vm.startPrank(mainOwner);
        
//         // Create main branch
//         uint256 branchId = branchManagement.createBranch(
//             MAIN_BRANCH_ID,
//             "Main Branch",
//             true
//         );
        
//         assertEq(branchId, MAIN_BRANCH_ID);
        
//         // Verify history tracking contract was deployed
//         address historyTrackAddr = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         assertTrue(historyTrackAddr != address(0));
        
//         HistoryTracking historyTrack = HistoryTracking(historyTrackAddr);
        
//         // Verify history tracking is accessible
//         bytes32 writerRole = historyTrack.WRITER_ROLE();
//         assertTrue(historyTrack.hasRole(writerRole, address(branchManagement)));
        
//         vm.stopPrank();
//     }

//     // ==================== INTEGRATION TEST: MANAGER LIFECYCLE WITH HISTORY ====================
    
//     function testIntegration_ManagerFullLifecycle() public {
//         // Setup
//         vm.startPrank(mainOwner);
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         // 1. ADD FIRST MANAGER - Direct execution (no proposal needed)
//         branchManagement.AddAndUpdateManager(
//             coOwner1,
//             "Co-Owner 1",
//             "1234567890",
//             "image1.jpg",
//             false,
//             branchIds,
//             true,
//             true,
//             true,
//             true
//         );
        
//         // Verify manager added
//         (address wallet,,,,,,,,,) = branchManagement.managers(coOwner1);
//         assertEq(wallet, coOwner1);
        
//         // Verify history recorded
//         address historyTrackAddr = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         HistoryTracking historyTrack = HistoryTracking(historyTrackAddr);
        
//         (ManagerSnapshot memory oldSnap, ManagerSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTrack.getManagerSnapshots(coOwner1);
        
//         assertTrue(hasNew);
//         assertFalse(hasOld);
//         assertEq(newSnap.manager.name, "Co-Owner 1");
        
//         // Verify history entry
//         (HistoryEntry[] memory entries, uint256 total) = historyTrack.getHistoryByType(
//             EntityType.MANAGER,
//             0,
//             10
//         );
        
//         assertEq(total, 1);
//         assertTrue(entries[0].actionType == ActionType.CREATE);
        
//         vm.stopPrank();
        
//         // 2. ADD SECOND MANAGER - Through proposal
//         vm.prank(coOwner1);
//         branchManagement.AddAndUpdateManager(
//             coOwner2,
//             "Co-Owner 2",
//             "0987654321",
//             "image2.jpg",
//             false,
//             branchIds,
//             true,
//             true,
//             true,
//             true
//         );
        
//         // Verify proposal auto-executed
//         (,,,,,,,, bool active) = branchManagement.managers(coOwner2);
//         assertTrue(active);
        
//         // Verify history for second manager
//         (oldSnap, newSnap, hasOld, hasNew) = historyTrack.getManagerSnapshots(coOwner2);
//         assertTrue(hasNew);
//         assertEq(newSnap.manager.name, "Co-Owner 2");
        
//         // 3. UPDATE MANAGER - Through proposal
//         vm.prank(coOwner1);
//         branchManagement.AddAndUpdateManager(
//             coOwner1,
//             "Updated Co-Owner 1",
//             "9999999999",
//             "new_image.jpg",
//             false,
//             branchIds,
//             true,
//             true,
//             true,
//             true
//         );
        
//         // Verify update
//         (, string memory name,,,,,,,) = branchManagement.managers(coOwner1);
//         assertEq(name, "Updated Co-Owner 1");
        
//         // Verify history shows old and new snapshots
//         (oldSnap, newSnap, hasOld, hasNew) = historyTrack.getManagerSnapshots(coOwner1);
//         assertTrue(hasOld);
//         assertTrue(hasNew);
//         assertEq(oldSnap.manager.name, "Co-Owner 1");
//         assertEq(newSnap.manager.name, "Updated Co-Owner 1");
        
//         // 4. REMOVE MANAGER - Through proposal
//         vm.prank(coOwner1);
//         branchManagement.removeManager(coOwner2);
        
//         // Verify removal
//         (,,,,,,,, active) = branchManagement.managers(coOwner2);
//         assertFalse(active);
        
//         // Verify complete history
//         (entries, total) = historyTrack.getHistoryByEntity(
//             EntityType.MANAGER,
//             _addressToString(coOwner2),
//             0,
//             10
//         );
        
//         assertEq(total, 2); // CREATE + DELETE
//         assertTrue(entries[0].actionType == ActionType.DELETE);
//         assertTrue(entries[1].actionType == ActionType.CREATE);
//     }

//     // ==================== INTEGRATION TEST: PAYMENT INFO WITH HISTORY ====================
    
//     function testIntegration_PaymentInfoLifecycle() public {
//         // Setup
//         vm.startPrank(mainOwner);
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         branchManagement.AddAndUpdateManager(
//             coOwner1,
//             "Co-Owner 1",
//             "1234567890",
//             "image1.jpg",
//             false,
//             branchIds,
//             true,
//             true,
//             true,
//             true
//         );
        
//         // 1. SET FIRST PAYMENT INFO
//         branchManagement.setPaymentAccount(
//             "123456789",
//             "John Doe",
//             "ABC Bank",
//             "TAX123",
//             "0xWallet"
//         );
        
//         // Verify payment info set
//         (string memory bankAcc,,,) = branchManagement.paymentInfo();
//         assertEq(bankAcc, "123456789");
        
//         // Verify history
//         address historyTrackAddr = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         HistoryTracking historyTrack = HistoryTracking(historyTrackAddr);
        
//         (PaymentInfoSnapshot memory oldSnap, PaymentInfoSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTrack.getPaymentInfoSnapshots(0);
        
//         assertTrue(hasNew);
//         assertFalse(hasOld);
//         assertEq(newSnap.paymentInfo.bankAccount, "123456789");
        
//         vm.stopPrank();
        
//         // 2. UPDATE PAYMENT INFO - Through proposal
//         vm.prank(coOwner1);
//         branchManagement.setPaymentAccount(
//             "987654321",
//             "Jane Doe",
//             "XYZ Bank",
//             "TAX456",
//             "0xNewWallet"
//         );
        
//         // Verify update
//         (bankAcc,,,) = branchManagement.paymentInfo();
//         assertEq(bankAcc, "987654321");
        
//         // Verify history shows old and new
//         (oldSnap, newSnap, hasOld, hasNew) = historyTrack.getPaymentInfoSnapshots(0);
//         assertTrue(hasOld);
//         assertTrue(hasNew);
//         assertEq(oldSnap.paymentInfo.bankAccount, "123456789");
//         assertEq(newSnap.paymentInfo.bankAccount, "987654321");
        
//         // Verify history entries
//         (HistoryEntry[] memory entries, uint256 total) = historyTrack.getHistoryByType(
//             EntityType.PAYMENT_INFO,
//             0,
//             10
//         );
        
//         assertEq(total, 2); // CREATE + UPDATE
//         assertTrue(entries[0].actionType == ActionType.UPDATE);
//         assertTrue(entries[1].actionType == ActionType.CREATE);
//     }

//     // ==================== INTEGRATION TEST: PROPOSAL VOTING WITH HISTORY ====================
    
//     function testIntegration_ProposalVotingWithHistory() public {
//         // Setup: Create branch and add 3 co-owners
//         vm.startPrank(mainOwner);
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         // Add first co-owner
//         branchManagement.AddAndUpdateManager(
//             coOwner1,
//             "Co-Owner 1",
//             "1234567890",
//             "image1.jpg",
//             false,
//             branchIds,
//             true,
//             true,
//             true,
//             true
//         );
        
//         vm.stopPrank();
        
//         // Add second co-owner
//         vm.prank(coOwner1);
//         branchManagement.AddAndUpdateManager(
//             coOwner2,
//             "Co-Owner 2",
//             "0987654321",
//             "image2.jpg",
//             false,
//             branchIds,
//             true,
//             true,
//             true,
//             true
//         );
        
//         // Add third co-owner
//         vm.prank(coOwner1);
//         branchManagement.AddAndUpdateManager(
//             coOwner3,
//             "Co-Owner 3",
//             "5555555555",
//             "image3.jpg",
//             false,
//             branchIds,
//             true,
//             true,
//             true,
//             true
//         );
        
//         // Create proposal by updating payment info
//         vm.prank(mainOwner);
//         branchManagement.setPaymentAccount(
//             "123456789",
//             "John Doe",
//             "ABC Bank",
//             "TAX123",
//             "0xWallet"
//         );
        
//         // Now update again - this creates a proposal
//         vm.prank(coOwner1);
//         branchManagement.setPaymentAccount(
//             "987654321",
//             "Jane Doe",
//             "XYZ Bank",
//             "TAX456",
//             "0xNewWallet"
//         );
        
//         // Get proposal ID (should be the latest)
//         uint256 proposalId = branchManagement.proposalCounter();
        
//         // Check proposal status before all votes
//         (,, , ProposalStatus status, uint256 votesFor, uint256 votesAgainst, uint256 totalVoters,) = 
//             branchManagement.getProposalDetails(proposalId);
        
//         console.log("Before additional votes:");
//         console.log("- Status:", uint(status));
//         console.log("- Votes for:", votesFor);
//         console.log("- Votes against:", votesAgainst);
//         console.log("- Total voters:", totalVoters);
        
//         // Vote by other co-owners
//         vm.prank(coOwner2);
//         branchManagement.voteProposal(proposalId, true);
        
//         vm.prank(coOwner3);
//         branchManagement.voteProposal(proposalId, true);
        
//         // Check final proposal status
//         (,, , status, votesFor, votesAgainst,,) = 
//             branchManagement.getProposalDetails(proposalId);
        
//         console.log("\nAfter all votes:");
//         console.log("- Status:", uint(status));
//         console.log("- Votes for:", votesFor);
//         console.log("- Votes against:", votesAgainst);
        
//         // Verify proposal executed
//         assertTrue(status == ProposalStatus.APPROVED || status == ProposalStatus.EXECUTED);
        
//         // Verify payment info updated
//         (string memory bankAcc,,,) = branchManagement.paymentInfo();
//         assertEq(bankAcc, "987654321");
        
//         // Verify history recorded
//         address historyTrackAddr = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         HistoryTracking historyTrack = HistoryTracking(historyTrackAddr);
        
//         (PaymentInfoSnapshot memory oldSnap, PaymentInfoSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTrack.getPaymentInfoSnapshots(0);
        
//         assertTrue(hasOld);
//         assertTrue(hasNew);
//         assertEq(oldSnap.paymentInfo.bankAccount, "123456789");
//         assertEq(newSnap.paymentInfo.bankAccount, "987654321");
//     }

//     // ==================== INTEGRATION TEST: MULTI-BRANCH WITH SEPARATE HISTORY ====================
    
//     function testIntegration_MultiBranchHistoryTracking() public {
//         vm.startPrank(mainOwner);
        
//         // Create two branches
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
//         branchManagement.createBranch(BRANCH_2_ID, "Branch 2", false);
        
//         // Get history tracking contracts
//         address historyTrack1 = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         address historyTrack2 = branchManagement.mBranchIdToHistoryTrack(BRANCH_2_ID);
        
//         // Verify separate history tracking contracts
//         assertTrue(historyTrack1 != address(0));
//         assertTrue(historyTrack2 != address(0));
//         assertTrue(historyTrack1 != historyTrack2);
        
//         uint256[] memory branchIds1 = new uint256[](1);
//         branchIds1[0] = MAIN_BRANCH_ID;
        
//         uint256[] memory branchIds2 = new uint256[](1);
//         branchIds2[0] = BRANCH_2_ID;
        
//         // Add manager for main branch
//         branchManagement.AddAndUpdateManager(
//             coOwner1,
//             "Main Branch Manager",
//             "1234567890",
//             "image1.jpg",
//             false,
//             branchIds1,
//             true,
//             true,
//             true,
//             true
//         );
        
//         vm.stopPrank();
        
//         // Verify history in main branch
//         HistoryTracking ht1 = HistoryTracking(historyTrack1);
//         (ManagerSnapshot memory snap1, , , bool hasNew1) = ht1.getManagerSnapshots(coOwner1);
//         assertTrue(hasNew1);
//         assertEq(snap1.manager.name, "Main Branch Manager");
        
//         // Verify no history in branch 2 for this manager
//         HistoryTracking ht2 = HistoryTracking(historyTrack2);
//         (, , , bool hasNew2) = ht2.getManagerSnapshots(coOwner1);
//         assertFalse(hasNew2);
//     }

//     // ==================== INTEGRATION TEST: PAGINATION ACROSS HISTORY ====================
    
//     function testIntegration_PaginationWithHistory() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         // Add first manager
//         branchManagement.AddAndUpdateManager(
//             coOwner1,
//             "Co-Owner 1",
//             "1234567890",
//             "image1.jpg",
//             false,
//             branchIds,
//             true,
//             true,
//             true,
//             true
//         );
        
//         vm.stopPrank();
        
//         // Create multiple proposals
//         for (uint i = 0; i < 10; i++) {
//             vm.prank(coOwner1);
//             branchManagement.AddAndUpdateManager(
//                 address(uint160(0x1000 + i)),
//                 string(abi.encodePacked("Manager ", i)),
//                 "1234567890",
//                 "image.jpg",
//                 false,
//                 branchIds,
//                 false,
//                 true,
//                 true,
//                 false
//             );
//         }
        
//         // Test proposal pagination
//         PaginatedProposals memory page1 = branchManagement.getAllProposalsPaginated(1, 5);
//         assertEq(page1.proposals.length, 5);
//         assertEq(page1.total, 10);
        
//         // Test history pagination
//         address historyTrackAddr = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         HistoryTracking historyTrack = HistoryTracking(historyTrackAddr);
        
//         (HistoryEntry[] memory entries, uint256 total) = historyTrack.getAllHistory(0, 5);
//         assertEq(entries.length, 5);
//         assertEq(total, 11); // 11 managers created (1 + 10)
//     }

//     // ==================== INTEGRATION TEST: COMPLEX WORKFLOW ====================
    
//     function testIntegration_ComplexWorkflow() public {
//         // This test simulates a complete restaurant setup workflow
        
//         // 1. Setup: Create branches
//         vm.startPrank(mainOwner);
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
//         branchManagement.createBranch(BRANCH_2_ID, "Branch 2", false);
        
//         uint256[] memory mainBranchIds = new uint256[](1);
//         mainBranchIds[0] = MAIN_BRANCH_ID;
        
//         uint256[] memory allBranchIds = new uint256[](2);
//         allBranchIds[0] = MAIN_BRANCH_ID;
//         allBranchIds[1] = BRANCH_2_ID;
        
//         // 2. Add co-owners
//         branchManagement.AddAndUpdateManager(
//             coOwner1,
//             "Full Access Owner",
//             "1234567890",
//             "image1.jpg",
//             false,
//             allBranchIds,
//             true, // Full access
//             true,
//             true,
//             true
//         );
        
//         vm.stopPrank();
        
//         vm.prank(coOwner1);
//         branchManagement.AddAndUpdateManager(
//             coOwner2,
//             "Main Branch Owner",
//             "0987654321",
//             "image2.jpg",
//             false,
//             mainBranchIds,
//             false, // Limited to main branch
//             true,
//             true,
//             true
//         );
        
//         // 3. Set payment info
//         vm.prank(mainOwner);
//         branchManagement.setPaymentAccount(
//             "123456789",
//             "Restaurant LLC",
//             "ABC Bank",
//             "TAX123",
//             "0xWallet"
//         );
        
//         // 4. Update manager permissions
//         vm.prank(coOwner1);
//         branchManagement.AddAndUpdateManager(
//             coOwner2,
//             "Main Branch Owner",
//             "0987654321",
//             "image2.jpg",
//             false,
//             mainBranchIds,
//             false,
//             true,
//             true,
//             false // Remove proposal/vote permission
//         );
        
//         // 5. Verify all history recorded correctly
//         address historyTrackAddr = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         HistoryTracking historyTrack = HistoryTracking(historyTrackAddr);
        
//         // Check manager history
//         (HistoryEntry[] memory managerEntries, uint256 managerTotal) = 
//             historyTrack.getHistoryByType(EntityType.MANAGER, 0, 10);
        
//         assertEq(managerTotal, 4); // 2 CREATE + 2 UPDATE
        
//         // Check payment info history
//         (HistoryEntry[] memory paymentEntries, uint256 paymentTotal) = 
//             historyTrack.getHistoryByType(EntityType.PAYMENT_INFO, 0, 10);
        
//         assertEq(paymentTotal, 1); // 1 CREATE
        
//         // 6. Verify snapshots
//         (ManagerSnapshot memory oldSnap, ManagerSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTrack.getManagerSnapshots(coOwner2);
        
//         assertTrue(hasOld);
//         assertTrue(hasNew);
//         assertTrue(oldSnap.manager.canProposeAndVote);
//         assertFalse(newSnap.manager.canProposeAndVote);
        
//         // 7. Get system stats
//         (
//             uint256 totalBranches,
//             uint256 totalManagers,
//             uint256 totalCoOwners,
//             ,
//             uint256 totalProposals,
            
//         ) = branchManagement.getSystemStats();
        
//         assertEq(totalBranches, 2);
//         assertEq(totalManagers, 2);
//         assertEq(totalCoOwners, 2);
//         assertTrue(totalProposals > 0);
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
// }