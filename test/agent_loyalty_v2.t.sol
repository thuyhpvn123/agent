// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../contracts/agent.sol";
import "../contracts/agentIqr.sol";
import "../contracts/agentLoyalty.sol";
import "../contracts/enhance.sol";
import "../contracts/interfaces/IAgent.sol";
import "../contracts/loyaltyFactory.sol";
import "../contracts/iqrFactory.sol";
import "../contracts/revenue.sol";
import "../contracts/mtd.sol";
import "./res_old.t.sol";
import "../contracts/staffMatch.sol";
import "../contracts/interfaces/IManagement.sol";
import "../contracts/branchManager.sol";
import "../contracts/historyTracking.sol";
import "../contracts/freegas.sol";
import "../contracts/bmFactory.sol";
import "../contracts/meosFactory.sol";
import "../contracts/loyaltyDB.sol";
import "./NetCafeV2FullFlow.t.sol";
import "./RobotFullFlowV2.t.sol";
// import "../contracts/StaffRobot.sol";
// import {BranchInfoInput} from "../contracts/interfaces/IAgent.sol";
/**
 * @title Agent Management Integration Test
 * @notice Comprehensive integration tests for the Agent Management system
 * @dev Tests full workflow including create, update, delete, pagination, and loyalty operations
 */

contract AgentManagementIntegrationTest is NetCafeV2FullFlowTest,RestaurantTest,RobotFullFlowV2Test {
     using Strings for uint256;
    // Contracts
    EnhancedAgentManagement public enhancedImplementation;
    EnhancedAgentManagement public enhanced;
    
    IQRFactory public iqrFactoryImplementation;
    IQRFactory public iqrFactory;
    
    LoyaltyFactory public loyaltyFactoryImplementation;
    LoyaltyFactory public loyaltyFactory;
    
    RevenueManager public revenueManagerImplementation;
    RevenueManager public revenueManager;
        
    StaffAgentStore public staffAgentStoreImplementation;
    StaffAgentStore public staffAgentStore;
    HistoryTracking public historyTrackingIMP;
    // Test accounts
    BranchManagement public branchManagementImplementation;
    BranchManagement public branchManager;

    FreeGasStorage   public freeGasImplementation;
    FreeGasStorage   public freeGasSc;

    BMFactory public bmFactoryImplementation;
    BMFactory public bmFactory;

    MeosFactory public meosFactoryImplementation;
    MeosFactory public meosFactory;

    RobotFactory public robotFactoryImplementation;
    RobotFactory public robotFactory;
    Management public management;
    Management public staffMeos;
    RestaurantOrder public order;
    // RestaurantLoyaltySystem public Points;

    PublicfullDB public publicfullDBImplementation;
    PublicfullDB public publicfullDB;
    
    // address public customer1;
    // address public customer2;
    string public domain="domain";
    BranchInfoInput[] branchInfoDatas ;
    constructor() {
        // Setup accounts

        customer1 = makeAddr("customer1");
        customer2 = makeAddr("customer2");
        
        // vm.deal(superAdmin, 100 ether);
        
        // Deploy all contracts with proxy pattern
        vm.startPrank(superAdmin);
        
        // 1. Deploy AgentManagement
        
        // 2. Deploy IQRFactory
        iqrFactoryImplementation = new IQRFactory();
        ERC1967Proxy iqrProxy = new ERC1967Proxy(
            address(iqrFactoryImplementation),
            abi.encodeWithSignature("initialize()")
        );
        iqrFactory = IQRFactory(address(iqrProxy));
        
        // 3. Deploy LoyaltyFactory
        loyaltyFactoryImplementation = new LoyaltyFactory();
        ERC1967Proxy loyaltyProxy = new ERC1967Proxy(
            address(loyaltyFactoryImplementation),
            abi.encodeWithSignature("initialize()")
        );
        loyaltyFactory = LoyaltyFactory(address(loyaltyProxy));
        
        // 4. Deploy RevenueManager
        revenueManagerImplementation = new RevenueManager();
        ERC1967Proxy revenueProxy = new ERC1967Proxy(
            address(revenueManagerImplementation),
            abi.encodeWithSignature("initialize()")
        );
        revenueManager = RevenueManager(address(revenueProxy));
        
        
        // 6. Deploy EnhancedAgentManagement (inherits from AgentManagement)
        enhancedImplementation = new EnhancedAgentManagement();
        ERC1967Proxy enhancedProxy = new ERC1967Proxy(
            address(enhancedImplementation),
            abi.encodeWithSignature("initialize()")
        );
        enhanced = EnhancedAgentManagement(address(enhancedProxy));

        // 7. Deploy StaffAgentStore
        staffAgentStoreImplementation = new StaffAgentStore();
        ERC1967Proxy staffAgentStoreProxy = new ERC1967Proxy(
            address(staffAgentStoreImplementation),
            abi.encodeWithSignature("initialize()")
        );
        staffAgentStore = StaffAgentStore(address(staffAgentStoreProxy));
        
        // 8. Deploy BranchManagement
        branchManagementImplementation = new BranchManagement();
        //9. Deploy historyTrackingIMP
        historyTrackingIMP = new HistoryTracking();

        //10 Deploy freeGasSc
        freeGasImplementation = new FreeGasStorage();
        ERC1967Proxy freeGasScProxy = new ERC1967Proxy(
            address(freeGasImplementation),
            abi.encodeWithSelector(RestaurantReporting.initialize.selector,
            address(iqrFactory))
        );
        freeGasSc = FreeGasStorage(address(freeGasScProxy));
        //11.Deploy branch manager factory
        bmFactoryImplementation = new BMFactory();
        ERC1967Proxy bmFactoryProxy = new ERC1967Proxy(
            address(bmFactoryImplementation),
            abi.encodeWithSignature("initialize()")
        );
        bmFactory = BMFactory(address(bmFactoryProxy));
        //12.
        meosFactoryImplementation = new MeosFactory();
        ERC1967Proxy meosProxy = new ERC1967Proxy(
            address(meosFactoryImplementation),
            abi.encodeWithSignature("initialize()")
        );
        meosFactory = MeosFactory(address(meosProxy));

        //13
        robotFactoryImplementation = new RobotFactory();
        ERC1967Proxy robotProxy = new ERC1967Proxy(
            address(robotFactoryImplementation),
            abi.encodeWithSignature("initialize()")
        );
        robotFactory = RobotFactory(address(robotProxy));

        //14. Deploy PublicfullDB
        publicfullDBImplementation = new PublicfullDB();
        ERC1967Proxy publicfullDBProxy = new ERC1967Proxy(
            address(publicfullDBImplementation),
            abi.encodeWithSignature("initialize()")
        );
        publicfullDB = PublicfullDB(address(publicfullDBProxy));
        // StaffRobot StaffRobot_IMP = new StaffRobot();
        // Setup admin
        enhanced.setAdmin(superAdmin);
               
        enhanced.setFactoryContracts(
            address(iqrFactory),
            address(loyaltyFactory),
            address(revenueManager),
            address(bmFactory),
            address(meosFactory),
            address(robotFactory)
        );
        bmFactory.setBranchManagerSC(
            address(branchManagementImplementation),
            address(historyTrackingIMP),
            address(staffAgentStore),
            address(iqrFactory),
            address(meosFactory),
            address(robotFactory),
            address(enhanced)

        );
        iqrFactory.setEnhancedAgent(address(enhanced));
        iqrFactory.setIQRSC(
            address(MANAGEMENT_IMP),
            address(ORDER_IMP),
            address(REPORT_IMP),
            address(TIMEKEEPING_IMP),
            0x10F4A365ff344b3Af382aBdB507c868F1c22f592,
            0x603dbFC668521aB143Ee1018e4D80b13FDDedfBd,
            address(revenueManager),
            address(staffAgentStore),
            address(freeGasSc)
        );

        loyaltyFactory.setPointsImp(address(POINTS_IMP));
        loyaltyFactory.setEnhancedAgent(address(enhanced));
        revenueManager.setEnhancedAgent(address(enhanced));
        meosFactory.setEnhancedAgent(address(enhanced));
        robotFactory.setEnhancedAgent(address(enhanced));

        staffAgentStore.setEnhancedAgent(address(enhanced));
        staffAgentStore.setIqrFactory(address(iqrFactory));

        freeGasSc.registerSCAdmin(address(iqrFactory),true);
        freeGasSc.registerSCAdmin(address(loyaltyFactory),true);
        freeGasSc.registerSCAdmin(address(enhanced),true);
        freeGasSc.registerSCAdmin(address(meosFactory),true);
        freeGasSc.registerSCAdmin(address(robotFactory),true);
        meosFactory.setMeos(
            address(StaffMeosSC_IMP),
            address(user_IMP),
            address(session_IMP),
            address(topup_IMP),
            address(spend_IMP),
            address(management_IMP),
            address(station_IMP),          
            address(staffAgentStore),
            address(freeGasSc),
            address(iqrFactory)
        );
        console.log("active:",address(active));
        console.log("testing:",address(testing));
        RobotInputs memory robotInputs = RobotInputs({
            _StaffRobotSC: address(MANAGEMENT_IMP),
            _RobotRegistryV2IMP: address(registry),
            _RobotActiveV2IMP: address(active),
            _RobotDataUploadTrainingV2IMP: address(upload),
            _RobotObservationTrainingV2IMP: address(observation),
            _RobotLocationV2IMP: address(location),
            _RobotQuestionV2IMP: address(question),
            _RobotDashboadV2IMP: address(checkpoint),
            _RobotTestingV2IMP: address(testing),
            _StaffAgentStore: address(staffAgentStore)
        });

        robotFactory.setRobot(
            robotInputs,
            address(freeGasSc),
            address(iqrFactory),
            address(meosFactory)   
        );
        loyaltyFactory.setPublicfullDB(address(publicfullDB));
        vm.stopPrank();
        
        console.log("=== Setup Complete ===");
        console.log("Super Admin:", superAdmin);
        console.log("EnhancedAgentManagement:", address(enhanced));
        console.log("IQRFactory:", address(iqrFactory));
        console.log("LoyaltyFactory:", address(loyaltyFactory));
        //        
        branchInfoDatas.push(BranchInfoInput({
            name: "branch1",
            location: "location1",
            phone: "phone1",
            domain: "thuy-cn1.fi.ai"
        }));
        branchInfoDatas.push(BranchInfoInput({
            name: "branch2",
            location: "location2",
            phone: "phone2",
            domain: "thuy-cn2.fi.ai"
        }));
        branchInfoDatas.push(BranchInfoInput({
            name: "branch3",
            location: "location3",
            phone: "phone3",
            domain: "thuy-cn3.fi.ai"
        }));
    }
        
    // function test_CreateAgentWithAnalytics_MultipleAgents() public {
    //     vm.startPrank(superAdmin);
        
    //     // Create multiple agents
    //     address[] memory agents = new address[](3);
    //     agents[0] = agent1;
    //     agents[1] = agent2;
    //     agents[2] = agent3;
        
    //     for (uint i = 0; i < agents.length; i++) {
    //         string memory storeName = string(abi.encodePacked("Store ", vm.toString(i + 1)));
    //         bool[4] memory permissions = [true, false, true, true]; // IQR + Loyalty only
    //         string[] memory subLocations = new string[](1);
    //         subLocations[0] = "Main Branch";
    //         string[] memory subPhones = new string[](1);
    //         subPhones[0] = "0123456789";
            
    //         bool success = enhanced.createAgentWithAnalytics(
    //             agents[i],
    //             storeName,
    //             "Address",
    //             "Phone",
    //             "Note",
    //             permissions,
    //             i.toString(),
    //             branchInfoDatas
    //         );
            
    //         assertTrue(success);
    //     }
        
    //     // Verify all agents created
    //     address[] memory allAgents = enhanced.getAllAgents();
    //     assertEq(allAgents.length, 3, "Should have 3 agents");
        
    //     vm.stopPrank();
        
    //     console.log("Test 1b PASSED: Multiple agents created");
    // }
    
    // ========================================================================
    // TEST 2: updateAgent
    // ========================================================================
    
    function test_UpdateAgent_Success() public {
        // First create an agent
        vm.startPrank(superAdmin);
        
        bool[4] memory initialPermissions = [true, false, false, false];        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Old Store Name",
            "Old Address",
            "0123456789",
            "Old Note",
            initialPermissions,
            domain,
            branchInfoDatas
        );
        
        // Update agent
        string memory newStoreName = "New Store Name";
        string memory newAddress = "New Address";
        string memory newPhone = "9876543210";
        string memory newNote = "Updated Note";
        bool[4] memory newPermissions = [true, true, true, true]; // Grant all permissions
        uint[] memory branchIds = enhanced.getAgentBranchIds(agent1);
        enhanced.BatchSetAllAgentIQR(agent1);
        
        Agent memory agentInfo = enhanced.getAgent(agent1);
        BranchInfo[] memory arr = new BranchInfo[](1);
        arr[0]= BranchInfo({
            branchId: 0,
            name: "branch4",
            location: "location4",
            phone: "phone4",
            domain: "thuy-cn4.fi.ai",
            isActive: true,
            isMain: false,
            createdAt: 0
        });
        enhanced.updateAgent(
            agent1,
            newStoreName,
            newAddress,
            newPhone,
            newNote,
            newPermissions,
            "domain_new",
            agentInfo.branches
        );
        enhanced.BatchSetAllAgentMEOS(agent1);
        Agent memory updatedAgent = enhanced.getAgent(agent1);
        // enhanced.BatchSetPointsIQR(agent1,branchIds);
        enhanced.BatchSetAllPointsIQR(agent1);
        // Verify updates
        updatedAgent = enhanced.getAgent(agent1);
        assertEq(updatedAgent.storeName, newStoreName);
        assertEq(updatedAgent.storeAddress, newAddress);
        assertEq(updatedAgent.phone, newPhone);
        assertEq(updatedAgent.note, newNote);
        assertTrue(updatedAgent.permissions[0]); // IQR
        assertTrue(updatedAgent.permissions[1]); // Loyalty (newly granted)
        assertTrue(updatedAgent.permissions[2]); // MeOS (newly granted)
        assertEq(updatedAgent.branches.length, 3);
        // Verify new contracts were created
        branchIds = enhanced.getAgentBranchIds(agent1);
        address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
        assertTrue(loyaltyContract != address(0), "Loyalty contract should be created");
        
        
        BranchInfo[] memory branchInfos1 = new BranchInfo[](1);
        branchInfos1[0] = BranchInfo({
            branchId: 0,
            name: "new branch",
            location: "location",
            phone: "phone",
            domain: "domain",
            isActive: true, 
            isMain: false,
            createdAt: 0
        });
        enhanced.updateAgent(
            agent1,
            newStoreName,
            newAddress,
            newPhone,
            newNote,
            newPermissions,
            "domain_new",
            branchInfos1
        );
        // bytes memory bytesCodeCall = abi.encodeCall(
        // enhanced.updateAgent,
        // (
        //     0x739b6287F81436B433145d76aE4713875864dBd8,
        //     "Com chien",
        //     "47 Dien Bien Phu TPHCM 4567",
        //     "0942115532",
        //     "Com chien",
        //     newPermissions,
        //     "comchien.fi.ai",
        //     branchInfos1
        // ));
        // console.log("updateAgent:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // ); 

        branchIds = enhanced.getAgentBranchIds(agent1);
        assertEq(branchIds.length, 2);
        uint256[] memory _branchIds = new uint256[](1);
        _branchIds[0]= branchIds[1];
        enhanced.BatchSetAgentIQR(agent1,_branchIds);
        enhanced.BatchSetPointsIQR(agent1,_branchIds);

        updatedAgent = enhanced.getAgent(agent1);
        assertEq(updatedAgent.branches.length, 1);
        vm.stopPrank();
        
        console.log("Test 2 PASSED: updateAgent");
    }
    
    // ========================================================================
    // TEST 3: deleteAgent
    // ========================================================================
    
    function test_DeleteAgent_Success() public {
        vm.startPrank(superAdmin);
        
        // Create agent
        bool[4] memory permissions = [true, false, true, true]; // IQR + MeOS (no loyalty)
        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store To Delete",
            "Address",
            "Phone",
            "Note",
            permissions,
            domain,
            branchInfoDatas
        );
        uint[] memory branchIds = enhanced.getAgentBranchIds(agent1);
        enhanced.BatchSetAllAgentIQR(agent1);
        enhanced.BatchSetAllAgentMEOS(agent1);

        //
        // enhanced.BatchSetPointsIQR(agent1,branchIds);

        // Verify agent exists and is active
        Agent memory agentBefore = enhanced.getAgent(agent1);
        assertTrue(agentBefore.isActive);
        
        // Delete agent
        
        enhanced.deleteAgent(agent1);
        
        // Verify agent is deleted
        Agent memory agentAfter = enhanced.getAgent(agent1);
        assertFalse(agentAfter.isActive, "Agent should be inactive");
        assertFalse(agentAfter.exists, "Agent should not exist in records");
        
        // Verify deleted agents list
        Agent[] memory deletedAgents = enhanced.getDeletedAgentd();
        assertEq(deletedAgents.length, 1, "Should have 1 deleted agent");
        assertEq(deletedAgents[0].walletAddress, agent1);
        
        vm.stopPrank();
        
        console.log("Test 3 PASSED: deleteAgent");
    }
    
    // function test_DeleteAgent_WithActiveLoyaltyTokens_ShouldRevert() public {
    //     vm.startPrank(superAdmin);
        
    //     // Create agent with loyalty permission
    //     bool[4] memory permissions = [true, true, false, true];
    //     string[] memory subLocations = new string[](1);
    //     subLocations[0] = "Branch";
    //     string[] memory subPhones = new string[](1);
    //     subPhones[0] = "0123456789";
        
    //     enhanced.createAgentWithAnalytics(
    //         agent1,
    //         "Store With Loyalty",
    //         "Address",
    //         "Phone",
    //         "Note",
    //         permissions,
    //         domain,
    //         branchInfoDatas
    //     );
    //     uint[] memory branchIds = enhanced.getAgentBranchIds(agent1);
    //     enhanced.BatchSetAllAgentIQR(agent1);
    //     //
    //     enhanced.BatchSetPointsIQR(agent1,branchIds);

    //     // Mint some loyalty tokens
    //     address loyaltyContract = enhanced.agentLoyaltyContracts(agent1,branchIds[0]);
    //     vm.stopPrank();
        
    //     // vm.prank(agent1);
    //     // RestaurantLoyaltySystem(loyaltyContract).mint(customer1, 1000 ether, "Initial mint");
        
    //     // Try to delete agent with active tokens - should revert
    //     vm.prank(superAdmin);
    //     vm.expectRevert("HasActiveLoyaltyTokens in one or more branches");
    //     enhanced.deleteAgent(agent1);
        
    //     console.log("Test 3b PASSED: Cannot delete agent with active loyalty tokens");
    // }
    
    function test_DeleteAgent_AfterFreezingLoyalty_Success() public {
        vm.startPrank(superAdmin);
        
        // Create agent with loyalty
        bool[4] memory permissions = [true, true, false, true];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store",
            "Address",
            "Phone",
            "Note",
            permissions,
            domain,
            branchInfoDatas
        );
        uint[] memory branchIds = enhanced.getAgentBranchIds(agent1);
        enhanced.BatchSetAllAgentIQR(agent1);
        //
        enhanced.BatchSetPointsIQR(agent1,branchIds);

        // Mint tokens
        address loyaltyContract = enhanced.agentLoyaltyContracts(agent1);
        vm.stopPrank();
        
        // vm.prank(agent1);
        // RestaurantLoyaltySystem(loyaltyContract).mint(customer1, 1000 ether, "Mint");
        
        // Freeze the loyalty contract
        vm.prank(agent1);
        RestaurantLoyaltySystem(loyaltyContract).pause();
        
        // Now deletion should succeed
        vm.prank(superAdmin);
        enhanced.deleteAgent(agent1);
        
        Agent memory deletedAgent = enhanced.getAgent(agent1);
        assertFalse(deletedAgent.isActive);
        
        console.log("Test 3c PASSED: Can delete after freezing loyalty");
    }
    
    // ========================================================================
    // TEST 4: getDeletedAgents
    // ========================================================================
    
    function test_GetDeletedAgents_Multiple() public {
        vm.startPrank(superAdmin);
        
        bool[4] memory permissions = [true, false, false, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        // Create and delete multiple agents
        address[] memory agents = new address[](3);
        agents[0] = agent1;
        agents[1] = agent2;
        agents[2] = agent3;
        
        for (uint i = 0; i < agents.length; i++) {
            enhanced.createAgentWithAnalytics(
                agents[i],
                string(abi.encodePacked("Store ", vm.toString(i))),
                "Address",
                "Phone",
                "Note",
                permissions,
                i.toString(),
                branchInfoDatas
            );
            uint[] memory branchIds = enhanced.getAgentBranchIds(agents[i]);
            enhanced.BatchSetAllAgentIQR(agents[i]);
            enhanced.BatchSetPointsIQR(agents[i],branchIds);
            enhanced.deleteAgent(agents[i]);
        }
        
        // Get all deleted agents
        Agent[] memory deletedAgents = enhanced.getDeletedAgentd();
        assertEq(deletedAgents.length, 3, "Should have 3 deleted agents");
        
        // Verify all are inactive
        for (uint i = 0; i < deletedAgents.length; i++) {
            assertFalse(deletedAgents[i].isActive);
        }
        
        vm.stopPrank();
        
        console.log("Test 4 PASSED: getDeletedAgents with multiple agents");
    }
    
    
    // ========================================================================
    // TEST 7: getAgentsInfoPaginatedWithPermissions
    // ========================================================================
    
    function test_GetAgentsInfoPaginatedWithPermissions_Success() public {
        uint currentTime = 1760089361;//16h43 ngay10/10/2025
        vm.warp(currentTime); 
        vm.startPrank(superAdmin);
        
        // Create agents with different permissions
        bool[4] memory allPermissions = [true, true, true, false];
        bool[4] memory iqrOnly = [true, false, false, false];
        bool[4] memory loyaltyAndIqr = [true, true, false, false];
        bool[4] memory noFilter = [false, false, false, false];

        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        // Agent 1: All permissions
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store 1",
            "Address 1",
            "Phone",
            "Note",
            allPermissions,
            // subLocations,
            // subPhones,
            domain,
            branchInfoDatas
        );
        
        vm.warp(currentTime + 1 seconds);
        
        // Agent 2: IQR only
        enhanced.createAgentWithAnalytics(
            agent2,
            "Store 2",
            "Address 2",
            "Phone",
            "Note",
            iqrOnly,
            // subLocations,
            // subPhones,
            "domain1",
            branchInfoDatas
        );
        
        vm.warp(currentTime + 2 seconds);
        
        // Agent 3: Loyalty only
        enhanced.createAgentWithAnalytics(
            agent3,
            "Store 3",
            "Address 3",
            "Phone",
            "Note",
            loyaltyAndIqr,
            // subLocations,
            // subPhones,
            "domain2",
            branchInfoDatas
        );
        
        vm.warp(currentTime + 3 seconds);
        
        // Agent 4: All permissions
        enhanced.createAgentWithAnalytics(
            agent4,
            "Store 4",
            "Address 4",
            "Phone",
            "Note",
            allPermissions,
            // subLocations,
            // subPhones,
            "domain3",
            branchInfoDatas
        );
        
        // Test 1: Get all agents (no permission filter)
        // bool[4] memory noFilter = [false, false, false, false];
        (
            AgentInfo[] memory allAgentsPage1,
            uint256 totalCount,
            uint256 totalPages,
            uint256 currentPage
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0, // from time
            currentTime+4, // to time
            "createdAt", // sort by
            true, // ascending
            1, // page
            10, // page size
            noFilter
        );
        
        assertEq(totalCount, 4, "Should have 4 total agents");
        assertEq(allAgentsPage1.length, 4, "Page should have 4 agents");
        assertEq(currentPage, 1);
        
        // Test 2: Filter by IQR permission only
        bool[4] memory iqrFilter = [true, false, false, false];
        (
            AgentInfo[] memory iqrAgents,
            uint256 iqrCount,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            true,
            1,
            10,
            iqrFilter
        );
        
        assertEq(iqrCount, 4, "Should have 4 agents with IQR");
        assertEq(iqrAgents.length, 4);
        
        // Verify all returned agents have IQR permission
        for (uint i = 0; i < iqrAgents.length; i++) {
            assertTrue(iqrAgents[i].permissions[0], "Agent should have IQR permission");
        }
        
        // Test 3: Filter by Loyalty permission only
        bool[4] memory loyaltyFilter = [false, true, false, false];
        (
            AgentInfo[] memory loyaltyAgents,
            uint256 loyaltyCount,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            true,
            1,
            10,
            loyaltyFilter
        );
        
        assertEq(loyaltyCount, 3, "Should have 3 agents with Loyalty");
        
        // Test 4: Filter by all permissions (AND logic)
        bool[4] memory allFilter = [true, true, true, false];
        (
            AgentInfo[] memory fullPermAgents,
            uint256 fullPermCount,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            true,
            1,
            10,
            allFilter
        );
        
        assertEq(fullPermCount, 2, "Should have 2 agents with all permissions");
        
        // Verify all returned agents have all permissions
        for (uint i = 0; i < fullPermAgents.length; i++) {
            assertTrue(fullPermAgents[i].permissions[0], "Should have IQR");
            assertTrue(fullPermAgents[i].permissions[1], "Should have Loyalty");
            assertTrue(fullPermAgents[i].permissions[2], "Should have MeOS");
        }
        
        // Test 5: Pagination with small page size
        (
            AgentInfo[] memory page1,
            uint256 count,
            uint256 pages,
            uint256 currPage
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            true,
            1,
            2, // Only 2 per page
            noFilter
        );
        
        assertEq(count, 4, "Total should be 4");
        assertEq(pages, 2, "Should have 2 pages");
        assertEq(page1.length, 2, "Page 1 should have 2 agents");
        assertEq(currPage, 1);
        
        // Get page 2
        (
            AgentInfo[] memory page2,
            ,
            ,
            uint256 currPage2
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            true,
            2,
            2,
            noFilter
        );
        
        assertEq(page2.length, 2, "Page 2 should have 2 agents");
        assertEq(currPage2, 2);
        
        // Verify no overlap between pages
        assertTrue(page1[0].walletAddress != page2[0].walletAddress);
        
        // Test 6: Sort by creation time descending
        (
            AgentInfo[] memory descendingAgents,
            ,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+4,
            "createdAt",
            false, // descending
            1,
            10,
            noFilter
        );
        
        // Verify sorting - newest first
        assertEq(descendingAgents[0].walletAddress, agent4, "First should be agent4 (newest)");
        assertEq(descendingAgents[3].walletAddress, agent1, "Last should be agent1 (oldest)");
        
        // Test 7: Time range filter
        uint256 midTime = currentTime+ 4 - 2 ;
        (
            AgentInfo[] memory recentAgents,
            uint256 recentCount,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            midTime,
            block.timestamp,
            "createdAt",
            true,
            1,
            10,
            noFilter
        );
        // Should only get agents 3 and 4 (created in last 2 days)
        assertEq(recentCount, 2, "Should have 2 recent agents");
        
        
        
        console.log("Test 7 PASSED: getAgentsInfoPaginatedWithPermissions");
        //
        vm.warp(currentTime + 7 seconds);
        // Agent 5: No permissions
        enhanced.createAgentWithAnalytics(
            address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B),
            "Store 5",
            "Address 5",
            "Phone",
            "Note",
            noFilter,
            // subLocations,
            // subPhones,
            "domain4",
            branchInfoDatas
        );
        
        (
            AgentInfo[] memory agents,
            ,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime+7,
            "createdAt",
            false, // descending
            1,
            10,
            noFilter
        );
        console.log("agents.length:",agents.length);
        vm.stopPrank();
    }
    
    function test_GetAgentsInfoPaginatedWithPermissions_EmptyResults() public {
        uint currentTime = 1760091452;
        vm.warp(currentTime);
        vm.startPrank(superAdmin);
        
        // Create agent with only IQR
        bool[4] memory permissions = [true, false, false, false];
        string[] memory subLocations = new string[](1);
        subLocations[0] = "Branch";
        string[] memory subPhones = new string[](1);
        subPhones[0] = "0123456789";
        
        enhanced.createAgentWithAnalytics(
            agent1,
            "Store",
            "Address",
            "Phone",
            "Note",
            permissions,
            // subLocations,
            // subPhones,
            domain,
            branchInfoDatas
        );
        enhanced.BatchSetAllAgentIQR(agent1);

        // Try to find agents with all permissions (should be empty)
        bool[4] memory allFilter = [true, true, true, false];
        (
            AgentInfo[] memory agents,
            uint256 totalCount,
            uint256 totalPages,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            currentTime,
            "createdAt",
            true,
            1,
            10,
            allFilter
        );
        
        assertEq(totalCount, 0, "Should have no agents with all permissions");
        assertEq(agents.length, 0, "Result should be empty");
        assertEq(totalPages, 0, "Should have 0 pages");
        
        vm.stopPrank();
        
        console.log("Test 7b PASSED: Empty results handling");
        // GetByteCode1();
    }

    // ========================================================================
    // TEST 8: Full Integration Workflow
    // ========================================================================
    
    function test_FullWorkflow_CompleteScenario() public {
        console.log("\n=== FULL INTEGRATION WORKFLOW ===\n");
        
        vm.startPrank(superAdmin);
        
        // STEP 1: Create multiple agents with different configurations
        console.log("Step 1: Creating agents...");
        
        bool[4] memory fullPerms = [true, true, true, true];
        bool[4] memory partialPerms = [true, true, true, false];
        enhanced.createAgentWithAnalytics(
            agent1,
            "Premium Store",
            "123 Premium St",
            "0123456789",
            "VIP Agent",
            fullPerms,
            "domain",
            branchInfoDatas
        );
        uint[] memory branchIds1 = enhanced.getAgentBranchIds(agent1);
        enhanced.BatchSetAllAgentIQR(agent1);
        enhanced.BatchSetAllAgentMEOS(agent1);
        enhanced.BatchSetAllPointsIQR(agent1);
        // enhanced.BatchSetPointsIQR(agent1,branchIds1);
        vm.warp(block.timestamp + 1 hours);
        
        enhanced.createAgentWithAnalytics(
            agent2,
            "Standard Store",
            "456 Main Ave",
            "0987654321",
            "Standard Agent",
            partialPerms,
            "domain1",
            branchInfoDatas
        );
        uint[] memory branchIds2 = enhanced.getAgentBranchIds(agent2);
        enhanced.BatchSetAllAgentIQR(agent2);
        enhanced.BatchSetAllPointsIQR(agent2);
        enhanced.BatchSetAllAgentMEOS(agent2);
        // enhanced.BatchSetPointsIQR(agent2,branchIds2);
        
        vm.warp(block.timestamp + 1 hours);
        
        enhanced.createAgentWithAnalytics(
            agent3,
            "Budget Store",
            "789 Budget Ln",
            "0555555555",
            "Budget Agent",
            partialPerms,
            "domain2",
            branchInfoDatas
        );
        uint[] memory branchIds3 = enhanced.getAgentBranchIds(agent3);
        enhanced.BatchSetAllAgentIQR(agent3);
        //\
        enhanced.BatchSetAllAgentMEOS(agent3);
        // enhanced.BatchSetPointsIQR(agent3,branchIds3);
        enhanced.BatchSetAllPointsIQR(agent3);
        console.log("Created 3 agents");
        
        // STEP 2: Update analytics for agents
        console.log("\nStep 2: Updating analytics...");
        
        enhanced.updateAgentAnalytics(agent1, 100, 50000 ether, 80); // High performer
        enhanced.updateAgentAnalytics(agent2, 50, 20000 ether, 40);  // Medium performer
        enhanced.updateAgentAnalytics(agent3, 20, 5000 ether, 15);   // Low performer
        
        AgentAnalytics memory agent1Analytics = enhanced.getAgentAnalytics(agent1);
        console.log("Agent1 performance score:", agent1Analytics.performanceScore);
        assertGt(agent1Analytics.performanceScore, 50, "Agent1 should have high score");
        
        // STEP 3: Mint loyalty tokens for agents with loyalty permission
        console.log("\nStep 3: Minting loyalty tokens...");
        
        address loyalty1 = enhanced.agentLoyaltyContracts(agent1);
        address loyalty2 = enhanced.agentLoyaltyContracts(agent2);
        
        vm.stopPrank();
                
        // STEP 4: Test pagination with filters
        console.log("\nStep 4: Testing pagination...");
        
        vm.startPrank(superAdmin);
        
        bool[4] memory loyaltyFilter = [false, true, false, false];
        (
            AgentInfo[] memory loyaltyAgents,
            uint256 loyaltyCount,
            ,
        ) = enhanced.getAgentsInfoPaginatedWithPemissions(
            0,
            block.timestamp,
            "createdAt",
            true,
            1,
            10,
            loyaltyFilter
        );
        
        console.log("Agents with loyalty:", loyaltyCount);
        assertEq(loyaltyCount, 3, "All agents have loyalty");
        
        // STEP 5: Update an agent
        console.log("\nStep 5: Updating agent...");
        
        string[] memory newSubLoc = new string[](1);
        newSubLoc[0] = "Updated Branch";
        uint[] memory subLocIdx = new uint[](1);
        subLocIdx[0] = 0;
        
        string[] memory newSubPhone = new string[](1);
        newSubPhone[0] = "0999999999";
        uint[] memory subPhoneIdx = new uint[](1);
        subPhoneIdx[0] = 0;
        Agent memory agentInfo = enhanced.getAgent(agent2);
        BranchInfo[] memory branchInfos = agentInfo.branches;
        console.log("branchInfos.length:",branchInfos.length);
        enhanced.updateAgent(
            agent2,
            "Updated Standard Store",
            "New Address",
            "0999999999",
            "Updated",
            fullPerms, // Grant MeOS now
            "domain3",
            branchInfos
        );
        
        Agent memory updatedAgent2 = enhanced.getAgent(agent2);
        assertTrue(updatedAgent2.permissions[2], "Agent2 should now have MeOS");
        console.log("Updated agent2 permissions");
        
        
        // STEP 7: Lock and unlock tokens
        console.log("\nStep 7: Testing lock/unlock...");
        
        vm.stopPrank();
        
        // STEP 8: Delete an agent
        console.log("\nStep 8: Deleting agent...");
        
        vm.startPrank(superAdmin);
        
        // Delete agent3 (has no active unfrozen loyalty)
        enhanced.deleteAgent(agent3);
        
        Agent memory deletedAgent = enhanced.getAgent(agent3);
        assertFalse(deletedAgent.isActive, "Agent3 should be deleted");
        
        Agent[] memory deletedAgents = enhanced.getDeletedAgentd();
        assertEq(deletedAgents.length, 1, "Should have 1 deleted agent");
        console.log("Deleted agent3");
        
        // STEP 9: Get final statistics
        console.log("\nStep 9: Final statistics...");
        
        (
            uint256 totalAgents,
            uint256 activeAgents,
            uint256 totalRevenue,
            uint256 totalOrders,
            uint256 avgPerformance,
            uint256[4] memory permStats
        ) = enhanced.getSystemAnalytics();
        
        console.log("Total agents:", totalAgents);
        console.log("Active agents:", activeAgents);
        console.log("Total revenue:", totalRevenue);
        console.log("Average performance:", avgPerformance);
        console.log("IQR agents:", permStats[0]);
        console.log("Loyalty agents:", permStats[1]);
        console.log("MeOS agents:", permStats[2]);
        
        assertEq(totalAgents, 3, "Should have 3 total agents");
        assertEq(activeAgents, 2, "Should have 2 active agents");
        
        // STEP 10: Get sorted agents
        console.log("\nStep 10: Getting sorted agents...");
        
        (address[] memory topAgents, uint256[] memory scores) = 
            enhanced.getPerformanceLeaderboard(10);
        
        console.log("Top performer:", topAgents[0]);
        console.log("Top score:", scores[0]);
        
        assertEq(topAgents[0], agent1, "Agent1 should be top performer");
        
        vm.stopPrank();
        //
        address branchManagerAdd = bmFactory.getBranchManagement(agent1);
        branchManager = BranchManagement(branchManagerAdd);
        ManagerInfo[] memory managerInfos = branchManager.getAllManagers();
        console.log("managerInfos.length:",managerInfos.length);
        Branch[] memory branchArr = branchManager.getAllBranches();
        console.log("branchArr.length:",branchArr.length);
        uint256[] memory ids = enhanced.getAgentBranchIds(agent1);
        console.log("ids.length:",ids.length);
        //Order:
        address iqrAgentAdd = iqrFactory.getAgentIQRContract(agent2,branchIds2[0]);
        IQRContracts memory iQRContracts = IAgentIQR(iqrAgentAdd).getIQRSCByAgent(agent2,branchIds2[0]);
        console.log("(iQRContracts.Management:",iQRContracts.Management);
        // staffAgentStore.getUserAgetSCs();
        management = Management(iQRContracts.Management);
        order = RestaurantOrder(iQRContracts.Order);
        bool kq = management.hasRole(ROLE_ADMIN,agent2);
        console.log("hasRole:",kq);
        
        RestaurantLoyaltySystem Points = RestaurantLoyaltySystem(iQRContracts.Points);
        console.log("Points:",address(Points));
        vm.startPrank(agent2);
        bytes32 memberGroupId = Points.createMemberGroup("khach hang than thiet");
        Points.updateMemberGroup(memberGroupId,"nhom22",true);
        vm.stopPrank();
        MemberGroup[] memory memberGroups = Points.getAllGroups();
        console.log("memberGroups[0].name:",memberGroups[0].name);
        (WorkingShift[] memory staff1Shifts, STAFF_ROLE[] memory staff1Roles) = _createPositionAndWorkingShif(management);
        _createStaff(management,staff1Shifts,staff1Roles,staff1);
        _createDishes();
        _createTables();
        // _order(Points );
        //Meos
        address meosAgentAdd = meosFactory.getAgentMEOSContract(agent2,branchIds2[0]);
        MeosContracts memory meoos = enhanced.getMeosSCByAgentFromFactory(agent2,branchIds2[0]);
        console.log("meoos.Points:",meoos.Points);
        staffMeos = Management(meoos.StaffMeosSC);
        bytes memory bytesCodeCall = abi.encodeCall(
            staffMeos.historyTracking,
            ()
        );
        console.log("staffMeos: historyTracking:");
        console.logBytes(bytesCodeCall);
        _createStaff(staffMeos,staff1Shifts,staff1Roles,staff2);
        IQRContracts memory iqr = enhanced.getIQRSCByAgentFromFactory(agent1,branchIds1[0]);
        console.log("iqr.Points:",iqr.Points);

        uint256[] memory _branchIds = new uint256[](0);
        vm.prank(agent1);
        branchManager.AddAndUpdateManager( 
            agent2,
            "name",
            "phone",
            "image",
            true,
            _branchIds,
            true,
            true,
            true,
            true);
        console.log("\n=== FULL WORKFLOW COMPLETED SUCCESSFULLY ===\n");
        // GetByteCode1();
    }

    function test_CreateStaff_Only_FullRoles_WithLogs() public {
        console.log("\n=== TEST: CreateStaff Only (Full Roles) ===\n");

        vm.startPrank(superAdmin);
        bool[4] memory fullPerms = [true, true, true, true];
        enhanced.createAgentWithAnalytics(
            agent2,
            "Staff Test Store",
            "100 Staff St",
            "0900000000",
            "Staff Test Agent",
            fullPerms,
            "staff-domain",
            branchInfoDatas
        );
        uint[] memory branchIds2 = enhanced.getAgentBranchIds(agent2);
        enhanced.BatchSetAllAgentIQR(agent2);
        enhanced.BatchSetAllPointsIQR(agent2);
        vm.stopPrank();

        address iqrAgentAdd = iqrFactory.getAgentIQRContract(agent2, branchIds2[0]);
        IQRContracts memory iQRContracts = IAgentIQR(iqrAgentAdd).getIQRSCByAgent(agent2, branchIds2[0]);
        management = Management(iQRContracts.Management);

        console.log("management:", address(management));
        console.log("agent2 has admin role:", management.hasRole(ROLE_ADMIN, agent2));
        (WorkingShift[] memory staff1Shifts, STAFF_ROLE[] memory staff1Roles) = _createPositionAndWorkingShif(management);

        _createStaff(management,staff1Shifts,staff1Roles,staff1);
    }

    function test_CreateStaff_WithRequestedRoles_8_7_4_1_6() public {
        console.log("\n=== TEST: CreateStaff With Roles [8,7,4,1,6] ===\n");

        vm.startPrank(superAdmin);
        bool[4] memory fullPerms = [true, true, true, true];
        enhanced.createAgentWithAnalytics(
            agent2,
            "Staff Test Store",
            "100 Staff St",
            "0900000000",
            "Staff Test Agent",
            fullPerms,
            "staff-domain",
            branchInfoDatas
        );
        uint[] memory branchIds2 = enhanced.getAgentBranchIds(agent2);
        enhanced.BatchSetAllAgentIQR(agent2);
        enhanced.BatchSetAllPointsIQR(agent2);
        vm.stopPrank();

        address iqrAgentAdd = iqrFactory.getAgentIQRContract(agent2, branchIds2[0]);
        IQRContracts memory iQRContracts = IAgentIQR(iqrAgentAdd).getIQRSCByAgent(agent2, branchIds2[0]);
        management = Management(iQRContracts.Management);

        console.log("management:", address(management));
        console.log("agent2 has admin role:", management.hasRole(ROLE_ADMIN, agent2));

        STAFF_ROLE[] memory requestedRoles = _requestedRoles_8_7_4_1_6();
        console.log("requestedRoles.length:", requestedRoles.length);
        for (uint256 i = 0; i < requestedRoles.length; i++) {
            console.log("requested role index:", i);
            console.log("requested role enum (uint):", uint256(requestedRoles[i]));
            console.log("requested role name:", _staffRoleName(requestedRoles[i]));
        }

        vm.warp(currentTime);
        vm.startPrank(agent2);
        management.CreatePosition("phuc vu ban req", requestedRoles);
        management.CreateWorkingShift("ca sang req", 28800, 43200);
        WorkingShift[] memory shifts = management.getWorkingShifts();
        WorkingShift[] memory staff1Shifts = new WorkingShift[](1);
        staff1Shifts[0] = shifts[0];

        Staff memory staff = Staff({
            wallet: staff1,
            name:"thuy",
            code:"NV1",
            phone:"0913088965",
            addr:"phu nhuan",
            position: "phuc vu ban req",
            role:ROLE.STAFF,
            active: true,
            linkImgSelfie: "linkImgSelfie",
            linkImgPortrait:"linkImgPortrait",
            shifts:staff1Shifts,
            roles: requestedRoles
        });

        management.CreateStaff(staff);
        console.log("CreateStaff with requested roles done");

        for (uint256 i = 0; i < requestedRoles.length; i++) {
            bool hasRequestedRole = management.checkRole(requestedRoles[i], staff1);
            console.log("checkRole for requested index:", i);
            console.log("checkRole result:", hasRequestedRole);
            assertTrue(hasRequestedRole, "staff1 should have requested role");
        }
        vm.stopPrank();
    }

    function _allStaffRolesEnum() internal pure returns (STAFF_ROLE[] memory roles) {
        roles = new STAFF_ROLE[](9);
        roles[0] = STAFF_ROLE.UPDATE_STATUS_DISH;
        roles[1] = STAFF_ROLE.PAYMENT_CONFIRM;
        roles[2] = STAFF_ROLE.TC_MANAGE;
        roles[3] = STAFF_ROLE.TABLE_MANAGE;
        roles[4] = STAFF_ROLE.MENU_MANAGE;
        roles[5] = STAFF_ROLE.STAFF_MANAGE;
        roles[6] = STAFF_ROLE.FINANCE;
        roles[7] = STAFF_ROLE.ACCOUNT_MANAGE;
        roles[8] = STAFF_ROLE.PC_MANAGE;
    }

    function _allSupportedStaffRolesInManagement() internal pure returns (STAFF_ROLE[] memory roles) {
        roles = new STAFF_ROLE[](6);
        roles[0] = STAFF_ROLE.UPDATE_STATUS_DISH;
        roles[1] = STAFF_ROLE.PAYMENT_CONFIRM;
        roles[2] = STAFF_ROLE.TC_MANAGE;
        roles[3] = STAFF_ROLE.TABLE_MANAGE;
        roles[4] = STAFF_ROLE.MENU_MANAGE;
        roles[5] = STAFF_ROLE.STAFF_MANAGE;
        
    }

    function _requestedRoles_8_7_4_1_6() internal pure returns (STAFF_ROLE[] memory roles) {
        roles = new STAFF_ROLE[](5);
        roles[0] = STAFF_ROLE.PC_MANAGE;        // 8
        roles[1] = STAFF_ROLE.ACCOUNT_MANAGE;   // 7
        roles[2] = STAFF_ROLE.MENU_MANAGE;      // 4
        roles[3] = STAFF_ROLE.PAYMENT_CONFIRM;  // 1
        roles[4] = STAFF_ROLE.FINANCE;          // 6
    }

    function _staffRoleName(STAFF_ROLE role) internal pure returns (string memory) {
        if (role == STAFF_ROLE.UPDATE_STATUS_DISH) return "UPDATE_STATUS_DISH";
        if (role == STAFF_ROLE.PAYMENT_CONFIRM) return "PAYMENT_CONFIRM";
        if (role == STAFF_ROLE.TC_MANAGE) return "TC_MANAGE";
        if (role == STAFF_ROLE.TABLE_MANAGE) return "TABLE_MANAGE";
        if (role == STAFF_ROLE.MENU_MANAGE) return "MENU_MANAGE";
        if (role == STAFF_ROLE.STAFF_MANAGE) return "STAFF_MANAGE";
        if (role == STAFF_ROLE.FINANCE) return "FINANCE";
        if (role == STAFF_ROLE.ACCOUNT_MANAGE) return "ACCOUNT_MANAGE";
        if (role == STAFF_ROLE.PC_MANAGE) return "PC_MANAGE";
        return "UNKNOWN";
    }

    function _createDishes()public{
         vm.startPrank(agent2);
         //Create option
        string[] memory featureNames1 = new string[](3);
        featureNames1[0] = "Khong";
        featureNames1[1] = "Vua";
        featureNames1[2] = "Nhieu";
        uint256[] memory _featurePrices = new uint256[](3);
        _featurePrices[0] = 0;
        _featurePrices[1] = 0;
        _featurePrices[2] = 0;

        bytes32 optionId1 = management.CreateDishOptions(
            "Do Cay",
            featureNames1,
            _featurePrices,
            false,
            3
        );

        bytes32 optionId2 = management.CreateDishOptions(
            "Do Beo",
            featureNames1,
            _featurePrices,
            false,
            3
        );
        bytes32 optionId3 = management.CreateDishOptions(
            "Do Ngot",
            featureNames1,
            _featurePrices,
            false,
            3
        );
        bytes32[] memory optionIds = new bytes32[](3);
        optionIds[0] = optionId1;
        optionIds[1] = optionId2;
        optionIds[2] = optionId3;
         //create Category
        Category memory category1 = Category({
            code:"THITBO",
            name:"thit bo",
            rank:1,
            desc:"Cac mon voi thit bo",
            active:true,
            imgUrl:"_imgURL1",
            icon: "icon"
        });
        management.CreateCategory(category1);

        string[] memory ingredients = new string[](1);
        ingredients[0] = "thit tuoi";
        Dish memory dish1 = Dish({
            code:"dish1_code",
            nameCategory:"Thit bo",
            name:"Bo BBQ",
            des:"Thit bo nuong BBQ voi nhieu loai sot",
            available:true,
            active:true,
            imgUrl:"img_bo1",
            averageStar: 0,
            cookingTime: 30,
            ingredients:ingredients,
            showIngredient: true,
            videoLink: "videoLink",
            totalReview:0,
            orderNum:0,
            createdAt:0
        });
        Attribute[] memory attrs1 = new Attribute[](1);
        attrs1[0] = Attribute({
            id: bytes32(0),
            key: "size",
            value: "S"
        });
        VariantParams memory variant1 = VariantParams({
            attrs: attrs1,
            price: 1000
        });
        //
        Attribute[] memory attrs2 = new Attribute[](1);
        attrs2[0] = Attribute({
            id: keccak256(abi.encodePacked("1")),
            key: "size",
            value: "M"
        });
        VariantParams memory variant2 = VariantParams({
            attrs: attrs2,
            price: 2000
        });
        //
        Attribute[] memory attrs3 = new Attribute[](1);
        attrs3[0] = Attribute({
            id: keccak256(abi.encodePacked("2")),
            key: "size",
            value: "L"
        });
        VariantParams memory variant3 = VariantParams({
            attrs: attrs3,
            price: 3000
        });
        //
        VariantParams[] memory variants = new VariantParams[](3);
        variants[0] = variant1;
        variants[1] = variant2;
        variants[2] = variant3;

        management.CreateDish("THITBO",dish1,variants,optionIds);
        vm.stopPrank();
    } 
    function _createStaff(Management managementSc,WorkingShift[] memory staff1Shifts,  STAFF_ROLE[] memory staff1Roles,address staffWallet)public{
        vm.startPrank(agent2);
        Staff memory staff = Staff({
            wallet: staffWallet,
            name:"thuy",
            code:"NV1",
            phone:"0913088965",
            addr:"phu nhuan",
            position: "phuc vu ban",
            role:ROLE.STAFF,
            active: true,
            linkImgSelfie: "linkImgSelfie",
            linkImgPortrait:"linkImgPortrait",
            shifts:staff1Shifts,
            roles: staff1Roles

        });
        console.log("CreateStaff payload:");
        console.log("wallet:", staff.wallet);
        console.log("name:", staff.name);
        console.log("code:", staff.code);
        console.log("position:", staff.position);
        console.log("active:", staff.active);
        console.log("roles.length:", staff.roles.length);
        console.log("shifts.length:", staff.shifts.length);
        managementSc.CreateStaff(staff);
        bytes memory bytesCodeCall = abi.encodeCall(
            managementSc.CreateStaff,
            (
                staff            
            )
        );
        console.log("managementSc: CreateStaff:");
        console.logBytes(bytesCodeCall);
        console.log("CreateStaff done");
        vm.stopPrank();
        console.log("=== _createStaff: end ===\n");
    }
    function _createPositionAndWorkingShif(Management managementSc)public returns(WorkingShift[] memory , STAFF_ROLE[] memory ) {
        console.log("\n=== createPositionAndWorkingShif: begin ===");
        console.log("warp currentTime:", currentTime);
        vm.warp(currentTime);
        vm.startPrank(agent2);
        //CreatePosition
        STAFF_ROLE[] memory allEnumRoles = _allStaffRolesEnum();
        console.log("all enum STAFF_ROLE count:", allEnumRoles.length);
        for (uint256 i = 0; i < allEnumRoles.length; i++) {
            console.log("enum role index:", i);
            console.log("enum role (uint):", uint256(allEnumRoles[i]));
            console.log("enum role name:", _staffRoleName(allEnumRoles[i]));
        }

        // STAFF_ROLE[] memory staff1Roles = _allSupportedStaffRolesInManagement();
        STAFF_ROLE[] memory staff1Roles = _allStaffRolesEnum();
        console.log("full supported STAFF_ROLE count:", staff1Roles.length);
        console.log("staff1Roles.length:", staff1Roles.length);
        for (uint256 i = 0; i < staff1Roles.length; i++) {
            console.log("role index:", i);
            console.log("role enum (uint):", uint256(staff1Roles[i]));
            console.log("role name:", _staffRoleName(staff1Roles[i]));
        }

        managementSc.CreatePosition("phuc vu ban",staff1Roles);
        bytes memory bytesCodeCall = abi.encodeCall(
            managementSc.CreatePosition,
            (
                "phuc vu ban",staff1Roles            
            )
        );
        console.log("managementSc: CreatePosition:");
        console.logBytes(bytesCodeCall);

        console.log("CreatePosition done");
        //CreateWorkingShift
        managementSc.CreateWorkingShift("ca sang",28800,43200); ////số giây tính từ 0h ngày hôm đó. vd 08:00 là 8*3600=28800
        console.log("CreateWorkingShift done: ca sang 28800 -> 43200");

        WorkingShift[] memory shifts = managementSc.getWorkingShifts();
        console.log("working shifts count:", shifts.length);
        console.log("first shift title:", shifts[0].title);
        assertEq(shifts[0].title,"ca sang","working shift title should equal");

        WorkingShift[] memory staff1Shifts = new WorkingShift[](1);
        staff1Shifts[0] = shifts[0];
        console.log("staff1Shifts.length:", staff1Shifts.length);
        return (staff1Shifts, staff1Roles);
    }
    function _createTables()public {
        vm.startPrank(agent2);
        management.CreateArea(1,"Khu A");
        vm.stopPrank();
    }
    function _order(RestaurantLoyaltySystem Points )public {

        vm.warp(currentTime);
        vm.prank(agent2);
        Points.updateExchangeRate(1);
        vm.startPrank(customer1);
        //register member
        RegisterInPut memory input = RegisterInPut({
            _memberId :"CUST0001",
            _phoneNumber:"0123456789",
            _firstName: "Nguyen",
            _lastName:"Van A",
            _whatsapp:"+84365621276",
            _email:"abc@gmail.com",
            _avatar:"avatar"

        });
        Points.registerMember(input);
        //order
        uint table =1;
        string[] memory dishCodes = new string[](1);
        dishCodes[0] = "dish1_code";
        uint8[] memory quantities = new uint8[](1);
        quantities[0] = 2;
        string[] memory notes = new string[](1);
        notes[0] = "";
        //
        DishInfo memory dishInfo = management.getDishInfo("dish1_code");       
        bytes32[] memory variantIDs = new bytes32[](3);
        variantIDs[0] = dishInfo.variants[0].variantID;
        variantIDs[1] = dishInfo.variants[1].variantID;
        variantIDs[2] = dishInfo.variants[2].variantID;
        SelectedOption[] memory selectionOption0 = new SelectedOption[](1);
        selectionOption0[0] = SelectedOption({
            optionId: optionId1,
            selectedFeatureIds: selectedFeatureIdsDish1
        });

        SelectedOption[][] memory dishSelectedOptions = new SelectedOption[][](1);
        dishSelectedOptions[0] = selectionOption0;
        // bytes32 orderId1T1 = ORDER.makeOrder(
        //     table,
        //     dishCodes,
        //     quantities,
        //     notes,
        //     variantIDs,
        //     dishSelectedOptions
        // );
        // string memory discountCode = "";
        // uint tip = 0;
        // Payment memory payment = order.getTablePayment(1);
        (bytes32 sessionIdT1, ) = order.CreateSessionForTable(2, 3, bytes32(0));

        MakeOrderParams memory params1T1 = MakeOrderParams({
            table: 2,
            sessionId: sessionIdT1,
            dishCodes: dishCodes,           // Sử dụng bộ dishCodes gốc
            quantities: quantities,         // Sử dụng bộ quantities gốc
            notes: notes,                   // Sử dụng bộ notes gốc
            variantIDs: variantIDs,         // Sử dụng bộ variantIDs gốc
            dishSelectedOptions: dishSelectedOptions,
            paymentType: PaymentType.POSTPAID
        });

        // Gọi hàm makeOrder với duy nhất 1 tham số struct
        bytes32 orderId1T1 = order.makeOrder(params1T1);
        string memory discountCode = "";
        uint tip = 0;
        Payment memory payment = order.getPaymentByOrder(orderId1T1);
        uint256 paymentAmount = payment.total; //(2200)
        console.log("paymentAmount:",paymentAmount);
        string memory txID = "";
        // order.executeOrder(1,discountCode,tip,paymentAmount,txID,false);
        order.executeOrder(sessionIdT1,payment.id,discountCode,tip,paymentAmount,txID,false);
        // ORDER.UpdateForReport(1);
        management.UpdateTotalRevenueReport(currentTime,payment.foodCharge-payment.discountAmount);
        management.SortDishesWithOrderRange(0,10);
        management.UpdateRankDishes();
        vm.stopPrank();
        vm.startPrank(staff1);
        uint tableId = order.getTableBySession(sessionIdT1);
        order.confirmPayment(tableId,payment.id,"paid");
        Points.earnTokenA(customer1, payment.foodCharge-payment.discountAmount, payment.id, payment.id,EconomyTypes.EVENT_FOOD_PAID,5,false);
        
        Member memory member = Points.getMember(customer1);
        console.log("Points after first purchase:", member.totalPoints);
        assertEq(member.totalPoints, 2);
        vm.stopPrank();
    }
    
    // // ========================================================================
    // // HELPER FUNCTIONS
    // // ========================================================================
    
    // function printAgentInfo(address _agent) internal view {
    //     Agent memory agent = enhanced.getAgent(_agent);
    //     console.log("\n--- Agent Info ---");
    //     console.log("Address:", agent.walletAddress);
    //     console.log("Store:", agent.storeName);
    //     console.log("Active:", agent.isActive);
    //     console.log("IQR:", agent.permissions[0]);
    //     console.log("Loyalty:", agent.permissions[1]);
    //     console.log("MeOS:", agent.permissions[2]);
    // }
    
    // function printSystemStats() internal view {
    //     (
    //         uint256 total,
    //         uint256 active,
    //         uint256 revenue,
    //         uint256 orders,
    //         uint256 avgPerf,
    //         uint256[4] memory perms
    //     ) = enhanced.getSystemAnalytics();
        
    //     console.log("\n--- System Stats ---");
    //     console.log("Total Agents:", total);
    //     console.log("Active Agents:", active);
    //     console.log("Total Revenue:", revenue);
    //     console.log("Total Orders:", orders);
    //     console.log("Avg Performance:", avgPerf);
    //     console.log("IQR Agents:", perms[0]);
    //     console.log("Loyalty Agents:", perms[1]);
    //     console.log("MeOS Agents:", perms[2]);
    // }
    function GetByteCode1()public {
    
        bytes memory bytesCodeCall = abi.encodeCall(
        enhanced.getAgentsInfoPaginated,
        (
            0,
            1870351118,
            "createdAt",
            false,
            1,
            20
        ));
        console.log("enhanced getAgentsInfoPaginated:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );
        //
        bytesCodeCall = abi.encodeCall(
        enhanced.getMeosSCByAgentFromFactory,
        (
            0x325C4A7eb1Edf24B46a2CE1FD0bB8B3fd333a7B6,
            9
        ));
        console.log("enhanced getMeosSCByAgentFromFactory:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );

    //     //getAgents
    //     address[] memory agentAdds = new address[](2);
    //     agentAdds[0] = 0x3185271B4AE45eE6d2CBc5A2b8203202b4A5ADee;
    //     agentAdds[1] = 0x0C037f2829d01a5E4FA1Ca7a2d67e120afeAD892;
    //     bytesCodeCall = abi.encodeCall(
    //     enhanced.getAgents,
    //     (
    //         agentAdds
    //     ));
    //     console.log("enhanced getAgents:");
    //     console.logBytes(bytesCodeCall);
    //     console.log(
    //         "-----------------------------------------------------------------------------"
    //     );

    //     //getAgent
    //     bytesCodeCall = abi.encodeCall(
    //     enhanced.getAgent,
    //     (
    //         0x3185271B4AE45eE6d2CBc5A2b8203202b4A5ADee
    //     ));
    //     console.log("enhanced getAgent:");
    //     console.logBytes(bytesCodeCall);
    //     console.log(
    //         "-----------------------------------------------------------------------------"
    //     );
    // //     //setIQRSC
    //     bytesCodeCall = abi.encodeCall(
    //         iqrFactory.setIQRSC,
    //         (
    //             0x47aed34E1F61eB68bB0A923aA54cCa19DBee40B7,
    //             0x27D526d5060Ec7dE55db095fC2568eC764FD15cd,
    //             0x100c93A4Bd8A3B837d8D3739dAb36Cc847051086,
    //             0xA7B2082cD26deA590b0BDc643aA52A802d8Ed9EF,
    //             0x10F4A365ff344b3Af382aBdB507c868F1c22f592,
    //             0x603dbFC668521aB143Ee1018e4D80b13FDDedfBd,
    //             0x1510151015101510151015101510151015101510,
    //             0x1510151015101510151015101510151015101510,
    //             0x0000000000000000000000000000000000000000
    //         )
    //     );
    //     console.log("iqrFactory: setIQRSC");
    //     console.logBytes(bytesCodeCall);
    //     console.log(
    //         "-----------------------------------------------------------------------------"
    //     );  
    //     //setIQRSC
        bytesCodeCall = abi.encodeCall(
            iqrFactory.setIQRSC,
            (
                0x8e76E828d54D4c006910135fc3106D38e8ac9Ee7,
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000,
                0x0000000000000000000000000000000000000000
            )
        );
        console.log("iqrFactory: setIQRSC");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  

    // //     //
    // //     bytesCodeCall = abi.encodeCall(
    // //         enhanced.deleteAgent,
    // //         (
    // //             0xF1B47A9dFb7Cc0228e1EDfeCe406FD47B0D78FD6            
    // //         )
    // //     );
    // //     console.log("enhanced: deleteAgent");
    // //     console.logBytes(bytesCodeCall);
    // //     console.log(
    // //         "-----------------------------------------------------------------------------"
    // //     );  
  
    // //     //
    // //     bytesCodeCall = abi.encodeCall(
    // //         enhanced.isAdmin,
    // //         (
    // //             0xC8643eF8f4232bf7E8bAc6Ac73a2fe9A28Cb575A            
    // //         )
    // //     );
    // //     console.log("enhanced: isAdmin:");
    // //     console.logBytes(bytesCodeCall);
    // //     console.log(
    // //         "-----------------------------------------------------------------------------"
    // //     );  

    // //     //agentLoyaltyContracts
    // //     bytesCodeCall = abi.encodeCall(
    // //         loyaltyFactory.agentLoyaltyContracts,
    // //         (
    // //             0xce29174f8d0581641a1597a5d3a14ee28d84640f            
    // //         )
    // //     );
    // //     console.log("loyaltyFactory: agentLoyaltyContracts:");
    // //     console.logBytes(bytesCodeCall);
    // //     console.log(
    // //         "-----------------------------------------------------------------------------"
    // //     );  
    // //     //loyaltyFactory.setPointsImp(address(POINTS_IMP));
    // //     bytesCodeCall = abi.encodeCall(
    // //         loyaltyFactory.setPointsImp,
    // //         (
    // //             0xE476Be15a7bf3b1DCcb0b6aF8C88fa233F6A9471            
    // //         )
    // //     );
    // //     console.log("loyaltyFactory: setPointsImp:");
    // //     console.logBytes(bytesCodeCall);
    // //     console.log(
    // //         "-----------------------------------------------------------------------------"
    // //     );  
    // //     //enhanced.setPointsIQR(agent1);
    // //     // bytesCodeCall = abi.encodeCall(
    // //     //     enhanced.setPointsIQR,
    // //     //     (
    // //     //         0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B            
    // //     //     )
    // //     // );
    // //     // console.log("enhanced: setPointsIQR:");
    // //     // console.logBytes(bytesCodeCall);
    // //     // console.log(
    // //     //     "-----------------------------------------------------------------------------"
    // //     // );  
    // //
        bytesCodeCall = abi.encodeCall(
            meosFactory.setMeos,
            (
            0x47aed34E1F61eB68bB0A923aA54cCa19DBee40B7,
            0x6ee8C04DDA7b0CB0DeB944cAaf485FaC57AEC74e,
            0x082a9CF7d2b56111b7F230BD4efF43Fd28F78064,
            0xE766CACa8E1bA5340e264f21374cD64831002058,
            0xBa1e583eA3a3d0dD5590E4c5C76d9Ed818121960,
            0x2e5288Bc460E2B9fc13e50FcCc4f7E076B75974F,
            0xBD9B7c0E5256677f336c898ca3Fc43C06bC6398f,
            0x1510151015101510151015101510151015101510,
            0x1510151015101510151015101510151015101510,
            0x1510151015101510151015101510151015101510
            )
        );
        console.log("enhanced: setMeos:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  
        //
        bytesCodeCall = abi.encodeCall(
            management.branchManagement,
            (
            )
        );
        console.log("management: branchManagement:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  

        //setRobot
        RobotInputs memory robotInputs1 = RobotInputs({
            _StaffRobotSC: 0xD6549130F11D9995824CA271C84e01F3EEC3A36A,
            _RobotRegistryV2IMP: 0x7D1402a3929B68317b600Cc3655B46C230267282,
            _RobotActiveV2IMP: 0xacbe1A933Ad18DbF96f9a66c4E69f535B95101E9,
            _RobotDataUploadTrainingV2IMP: 0x81Bd6811573D3756eCFC7163B5b51ac7D0Ae3fd3,
            _RobotObservationTrainingV2IMP: 0x401FC6324aF8d35A98F6d7b5851AA26b9EF35FB3,
            _RobotLocationV2IMP: 0x7A99fd2824f7F199DF5C44d0ea95aFfE9fF26581,
            _RobotQuestionV2IMP: 0x64627E3f0eb920a14E6A8342C1F95B0F6B17a856,
            _RobotDashboadV2IMP: 0x507caf110A658B0104dAEd1DBf536a0e81b442ff,
            _RobotTestingV2IMP: 0xd2dFa22aB1F6572CcB11e773be9b9DA63919B735,
            _StaffAgentStore: 0x1510151015101510151015101510151015101510
        });

        bytesCodeCall = abi.encodeCall(
            robotFactory.setRobot,
            (
            robotInputs1,
            0x1510151015101510151015101510151015101510,
            0x1510151015101510151015101510151015101510,
            0x1510151015101510151015101510151015101510
            )
        );
        console.log("robotFactory: setRobot:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  

        //setBranchManagerSC
        bytesCodeCall = abi.encodeCall(
            bmFactory.setBranchManagerSC,
            (
            0x0000000000000000000000000000000000000000,
            0x2f5d0454beEB5dCc3CD8860a4A37D583aD7C8d6b,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
            )
        );
        console.log("enhanced: setBranchManagerSC:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  

        //        enhanced.setFactoryContracts
        bytesCodeCall = abi.encodeCall(
            enhanced.setFactoryContracts,
            (
            0x1510151015101510151015101510151015101510,
            0x1510151015101510151015101510151015101510,
            0x1510151015101510151015101510151015101510,
            0x1510151015101510151015101510151015101510,
            0x1510151015101510151015101510151015101510,
            0x1510151015101510151015101510151015101510
            )
        );
        console.log("enhanced: setFactoryContracts:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  
    //     //getAgentsInfoPaginatedWithPemissions
    //     bool[4] memory noFilter = [false, false, false, false];
    //     bool[4] memory allFilter = [true,true,false, false];
    //     bytesCodeCall = abi.encodeCall(
    //         enhanced.getAgentsInfoPaginatedWithPemissions,
    //         (
    //         1760288400,
    //         1767061379,
    //         "createdAt",
    //         false,
    //         1,
    //         20,
    //         allFilter          
    //         )
    //     );
    //     console.log("getAgentsInfoPaginatedWithPemissions:");
    //     console.logBytes(bytesCodeCall);
    //     console.log(
    //         "-----------------------------------------------------------------------------"
    //     ); 
        //getAgentsInfoPaginatedWithSearch
        bytesCodeCall = abi.encodeCall(
        enhanced.getAgentsInfoPaginatedWithSearch,
            (
                1748694440,
                1770351773,
                "createdAt",
                false,
                1,
                10,
                ""
            )
        );
        console.log("enhanced: getAgentsInfoPaginatedWithSearch");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  
 
    // //     //enhancedV1.upgradeToAndCall(address(enhancedImplementationV2), "");
    // //     bytesCodeCall = abi.encodeCall(
    // //         enhanced.upgradeToAndCall,
    // //         (
    // //         address(enhancedImplementation), ""            
    // //         ));
    // //     console.log("upgradeToAndCall:");
    // //     console.logBytes(bytesCodeCall);
    // //     console.log(
    // //         "-----------------------------------------------------------------------------"
    // //     );  
    //createAgentWithAnalytics
    bool[4] memory filter = [true,true,true, true];
    bytesCodeCall = abi.encodeCall(
        enhanced.createAgentWithAnalytics,
        (
            address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B),
            "Store 5",
            "Address 5",
            "Phone",
            "Note",
            filter,
            "https://thuy.fi.ai",
            branchInfoDatas
        ));
    console.log("enhanced createAgentWithAnalytics:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    //
    bytes32 WRITER_ROLE = keccak256("WRITER_ROLE");
    bytesCodeCall = abi.encodeCall(
    historyTrackingIMP.hasRole,
        (
            WRITER_ROLE,
            0xCe0035f386814b05dC36A2187AF1dc3f1A6B0699
        )
    );
    console.log("historyTrackingIMP hasRole:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  

    // enhanced.BatchSetAllAgentMEOS(agent1);
    //BatchSetAllAgentIQR
    bytesCodeCall = abi.encodeCall(
        bmFactory.branchManagementBeacon,
        (
        ));
    console.log("bmFactory branchManagementBeacon:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 

    //upgradeBeacon
    bytesCodeCall = abi.encodeCall(
        bmFactory.upgradeBeacon,
        (
            address(0xaB1915B6D1F29745ff9965df13d807274bb2F5e3)
        ));
    console.log("bmFactory upgradeBeacon:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    // //BatchSetAllAgentIQR
    // bytesCodeCall = abi.encodeCall(
    //     enhanced.BatchSetAllAgentIQR,
    //     (
    //         address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B)
    //     ));
    // console.log("enhanced BatchSetAllAgentIQR:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // ); 
    uint[] memory branchIds = new uint[](3);
    branchIds[0] = 1;
    branchIds[1] = 2;
    branchIds[2] = 3;
    bytesCodeCall = abi.encodeCall(
        enhanced.BatchSetPointsIQR,
        (
            address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B),
            branchIds
        ));
    console.log("enhanced BatchSetPointsIQR:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 

    // //

    bytesCodeCall = abi.encodeCall(
        enhanced.BatchSetAllPointsIQR,
        (
            address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B)
        ));
    console.log("enhanced BatchSetAllPointsIQR:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    // //
    // bytesCodeCall = abi.encodeCall(
    //     enhanced.branchIdCount,
    //     (
    //     ));
    // console.log("enhanced branchIdCount:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // ); 

    // //getAgentBranchIds
    // bytesCodeCall = abi.encodeCall(
    //     enhanced.getAgentBranchIds,
    //     (
    //         0x739b6287F81436B433145d76aE4713875864dBd8
    //     ));
    // console.log("getAgentBranchIds:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // ); 

    //getIQRSCByAgentFromFactory
    bytesCodeCall = abi.encodeCall(
        iqrFactory.getIQRSCByAgentFromFactory,
        (
            0x804c438945f0AeD1D752dA9adb2A03202cad2B2B,
            9
        ));
    console.log("iqrFactory: getIQRSCByAgentFromFactory:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    // //getBranchManagement
    // bytesCodeCall = abi.encodeCall(
    //     bmFactory.getBranchManagement,
    //     (
    //         0x739b6287F81436B433145d76aE4713875864dBd8
    //     ));
    // console.log("iqrFactory: getBranchManagement:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // );
    // //getAllBranches
    // bytesCodeCall = abi.encodeCall(
    //     branchManagementImplementation.getAllBranches,
    //     (
    //     ));
    // console.log("branchManagementImplementation: getAllBranches:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // ); 
    // //getManagerDashboardProposalByBranch
    // bytesCodeCall = abi.encodeCall(
    //     branchManagementImplementation.getManagerDashboardProposalByBranch,
    //     (
    //         0x5f624ed84CeBD51bAf6AD9c6abFf57d6dC50f2E8,
    //         0,
    //         1,
    //         20
    //     ));
    // console.log("branchManagementImplementation: getManagerDashboardProposalByBranch:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // ); 


    // //voteProposal
    // bytesCodeCall = abi.encodeCall(
    //     branchManagementImplementation.proposalCounter,
    //     (
    //     ));
    // console.log("branchManagementImplementation: proposalCounter:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // ); 

    // //voteProposal
    //     bytesCodeCall = abi.encodeCall(
    //     branchManagementImplementation.voteProposal,
    //     (
    //         1,true
    //     ));
    // console.log("branchManagementImplementation: voteProposal:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // ); 

    // //AddAndUpdateManager
    uint256[] memory _branchIds = new uint256[](3);
    _branchIds[0]=1;
    _branchIds[1]=2;
    _branchIds[2]=3;
    bytesCodeCall = abi.encodeCall(
        branchManagementImplementation.AddAndUpdateManager,
        (
            0x739b6287F81436B433145d76aE4713875864dBd8,
            "name",
            "phone",
            "image",
            true,
            _branchIds,
            true,
            true,
            true,
            true
        ));
    console.log("branchManagementImplementation: AddAndUpdateManager:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    // //mDomainToWallet
    // bytesCodeCall = abi.encodeCall(
    //     enhanced.mDomainToWallet,
    //     (
    //         "https://comtamsaigon-cn2.fi.ai"
    //     ));
    // console.log("mDomainToWallet:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // ); 

    // //updateAgent
    // BranchInfo[] memory branchInfos = new BranchInfo[](3);
    // filter = [true,true,true, true];
    // bytesCodeCall = abi.encodeCall(
    //     enhanced.updateAgent,
    //     (
    //         0x739b6287F81436B433145d76aE4713875864dBd8,
    //         "Com chien",
    //         "47 Dien Bien Phu TPHCM 4567",
    //         "0942115532",
    //         "Com chien",
    //         filter,
    //         "comchien.fi.ai",
    //         branchInfos
    //     ));
    // console.log("updateAgent:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // ); 
    //setPublicfullDB
    bytesCodeCall = abi.encodeCall(
        loyaltyFactory.setPublicfullDB,
        (
            address(0x1510151015101510151015101510151015101510)
        ));
    console.log("loyaltyFactory setPublicfullDB:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 

    // // //getAgentLoyaltyContract
    // //      bytesCodeCall = abi.encodeCall(
    // //     loyaltyFactory.getAgentLoyaltyContract,
    // //     (
    // //         address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B)
    // //     ));
    // // console.log("getAgentLoyaltyContract:");
    // // console.logBytes(bytesCodeCall);
    // // console.log(
    // //     "-----------------------------------------------------------------------------"
    // // ); 
    // // //
    }
}
