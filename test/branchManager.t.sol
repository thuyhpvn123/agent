// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "../src/BranchManagement.sol";
// import "../src/HistoryTracking.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// contract BranchManagementTest is Test {
//     BranchManagement public branchManagementImpl;
//     BranchManagement public branchManagement;
//     HistoryTracking public historyTrackingImpl;
//     HistoryTracking public historyTracking;
    
//     address public agent = address(0x1);
//     address public mainOwner = address(0x2);
//     address public coOwner1 = address(0x3);
//     address public coOwner2 = address(0x4);
//     address public manager1 = address(0x5);
//     address public manager2 = address(0x6);
//     address public user1 = address(0x7);
    
//     // Mock contracts
//     address public mockStaffAgentStore = address(0x100);
//     address public mockIqrFactory = address(0x101);
//     address public mockManagement = address(0x102);
    
//     uint256 public constant MAIN_BRANCH_ID = 1;
//     uint256 public constant BRANCH_2_ID = 2;
//     uint256 public constant BRANCH_3_ID = 3;

//     event BranchCreated(uint256 indexed branchId, string name);
//     event ManagerAdded(address indexed manager, bool isCoOwner, uint256[] branchIds);
//     event ProposalCreated(uint256 indexed proposalId, address indexed proposer, ProposalType proposalType, uint256 branchId);
//     event ProposalVoted(uint256 indexed proposalId, address indexed voter, bool support);
//     event ProposalExecuted(uint256 indexed proposalId, ProposalStatus status);

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
        
//         // Setup main owner
//         vm.prank(agent);
//         branchManagement.setMainOwner(mainOwner);
        
//         // Deploy HistoryTracking proxy
//         bytes memory historyInitData = abi.encodeWithSelector(
//             HistoryTracking.initialize.selector,
//             address(branchManagement),
//             mockManagement,
//             agent
//         );
        
//         ERC1967Proxy historyProxy = new ERC1967Proxy(
//             address(historyTrackingImpl),
//             historyInitData
//         );
        
//         historyTracking = HistoryTracking(address(historyProxy));
        
//         // Setup mock contracts
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
        
//         // Set mock contracts
//         vm.startPrank(mainOwner);
//         branchManagement.setStaffAgentStore(mockStaffAgentStore);
//         branchManagement.setIqrFactorySC(mockIqrFactory);
//         vm.stopPrank();
//     }

//     // ==================== BRANCH MANAGEMENT TESTS ====================
    
//     function test_CreateMainBranch() public {
//         vm.startPrank(mainOwner);
        
//         vm.expectEmit(true, false, false, true);
//         emit BranchCreated(MAIN_BRANCH_ID, "Main Branch");
        
//         uint256 branchId = branchManagement.createBranch(
//             MAIN_BRANCH_ID,
//             "Main Branch",
//             true
//         );
        
//         assertEq(branchId, MAIN_BRANCH_ID);
//         assertEq(branchManagement.getMainBranchId(), MAIN_BRANCH_ID);
        
//         (uint256 id, string memory name, bool active, bool isMain) = branchManagement.branches(MAIN_BRANCH_ID);
//         assertEq(id, MAIN_BRANCH_ID);
//         assertEq(name, "Main Branch");
//         assertTrue(active);
//         assertTrue(isMain);
        
//         vm.stopPrank();
//     }
    
//     function test_CreateMultipleBranches() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
//         branchManagement.createBranch(BRANCH_2_ID, "Branch 2", false);
//         branchManagement.createBranch(BRANCH_3_ID, "Branch 3", false);
        
//         Branch[] memory branches = branchManagement.getAllBranches();
//         assertEq(branches.length, 3);
//         assertEq(branches[0].name, "Main Branch");
//         assertEq(branches[1].name, "Branch 2");
//         assertEq(branches[2].name, "Branch 3");
        
//         vm.stopPrank();
//     }
    
//     function test_RevertCreateBranch_AlreadyExists() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         vm.expectRevert("Branch already exists");
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Duplicate Branch", false);
        
//         vm.stopPrank();
//     }
    
//     function test_UpdateBranch() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
//         branchManagement.updateBranch(MAIN_BRANCH_ID, "Updated Main Branch");
        
//         (, string memory name,,) = branchManagement.branches(MAIN_BRANCH_ID);
//         assertEq(name, "Updated Main Branch");
        
//         vm.stopPrank();
//     }
    
//     function test_DeactivateBranch() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
//         branchManagement.createBranch(BRANCH_2_ID, "Branch 2", false);
        
//         branchManagement.deactivateBranch(BRANCH_2_ID);
        
//         (,, bool active,) = branchManagement.branches(BRANCH_2_ID);
//         assertFalse(active);
        
//         vm.stopPrank();
//     }

//     // ==================== MANAGER MANAGEMENT TESTS ====================
    
//     function test_AddFirstManager_DirectExecution() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         vm.expectEmit(true, false, false, true);
//         emit ManagerAdded(coOwner1, true, branchIds);
        
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
        
//         (address wallet,,,,,,,,,) = branchManagement.managers(coOwner1);
//         assertEq(wallet, coOwner1);
        
//         // Verify history was recorded
//         address historyTrackAddr = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         HistoryTracking historyTrack = HistoryTracking(historyTrackAddr);
        
//         (ManagerSnapshot memory oldSnap, ManagerSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTrack.getManagerSnapshots(coOwner1);
        
//         assertTrue(hasNew);
//         assertEq(newSnap.manager.wallet, coOwner1);
//         assertEq(newSnap.manager.name, "Co-Owner 1");
        
//         vm.stopPrank();
//     }
    
//     function test_AddSecondManager_ProposalFlow() public {
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
        
//         // Add second manager - should create proposal
//         vm.startPrank(coOwner1);
        
//         vm.expectEmit(true, true, false, true);
//         emit ProposalCreated(1, coOwner1, ProposalType.ADD_MANAGER, MAIN_BRANCH_ID);
        
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
        
//         // Check proposal created
//         (address proposer, ProposalType pType, uint256 branchId, ProposalStatus status,,,,) = 
//             branchManagement.getProposalDetails(1);
        
//         assertEq(proposer, coOwner1);
//         assertTrue(pType == ProposalType.ADD_MANAGER);
//         assertEq(branchId, MAIN_BRANCH_ID);
//         assertTrue(status == ProposalStatus.APPROVED); // Auto-approved with 1 voter
        
//         // Manager should be added
//         (address wallet,,,,,,,,,) = branchManagement.managers(coOwner2);
//         assertEq(wallet, coOwner2);
        
//         vm.stopPrank();
//     }
    
//     function test_UpdateManager_ProposalFlow() public {
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
        
//         // Update manager
//         vm.startPrank(coOwner1);
        
//         branchManagement.AddAndUpdateManager(
//             coOwner1,
//             "Updated Co-Owner 1",
//             "1111111111",
//             "new_image.jpg",
//             false,
//             branchIds,
//             true,
//             true,
//             true,
//             true
//         );
        
//         // Check manager updated
//         (, string memory name, string memory phone,,,,,,,) = branchManagement.managers(coOwner1);
//         assertEq(name, "Updated Co-Owner 1");
//         assertEq(phone, "1111111111");
        
//         vm.stopPrank();
//     }
    
//     function test_RemoveManager_ProposalFlow() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         // Add managers
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
        
//         // Create proposals
//         vm.startPrank(coOwner1);
        
//         branchManagement.AddAndUpdateManager(
//             manager1,
//             "Manager 1",
//             "5555555555",
//             "manager1.jpg",
//             false,
//             branchIds,
//             false,
//             true,
//             true,
//             false
//         );
        
//         vm.stopPrank();
        
//         // Get dashboard for coOwner1 (has voted on proposal 1, not voted on proposal 2)
//         ManagerProposalDashboard memory dashboard = branchManagement.getManagerDashboardProposal(
//             coOwner1,
//             1,
//             10
//         );
        
//         assertEq(dashboard.totalVoted, 1);
//         assertEq(dashboard.totalUnvoted, 1);
//         assertTrue(dashboard.votedProposals.length > 0);
//         assertTrue(dashboard.unvotedProposals.length > 0);
//     }

//     // ==================== PERMISSION TESTS ====================
    
//     function test_CheckPermissions() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         branchManagement.AddAndUpdateManager(
//             manager1,
//             "Manager 1",
//             "1234567890",
//             "image1.jpg",
//             false,
//             branchIds,
//             false,
//             true,
//             false,
//             false
//         );
        
//         vm.stopPrank();
        
//         // Check manager permissions
//         (bool isManager, bool canView, bool canEdit, bool canPropose) = 
//             branchManagement.checkPermissions(manager1, MAIN_BRANCH_ID);
        
//         assertTrue(isManager);
//         assertTrue(canView);
//         assertFalse(canEdit);
//         assertFalse(canPropose);
        
//         // Check main owner permissions
//         (isManager, canView, canEdit, canPropose) = 
//             branchManagement.checkPermissions(mainOwner, MAIN_BRANCH_ID);
        
//         assertTrue(isManager);
//         assertTrue(canView);
//         assertTrue(canEdit);
//         assertTrue(canPropose);
//     }
    
//     function test_RevertEditData_NoPermission() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         branchManagement.AddAndUpdateManager(
//             manager1,
//             "Manager 1",
//             "1234567890",
//             "image1.jpg",
//             false,
//             branchIds,
//             false,
//             true,
//             false,  // Can't edit
//             false
//         );
        
//         vm.stopPrank();
        
//         // Try to update branch (requires edit permission)
//         vm.startPrank(manager1);
        
//         vm.expectRevert("No edit permission");
//         branchManagement.updateBranch(MAIN_BRANCH_ID, "New Name");
        
//         vm.stopPrank();
//     }

//     // ==================== SYSTEM STATS TESTS ====================
    
//     function test_GetSystemStats() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
//         branchManagement.createBranch(BRANCH_2_ID, "Branch 2", false);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         // Add managers
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
        
//         vm.prank(coOwner1);
//         branchManagement.AddAndUpdateManager(
//             manager1,
//             "Manager 1",
//             "5555555555",
//             "manager1.jpg",
//             false,
//             branchIds,
//             false,
//             true,
//             true,
//             false
//         );
        
//         (
//             uint256 totalBranches,
//             uint256 totalManagers,
//             uint256 totalCoOwners,
//             uint256 totalBranchManagers,
//             uint256 totalProposals,
//             uint256 pendingProposals
//         ) = branchManagement.getSystemStats();
        
//         assertEq(totalBranches, 2);
//         assertEq(totalManagers, 2);
//         assertEq(totalCoOwners, 1);
//         assertEq(totalBranchManagers, 1);
//         assertTrue(totalProposals > 0);
//     }
    
//     function test_GetManagerDashboard() public {
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
        
//         vm.stopPrank();
        
//         (
//             ManagerInfo memory managerInfo,
//             Branch[] memory accessibleBranches,
//             uint256[] memory pendingProposals,
//             uint256 unreadNotifications
//         ) = branchManagement.getManagerDashboard(coOwner1);
        
//         assertEq(managerInfo.wallet, coOwner1);
//         assertEq(managerInfo.name, "Co-Owner 1");
//         assertEq(accessibleBranches.length, 1);
//     }

//     // ==================== PAYMENT METHOD TESTS ====================
    
//     function test_SetPaymentMethodStatuses() public {
//         vm.startPrank(mainOwner);
        
//         PaymentMethod[] memory methods = new PaymentMethod[](2);
//         methods[0] = PaymentMethod.CASH;
//         methods[1] = PaymentMethod.BANK_TRANSFER;
        
//         bool[] memory statuses = new bool[](2);
//         statuses[0] = true;
//         statuses[1] = true;
        
//         branchManagement.setPaymentMethodStatuses(methods, statuses);
        
//         bool[] memory allStatuses = branchManagement.getAllPaymentMethodStatus();
//         assertTrue(allStatuses[uint(PaymentMethod.CASH)]);
//         assertTrue(allStatuses[uint(PaymentMethod.BANK_TRANSFER)]);
        
//         vm.stopPrank();
//     }
    
//     function test_SetCurrency() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.setCurrency(Currency.USD, CurrencyDisplay.SYMBOL);
        
//         (Currency curr, CurrencyDisplay display) = branchManagement.getCurrentDisplay();
//         assertTrue(curr == Currency.USD);
//         assertTrue(display == CurrencyDisplay.SYMBOL);
        
//         vm.stopPrank();
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
// }Owner1);
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
        
//         // Remove manager
//         vm.startPrank(coOwner1);
        
//         branchManagement.removeManager(coOwner2);
        
//         // Check manager removed
//         (,,,,,,,, bool active) = branchManagement.managers(coOwner2);
//         assertFalse(active);
        
//         vm.stopPrank();
//     }
    
//     function test_RevertRemoveManager_NotFound() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         vm.expectRevert("Manager not found");
//         branchManagement.removeManager(user1);
        
//         vm.stopPrank();
//     }

//     // ==================== PROPOSAL TESTS ====================
    
//     function test_ProposalVoting_MultipleVoters() public {
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
        
//         // Add second manager
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
        
//         // Create proposal by adding third manager
//         vm.prank(coOwner1);
//         branchManagement.AddAndUpdateManager(
//             manager1,
//             "Manager 1",
//             "5555555555",
//             "manager1.jpg",
//             false,
//             branchIds,
//             true,
//             true,
//             true,
//             true
//         );
        
//         // Vote on proposal
//         vm.prank(coOwner2);
//         branchManagement.voteProposal(2, true);
        
//         // Check proposal status
//         (,,, ProposalStatus status,,,,) = branchManagement.getProposalDetails(2);
//         assertTrue(status == ProposalStatus.APPROVED || status == ProposalStatus.EXECUTED);
//     }
    
//     function test_ProposalRejection() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         // Add multiple managers
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
        
//         // Update voting threshold to require more votes
//         vm.prank(mainOwner);
//         branchManagement.updateVotingThreshold(100); // 100% required
        
//         // Create proposal
//         vm.prank(coOwner1);
//         branchManagement.AddAndUpdateManager(
//             manager1,
//             "Manager 1",
//             "5555555555",
//             "manager1.jpg",
//             false,
//             branchIds,
//             false,
//             true,
//             true,
//             false
//         );
        
//         // Vote against
//         vm.prank(coOwner2);
//         branchManagement.voteProposal(2, false);
        
//         // Vote against by mainOwner too
//         vm.prank(mainOwner);
//         branchManagement.voteProposal(2, false);
        
//         // Check if rejected
//         (,,, ProposalStatus status,,,,) = branchManagement.getProposalDetails(2);
//         assertTrue(status == ProposalStatus.REJECTED);
//     }
    
//     function test_RevertVoting_AlreadyVoted() public {
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
        
//         vm.stopPrank();
        
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
        
//         vm.startPrank(coOwner1);
        
//         vm.expectRevert("Already voted");
//         branchManagement.voteProposal(1, true);
        
//         vm.stopPrank();
//     }

//     // ==================== PAYMENT ACCOUNT TESTS ====================
    
//     function test_SetPaymentAccount_FirstTime() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         branchManagement.setPaymentAccount(
//             "123456789",
//             "John Doe",
//             "ABC Bank",
//             "TAX123",
//             "0xWallet"
//         );
        
//         // Check payment info
//         (string memory bankAcc, string memory nameAcc,,,) = branchManagement.paymentInfo();
//         assertEq(bankAcc, "123456789");
//         assertEq(nameAcc, "John Doe");
        
//         vm.stopPrank();
//     }
    
//     function test_UpdatePaymentAccount_ProposalFlow() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         // Add co-owner
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
        
//         // Set first payment account
//         branchManagement.setPaymentAccount(
//             "123456789",
//             "John Doe",
//             "ABC Bank",
//             "TAX123",
//             "0xWallet"
//         );
        
//         vm.stopPrank();
        
//         // Update payment account - should create proposal
//         vm.prank(coOwner1);
//         branchManagement.setPaymentAccount(
//             "987654321",
//             "Jane Doe",
//             "XYZ Bank",
//             "TAX456",
//             "0xNewWallet"
//         );
        
//         // Check payment info updated
//         (string memory bankAcc, string memory nameAcc,,,) = branchManagement.paymentInfo();
//         assertEq(bankAcc, "987654321");
//         assertEq(nameAcc, "Jane Doe");
//     }

//     // ==================== HISTORY TRACKING TESTS ====================
    
//     function test_HistoryTracking_ManagerCreate() public {
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
        
//         // Get history tracking contract
//         address historyTrackAddr = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         HistoryTracking historyTrack = HistoryTracking(historyTrackAddr);
        
//         // Check snapshot saved
//         (ManagerSnapshot memory oldSnap, ManagerSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTrack.getManagerSnapshots(coOwner1);
        
//         assertTrue(hasNew);
//         assertFalse(hasOld);
//         assertEq(newSnap.manager.name, "Co-Owner 1");
//         assertTrue(newSnap.timestamp > 0);
        
//         // Check history entry
//         (HistoryEntry[] memory entries, uint256 total) = historyTrack.getHistoryByType(
//             EntityType.MANAGER,
//             0,
//             10
//         );
        
//         assertEq(total, 1);
//         assertEq(entries[0].entityId, _addressToString(coOwner1));
//         assertTrue(entries[0].actionType == ActionType.CREATE);
        
//         vm.stopPrank();
//     }
    
//     function test_HistoryTracking_ManagerUpdate() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         // Create manager
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
        
//         // Update manager
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
        
//         // Get history tracking contract
//         address historyTrackAddr = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         HistoryTracking historyTrack = HistoryTracking(historyTrackAddr);
        
//         // Check snapshots
//         (ManagerSnapshot memory oldSnap, ManagerSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTrack.getManagerSnapshots(coOwner1);
        
//         assertTrue(hasNew);
//         assertTrue(hasOld);
//         assertEq(oldSnap.manager.name, "Co-Owner 1");
//         assertEq(newSnap.manager.name, "Updated Co-Owner 1");
        
//         // Check history entries
//         (HistoryEntry[] memory entries, uint256 total) = historyTrack.getHistoryByEntity(
//             EntityType.MANAGER,
//             _addressToString(coOwner1),
//             0,
//             10
//         );
        
//         assertEq(total, 2);
//         assertTrue(entries[0].actionType == ActionType.UPDATE); // Most recent
//         assertTrue(entries[1].actionType == ActionType.CREATE);
//     }
    
//     function test_HistoryTracking_PaymentInfoUpdate() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         // Set payment account first time
//         branchManagement.setPaymentAccount(
//             "123456789",
//             "John Doe",
//             "ABC Bank",
//             "TAX123",
//             "0xWallet"
//         );
        
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
        
//         vm.stopPrank();
        
//         // Update payment account
//         vm.prank(coOwner1);
//         branchManagement.setPaymentAccount(
//             "987654321",
//             "Jane Doe",
//             "XYZ Bank",
//             "TAX456",
//             "0xNewWallet"
//         );
        
//         // Get history tracking contract
//         address historyTrackAddr = branchManagement.mBranchIdToHistoryTrack(MAIN_BRANCH_ID);
//         HistoryTracking historyTrack = HistoryTracking(historyTrackAddr);
        
//         // Check snapshots
//         (PaymentInfoSnapshot memory oldSnap, PaymentInfoSnapshot memory newSnap, bool hasOld, bool hasNew) = 
//             historyTrack.getPaymentInfoSnapshots(0);
        
//         assertTrue(hasNew);
//         assertTrue(hasOld);
//         assertEq(oldSnap.paymentInfo.bankAccount, "123456789");
//         assertEq(newSnap.paymentInfo.bankAccount, "987654321");
        
//         vm.stopPrank();
//     }

//     // ==================== PAGINATION TESTS ====================
    
//     function test_GetAllProposalsPaginated() public {
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
//         vm.startPrank(coOwner1);
        
//         for (uint i = 0; i < 5; i++) {
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
        
//         vm.stopPrank();
        
//         // Test pagination
//         PaginatedProposals memory page1 = branchManagement.getAllProposalsPaginated(1, 3);
//         assertEq(page1.proposals.length, 3);
//         assertEq(page1.total, 5);
//         assertEq(page1.page, 1);
//         assertEq(page1.totalPages, 2);
        
//         PaginatedProposals memory page2 = branchManagement.getAllProposalsPaginated(2, 3);
//         assertEq(page2.proposals.length, 2);
//         assertEq(page2.page, 2);
//     }
    
//     function test_GetManagerDashboardProposal() public {
//         vm.startPrank(mainOwner);
        
//         branchManagement.createBranch(MAIN_BRANCH_ID, "Main Branch", true);
        
//         uint256[] memory branchIds = new uint256[](1);
//         branchIds[0] = MAIN_BRANCH_ID;
        
//         // Add managers
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
        
//         vm.prank(co