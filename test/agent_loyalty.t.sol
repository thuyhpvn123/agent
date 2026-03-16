// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import "../contracts/agent.sol";
// import "../contracts/agentIqr.sol";
// import "../contracts/agentLoyalty.sol";
// import "../contracts/enhance.sol";
// import "../contracts/interfaces/IAgent.sol";
// import "../contracts/loyaltyFactory.sol";
// import "../contracts/iqrFactory.sol";
// import "../contracts/revenue.sol";
// import "../contracts/mtd.sol";
// import "./res.t.sol";
// import "../contracts/staffMatch.sol";
// import "../contracts/interfaces/IManagement.sol";
// /**
//  * @title Agent Management Integration Test
//  * @notice Comprehensive integration tests for the Agent Management system
//  * @dev Tests full workflow including create, update, delete, pagination, and loyalty operations
//  */

// contract AgentManagementIntegrationTest is RestaurantTest {
//      using Strings for uint256;
//     // Contracts
//     AgentManagement public agentManagementImplementation;
//     AgentManagement public agentManagement;
//     EnhancedAgentManagement public enhancedImplementation;
//     EnhancedAgentManagement public enhanced;
    
//     IQRFactory public iqrFactoryImplementation;
//     IQRFactory public iqrFactory;
    
//     LoyaltyFactory public loyaltyFactoryImplementation;
//     LoyaltyFactory public loyaltyFactory;
    
//     RevenueManager public revenueManagerImplementation;
//     RevenueManager public revenueManager;
    
//     MTDToken public mtdTokenImplementation;
//     MTDToken public mtdToken;
    
//     StaffAgentStore public staffAgentStoreImplementation;
//     StaffAgentStore public staffAgentStore;
//     // Test accounts

//     Management public management;
//     RestaurantLoyaltySystem public Points;
//     // address public customer1;
//     // address public customer2;
//     string public domain="domain";
//     constructor() {
//         // Setup accounts

//         customer1 = makeAddr("customer1");
//         customer2 = makeAddr("customer2");
        
//         // vm.deal(superAdmin, 100 ether);
        
//         // Deploy all contracts with proxy pattern
//         vm.startPrank(superAdmin);
        
//         // 1. Deploy AgentManagement
//         agentManagementImplementation = new AgentManagement();
//         ERC1967Proxy agentProxy = new ERC1967Proxy(
//             address(agentManagementImplementation),
//             abi.encodeWithSignature("initialize()")
//         );
//         agentManagement = AgentManagement(address(agentProxy));
        
//         // 2. Deploy IQRFactory
//         iqrFactoryImplementation = new IQRFactory();
//         ERC1967Proxy iqrProxy = new ERC1967Proxy(
//             address(iqrFactoryImplementation),
//             abi.encodeWithSignature("initialize()")
//         );
//         iqrFactory = IQRFactory(address(iqrProxy));
        
//         // 3. Deploy LoyaltyFactory
//         loyaltyFactoryImplementation = new LoyaltyFactory();
//         ERC1967Proxy loyaltyProxy = new ERC1967Proxy(
//             address(loyaltyFactoryImplementation),
//             abi.encodeWithSignature("initialize()")
//         );
//         loyaltyFactory = LoyaltyFactory(address(loyaltyProxy));
        
//         // 4. Deploy RevenueManager
//         revenueManagerImplementation = new RevenueManager();
//         ERC1967Proxy revenueProxy = new ERC1967Proxy(
//             address(revenueManagerImplementation),
//             abi.encodeWithSignature("initialize()")
//         );
//         revenueManager = RevenueManager(address(revenueProxy));
        
//         // 5. Deploy MTDToken
//         mtdTokenImplementation = new MTDToken();
//         ERC1967Proxy mtdProxy = new ERC1967Proxy(
//             address(mtdTokenImplementation),
//             abi.encodeWithSignature("initialize(uint256)", 1000000)
//         );
//         // mtdToken = MTDToken(address(mtdProxy));
        
//         // 6. Deploy EnhancedAgentManagement (inherits from AgentManagement)
//         enhancedImplementation = new EnhancedAgentManagement();
//         ERC1967Proxy enhancedProxy = new ERC1967Proxy(
//             address(enhancedImplementation),
//             abi.encodeWithSignature("initialize()")
//         );
//         enhanced = EnhancedAgentManagement(address(enhancedProxy));

//         // 7. Deploy StaffAgentStore
//         staffAgentStoreImplementation = new StaffAgentStore();
//         ERC1967Proxy staffAgentStoreProxy = new ERC1967Proxy(
//             address(staffAgentStoreImplementation),
//             abi.encodeWithSignature("initialize()")
//         );
//         staffAgentStore = StaffAgentStore(address(staffAgentStoreProxy));
//         // Setup admin
//         enhanced.setAdmin(superAdmin);
               
//         enhanced.setFactoryContracts(
//             address(iqrFactory),
//             address(loyaltyFactory),
//             address(revenueManager)
//             // address(mtdToken)
//         );
//         iqrFactory.setEnhancedAgent(address(enhanced));
//         iqrFactory.setIQRSC(
//             address(MANAGEMENT_IMP),
//             address(ORDER_IMP),
//             address(REPORT_IMP),
//             address(TIMEKEEPING_IMP),
//             0x10F4A365ff344b3Af382aBdB507c868F1c22f592,
//             0x603dbFC668521aB143Ee1018e4D80b13FDDedfBd,
//             address(revenueManager),
//             address(staffAgentStore)
//         );
//         loyaltyFactory.setPointsImp(address(POINTS_IMP));
//         loyaltyFactory.setEnhancedAgent(address(enhanced));
//         revenueManager.setEnhancedAgent(address(enhanced));

//         staffAgentStore.setEnhancedAgent(address(enhanced));
//         staffAgentStore.setIqrFactory(address(iqrFactory));
//         vm.stopPrank();
        
//         console.log("=== Setup Complete ===");
//         console.log("Super Admin:", superAdmin);
//         console.log("AgentManagement:", address(agentManagement));
//         console.log("EnhancedAgentManagement:", address(enhanced));
//         console.log("IQRFactory:", address(iqrFactory));
//         console.log("LoyaltyFactory:", address(loyaltyFactory));
//     }
    
//     // ========================================================================
//     // TEST 1: createAgentWithAnalytics
//     // ========================================================================
    
//     function test_CreateAgentWithAnalytics_Success() public {
//         vm.startBroadcast(superAdmin);
        
//         // Prepare data
//         string memory storeName = "Store One";
//         string memory storeAddress = "123 Main St";
//         string memory phone = "0123456789";
//         string memory note = "Test store";
//         bool[3] memory permissions = [true, true, true]; // All permissions
//         string[] memory subLocations = new string[](2);
//         subLocations[0] = "Branch A";
//         subLocations[1] = "Branch B";
//         string[] memory subPhones = new string[](2);
//         subPhones[0] = "0111111111";
//         subPhones[1] = "0122222222";
                
//         // Create agent
//         bool success = enhanced.createAgentWithAnalytics(
//             agent1,
//             storeName,
//             storeAddress,
//             phone,
//             note,
//             permissions,
//             subLocations,
//             subPhones,
//             domain
//         );
//         enhanced.setAgentIQR(agent1);
//         //
//         enhanced.setPointsIQR(agent1);
//     bytes memory bytesCodeCall = abi.encodeCall(
//     enhanced.setAgentIQR,
//         (
//             agent1          
//         ));
//     console.log("setAgentIQR:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     ); 
//         assertTrue(success, "Agent creation should succeed");
        
//         // Verify agent data
//         Agent memory agent = enhanced.getAgent(agent1);
//         assertEq(agent.walletAddress, agent1);
//         assertEq(agent.storeName, storeName);
//         assertEq(agent.storeAddress, storeAddress);
//         assertEq(agent.phone, phone);
//         assertTrue(agent.isActive);
//         assertTrue(agent.exists);
//         assertTrue(agent.permissions[0]); // IQR
//         assertTrue(agent.permissions[1]); // Loyalty
//         assertTrue(agent.permissions[2]); // MeOS
//         assertEq(agent.subLocations.length, 2);
        
//         // Verify analytics
//         AgentAnalytics memory analytics = enhanced.getAgentAnalytics(agent1);
//         assertEq(analytics.totalOrders, 0);
//         assertEq(analytics.totalRevenue, 0);
//         assertEq(analytics.performanceScore, 50); // Starting score
//         assertEq(analytics.meosLicensesActive, 1);
        
//         // Verify contracts were created
//         address iqrContract = enhanced.agentIQRContracts(agent1);
//         address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
//         assertTrue(iqrContract != address(0), "IQR contract should be created");
//         assertTrue(loyaltyContract != address(0), "Loyalty contract should be created");
        
//         // Verify MeOS license
//         MeOSLicense memory license = enhanced.getMeOSLicense(agent1);
//         assertTrue(license.isActive);
//         assertTrue(bytes(license.licenseKey).length > 0);
        
//         vm.stopPrank();
        
//         console.log("Test 1 PASSED: createAgentWithAnalytics");
//     }
    
//     function test_CreateAgentWithAnalytics_MultipleAgents() public {
//         vm.startPrank(superAdmin);
        
//         // Create multiple agents
//         address[] memory agents = new address[](3);
//         agents[0] = agent1;
//         agents[1] = agent2;
//         agents[2] = agent3;
        
//         for (uint i = 0; i < agents.length; i++) {
//             string memory storeName = string(abi.encodePacked("Store ", vm.toString(i + 1)));
//             bool[3] memory permissions = [true, true, false]; // IQR + Loyalty only
//             string[] memory subLocations = new string[](1);
//             subLocations[0] = "Main Branch";
//             string[] memory subPhones = new string[](1);
//             subPhones[0] = "0123456789";
            
//             bool success = enhanced.createAgentWithAnalytics(
//                 agents[i],
//                 storeName,
//                 "Address",
//                 "Phone",
//                 "Note",
//                 permissions,
//                 subLocations,
//                 subPhones,
//                 i.toString()
//             );
            
//             assertTrue(success);
//         }
        
//         // Verify all agents created
//         address[] memory allAgents = enhanced.getAllAgents();
//         assertEq(allAgents.length, 3, "Should have 3 agents");
        
//         vm.stopPrank();
        
//         console.log("Test 1b PASSED: Multiple agents created");
//     }
    
//     // ========================================================================
//     // TEST 2: updateAgent
//     // ========================================================================
    
//     function test_UpdateAgent_Success() public {
//         // First create an agent
//         vm.startPrank(superAdmin);
        
//         bool[3] memory initialPermissions = [true, false, false];
//         string[] memory subLocations = new string[](1);
//         subLocations[0] = "Branch A";
//         string[] memory subPhones = new string[](1);
//         subPhones[0] = "0111111111";
        
//         enhanced.createAgentWithAnalytics(
//             agent1,
//             "Old Store Name",
//             "Old Address",
//             "0123456789",
//             "Old Note",
//             initialPermissions,
//             subLocations,
//             subPhones,
//             domain
//         );
        
//         // Update agent
//         string memory newStoreName = "New Store Name";
//         string memory newAddress = "New Address";
//         string memory newPhone = "9876543210";
//         string memory newNote = "Updated Note";
//         bool[3] memory newPermissions = [true, true, true]; // Grant all permissions
        
//         // Update subLocations
//         string[] memory updatedSubLocations = new string[](1);
//         updatedSubLocations[0] = "Updated Branch A";
//         uint[] memory subLocationIndexes = new uint[](1);
//         subLocationIndexes[0] = 0;
        
//         // Update subPhones
//         string[] memory updatedSubPhones = new string[](1);
//         updatedSubPhones[0] = "0999999999";
//         uint[] memory subPhoneIndexes = new uint[](1);
//         subPhoneIndexes[0] = 0;
        
//         enhanced.updateAgent(
//             agent1,
//             newStoreName,
//             newAddress,
//             newPhone,
//             newNote,
//             newPermissions,
//             updatedSubLocations,
//             updatedSubPhones,
//             "domain_new"
//         );
        
//         // Verify updates
//         Agent memory updatedAgent = enhanced.getAgent(agent1);
//         assertEq(updatedAgent.storeName, newStoreName);
//         assertEq(updatedAgent.storeAddress, newAddress);
//         assertEq(updatedAgent.phone, newPhone);
//         assertEq(updatedAgent.note, newNote);
//         assertTrue(updatedAgent.permissions[0]); // IQR
//         assertTrue(updatedAgent.permissions[1]); // Loyalty (newly granted)
//         assertTrue(updatedAgent.permissions[2]); // MeOS (newly granted)
//         assertEq(updatedAgent.subLocations[0], "Updated Branch A");
//         assertEq(updatedAgent.subPhones[0], "0999999999");
        
//         // Verify new contracts were created
//         address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
//         assertTrue(loyaltyContract != address(0), "Loyalty contract should be created");
        
//         vm.stopPrank();
        
//         console.log("Test 2 PASSED: updateAgent");
//     }
    
//     // ========================================================================
//     // TEST 3: deleteAgent
//     // ========================================================================
    
//     // function test_DeleteAgent_Success() public {
//     //     vm.startPrank(superAdmin);
        
//     //     // Create agent
//     //     bool[3] memory permissions = [true, false, true]; // IQR + MeOS (no loyalty)
//     //     string[] memory subLocations = new string[](1);
//     //     subLocations[0] = "Branch";
//     //     string[] memory subPhones = new string[](1);
//     //     subPhones[0] = "0123456789";
        
//     //     enhanced.createAgentWithAnalytics(
//     //         agent1,
//     //         "Store To Delete",
//     //         "Address",
//     //         "Phone",
//     //         "Note",
//     //         permissions,
//     //         subLocations,
//     //         subPhones,
//     //         domain
//     //     );
//     //     enhanced.setAgentIQR( agent1);
//     //     enhanced.setPointsIQR( agent1);

//     //     // Verify agent exists and is active
//     //     Agent memory agentBefore = enhanced.getAgent(agent1);
//     //     assertTrue(agentBefore.isActive);
        
//     //     // Delete agent
        
//     //     enhanced.deleteAgent(agent1);
        
//     //     // Verify agent is deleted
//     //     Agent memory agentAfter = enhanced.getAgent(agent1);
//     //     assertFalse(agentAfter.isActive, "Agent should be inactive");
//     //     assertTrue(agentAfter.exists, "Agent should still exist in records");
        
//     //     // Verify deleted agents list
//     //     Agent[] memory deletedAgents = enhanced.getDeletedAgentd();
//     //     assertEq(deletedAgents.length, 1, "Should have 1 deleted agent");
//     //     assertEq(deletedAgents[0].walletAddress, agent1);
        
//     //     vm.stopPrank();
        
//     //     console.log("Test 3 PASSED: deleteAgent");
//     // }
    
//     function test_DeleteAgent_WithActiveLoyaltyTokens_ShouldRevert() public {
//         vm.startPrank(superAdmin);
        
//         // Create agent with loyalty permission
//         bool[3] memory permissions = [true, true, false];
//         string[] memory subLocations = new string[](1);
//         subLocations[0] = "Branch";
//         string[] memory subPhones = new string[](1);
//         subPhones[0] = "0123456789";
        
//         enhanced.createAgentWithAnalytics(
//             agent1,
//             "Store With Loyalty",
//             "Address",
//             "Phone",
//             "Note",
//             permissions,
//             subLocations,
//             subPhones,
//             domain
//         );
//         enhanced.setAgentIQR(agent1);
//         enhanced.setPointsIQR(agent1);

//         // Mint some loyalty tokens
//         address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
//         vm.stopPrank();
        
//         vm.prank(agent1);
//         RestaurantLoyaltySystem(loyaltyContract).mint(customer1, 1000 ether, "Initial mint");
        
//         // Try to delete agent with active tokens - should revert
//         vm.prank(superAdmin);
//         vm.expectRevert("HasActiveLoyaltyTokens");
//         enhanced.deleteAgent(agent1);
        
//         console.log("Test 3b PASSED: Cannot delete agent with active loyalty tokens");
//     }
    
//     function test_DeleteAgent_AfterFreezingLoyalty_Success() public {
//         vm.startPrank(superAdmin);
        
//         // Create agent with loyalty
//         bool[3] memory permissions = [true, true, false];
//         string[] memory subLocations = new string[](1);
//         subLocations[0] = "Branch";
//         string[] memory subPhones = new string[](1);
//         subPhones[0] = "0123456789";
        
//         enhanced.createAgentWithAnalytics(
//             agent1,
//             "Store",
//             "Address",
//             "Phone",
//             "Note",
//             permissions,
//             subLocations,
//             subPhones,
//             domain
//         );
//         enhanced.setAgentIQR(agent1);
//         enhanced.setPointsIQR(agent1);

//         // Mint tokens
//         address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
//         vm.stopPrank();
        
//         vm.prank(agent1);
//         RestaurantLoyaltySystem(loyaltyContract).mint(customer1, 1000 ether, "Mint");
        
//         // Freeze the loyalty contract
//         vm.prank(agent1);
//         RestaurantLoyaltySystem(loyaltyContract).freeze();
        
//         // Now deletion should succeed
//         vm.prank(superAdmin);
//         enhanced.deleteAgent(agent1);
        
//         Agent memory deletedAgent = enhanced.getAgent(agent1);
//         assertFalse(deletedAgent.isActive);
        
//         console.log("Test 3c PASSED: Can delete after freezing loyalty");
//     }
    
//     // ========================================================================
//     // TEST 4: getDeletedAgents
//     // ========================================================================
    
//     function test_GetDeletedAgents_Multiple() public {
//         vm.startPrank(superAdmin);
        
//         bool[3] memory permissions = [true, false, false];
//         string[] memory subLocations = new string[](1);
//         subLocations[0] = "Branch";
//         string[] memory subPhones = new string[](1);
//         subPhones[0] = "0123456789";
        
//         // Create and delete multiple agents
//         address[] memory agents = new address[](3);
//         agents[0] = agent1;
//         agents[1] = agent2;
//         agents[2] = agent3;
        
//         for (uint i = 0; i < agents.length; i++) {
//             enhanced.createAgentWithAnalytics(
//                 agents[i],
//                 string(abi.encodePacked("Store ", vm.toString(i))),
//                 "Address",
//                 "Phone",
//                 "Note",
//                 permissions,
//                 subLocations,
//                 subPhones,
//                 i.toString()
//             );
//             enhanced.setAgentIQR( agents[i]);
//             enhanced.setPointsIQR( agents[i]);
//             enhanced.deleteAgent(agents[i]);
//         }
        
//         // Get all deleted agents
//         Agent[] memory deletedAgents = enhanced.getDeletedAgentd();
//         assertEq(deletedAgents.length, 3, "Should have 3 deleted agents");
        
//         // Verify all are inactive
//         for (uint i = 0; i < deletedAgents.length; i++) {
//             assertFalse(deletedAgents[i].isActive);
//         }
        
//         vm.stopPrank();
        
//         console.log("Test 4 PASSED: getDeletedAgents with multiple agents");
//     }
    
//     // ========================================================================
//     // TEST 5: unlockLoyaltyTokens
//     // ========================================================================
    
//     // function test_UnlockLoyaltyTokens_Success() public {
//     //     vm.startPrank(superAdmin);
        
//     //     // Create agent with loyalty
//     //     bool[3] memory permissions = [false, true, false];
//     //     string[] memory subLocations = new string[](1);
//     //     subLocations[0] = "Branch";
//     //     string[] memory subPhones = new string[](1);
//     //     subPhones[0] = "0123456789";
        
//     //     enhanced.createAgentWithAnalytics(
//     //         agent1,
//     //         "Store",
//     //         "Address",
//     //         "Phone",
//     //         "Note",
//     //         permissions,
//     //         subLocations,
//     //         subPhones,
//     //         domain
//     //     );
        
//     //     address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
//     //     vm.stopPrank();
        
//     //     // Mint tokens to the loyalty contract itself
//     //     vm.prank(agent1);
//     //     RestaurantLoyaltySystem(loyaltyContract).mint(loyaltyContract, 5000 , "Locked tokens");
        
//     //     // Freeze to enable unlock
//     //     vm.prank(agent1);
//     //     RestaurantLoyaltySystem(loyaltyContract).freeze();
        
//     //     uint256 contractBalanceBefore = RestaurantLoyaltySystem(loyaltyContract).balanceOf(loyaltyContract);
//     //     assertEq(contractBalanceBefore, 5000 );
        
//     //     // Unlock tokens
//     //     vm.startBroadcast(superAdmin);
        
//     //     uint256 unlockedAmount = enhanced.unlockLoyaltyTokens(agent1);
        
//     //     assertEq(unlockedAmount, 5000 , "Should unlock all tokens");
        
//     //     // Verify tokens moved to agent
//     //     uint256 agentBalance = RestaurantLoyaltySystem(loyaltyContract).balanceOf(agent1);
//     //     assertEq(agentBalance, 5000 , "Agent should receive unlocked tokens");
        
//     //     uint256 contractBalanceAfter = RestaurantLoyaltySystem(loyaltyContract).balanceOf(loyaltyContract);
//     //     assertEq(contractBalanceAfter, 0, "Contract balance should be 0");
        
//     //     console.log("Test 5 PASSED: unlockLoyaltyTokens");
//     //     // GetByteCode();
//     // }
    
//     // function test_MigrateLoyaltyTokens_Success() public {
//     //     vm.startPrank(superAdmin);
        
//     //     bool[3] memory permissions = [false, true, false];
//     //     string[] memory subLocations = new string[](1);
//     //     subLocations[0] = "Branch";
//     //     string[] memory subPhones = new string[](1);
//     //     subPhones[0] = "0123456789";
        
//     //     // Create old agent
//     //     enhanced.createAgentWithAnalytics(
//     //         agent1,
//     //         "Old Store",
//     //         "Address",
//     //         "Phone",
//     //         "Note",
//     //         permissions,
//     //         subLocations,
//     //         subPhones,
//     //         "domain1"
//     //     );
        
//     //     // Create new agent
//     //     enhanced.createAgentWithAnalytics(
//     //         agent2,
//     //         "New Store",
//     //         "Address",
//     //         "Phone",
//     //         "Note",
//     //         permissions,
//     //         subLocations,
//     //         subPhones,
//     //         "domain2"
//     //     );
        
//     //     address oldLoyaltyContract = enhanced.agentLoyaltyContracts(agent1);
//     //     address newLoyaltyContract = enhanced.agentLoyaltyContracts(agent2);
        
//     //     vm.stopPrank();
        
//     //     // Mint tokens in old contract
//     //     vm.prank(agent1);
//     //     RestaurantLoyaltySystem(oldLoyaltyContract).mint(customer1, 10000 ether, "Old tokens");
        
//     //     uint256 oldSupply = RestaurantLoyaltySystem(oldLoyaltyContract).totalSupply();
//     //     assertEq(oldSupply, 10000 ether);
        
//     //     // Migrate tokens
//     //     vm.prank(superAdmin);
        
//     //     uint256 migratedAmount = enhanced.migrateLoyaltyTokens(agent1, agent2);
        
//     //     assertEq(migratedAmount, oldSupply, "Should return migrated amount");
        
//     //     // Verify old contract is frozen and in redeem-only mode
//     //     assertTrue(RestaurantLoyaltySystem(oldLoyaltyContract).isFrozen());
//     //     assertTrue(RestaurantLoyaltySystem(oldLoyaltyContract).isRedeemOnly());
//     //     assertTrue(RestaurantLoyaltySystem(oldLoyaltyContract).isMigrated());
        
//     //     console.log("Test 6 PASSED: migrateLoyaltyTokens");
//     // }
    
//     // ========================================================================
//     // TEST 7: getAgentsInfoPaginatedWithPermissions
//     // ========================================================================
    
//     function test_GetAgentsInfoPaginatedWithPermissions_Success() public {
//         uint currentTime = 1760089361;//16h43 ngay10/10/2025
//         vm.warp(currentTime); 
//         vm.startPrank(superAdmin);
        
//         // Create agents with different permissions
//         bool[3] memory allPermissions = [true, true, true];
//         bool[3] memory iqrOnly = [true, false, false];
//         bool[3] memory loyaltyAndIqr = [true, true, false];
//         bool[3] memory noFilter = [false, false, false];

//         string[] memory subLocations = new string[](1);
//         subLocations[0] = "Branch";
//         string[] memory subPhones = new string[](1);
//         subPhones[0] = "0123456789";
//         // Agent 1: All permissions
//         enhanced.createAgentWithAnalytics(
//             agent1,
//             "Store 1",
//             "Address 1",
//             "Phone",
//             "Note",
//             allPermissions,
//             subLocations,
//             subPhones,
//             domain
//         );
        
//         vm.warp(currentTime + 1 seconds);
        
//         // Agent 2: IQR only
//         enhanced.createAgentWithAnalytics(
//             agent2,
//             "Store 2",
//             "Address 2",
//             "Phone",
//             "Note",
//             iqrOnly,
//             subLocations,
//             subPhones,
//             "domain1"
//         );
        
//         vm.warp(currentTime + 2 seconds);
        
//         // Agent 3: Loyalty only
//         enhanced.createAgentWithAnalytics(
//             agent3,
//             "Store 3",
//             "Address 3",
//             "Phone",
//             "Note",
//             loyaltyAndIqr,
//             subLocations,
//             subPhones,
//             "domain2"
//         );
        
//         vm.warp(currentTime + 3 seconds);
        
//         // Agent 4: All permissions
//         enhanced.createAgentWithAnalytics(
//             agent4,
//             "Store 4",
//             "Address 4",
//             "Phone",
//             "Note",
//             allPermissions,
//             subLocations,
//             subPhones,
//             "domain3"
//         );
        
//         // Test 1: Get all agents (no permission filter)
//         // bool[3] memory noFilter = [false, false, false];
//         (
//             AgentInfo[] memory allAgentsPage1,
//             uint256 totalCount,
//             uint256 totalPages,
//             uint256 currentPage
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             0, // from time
//             currentTime+4, // to time
//             "createdAt", // sort by
//             true, // ascending
//             1, // page
//             10, // page size
//             noFilter
//         );
        
//         assertEq(totalCount, 4, "Should have 4 total agents");
//         assertEq(allAgentsPage1.length, 4, "Page should have 4 agents");
//         assertEq(currentPage, 1);
        
//         // Test 2: Filter by IQR permission only
//         bool[3] memory iqrFilter = [true, false, false];
//         (
//             AgentInfo[] memory iqrAgents,
//             uint256 iqrCount,
//             ,
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             0,
//             currentTime+4,
//             "createdAt",
//             true,
//             1,
//             10,
//             iqrFilter
//         );
        
//         assertEq(iqrCount, 4, "Should have 4 agents with IQR");
//         assertEq(iqrAgents.length, 4);
        
//         // Verify all returned agents have IQR permission
//         for (uint i = 0; i < iqrAgents.length; i++) {
//             assertTrue(iqrAgents[i].permissions[0], "Agent should have IQR permission");
//         }
        
//         // Test 3: Filter by Loyalty permission only
//         bool[3] memory loyaltyFilter = [false, true, false];
//         (
//             AgentInfo[] memory loyaltyAgents,
//             uint256 loyaltyCount,
//             ,
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             0,
//             currentTime+4,
//             "createdAt",
//             true,
//             1,
//             10,
//             loyaltyFilter
//         );
        
//         assertEq(loyaltyCount, 3, "Should have 3 agents with Loyalty");
        
//         // Test 4: Filter by all permissions (AND logic)
//         bool[3] memory allFilter = [true, true, true];
//         (
//             AgentInfo[] memory fullPermAgents,
//             uint256 fullPermCount,
//             ,
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             0,
//             currentTime+4,
//             "createdAt",
//             true,
//             1,
//             10,
//             allFilter
//         );
        
//         assertEq(fullPermCount, 2, "Should have 2 agents with all permissions");
        
//         // Verify all returned agents have all permissions
//         for (uint i = 0; i < fullPermAgents.length; i++) {
//             assertTrue(fullPermAgents[i].permissions[0], "Should have IQR");
//             assertTrue(fullPermAgents[i].permissions[1], "Should have Loyalty");
//             assertTrue(fullPermAgents[i].permissions[2], "Should have MeOS");
//         }
        
//         // Test 5: Pagination with small page size
//         (
//             AgentInfo[] memory page1,
//             uint256 count,
//             uint256 pages,
//             uint256 currPage
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             0,
//             currentTime+4,
//             "createdAt",
//             true,
//             1,
//             2, // Only 2 per page
//             noFilter
//         );
        
//         assertEq(count, 4, "Total should be 4");
//         assertEq(pages, 2, "Should have 2 pages");
//         assertEq(page1.length, 2, "Page 1 should have 2 agents");
//         assertEq(currPage, 1);
        
//         // Get page 2
//         (
//             AgentInfo[] memory page2,
//             ,
//             ,
//             uint256 currPage2
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             0,
//             currentTime+4,
//             "createdAt",
//             true,
//             2,
//             2,
//             noFilter
//         );
        
//         assertEq(page2.length, 2, "Page 2 should have 2 agents");
//         assertEq(currPage2, 2);
        
//         // Verify no overlap between pages
//         assertTrue(page1[0].walletAddress != page2[0].walletAddress);
        
//         // Test 6: Sort by creation time descending
//         (
//             AgentInfo[] memory descendingAgents,
//             ,
//             ,
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             0,
//             currentTime+4,
//             "createdAt",
//             false, // descending
//             1,
//             10,
//             noFilter
//         );
        
//         // Verify sorting - newest first
//         assertEq(descendingAgents[0].walletAddress, agent4, "First should be agent4 (newest)");
//         assertEq(descendingAgents[3].walletAddress, agent1, "Last should be agent1 (oldest)");
        
//         // Test 7: Time range filter
//         uint256 midTime = currentTime+ 4 - 2 ;
//         (
//             AgentInfo[] memory recentAgents,
//             uint256 recentCount,
//             ,
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             midTime,
//             block.timestamp,
//             "createdAt",
//             true,
//             1,
//             10,
//             noFilter
//         );
//         // Should only get agents 3 and 4 (created in last 2 days)
//         assertEq(recentCount, 2, "Should have 2 recent agents");
        
        
        
//         console.log("Test 7 PASSED: getAgentsInfoPaginatedWithPermissions");
//         //
//         vm.warp(currentTime + 7 seconds);
//         // Agent 5: No permissions
//         enhanced.createAgentWithAnalytics(
//             address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B),
//             "Store 5",
//             "Address 5",
//             "Phone",
//             "Note",
//             noFilter,
//             subLocations,
//             subPhones,
//             "domain4"
//         );
        
//         (
//             AgentInfo[] memory agents,
//             ,
//             ,
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             0,
//             currentTime+7,
//             "createdAt",
//             false, // descending
//             1,
//             10,
//             noFilter
//         );
//         console.log("agents.length:",agents.length);
//         vm.stopPrank();
//     }
    
//     function test_GetAgentsInfoPaginatedWithPermissions_EmptyResults() public {
//         uint currentTime = 1760091452;
//         vm.warp(currentTime);
//         vm.startPrank(superAdmin);
        
//         // Create agent with only IQR
//         bool[3] memory permissions = [true, false, false];
//         string[] memory subLocations = new string[](1);
//         subLocations[0] = "Branch";
//         string[] memory subPhones = new string[](1);
//         subPhones[0] = "0123456789";
        
//         enhanced.createAgentWithAnalytics(
//             agent1,
//             "Store",
//             "Address",
//             "Phone",
//             "Note",
//             permissions,
//             subLocations,
//             subPhones,
//             domain
//         );
//         enhanced.setAgentIQR(agent1);

//         // Try to find agents with all permissions (should be empty)
//         bool[3] memory allFilter = [true, true, true];
//         (
//             AgentInfo[] memory agents,
//             uint256 totalCount,
//             uint256 totalPages,
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             0,
//             currentTime,
//             "createdAt",
//             true,
//             1,
//             10,
//             allFilter
//         );
        
//         assertEq(totalCount, 0, "Should have no agents with all permissions");
//         assertEq(agents.length, 0, "Result should be empty");
//         assertEq(totalPages, 0, "Should have 0 pages");
        
//         vm.stopPrank();
        
//         console.log("Test 7b PASSED: Empty results handling");
//     }
//     // ========================================================================
//     // TEST 6: migrateLoyaltyTokens
//     // ========================================================================

//     // ========================================================================
//     // TEST 8: Full Integration Workflow
//     // ========================================================================
    
//     function test_FullWorkflow_CompleteScenario() public {
//         console.log("\n=== FULL INTEGRATION WORKFLOW ===\n");
        
//         vm.startPrank(superAdmin);
        
//         // STEP 1: Create multiple agents with different configurations
//         console.log("Step 1: Creating agents...");
        
//         bool[3] memory fullPerms = [true, true, true];
//         bool[3] memory partialPerms = [true, true, false];
//         string[] memory subLocations = new string[](2);
//         subLocations[0] = "Main Branch";
//         subLocations[1] = "Secondary Branch";
//         string[] memory subPhones = new string[](2);
//         subPhones[0] = "0111111111";
//         subPhones[1] = "0122222222";
        
//         enhanced.createAgentWithAnalytics(
//             agent1,
//             "Premium Store",
//             "123 Premium St",
//             "0123456789",
//             "VIP Agent",
//             fullPerms,
//             subLocations,
//             subPhones,
//             "domain"
//         );
//         enhanced.setAgentIQR(agent1);
//         enhanced.setPointsIQR(agent1);
//         vm.warp(block.timestamp + 1 hours);
        
//         enhanced.createAgentWithAnalytics(
//             agent2,
//             "Standard Store",
//             "456 Main Ave",
//             "0987654321",
//             "Standard Agent",
//             partialPerms,
//             subLocations,
//             subPhones,
//             "domain1"
//         );
//         enhanced.setAgentIQR(agent2);
//         enhanced.setPointsIQR(agent2);
//         vm.warp(block.timestamp + 1 hours);
        
//         enhanced.createAgentWithAnalytics(
//             agent3,
//             "Budget Store",
//             "789 Budget Ln",
//             "0555555555",
//             "Budget Agent",
//             partialPerms,
//             subLocations,
//             subPhones,
//             "domain2"
//         );
//         enhanced.setAgentIQR(agent3);
//         enhanced.setPointsIQR(agent3);
//         console.log("Created 3 agents");
        
//         // STEP 2: Update analytics for agents
//         console.log("\nStep 2: Updating analytics...");
        
//         enhanced.updateAgentAnalytics(agent1, 100, 50000 ether, 80); // High performer
//         enhanced.updateAgentAnalytics(agent2, 50, 20000 ether, 40);  // Medium performer
//         enhanced.updateAgentAnalytics(agent3, 20, 5000 ether, 15);   // Low performer
        
//         AgentAnalytics memory agent1Analytics = enhanced.getAgentAnalytics(agent1);
//         console.log("Agent1 performance score:", agent1Analytics.performanceScore);
//         assertGt(agent1Analytics.performanceScore, 50, "Agent1 should have high score");
        
//         // STEP 3: Mint loyalty tokens for agents with loyalty permission
//         console.log("\nStep 3: Minting loyalty tokens...");
        
//         address loyalty1 = enhanced.agentLoyaltyContracts(agent1);
//         address loyalty2 = enhanced.agentLoyaltyContracts(agent2);
        
//         vm.stopPrank();
        
//         vm.prank(agent1);
//         RestaurantLoyaltySystem(loyalty1).mint(customer1, 1000 ether, "Customer1 rewards");
        
//         vm.prank(agent1);
//         RestaurantLoyaltySystem(loyalty1).mint(customer2, 500 ether, "Customer2 rewards");
        
//         vm.prank(agent2);
//         RestaurantLoyaltySystem(loyalty2).mint(customer1, 750 ether, "Customer1 at store2");
        
//         console.log("Minted loyalty tokens for customers");
        
//         // STEP 4: Test pagination with filters
//         console.log("\nStep 4: Testing pagination...");
        
//         vm.startPrank(superAdmin);
        
//         bool[3] memory loyaltyFilter = [false, true, false];
//         (
//             AgentInfo[] memory loyaltyAgents,
//             uint256 loyaltyCount,
//             ,
//         ) = enhanced.getAgentsInfoPaginatedWithPemissions(
//             0,
//             block.timestamp,
//             "createdAt",
//             true,
//             1,
//             10,
//             loyaltyFilter
//         );
        
//         console.log("Agents with loyalty:", loyaltyCount);
//         assertEq(loyaltyCount, 3, "All agents have loyalty");
        
//         // STEP 5: Update an agent
//         console.log("\nStep 5: Updating agent...");
        
//         string[] memory newSubLoc = new string[](1);
//         newSubLoc[0] = "Updated Branch";
//         uint[] memory subLocIdx = new uint[](1);
//         subLocIdx[0] = 0;
        
//         string[] memory newSubPhone = new string[](1);
//         newSubPhone[0] = "0999999999";
//         uint[] memory subPhoneIdx = new uint[](1);
//         subPhoneIdx[0] = 0;
        
//         enhanced.updateAgent(
//             agent2,
//             "Updated Standard Store",
//             "New Address",
//             "0999999999",
//             "Updated",
//             fullPerms, // Grant MeOS now
//             newSubLoc,
//             newSubPhone,
//             "domain3"
//         );
        
//         Agent memory updatedAgent2 = enhanced.getAgent(agent2);
//         assertTrue(updatedAgent2.permissions[2], "Agent2 should now have MeOS");
//         console.log("Updated agent2 permissions");
        
//         // STEP 6: Migrate loyalty tokens
//         console.log("\nStep 6: Migrating loyalty tokens...");
        
//         uint256 agent1Supply = RestaurantLoyaltySystem(loyalty1).totalSupply();
//         console.log("Agent1 loyalty supply before migration:", agent1Supply);
        
//         uint256 migratedAmount = enhanced.migrateLoyaltyTokens(agent1, agent2);
//         console.log("Migrated amount:", migratedAmount);
        
//         assertEq(migratedAmount, agent1Supply, "Should migrate all tokens");
//         assertTrue(RestaurantLoyaltySystem(loyalty1).isMigrated(), "Agent1 loyalty should be migrated");
        
//         // STEP 7: Lock and unlock tokens
//         console.log("\nStep 7: Testing lock/unlock...");
        
//         vm.stopPrank();
        
//         // Mint tokens to contract itself
//         vm.prank(agent2);
//         RestaurantLoyaltySystem(loyalty2).mint(loyalty2, 2000 ether, "Locked rewards");
        
//         // Freeze to enable unlock
//         vm.prank(agent2);
//         RestaurantLoyaltySystem(loyalty2).freeze();
        
//         vm.prank(superAdmin);
//         uint256 unlocked = enhanced.unlockLoyaltyTokens(agent2);
//         console.log("Unlocked tokens:", unlocked);
//         assertEq(unlocked, 2000 ether);
        
//         // STEP 8: Delete an agent
//         console.log("\nStep 8: Deleting agent...");
        
//         vm.startPrank(superAdmin);
        
//         // Delete agent3 (has no active unfrozen loyalty)
//         enhanced.deleteAgent(agent3);
        
//         Agent memory deletedAgent = enhanced.getAgent(agent3);
//         assertFalse(deletedAgent.isActive, "Agent3 should be deleted");
        
//         Agent[] memory deletedAgents = enhanced.getDeletedAgentd();
//         assertEq(deletedAgents.length, 1, "Should have 1 deleted agent");
//         console.log("Deleted agent3");
        
//         // STEP 9: Get final statistics
//         console.log("\nStep 9: Final statistics...");
        
//         (
//             uint256 totalAgents,
//             uint256 activeAgents,
//             uint256 totalRevenue,
//             uint256 totalOrders,
//             uint256 avgPerformance,
//             uint256[3] memory permStats
//         ) = enhanced.getSystemAnalytics();
        
//         console.log("Total agents:", totalAgents);
//         console.log("Active agents:", activeAgents);
//         console.log("Total revenue:", totalRevenue);
//         console.log("Average performance:", avgPerformance);
//         console.log("IQR agents:", permStats[0]);
//         console.log("Loyalty agents:", permStats[1]);
//         console.log("MeOS agents:", permStats[2]);
        
//         assertEq(totalAgents, 3, "Should have 3 total agents");
//         assertEq(activeAgents, 2, "Should have 2 active agents");
        
//         // STEP 10: Get sorted agents
//         console.log("\nStep 10: Getting sorted agents...");
        
//         (address[] memory topAgents, uint256[] memory scores) = 
//             enhanced.getPerformanceLeaderboard(10);
        
//         console.log("Top performer:", topAgents[0]);
//         console.log("Top score:", scores[0]);
        
//         assertEq(topAgents[0], agent1, "Agent1 should be top performer");
        
//         vm.stopPrank();
//         //Order:
//         address iqrAgentAdd = iqrFactory.getAgentIQRContract(agent2);
//         IQRContracts memory iQRContracts = IAgentIQR(iqrAgentAdd).getIQRSCByAgent(agent2);
//         console.log("(iQRContracts.Management:",iQRContracts.Management);
//         // staffAgentStore.getUserAgetSCs();
//         management = Management(iQRContracts.Management);
//         Points = RestaurantLoyaltySystem(iQRContracts.Points);
//         console.log("Points:",address(Points));
//         _createStaff();
//         _createDishes();
//         _createTables();
//         _order();
//         console.log("\n=== FULL WORKFLOW COMPLETED SUCCESSFULLY ===\n");
//         GetByteCode1();
//     }
//     function _createDishes()public{
//          vm.startPrank(agent2);
//          //Create option
//         string[] memory featureNames1 = new string[](3);
//         featureNames1[0] = "Khong";
//         featureNames1[1] = "Vua";
//         featureNames1[2] = "Nhieu";
//         uint256[] memory _featurePrices = new uint256[](3);
//         _featurePrices[0] = 0;
//         _featurePrices[1] = 0;
//         _featurePrices[2] = 0;

//         bytes32 optionId1 = MANAGEMENT.CreateDishOptions(
//             "Do Cay",
//             featureNames1,
//             _featurePrices,
//             false,
//             3
//         );
//         bytes32 optionId2 = MANAGEMENT.CreateDishOptions(
//             "Do Beo",
//             featureNames1,
//             _featurePrices,
//             false,
//             3
//         );
//         bytes32 optionId3 = MANAGEMENT.CreateDishOptions(
//             "Do Ngot",
//             featureNames1,
//             _featurePrices,
//             false,
//             3
//         );
//         bytes32[] memory optionIds = new bytes32[](3);
//         optionIds[0] = optionId1;
//         optionIds[1] = optionId2;
//         optionIds[2] = optionId3;
//          //create Category
//         Category memory category1 = Category({
//             code:"THITBO",
//             name:"thit bo",
//             rank:1,
//             desc:"Cac mon voi thit bo",
//             active:true,
//             imgUrl:"_imgURL1",
//             icon: "icon"
//         });
//         management.CreateCategory(category1);

//         string[] memory ingredients = new string[](1);
//         ingredients[0] = "thit tuoi";
//         Dish memory dish1 = Dish({
//             code:"dish1_code",
//             nameCategory:"Thit bo",
//             name:"Bo BBQ",
//             des:"Thit bo nuong BBQ voi nhieu loai sot",
//             available:true,
//             active:true,
//             imgUrl:"img_bo1",
//             averageStar: 0,
//             cookingTime: 30,
//             ingredients:ingredients,
//             showIngredient: true,
//             videoLink: "videoLink",
//             totalReview:0,
//             orderNum:0,
//             createdAt:0
//         });
//         Attribute[] memory attrs1 = new Attribute[](1);
//         attrs1[0] = Attribute({
//             id: bytes32(0),
//             key: "size",
//             value: "S"
//         });
//         VariantParams memory variant1 = VariantParams({
//             attrs: attrs1,
//             price: 1000
//         });
//         //
//         Attribute[] memory attrs2 = new Attribute[](1);
//         attrs2[0] = Attribute({
//             id: keccak256(abi.encodePacked("1")),
//             key: "size",
//             value: "M"
//         });
//         VariantParams memory variant2 = VariantParams({
//             attrs: attrs2,
//             price: 2000
//         });
//         //
//         Attribute[] memory attrs3 = new Attribute[](1);
//         attrs3[0] = Attribute({
//             id: keccak256(abi.encodePacked("2")),
//             key: "size",
//             value: "L"
//         });
//         VariantParams memory variant3 = VariantParams({
//             attrs: attrs3,
//             price: 3000
//         });
//         //
//         VariantParams[] memory variants = new VariantParams[](3);
//         variants[0] = variant1;
//         variants[1] = variant2;
//         variants[2] = variant3;

//         management.CreateDish("THITBO",dish1,variants,optionIds);
//         vm.stopPrank();
//     } 
//     function _createStaff()public{
//         vm.startPrank(agent2);
//         //CreatePosition
//         STAFF_ROLE[] memory staff1Roles = new STAFF_ROLE[](1);
//         staff1Roles[0] = STAFF_ROLE.UPDATE_STATUS_DISH;

//         management.CreatePosition("phuc vu ban",staff1Roles);
//         //CreateWorkingShift
//         management.CreateWorkingShift("ca sang",28800,43200); ////số giây tính từ 0h ngày hôm đó. vd 08:00 là 8*3600=28800

//         WorkingShift[] memory shifts = management.getWorkingShifts();
//         assertEq(shifts[0].title,"ca sang","working shift title should equal");

//         WorkingShift[] memory staff1Shifts = new WorkingShift[](2);
//         staff1Shifts[0] = shifts[0];

//         Staff memory staff = Staff({
//             wallet: staff1,
//             name:"thuy",
//             code:"NV1",
//             phone:"0913088965",
//             addr:"phu nhuan",
//             position: "phuc vu ban",
//             role:ROLE.STAFF,
//             active: true,
//             linkImgSelfie: "linkImgSelfie",
//             linkImgPortrait:"linkImgPortrait",
//             shifts:staff1Shifts,
//             roles: staff1Roles

//         });
//         management.CreateStaff(staff);
//         vm.stopPrank();
//     }
//     function _createTables()public {
//         vm.startPrank(agent2);
//         management.CreateArea(1,"Khu A");
//         vm.stopPrank();
//     }
//     function _order()public {
//         vm.warp(currentTime);
//         vm.prank(agent2);
//         Points.updateExchangeRate(1);
//         vm.startPrank(customer1);
//         //register member
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
//         //order
//         uint table =1;
//         string[] memory dishCodes = new string[](1);
//         dishCodes[0] = "dish1_code";
//         uint8[] memory quantities = new uint8[](1);
//         quantities[0] = 2;
//         string[] memory notes = new string[](1);
//         notes[0] = "";
//         //
//         DishInfo memory dishInfo = management.getDishInfo("dish1_code");       
//         bytes32[] memory variantIDs = new bytes32[](3);
//         variantIDs[0] = dishInfo.variants[0].variantID;
//         variantIDs[1] = dishInfo.variants[1].variantID;
//         variantIDs[2] = dishInfo.variants[2].variantID;
//         SelectedOption[] memory selectionOption0 = new SelectedOption[](1);
//         selectionOption0[0] = SelectedOption({
//             optionId: optionId1,
//             selectedFeatureIds: selectedFeatureIdsDish1
//         });

//         SelectedOption[][] memory dishSelectedOptions = new SelectedOption[][](1);
//         dishSelectedOptions[0] = selectionOption0;
//         bytes32 orderId1T1 = ORDER.makeOrder(
//             table,
//             dishCodes,
//             quantities,
//             notes,
//             variantIDs,
//             dishSelectedOptions
//         );
//         string memory discountCode = "";
//         uint tip = 0;
//         Payment memory payment = ORDER.getTablePayment(1);
//         uint256 paymentAmount = payment.total; //(2200)
//         console.log("paymentAmount:",paymentAmount);
//         string memory txID = "";
//         ORDER.executeOrder(1,discountCode,tip,paymentAmount,txID,false);
//         ORDER.UpdateForReport(1);
//         MANAGEMENT.UpdateTotalRevenueReport(currentTime,payment.foodCharge-payment.discountAmount);
//         MANAGEMENT.SortDishesWithOrderRange(0,10);
//         MANAGEMENT.UpdateRankDishes();
//         vm.stopPrank();
//         vm.startPrank(staff1);
//         ORDER.confirmPayment(1,payment.id,"paid");
//         POINTS.earnPoints("CUST0001", payment.foodCharge-payment.discountAmount, payment.id,0);
        
//         (, uint256 points1,,,,,,,,,,) = POINTS.getMember(customer1);
//         console.log("Points after first purchase:", points1);
//         // assertEq(points1, 212);
//         vm.stopPrank();
//     }
    
//     // ========================================================================
//     // HELPER FUNCTIONS
//     // ========================================================================
    
//     function printAgentInfo(address _agent) internal view {
//         Agent memory agent = enhanced.getAgent(_agent);
//         console.log("\n--- Agent Info ---");
//         console.log("Address:", agent.walletAddress);
//         console.log("Store:", agent.storeName);
//         console.log("Active:", agent.isActive);
//         console.log("IQR:", agent.permissions[0]);
//         console.log("Loyalty:", agent.permissions[1]);
//         console.log("MeOS:", agent.permissions[2]);
//     }
    
//     function printSystemStats() internal view {
//         (
//             uint256 total,
//             uint256 active,
//             uint256 revenue,
//             uint256 orders,
//             uint256 avgPerf,
//             uint256[3] memory perms
//         ) = enhanced.getSystemAnalytics();
        
//         console.log("\n--- System Stats ---");
//         console.log("Total Agents:", total);
//         console.log("Active Agents:", active);
//         console.log("Total Revenue:", revenue);
//         console.log("Total Orders:", orders);
//         console.log("Avg Performance:", avgPerf);
//         console.log("IQR Agents:", perms[0]);
//         console.log("Loyalty Agents:", perms[1]);
//         console.log("MeOS Agents:", perms[2]);
//     }
//     function GetByteCode1()public {
//     //
//         bytes memory bytesCodeCall = abi.encodeCall(
//         enhanced.getAgentsInfoPaginated,
//         (
//             0,
//             1855995908,
//             "createdAt",
//             false,
//             1,
//             20
//         ));
//         console.log("enhanced getAgentsInfoPaginated:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );
//         //
//         bytesCodeCall = abi.encodeCall(
//             enhanced.deleteAgent,
//             (
//                 0xF1B47A9dFb7Cc0228e1EDfeCe406FD47B0D78FD6            
//             )
//         );
//         console.log("enhanced: deleteAgent");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  
  
//         //
//         bytesCodeCall = abi.encodeCall(
//             enhanced.isAdmin,
//             (
//                 0xC8643eF8f4232bf7E8bAc6Ac73a2fe9A28Cb575A            
//             )
//         );
//         console.log("enhanced: isAdmin:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  

//         //agentLoyaltyContracts
//         bytesCodeCall = abi.encodeCall(
//             loyaltyFactory.agentLoyaltyContracts,
//             (
//                 0xce29174f8d0581641a1597a5d3a14ee28d84640f            
//             )
//         );
//         console.log("loyaltyFactory: agentLoyaltyContracts:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  
//         //loyaltyFactory.setPointsImp(address(POINTS_IMP));
//         bytesCodeCall = abi.encodeCall(
//             loyaltyFactory.setPointsImp,
//             (
//                 0xE476Be15a7bf3b1DCcb0b6aF8C88fa233F6A9471            
//             )
//         );
//         console.log("loyaltyFactory: setPointsImp:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  
//         //enhanced.setPointsIQR(agent1);
//         bytesCodeCall = abi.encodeCall(
//             enhanced.setPointsIQR,
//             (
//                 0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B            
//             )
//         );
//         console.log("enhanced: setPointsIQR:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  
//         //        enhanced.setFactoryContracts(
//         bytesCodeCall = abi.encodeCall(
//             enhanced.setFactoryContracts,
//             (
//             address(iqrFactory),
//             address(loyaltyFactory),
//             address(revenueManager)
//             )
//         );
//         console.log("enhanced: setFactoryContracts:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  
//         //getAgentsInfoPaginatedWithPemissions
//         bool[3] memory noFilter = [false, false, false];
//         bool[3] memory allFilter = [true,true,true];
//         bytesCodeCall = abi.encodeCall(
//             enhanced.getAgentsInfoPaginatedWithPemissions,
//             (
//             1760288400,
//             1761338782,
//             "createdAt",
//             false,
//             1,
//             20,
//             allFilter          
//             )
//         );
//         console.log("getAgentsInfoPaginatedWithPemissions:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  
//         //enhancedV1.upgradeToAndCall(address(enhancedImplementationV2), "");
//         bytesCodeCall = abi.encodeCall(
//             enhanced.upgradeToAndCall,
//             (
//             address(enhancedImplementation), ""            
//             ));
//         console.log("upgradeToAndCall:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  
//     //createAgentWithAnalytics
//     string[] memory subLocations = new string[](2);
//     subLocations[0] = "Branch A";
//     subLocations[1] = "Branch B";
//     string[] memory subPhones = new string[](2);
//     subPhones[0] = "0111111111";
//     subPhones[1] = "0122222222";
//     bool[3] memory filter = [true,false,false];
//     bytesCodeCall = abi.encodeCall(
//         enhanced.createAgentWithAnalytics,
//         (
//             address(0xADB358abbd858798CEF68c2F323EF8edEbeeA51a),
//             "Store 5",
//             "Address 5",
//             "Phone",
//             "Note",
//             filter,
//             subLocations,
//             subPhones,
//             "suicao.fi.ai"
//         ));
//     console.log("createAgentWithAnalytics:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     ); 
//     //updateAgent
//     filter = [true,true,false];
//     bytesCodeCall = abi.encodeCall(
//         enhanced.updateAgent,
//         (
//             address(0xA620249dc17f23887226506b3eB260f4802a7efc),
//             "Store 5",
//             "Address 5",
//             "Phone",
//             "Note",
//             filter,
//             subLocations,
//             subPhones,
//             "domain_new1"
//         ));
//     console.log("updateAgent:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     ); 
//     //getAgentLoyaltyContract
//          bytesCodeCall = abi.encodeCall(
//         loyaltyFactory.getAgentLoyaltyContract,
//         (
//             address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B)
//         ));
//     console.log("getAgentLoyaltyContract:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     ); 
//     //
//     }
// }