// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import  "../contracts/ManagementDemo.sol";
import "../contracts/interfaces/IRestaurant.sol";
import  "../contracts/order_new.sol";
import  "../contracts/report.sol";
import  "../contracts/timekeeping.sol";
import "../contracts/agentLoyalty.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MOCKRestaurantOrder is RestaurantOrder{

    function setInvoiceAmountTest(bytes32 _paymentId,uint foodCharge,uint discountAmount) external onlyOwner {
        mIdToPayment[_paymentId].foodCharge = foodCharge;
        mIdToPayment[_paymentId].discountAmount = discountAmount;
    }

}
contract MOCKPublicfullDB  {
    event TransactionSynced(address indexed agent, uint256 indexed txId, uint256 docId, uint256 branchId, bytes32 module);
    bytes32 public constant TOKEN_A = keccak256("A");
    bytes32 public constant ACT_CREDIT = keccak256("CREDIT");
    bytes32 public constant ACT_GRANT  = keccak256("GRANT");
    bytes32 public constant TOKEN_B = keccak256("B");
    function syncTransaction(
        address agent,
        uint256 txId,
        address member,
        string  memory txType,
        int256  points,
        uint256 amount,
        bytes32 invoiceId,
        string  memory note,
        uint256 timestamp,
        uint256 branchId,
        bytes32 module
    ) external  {
        // Simulate DB sync by emitting an event
        emit TransactionSynced(agent, txId, 1, branchId, module);    
    }

    function syncMember(
        address agent,
        address wallet,
        bytes32 tokenType,
        bytes32 actionType,
        int256  delta,
        uint256 balA,
        uint256 balB,
        uint256 totalSpent,
        uint256 branchId,
        bytes32 module,
        bytes32 refId
    ) external {
        // Simulate DB sync by emitting an event
        emit TransactionSynced(agent, 1, 1, branchId, module);
    }
}
contract RestaurantTest is Test {
    Management public MANAGEMENT;
    Management public MANAGEMENT_IMP;
    MOCKRestaurantOrder public ORDER;
    MOCKRestaurantOrder public ORDER_IMP;
    RestaurantReporting public REPORT;
    RestaurantReporting public REPORT_IMP;
    AttendanceSystem public TIMEKEEPING;
    AttendanceSystem public TIMEKEEPING_IMP;
    RestaurantLoyaltySystem public POINTS;
    RestaurantLoyaltySystem public POINTS_IMP;
    address public pos = address(0x11);
    address public Deployer = address(0x1);
    address admin = address(0x2);
    address staff1 = address(0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B);
    address staff2 = address(0xE730d4572f20A4d701EBb80b8b5aFA99b36d5e49);
    address staff3 = address(0x11111111);
    address customer1 = address(0x5);
    address customer2 = address(0x6);
    bytes32 public ROLE_ADMIN = keccak256("ROLE_ADMIN");
    bytes32 public ROLE_STAFF = keccak256("ROLE_STAFF");
    bytes32 public ROLE_HASH_STATUS_ORDER = keccak256("ROLE_HASH_STATUS_ORDER");
    bytes32 public ROLE_HASH_PAYMENT_CONFIRM = keccak256("ROLE_HASH_PAYMENT_CONFIRM");
    bytes32 public ROLE_HASH_UPDATE_TC = keccak256("ROLE_HASH_UPDATE_TC");
    bytes32 public ROLE_HASH_TABLE_MANAGE = keccak256("ROLE_HASH_TABLE_MANAGE");
    bytes32 public ROLE_HASH_STAFF_MANAGE = keccak256("ROLE_HASH_STAFF_MANAGE");
    // bytes32 public DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    // Proxies
    ERC1967Proxy public MANAGEMENT_PROXY;
    ERC1967Proxy public ORDER_PROXY;
    ERC1967Proxy public REPORT_PROXY;
    ERC1967Proxy public TIMEKEEPING_PROXY;
    ERC1967Proxy public POINTS_PROXY;
    WorkPlace[] public workPlaces;
    uint[] public workPlaceIds;
    uint currentTime = 1761301509; //17h25-24/10/2025
    address public superAdmin;
    address public agent1;
    address public agent2;
    address public agent3;
    address public agent4;
    bytes32 optionId1; //option "Do cay" dish1_code
    bytes32 optionId2; //option "Do cay" dish2_code
    bytes32 optionId3; //option "Do cay" dish2_code
    bytes32[] public selectedFeatureIdsDish1; //3 muc do cay cua dish1_code
    bytes32[] public selectedFeatureIdsDish2; //3 muc do beo cua dish2_code
    bytes32[] public selectedFeatureIdsDish3; //3 muc do ngot cua dish3_code
    uint256 public eventId11;
    uint256[] public eventIdArr11;
    bytes32 public paymentId1;
    uint256 public amountPayment1;
    MOCKPublicfullDB public publicfullDBMock;
    constructor() {
        vm.warp(1759724234);//11h17 -7/10/2025
        superAdmin = makeAddr("superAdmin");
        agent1 = makeAddr("agent1");
        agent2 = makeAddr("agent2");
        agent3 = makeAddr("agent3");
        agent4 = makeAddr("agent4");
        vm.startPrank(Deployer);
         // Deploy implementation contracts
         MANAGEMENT_IMP = new Management();
         ORDER_IMP = new MOCKRestaurantOrder();
         REPORT_IMP = new RestaurantReporting();
         TIMEKEEPING_IMP = new AttendanceSystem();
         POINTS_IMP = new RestaurantLoyaltySystem();
         publicfullDBMock = new MOCKPublicfullDB();
        // Deploy proxies
        MANAGEMENT_PROXY = new ERC1967Proxy(
            address(MANAGEMENT_IMP),
            abi.encodeWithSelector(Management.initialize.selector)
        );
        ORDER_PROXY = new ERC1967Proxy(
            address(ORDER_IMP),
            abi.encodeWithSelector(RestaurantOrder.initialize.selector)
        );
        REPORT_PROXY = new ERC1967Proxy(
            address(REPORT_IMP),
            abi.encodeWithSelector(RestaurantReporting.initialize.selector,
            address(MANAGEMENT_PROXY))
        );
        POINTS_PROXY = new ERC1967Proxy(
            address(POINTS_IMP),
            abi.encodeWithSelector(RestaurantLoyaltySystem.initialize.selector,
            agent1,
            address(0))
        );
        bytes memory initData = abi.encodeWithSelector(
            AttendanceSystem.initialize.selector,
            address(MANAGEMENT_PROXY)
        );
        
        TIMEKEEPING_PROXY = new ERC1967Proxy(address(TIMEKEEPING_IMP), initData);    
        
            
//         // Set BE
//         attendanceSystem.setBE(be);
        // Wrap proxies
        MANAGEMENT = Management(address(MANAGEMENT_PROXY));
        ORDER = MOCKRestaurantOrder(address(ORDER_PROXY));
        REPORT = RestaurantReporting(address(REPORT_PROXY));
        TIMEKEEPING = AttendanceSystem(address(TIMEKEEPING_PROXY));
        POINTS = RestaurantLoyaltySystem(address(POINTS_PROXY));
        //SET
        ORDER.setConfig(address(MANAGEMENT),address(0x456),address(0x789),10,address(0x999),address(REPORT));
        MANAGEMENT.setRestaurantOrder(address(ORDER));
        MANAGEMENT.setReport(address(REPORT));
        MANAGEMENT.setTimeKeeping(address(TIMEKEEPING));
        MANAGEMENT.setStaffAgentStore(address(0x123));
        
        REPORT.setManangement(address(MANAGEMENT));
        TIMEKEEPING.setManagement(address(MANAGEMENT));
        //
        MANAGEMENT.setPoints(address(POINTS));
        POINTS.setManagementSC(address(MANAGEMENT));
        POINTS.setOrder(address(ORDER),1);
        POINTS.setSearchIndex(address(publicfullDBMock));
        ORDER.setPointSC(address(POINTS));
        vm.stopPrank();
        SetUpRestaurant();
        SetAttendance();
    }
    function SetUpRestaurant()public{
        SetUpStaff();
        SetUpCategory();
        SetUpDish();
        SetUpDiscount();
        SetUpTable();
    }
    function SetUpTable()public {
        vm.startPrank(admin);
        MANAGEMENT.CreateArea(1,"Khu A");
        // bytes memory bytesCodeCall = abi.encodeCall(
        // MANAGEMENT.CreateArea,
        //     (
        //         1,"Khu A"          
        //     )
        // );
        // console.log("MANAGEMENT CreateArea:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  

        MANAGEMENT.CreateTable(2,6,true,"2",1);
        // bytesCodeCall = abi.encodeCall(
        // MANAGEMENT.CreateTable,
        //     (
        //         2,6,true,"2",1            
        //     )
        // );
        // console.log("MANAGEMENT CreateTable:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  
    }
    function SetAttendance()public {
        SetTimeKeeping();
    }
    function SetTimeKeeping()public {
        vm.startPrank(Deployer);
        WorkPlace[] memory _workPlaces = new WorkPlace[](1);
        _workPlaces[0] = WorkPlace({
            WorkPlaceId: 0,
            LocationName: "ibe",
            LocationAddress:"location",
            LatLon: "10.791129697817134|106.69827066494396"
        });
        uint[] memory ids = TIMEKEEPING.createSettingAddress(_workPlaces);
        assertEq(ids[0],1,"workplace id should start from 1");
        workPlaces.push(_workPlaces[0]);
        workPlaceIds.push(ids[0]);
        vm.stopPrank();
        // bytes memory bytesCodeCall = abi.encodeCall(
        // TIMEKEEPING.createSettingAddress,
        //     (_workPlaces
        //     )
        // );
        // console.log("MANAGEMENT createSettingAddress:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  

    }
    function SetUpStaff()public{
        vm.warp(1759724234);//11h17 -7/10/2025
        vm.startPrank(Deployer);
        bytes32 role = MANAGEMENT.DEFAULT_ADMIN_ROLE();
        MANAGEMENT.grantRole(role,admin);
        vm.startPrank(admin);
        MANAGEMENT.grantRole(ROLE_ADMIN,admin);
        //CreatePosition
        STAFF_ROLE[] memory staff1Roles = new STAFF_ROLE[](2);
        staff1Roles[0] = STAFF_ROLE.UPDATE_STATUS_DISH;
        staff1Roles[1] = STAFF_ROLE.FINANCE;

        MANAGEMENT.CreatePosition("phuc vu ban",staff1Roles);
        // bytes memory bytesCodeCall = abi.encodeCall(
        // MANAGEMENT.CreatePosition,
        //     (
        //        "phuc vu ban",staff1Roles            
        //     )
        // );
        // console.log("MANAGEMENT CreatePosition:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  
        //CreateWorkingShift
        MANAGEMENT.CreateWorkingShift("ca sang",28800,43200); ////số giây tính từ 0h ngày hôm đó. vd 08:00 là 8*3600=28800
        MANAGEMENT.CreateWorkingShift("ca chieu",46800,61200); //tu 13:00 den 17:00
        // bytesCodeCall = abi.encodeCall(
        // MANAGEMENT.CreateWorkingShift,
        //     (
        //         "ca sang",28800,43200            
        //     )
        // );
        // console.log("MANAGEMENT CreateWorkingShift:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  

        WorkingShift[] memory shifts = MANAGEMENT.getWorkingShifts();
        assertEq(shifts[0].title,"ca sang","working shift title should equal");
        // MANAGEMENT.UpdateWorkingShift("full time",28800,61200,0);

        //
        WorkingShift[] memory staff1Shifts = new WorkingShift[](2);
        staff1Shifts[0] = shifts[0];
        staff1Shifts[1] = shifts[1];

        Staff memory staff = Staff({
            wallet: staff1,
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
        MANAGEMENT.CreateStaff(staff);
        // bytesCodeCall = abi.encodeCall(
        // MANAGEMENT.CreateStaff,
        //     (
        //         staff            
        //     )
        // );
        // console.log("MANAGEMENT CreateStaff:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  

        staff = Staff({
            wallet: staff2,
            name:"han",
            code:"NV2",
            phone:"0914526387",
            addr:"quan 7",
            position: "phuc vu ban",
            role:ROLE.STAFF,
            active: true,
            linkImgSelfie: "linkImgSelfie",
            linkImgPortrait:"linkImgPortrait",
            shifts:staff1Shifts,
            roles: staff1Roles
        });
        MANAGEMENT.CreateStaff(staff);

        (Staff[] memory staffs,uint totalCount) = MANAGEMENT.GetStaffsPagination(0,100);

        assertEq(staffs.length,2,"should be equal");
        Staff memory staffInfo = MANAGEMENT.GetStaffInfo(staff1);
        assertEq(staffInfo.name,"thuy","should be equal");
        assertEq(staffInfo.phone,"0913088965","should be equal");
        MANAGEMENT.grantRole(ROLE_STAFF,staff1);
        MANAGEMENT.UpdateStaffInfo(staff1,"thanh thuy","NV1","1111111111","phu nhuan",staff1Roles,staff1Shifts,"linkImgSelfie","linkImgPortrait","phuc vu ban",true);
        staffInfo = MANAGEMENT.GetStaffInfo(staff1);
        assertEq(staffInfo.name,"thanh thuy","should be equal");
        assertEq(staffInfo.phone,"1111111111","should be equal");
        bool kq = MANAGEMENT.isStaff(staff1);
        assertEq(kq,true,"should be equal"); 
        (staffs,totalCount) = MANAGEMENT.GetStaffsPagination(0,100);
        assertEq(staffs[0].name,"han","should be equal");
        assertEq(staffs[0].phone,"0914526387","should be equal");

        MANAGEMENT.grantRole(ROLE_ADMIN,staff2);
        
        vm.stopPrank();
        vm.prank(staff2);
        staff = Staff({
            wallet: staff3,
            name:"han",
            code:"NV3",
            phone:"11111111",
            addr:"quan 7",
            position: "phuc vu ban",
            role:ROLE.STAFF,
            active: true,
            linkImgSelfie: "linkImgSelfie",
            linkImgPortrait:"linkImgPortrait",
            shifts:staff1Shifts,
            roles: staff1Roles
        });
        MANAGEMENT.CreateStaff(staff);
        MANAGEMENT.GetStaffsPagination(0,10);
        vm.prank(staff2);
        MANAGEMENT.removeStaff(staff3);
        
    }
    function SetUpCategory()public {
        vm.startPrank(admin);
        Category memory category1 = Category({
            code:"THITBO",
            name:"thit bo",
            rank:1,
            desc:"Cac mon voi thit bo",
            active:true,
            imgUrl:"_imgURL1",
            icon:"icon"
        });
        MANAGEMENT.CreateCategory(category1);

        Category memory category2 = Category({
            code:"THITGA",
            name:"thit ga",
            rank:2,
            desc:"Cac mon voi thit ga",
            active:true,
            imgUrl:"_imgURL2",
            icon:"icon"
        });
        MANAGEMENT.CreateCategory(category2);
        Category[] memory categories = MANAGEMENT.GetCategories();
        assertEq(categories.length,2,"should be equal");
        Category memory cat2 = MANAGEMENT.GetCategory("THITGA");
        assertEq(cat2.name,"thit ga","should be equal");
        assertEq(cat2.imgUrl,"_imgURL2","should be equal");
        MANAGEMENT.UpdateCategory("THITGA","thit ga ta",1,"Cac mon voi thit ga",true,"_imgURL3","icon");
        cat2 = MANAGEMENT.GetCategory("THITGA");
        assertEq(cat2.name,"thit ga ta","should be equal");
        assertEq(cat2.imgUrl,"_imgURL3","should be equal");
        Category[] memory categoriesUpdate = MANAGEMENT.GetCategories();
        assertEq(categoriesUpdate[1].name,"thit ga ta","should be equal");
        assertEq(categoriesUpdate[1].imgUrl,"_imgURL3","should be equal");
        MANAGEMENT.GetCategoriesPagination(0,10);

        vm.stopPrank();
    }
    function SetUpDish()public {
        vm.startPrank(admin);
                //create Dish Option for Dish1
        string[] memory featureNames1 = new string[](3);
        featureNames1[0] = "Khong";
        featureNames1[1] = "Vua";
        featureNames1[2] = "Nhieu";
        uint256[] memory _featurePrices = new uint256[](3);
        _featurePrices[0] = 0;
        _featurePrices[1] = 0;
        _featurePrices[2] = 0;
        optionId1 = MANAGEMENT.CreateDishOptions(
            "Do Cay",
            featureNames1,
            _featurePrices,
            false,
            3
        );
        optionId2 = MANAGEMENT.CreateDishOptions(
            "Do Beo",
            featureNames1,
            _featurePrices,
            false,
            3
        );
        optionId3 = MANAGEMENT.CreateDishOptions(
            "Do Ngot",
            featureNames1,
            _featurePrices,
            false,
            3
        );
        (DishOption[] memory allDishOptions) = MANAGEMENT.GetAllDishOptions();
        //
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
        Dish memory dish2 = Dish({
            code:"dish2_code",
            nameCategory:"Thit bo",
            name:"Bo nuong tang",
            des:"Thit bo nuong tang an kem phomai",
            available:true,
            active:true,
            imgUrl:"img_bo2",
            averageStar: 0,
            cookingTime: 30,
            ingredients:ingredients,
            showIngredient: true,
            videoLink: "videoLink",
            totalReview:0,
            orderNum:0,
            createdAt:0
        });
        Dish memory dish3 = Dish({
            code:"dish3_code",
            nameCategory:"Thit ga",
            name:"Ga luoc",
            des:"Thit ga luoc an kem com chien",
            available:true,
            active:true,
            imgUrl:"img_ga1",
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

        bytes32[] memory optionIds = new bytes32[](3);
        optionIds[0] = optionId1;
        optionIds[1] = optionId2;
        optionIds[2] = optionId3;

        MANAGEMENT.CreateDish("THITBO",dish1,variants,optionIds);
        MANAGEMENT.CreateDish("THITBO",dish2,variants,optionIds);
        MANAGEMENT.CreateDish("THITGA",dish3,variants,optionIds);
        Dish[] memory dishes = MANAGEMENT.GetDishes("THITBO");
        assertEq(dishes.length,2,"should be equal");
        Dish memory dish = MANAGEMENT.GetDish("dish2_code");
        assertEq(dish.name,"Bo nuong tang","should be equal");
        bytes32 variantID = hashAttributes(variants[0].attrs);
        Variant memory orderVariant = MANAGEMENT.getVariant("dish1_code", variantID);
        uint dishPrice = orderVariant.dishPrice;
        assertEq(dishPrice,1000 ,"should be equal");
        variants[0].price = 1500;
        string[] memory  _ingredients = new string[](0);
        MANAGEMENT.UpdateDish(
            "THITBO",
            "dish2_code",
            "Thit bo",
            "Bo xong khoi",
            "Thit bo xong khoi an kem salad",
            true,
            true,
            "img_bo2",
            30,
            true,
            "",
            variants,
            _ingredients
        );
        dish = MANAGEMENT.GetDish("dish2_code");
        orderVariant = MANAGEMENT.getVariant("dish2_code", variantID);
        dishPrice = orderVariant.dishPrice;
        assertEq(dish.name,"Bo xong khoi","should be equal");
        assertEq(dishPrice,1500,"should be equal");
        assertEq(dish.available,true,"should be equal");
        Dish[] memory dishesUpdate = MANAGEMENT.GetDishes("THITBO");
        assertEq(dishesUpdate[1].name,"Bo xong khoi","should be equal");
        assertEq(dishesUpdate[1].available,true,"should be equal");

        vm.stopPrank();
        vm.startPrank(staff1);
        MANAGEMENT.UpdateDishStatus("THITBO","dish2_code",false);
        dish = MANAGEMENT.GetDish("dish2_code");
        assertEq(dish.available,false,"should be equal");
        vm.stopPrank();
        MANAGEMENT.GetTopDishesWithLimit(0,10);

        vm.startPrank(admin);

        //check option
        DishOption[] memory optionsDish1 = MANAGEMENT.GetAllDishOptionsFromDishCode("dish1_code");
        //lay futureIds de order
        (DishOption[] memory dishOptions, uint totalCount) = MANAGEMENT.GetAllDishOptionsFromDishCodePagination("dish1_code",0,10);
        assertEq(totalCount,3,"dish options number should be equal");
        OptionFeature[] memory optionFeaturesDish1 = dishOptions[0].features; //dishOptions[0] la Do Ngot
        // ✅ Lấy đúng features từ option "Do Cay"
        DishOption memory doCayOption;
        DishOption memory doBeoOption;  
        DishOption memory doNgotOption;

        for(uint i = 0; i < dishOptions.length; i++) {
            if(dishOptions[i].optionId == optionId1) { // Do Cay
                doCayOption = dishOptions[i];
            } else if(dishOptions[i].optionId == optionId2) { // Do Beo
                doBeoOption = dishOptions[i];
            } else if(dishOptions[i].optionId == optionId3) { // Do Ngot
                doNgotOption = dishOptions[i];
            }
        }

        // ✅ Push đúng features
        selectedFeatureIdsDish1.push(doCayOption.features[0].featureId);
        selectedFeatureIdsDish1.push(doCayOption.features[1].featureId);
        selectedFeatureIdsDish1.push(doCayOption.features[2].featureId);

        (DishOption[] memory dishOptions2,) = MANAGEMENT.GetAllDishOptionsFromDishCodePagination("dish2_code",0,10);      
        DishOption memory doBeoOption2;
        for(uint i = 0; i < dishOptions2.length; i++) {
            if(dishOptions2[i].optionId == optionId2) {
                doBeoOption2 = dishOptions2[i];
                break;
            }
        }

        selectedFeatureIdsDish2.push(doBeoOption2.features[0].featureId);
        selectedFeatureIdsDish2.push(doBeoOption2.features[1].featureId);
        selectedFeatureIdsDish2.push(doBeoOption2.features[2].featureId);

        (DishOption[] memory dishOptions3,) = MANAGEMENT.GetAllDishOptionsFromDishCodePagination("dish3_code",0,10);   
        DishOption memory doNgotOption3;
        for(uint i = 0; i < dishOptions3.length; i++) {
            if(dishOptions3[i].optionId == optionId3) {
                doNgotOption3 = dishOptions3[i];
                break;
            }
        }

        selectedFeatureIdsDish3.push(doNgotOption3.features[0].featureId);
        selectedFeatureIdsDish3.push(doNgotOption3.features[1].featureId);
        selectedFeatureIdsDish3.push(doNgotOption3.features[2].featureId);
        vm.stopPrank();
    }
    function SetUpDiscount()public{
        vm.startPrank(admin);
         
        bytes32 memberGroupId = POINTS.createMemberGroup("khach hang than thiet");
        // (string memory namePoint,,,,,) = POINTS.getPointsInfo();
        POINTS.updateMemberGroup(memberGroupId,"nhom2",true);
        MemberGroup[] memory memberGroups = POINTS.getAllGroups();
        assertEq(memberGroups[0].name,"nhom2","should be equal");
        bytes32[] memory _targetGroupIds = new bytes32[](1);
        _targetGroupIds[0] = memberGroupId;
        MANAGEMENT.CreateDiscount(
            "KM20",
            "Chuong trinh kmai mua thu",
            15,
            "Kmai giam 15% tren tong chi phi",
            currentTime,
            currentTime + 360 days,
            true,
            "_imgIRL",
            100,
            DiscountType.AUTO_ALL,
            _targetGroupIds,
            200,
            true,
            "textDes"
        );
        Discount memory discount = MANAGEMENT.GetDiscount("KM20");
        assertEq(discount.amountMax,100,"should be equal");
        MANAGEMENT.UpdateDiscount(
            "KM20",
            "Chuong trinh kmai mua dong",
            20,
            "Kmai giam 20% tren tong chi phi",
            currentTime,
            currentTime + 360 days,
            true,
            "_imgIRL",
            200,
             DiscountType.AUTO_ALL,
            _targetGroupIds,
            200,
            true,
            "textDes"
        ); 
        discount = MANAGEMENT.GetDiscount("KM20");
        assertEq(discount.amountMax,200,"should be equal");
        Discount[] memory discounts = MANAGEMENT.GetAllDiscounts();
        assertEq(discounts.length,1,"should be equal");
        assertEq(discounts[0].amountMax,200,"should be equal");
        assertEq(discounts[0].discountPercent,20,"should be equal");
        //
        MANAGEMENT.CreateDiscount(
            "KM30",
            "Chuong trinh tri an khach hang ",
            15,
            "Kmai giam 30% tren tong chi phi",
            currentTime,
            currentTime + 360 days,
            true,
            "_imgIRL",
            100,
            DiscountType.AUTO_ALL,
            _targetGroupIds,
            0,
            false,
            "textDes"
        );
        vm.stopPrank();
        // GetByteCode();
    }
    function testAttendance()public{
        vm.warp(1759724234);//4h17 -6/10/2025
        vm.startBroadcast(staff1);
        SettingAddress memory settingAddress = TIMEKEEPING.getSettingAddress();
        WorkPlace[] memory workplaces = settingAddress.WorkPlaces;
        WorkPlaceAttendance memory workPlace = WorkPlaceAttendance({
            WorkPlaceId:workplaces[0].WorkPlaceId,
            LatLon:workplaces[0].LatLon
        });
        TIMEKEEPING.checkIn(staff1,workPlace);
        TIMEKEEPING.checkOut(staff1,workPlace);
        vm.stopBroadcast();
        // bytes memory bytesCodeCall = abi.encodeCall(
        // TIMEKEEPING.checkIn,
        //     (
        //         staff1,
        //         workPlace
        //     )
        // );
        // console.log("MANAGEMENT checkIn:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  
        vm.prank(staff2);
        TIMEKEEPING.ReportCheckin(staff2,workPlace);
        AttendanceRecord[] memory records = TIMEKEEPING.getStaffDailyReport(staff1,20251006);
        assertEq(records.length,1,"should be equal");
        records = TIMEKEEPING.getStaffDailyReport(staff2,20251006);
        assertEq(records.length,0,"should be equal");
        records = TIMEKEEPING.getStaffDailyReport(customer1,20251006);
        assertEq(records.length,0,"should be equal");
        //hr set absent day
        address[] memory _staffs = new address[](1);
        _staffs[0] = staff1;
        uint256[] memory _dates = new uint256[](1);
        _dates[0] = 20251005;
        AttendanceStatus[] memory _statuses = new AttendanceStatus[](1);
        _statuses[0] = AttendanceStatus.ABSENT;
        ABSENT_TYPE[] memory _absentTypes = new ABSENT_TYPE[](1);
        _absentTypes[0] = ABSENT_TYPE.UNAUTHORIZED;
        string memory _notes = "";
        address approver = Deployer;
        vm.prank(Deployer);
        TIMEKEEPING.setBulkAttendanceData(_staffs,_dates,_statuses,_absentTypes,_notes,approver);
                //hr set absent day
        _staffs[0] = staff1;
        _dates[0] = 20251005;
        _statuses[0] = AttendanceStatus.ABSENT;
        _absentTypes[0] = ABSENT_TYPE.VACATION;
        vm.prank(Deployer);
        TIMEKEEPING.setBulkAttendanceData(_staffs,_dates,_statuses,_absentTypes,_notes,approver);

            vm.warp(1759831318);//4h17 -7/10/2025
        StaffMonthlyReport memory report = TIMEKEEPING.getStaffMonthlyReportRealtime(staff1,202510);
        // console.log("report.workingDayArr.length:",report.workingDayArr.length);
        // console.log("report.absentVacationDayArr.length:",report.absentVacationDayArr.length);
        // console.log("report.lateDayArr.length:",report.lateDayArr.length);
        // console.log("report.absentUnauthorizedDayArr.length:",report.lateDayArr.length);

    }

    function testMakeOrder()public{
        vm.warp(1759724234);//11h17 -7/10/2025
        //order lan 1 table1
        (bytes32 sessionIdT1, ) = ORDER.CreateSessionForTable(2, 3, bytes32(0));
 
        uint table =1;
        string[] memory dishCodes = new string[](3);
        dishCodes[0] = "dish1_code";
        dishCodes[1] = "dish3_code";
        dishCodes[2] = "dish1_code";      
        uint8[] memory quantities = new uint8[](3);
        quantities[0] = 2;
        quantities[1] = 5;
        quantities[2] = 2;
        string[] memory notes = new string[](3);
        notes[0] = "";
        notes[1] = "";
        notes[2] = "medium";
        //
        // (Order[] memory ordersArr, uint totalCount4) = ORDER.GetOrdersAcknowlegdePaginationByStatus(staff1,0,5,ORDER_STATUS.CONFIRMED);
        DishInfo memory dishInfo = MANAGEMENT.getDishInfo("dish1_code");       
        bytes32[] memory variantIDs = new bytes32[](3);
        variantIDs[0] = dishInfo.variants[0].variantID;
        variantIDs[1] = dishInfo.variants[1].variantID;
        variantIDs[2] = dishInfo.variants[2].variantID;
        SelectedOption[] memory selectionOption0 = new SelectedOption[](1);
        SelectedOption[] memory selectionOption1 = new SelectedOption[](1);
        SelectedOption[] memory selectionOption2 = new SelectedOption[](1);
        selectionOption0[0] = SelectedOption({ //option cua dish1: do cay
            optionId: optionId1,
            selectedFeatureIds: selectedFeatureIdsDish1 //dish1 chon ca 3 feature khong cay, cay it, cay nhieuf
        });
        selectionOption1[0] = SelectedOption({
            optionId: optionId3,
            selectedFeatureIds: selectedFeatureIdsDish3
        });
        selectionOption2[0] = SelectedOption({
            optionId: optionId1,
            selectedFeatureIds: selectedFeatureIdsDish1
        });

        SelectedOption[][] memory dishSelectedOptions = new SelectedOption[][](3);
        dishSelectedOptions[0] = selectionOption0; //dish1
        dishSelectedOptions[1] = selectionOption1; //dish3
        dishSelectedOptions[2] = selectionOption2; //dish1
        MakeOrderParams memory params = MakeOrderParams({
            table: table,
            sessionId: sessionIdT1,
            dishCodes: dishCodes,
            quantities: quantities,
            notes: notes,
            variantIDs: variantIDs,
            dishSelectedOptions: dishSelectedOptions,
            paymentType: PaymentType.POSTPAID
        });
        bytes32 orderId1T1 = ORDER.makeOrder(
          params
        );

        //order lan 2 table1
        string[] memory dishCodes1 = new string[](1);
        dishCodes1[0] = "dish3_code";
        uint8[] memory quantities1 = new uint8[](1);
        quantities1[0] = 10;
        string[] memory notes1 = new string[](1);
        notes1[0] = "";
        bytes32[] memory variantIDs1 = new bytes32[](1);
        variantIDs1[0] = dishInfo.variants[0].variantID;
        SelectedOption[] memory selectionOption3 = new SelectedOption[](1);
        selectionOption3[0] = SelectedOption({
            optionId: optionId3,
            selectedFeatureIds: selectedFeatureIdsDish3
        });
        SelectedOption[][] memory dishSelectedOptions3 = new SelectedOption[][](1);
        dishSelectedOptions3[0] = selectionOption3;
         MakeOrderParams memory params2 = MakeOrderParams({
            table: table,
            sessionId: sessionIdT1,
            dishCodes: dishCodes1,           // Chú ý dùng đúng biến dishCodes1
            quantities: quantities1,       // Chú ý dùng đúng biến quantities1
            notes: notes1,                 // Chú ý dùng đúng biến notes1
            variantIDs: variantIDs1,       // Chú ý dùng đúng biến variantIDs1
            dishSelectedOptions: dishSelectedOptions3, // Chú ý dùng đúng biến options3
            paymentType: PaymentType.POSTPAID
        });

        bytes32 orderId2T1 = ORDER.makeOrder(params2);
        //order lan 1 table2
        table = 2;
        string[] memory dishCodes2 = new string[](1);
        dishCodes2[0] = "dish3_code";
        uint8[] memory quantities2 = new uint8[](1);
        quantities2[0] = 10;
        string[] memory notes2 = new string[](1);
        notes2[0] = "";
        bytes32[] memory variantIDs2 = new bytes32[](1);
        variantIDs2[0] = dishInfo.variants[0].variantID;
        
          MakeOrderParams memory params1T2 = MakeOrderParams({
            table: table,
            sessionId: 0x0000000000000000000000000000000000000000000000000000000000000003,
            dishCodes: dishCodes2,           // Sử dụng bộ dishCodes2
            quantities: quantities2,         // Sử dụng bộ quantities2
            notes: notes2,                   // Sử dụng bộ notes2
            variantIDs: variantIDs2,         // Sử dụng bộ variantIDs2
            dishSelectedOptions: dishSelectedOptions3,
            paymentType: PaymentType.POSTPAID
        });

        bytes32 orderId1T2 = ORDER.makeOrder(params1T2);

        //order lan 1 table3
        table = 3;
        string[] memory dishCodes3 = new string[](1);
        dishCodes3[0] = "dish1_code";
        uint8[] memory quantities3 = new uint8[](1);
        quantities3[0] = 4;
        string[] memory notes3 = new string[](1);
        notes3[0] = "";
        bytes32[] memory variantIDs3 = new bytes32[](1);
        variantIDs3[0] = dishInfo.variants[0].variantID;
        SelectedOption[] memory selectionOption4 = new SelectedOption[](1);
        selectionOption4[0] = SelectedOption({
            optionId: optionId1, 
            selectedFeatureIds: selectedFeatureIdsDish1
        });

        SelectedOption[][] memory dishSelectedOptions4 = new SelectedOption[][](1);
        dishSelectedOptions4[0] = selectionOption4;

        MakeOrderParams memory params1T3 = MakeOrderParams({
            table: table,
            sessionId: 0x0000000000000000000000000000000000000000000000000000000000000004,
            dishCodes: dishCodes3,           // Sử dụng bộ dishCodes3
            quantities: quantities3,         // Sử dụng bộ quantities3
            notes: notes2,                   // Sử dụng bộ notes2 (như trong code cũ của bạn)
            variantIDs: variantIDs2,         // Sử dụng bộ variantIDs2 (như trong code cũ của bạn)
            dishSelectedOptions: dishSelectedOptions4, // Sử dụng bộ options4
            paymentType: PaymentType.POSTPAID
        });

        // Gọi hàm makeOrder với struct vừa tạo
        bytes32 orderId1T3 = ORDER.makeOrder(params1T3);
        //get orders by table
        Order[] memory orders1 = ORDER.GetOrders(sessionIdT1);
        assertEq(orders1.length,2,"should be equal");
        Order[] memory orders2 = ORDER.GetOrders(0x0000000000000000000000000000000000000000000000000000000000000002);
        assertEq(orders2.length,0,"should be equal");
        Order[] memory orders3 = ORDER.GetOrders(0x0000000000000000000000000000000000000000000000000000000000000003);
        assertEq(orders3.length,1,"should be equal");
        Order[] memory allOrders = ORDER.GetAllOrders();
        assertEq(allOrders.length,4,"should be equal");

        //get courses
        // SimpleCourse memory course = ORDER.getTableCourse(1,0);
        SimpleCourse memory course = ORDER.getSessionCourse(sessionIdT1,0);
        assertEq(course.quantity, 2);
        SimpleCourse[] memory coursesByOrder1 = ORDER.GetCoursesByOrderId(orderId1T1);
        assertEq(coursesByOrder1.length,3,"should be equal");
        SimpleCourse[] memory coursesByOrder3 = ORDER.GetCoursesByOrderId(orderId1T2);
        assertEq(coursesByOrder3.length,1,"should be equal");
        SimpleCourse[] memory coursesByTable1 = ORDER.GetCoursesBySession(sessionIdT1);
        assertEq(coursesByTable1.length,4,"should be equal");
        Payment memory payment = ORDER.getPaymentByOrder(orderId1T1);
        assertEq(payment.foodCharge,28000 );
        uint taxPercent = ORDER.getTaxPercent();
        assertEq(payment.tax,28000  * taxPercent/100);

        //update order table 1 order 1 more quantity
        uint[] memory updateCourseIds = new uint[](1);
        updateCourseIds[0] = coursesByTable1[0].id;
        uint[] memory updateQuantities = new uint[](1);
        updateQuantities[0]  = 3;
        // ORDER.UpdateOrder(1,orderId1T1,updateCourseIds,updateQuantities);
        ORDER.UpdateOrder(sessionIdT1,orderId1T1,updateCourseIds,updateQuantities);
        // bytesCodeCall = abi.encodeCall(
        //     ORDER.UpdateOrder,
        //     (
        //         1,orderId1T1,updateCourseIds,updateQuantities
        //     )
        // );
        // console.log("UpdateOrder table 1 order 1:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  

        // course = ORDER.getTableCourse(1,0);
         course = ORDER.getSessionCourse(sessionIdT1,0);
        assertEq(course.quantity, 3);
        coursesByOrder1 = ORDER.GetCoursesByOrderId(orderId1T1);
        assertEq(coursesByOrder1[0].quantity,3);
        // coursesByTable1 = ORDER.GetCoursesByTable(1);
        coursesByTable1 = ORDER.GetCoursesBySession(sessionIdT1);
        assertEq(coursesByTable1[0].quantity,3);
        // payment = ORDER.getTablePayment(1);
        payment = ORDER.getPaymentByOrder(orderId1T1);
        assertEq(payment.foodCharge,29000 );
        assertEq(payment.tax,29000  * taxPercent/100);

        //update order table 1 order 1 less quantity
        coursesByTable1 = ORDER.GetCoursesBySession(sessionIdT1);
        updateCourseIds[0] = coursesByTable1[3].id; //4
        updateQuantities[0]  = 5;
        ORDER.UpdateOrder(sessionIdT1,orderId2T1,updateCourseIds,updateQuantities);
        // payment = ORDER.getTablePayment(1);
        payment = ORDER.getPaymentByOrder(orderId1T1);
        assertEq(payment.foodCharge,24000); //=(29000- 5*1500)
        assertEq(payment.tax,2400); //=3250*8/100

        // //pay by usdt table 1
        // vm.startPrank(customer);
        // USDT_ERC.approve(address(ORDER),1_000_000*ONE_USDT);
        // uint tip = 5 *ONE_USDT;
        // bytes32 idPayment = ORDER.PayUSDT(customer,"KM20",tip);
        // uint paymentAmount1 = foodCharge*80/100 +tax+ tip;
        // assertEq(USDT_ERC.balanceOf(address(MONEY_POOL)),paymentAmount1);
        // vm.stopPrank();
        // bytesCodeCall = abi.encodeCall(
        //     ORDER.PayUSDT,
        //     (
        //         customer,"KM20",tip
        //     )
        // );
        // console.log("PayUSDT table 1:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  

        //pay by visa table 2
        vm.startPrank(customer1);
        // bytes32 idCalldata = ORDER.SetCallData(customer,"KM20",tip);
        // uint256 paymentAmount2 = (7*50*(80/100 + 8/100) + 5)*ONE_USDT;
        // bytes memory getCallData = ORDER.GetCallData(idCalldata);
        string memory discountCode = "";
        uint tip = 0;
        uint256 paymentAmount = 70400;
        string memory txID = "";
        // ORDER.executeOrder(1,discountCode,tip,paymentAmount,txID,false);
        Payment memory paymentRecord = ORDER.getPaymentByOrder(orderId1T1);
        ORDER.executeOrder(sessionIdT1,paymentRecord.id,discountCode,tip,paymentAmount,txID,false);
        
        // ORDER.UpdateForReport(1);
        MANAGEMENT.UpdateTotalRevenueReport(currentTime,payment.foodCharge-payment.discountAmount);
        MANAGEMENT.SortDishesWithOrderRange(0,10);
        MANAGEMENT.UpdateRankDishes();
        REPORT.UpdateDishStats("dish1_code",payment.foodCharge-payment.discountAmount,1);
        vm.stopPrank();
        MANAGEMENT.SortDishesWithOrderRange(0,10);
        (DishWithFirstPrice[] memory dishes1, uint totalCount) =MANAGEMENT.GetTopDishesWithLimit(0,10);
        // ORDER.executeOrder(2,discountCode,tip,paymentAmount,txID);
        // ORDER.UpdateForReport(2);
        // MANAGEMENT.SortDishesWithOrderRange(0,10);
        // ( DishWithFirstPrice[] memory dishes2, ) =MANAGEMENT.GetTopDishesWithLimit(0,10);
        // console.log("dishesWithOrder.length:",dishes2.length);
        // console.log(dishes2[0].dish.code);
        // console.log(dishes2[1].dish.code);
        // console.log(dishes2[2].dish.code);

        //staff comfirm payment 1,2
        vm.startPrank(staff1);
        // ORDER.BatchUpdateCourseStatus(1,orderId1T1,COURSE_STATUS.PREPARING);
        // ORDER.ConfirmOrder(orderId1T1,ORDER_STATUS.CONFIRMED);
         ORDER.BatchUpdateCourseStatus(sessionIdT1,orderId1T1,COURSE_STATUS.PREPARING);
        ORDER.ConfirmOrder(orderId1T1,ORDER_STATUS.KITCHEN_CONFIRMED);
        (Order[] memory orders, uint totalCount3) = ORDER.GetOrdersAcknowlegdePaginationByStatus(staff1,0,5,ORDER_STATUS.KITCHEN_CONFIRMED);
        console.log("totalCount3:",totalCount3);
        paymentId1 = payment.id;
        amountPayment1 = payment.foodCharge - payment.discountAmount + payment.tax;
        console.log("amountPayment1:",amountPayment1);
        ORDER.confirmPayment(1,payment.id,"paid");
        // Payment memory payment = ORDER.GetPaymentById(idPayment);
        // assertEq(payment.staffComfirm,staff1);
        // assertEq(payment.reasonComfirm,"paid");
        // assertEq(payment.total,paymentAmount1,"total payment1 should be equal");
        // vm.stopPrank();
        // vm.startPrank(staff2);
        // bytes32 idPayment2 = ORDER.GetLastIdPaymentByAdd(customer);
        // ORDER.ComfirmPayment(customer,idPayment2,"paid");
        // payment = ORDER.GetPaymentById(idPayment2);
        // assertEq(payment.staffComfirm,staff2);
        // assertEq(payment.reasonComfirm,"paid");
        // assertEq(payment.total,paymentAmount2,"total payment2 should be equal");

        // //staff update course status
        // address _numAdd = customer;
        // bytes32 _orderId = orderId1T3;
        // uint _courseId = 1;   
        // ORDER.UpdateCourseStatus(_numAdd,_orderId,_courseId,COURSE_STATUS.PREPARING);
        // Course[] memory coursesByOrder4 = ORDER.GetCoursesByOrderId(orderId1T3);
        // assertEq(uint(coursesByOrder4[0].status),uint(COURSE_STATUS.PREPARING),"should equal");
        // coursesByOrder4 = ORDER.GetCoursesByAdd(customer);
        // assertEq(uint(coursesByOrder4[0].status),uint(COURSE_STATUS.PREPARING),"should equal");
        // Course memory courseByOrder4 = ORDER.GetCourseByAddAndIdCourse(customer,1);
        // assertEq(uint(courseByOrder4.status),uint(COURSE_STATUS.PREPARING),"should equal");
        vm.stopPrank();

        // //get history payments
        // Payment[] memory payments = ORDER.GetPaymentHistory();
        // assertEq(payments.length,2,"should equal");
        // assertEq(payments[0].total,paymentAmount1,"total payment1 should be equal");
        // assertEq(payments[1].total,paymentAmount2,"total payment2 should be equal");
        // Course[] memory courseArr = ORDER.GetCoursesByPaymentId(payments[0].id);
        // assertEq(courseArr.length,4,"should be equal");
        // courseArr = ORDER.GetCoursesByPaymentId(payments[1].id);
        // assertEq(courseArr.length,1,"should be equal");

        // //customer review 
        // vm.startPrank(customer);
        // bytes32 _idPayment = payments[0].id;
        // uint8 _serviceQuality = 4;
        // uint8 _foodQuality = 5;
        // string memory _contribution = "improve attitude";
        // string memory _needAprove = "improve decoration";
        // ORDER.MakeReview(_idPayment,_serviceQuality,_foodQuality,_contribution,_needAprove);
        // vm.stopPrank();
        // GetByteCode();
        DishReport memory dishReport = REPORT.GetDishReport("dish1_code");
        (NewDish[] memory newDishes, uint totalCount1) = MANAGEMENT.GetNewDishesWithLimit(0,10);
        customerGetPoints(payment.foodCharge - payment.discountAmount,payment.id);
    }
    function customerGetPoints(uint256 _amount,bytes32 _invoiceId)public{
        adminCreateEvent();
        string memory memberID = "12345647589";
        RegisterInPut memory input = RegisterInPut({
            _memberId: memberID,
            _phoneNumber: "0962345872",
            _firstName: "Hoan",
            _lastName: "Le",
            _whatsapp: "0962345872",
            _email: "hoan@gmail.com",
            _avatar: "avatar"

        });
        vm.prank(customer1);
        POINTS.registerMember(input);
        POINTS.earnTokenA(customer1, _amount,_invoiceId, _invoiceId, EconomyTypes.EVENT_FOOD_PAID,1,false);
    }
    function adminCreateEvent()public{
        vm.startPrank(admin);
        uint startTime = currentTime;
        uint endTime = startTime + 180 days;
        bytes32[] memory allowedTiers = new bytes32[](0);
        eventId11 = POINTS.createCampaign(
            "Tang new member",
            EconomyTypes.EVENT_FOOD_PAID, // eventType
            0,                            // minAmount
            10,                           // rewardAmount (10%)
            true,                         // isPercent
            0,                            // branchScope (all)
            0,                            // exclusiveGroup
            1,                            // priority
            true,                         // stackable
            0,                            // expiresAt (no expiry)
            bytes32(0),                   // minTierID
            allowedTiers,
            100
        );
        eventIdArr11.push(eventId11);
        vm.stopPrank();
    }

    function hashAttributes(
        Attribute[] memory attrs
    ) internal pure returns (bytes32) {
        bytes memory attributesHash;

        for (uint256 i = 0; i < attrs.length; i++) {
            attributesHash = abi.encodePacked(
                attributesHash,
                attrs[i].key,
                attrs[i].value
            );
        }

        return keccak256(attributesHash);
    }

    function GetByteCode()public {
    //
    bytes memory bytesCodeCall = abi.encodeCall(
    MANAGEMENT.GetStaffRolePayment,
        (
        )
    );
    console.log("MANAGEMENT GetStaffRolePayment:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  
     //ORDER.executeOrder(1,discountCode,tip,paymentAmount,txID,false);
    //  bytesCodeCall = abi.encodeCall(
    // ORDER.executeOrder,
    //     (
    //         0x0000000000000000000000000000000000000000000000000000000000000001, 0x0000000000000000000000000000000000000000000000000000000000000001,"",0,111111111111,"",false
    //     )
    // );
    // console.log("ORDER executeOrder:");
    // console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  
    //ORDER.GetOrdersAcknowlegdePaginationByStatus(staff1,0,5,ORDER_STATUS.CONFIRMED)
    bytesCodeCall = abi.encodeCall(
    ORDER.GetOrdersAcknowlegdePaginationByStatus,
        (
            0x28123db3931C5c9A26c5A1A6F27f3C392ABA077D,
            0,
            5,
            ORDER_STATUS.KITCHEN_CONFIRMED
        )
    );
    console.log("Order GetOrdersAcknowlegdePaginationByStatus:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    //orderPrimaryStaff
    bytesCodeCall = abi.encodeCall(
    ORDER.orderPrimaryStaff,
        (
            0x269a0632cc153a3b51a74e22b4e2f949bc0f1dd3c0d73c4e5f15ceb70940f475
        )
    );
    console.log("Order orderPrimaryStaff:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    //
    bytesCodeCall = abi.encodeCall(
    MANAGEMENT.UpdateTable,
        (
            92,
            8,
            true,
            "Ban tap the",
            0
        )
    );
    console.log("MANAGEMENT UpdateTable:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    //makeOrder
    uint table = 1223698623;
    string[] memory dishCodes3 = new string[](1);
    dishCodes3[0] = "vxsvcs";
    uint8[] memory quantities3 = new uint8[](1);
    quantities3[0] = 2;
    string[] memory notesArr = new string[](1);
    notesArr[0] = "xin chafo";
    bytes32[] memory variantIDs3 = new bytes32[](1);
    variantIDs3[0] = 0xd6175ed4e1b24515b3acacf3b62389fd3114ab8ebc9db9104bfc4fe1dd36aeec;

    bytes32[] memory selectedFeatureIds1 = new bytes32[](2);
    selectedFeatureIds1[0]= 0xd463be0fb8507780b765dc7af98729fc4c7217d005796011620391cff3593e46;
    selectedFeatureIds1[1]= 0xca8bda6fecd646859a7775850807adef25fe4132d113be007ff9cd46d7729726;

    bytes32[] memory selectedFeatureIds3 = new bytes32[](1);
    selectedFeatureIds3[0]= 0xa5fb0685f3741ca7beb548ef4f9a92819f2e63cedc44b1650af59055db47b37b;

    SelectedOption[] memory selectionOption3 = new SelectedOption[](2);
    selectionOption3[0] = SelectedOption({
        optionId: 0xdec294c3c79b015ec3f9a050b4b4e8eb89f374b6864b1f5b77ed756487053ee8, 
        selectedFeatureIds: selectedFeatureIds3
    });
    selectionOption3[1] = SelectedOption({
        optionId: 0xb3f7cb3ea8aa1d93edbea3e45d5baf8fa13972240b24751f820db0466fbde949, 
        selectedFeatureIds: selectedFeatureIds1
    });
    SelectedOption[][] memory dishSelectedOptions3 = new SelectedOption[][](1);
    dishSelectedOptions3[0] = selectionOption3;
    // bytesCodeCall = abi.encodeCall(
    // ORDER.makeOrder,
    //     (
    //         table,
    //         dishCodes3,
    //         quantities3,
    //         notesArr,
    //         variantIDs3,
    //         dishSelectedOptions3
    //     )
    // );
     MakeOrderParams memory params = MakeOrderParams({
        table: table,
        sessionId: 0x0000000000000000000000000000000000000000000000000000000000000001,
        dishCodes: dishCodes3,
        quantities: quantities3,
        notes: notesArr,
        variantIDs: variantIDs3,
        dishSelectedOptions: dishSelectedOptions3,
        paymentType: PaymentType.POSTPAID
    });

    bytesCodeCall = abi.encodeCall(
        ORDER.makeOrder,
        (params)
    );
    console.log("ORDER makeOrder:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 

    //
    bytesCodeCall = abi.encodeCall(
    ORDER.POINTS,
        (
        )
    );
    console.log("ORDER POINTS:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 


    //MANAGEMENT.setStaffAgentStore(address(0x123));
    bytesCodeCall = abi.encodeCall(
    MANAGEMENT.setStaffAgentStore,
        (
            0x1510151015101510151015101510151015101510
        )
    );
    console.log("MANAGEMENT setStaffAgentStore:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 

    //ORDER.UpdateForReport(1);
    // bytesCodeCall = abi.encodeCall(
    // ORDER.UpdateForReport,
    //     (
    //         1099001323
    //     )
    // );
    // console.log("REPORT UpdateForReport:");
    // console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 

    //GetDailyReport
    uint256 date = uint256(1761551024)/uint256(86400);
    bytesCodeCall = abi.encodeCall(
    REPORT.GetDailyReport,
        (
            date
        )
    );
    console.log("REPORT GetDailyReport:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    //ORDER.getTablePayment(1);
    // bytesCodeCall = abi.encodeCall(
    // ORDER.getTablePayment,
    //     (2362859133
    //     )
    // );
    // console.log("ORDER getTablePayment:");
    // console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  
    //GetAllPositions
    bytesCodeCall = abi.encodeCall(
    MANAGEMENT.GetAllPositions,
        (
        )
    );
    console.log("MANAGEMENT GetAllPositions:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  
    // bytesCodeCall = abi.encodeCall(
    // MANAGEMENT.removeTable,
    //     (1
    //     )
    // );
    // console.log("MANAGEMENT removeTable:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // );  
    // bytesCodeCall = abi.encodeCall(
    // MANAGEMENT.GetCategoriesPagination,
    //     (0,10
    //     )
    // );
    // console.log("MANAGEMENT GetCategoriesPagination:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // );  

    // bytesCodeCall = abi.encodeCall(
    // MANAGEMENT.hasRole,
    //     (
    //         ROLE_ADMIN,
    //         0x2896112faFe802B8529A722D40616436D10Fca3f
    //     )
    // );
    // console.log("MANAGEMENT hasRole:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // );  
    // //MANAGEMENT.GetStaffsPagination(0,10);
    bytesCodeCall = abi.encodeCall(
    MANAGEMENT.GetStaffsPagination,
        (
            0,
            10
        )
    );
    console.log("MANAGEMENT GetStaffsPagination:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  
    // // MANAGEMENT.grantRole(ROLE_ADMIN,staff2); 
    // bytesCodeCall = abi.encodeCall(
    // MANAGEMENT.grantRole,
    //     (
    //         ROLE_HASH_STAFF_MANAGE,
    //         0x940438880ab4655424D494df5376595a98B3fE37
    //     )
    // );
    // console.log("MANAGEMENT grantRole:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // );  
    // //MANAGEMENT.setReport(address(REPORT));
    // bytesCodeCall = abi.encodeCall(
    // MANAGEMENT.setReport,
    //     (0x5583857dEc4317aCB87C50E09056e3862fF127bc));
    // console.log("MANAGEMENT setReport:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // );  
    // ORDER.confirmPayment(1,payment.id,"paid");
    bytes32 paymentId = 0xf3c8e4f62ea1db68f60c0f717a22d8c665945633860c443fef17fd1faceeffe0;
    bytesCodeCall = abi.encodeCall(
    ORDER.confirmPayment,
        (7,paymentId,"paid"));
    console.log("ORDER confirmPayment:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  

    //restaurantOrder
    bytesCodeCall = abi.encodeCall(
    MANAGEMENT.restaurantOrder,
        ());
    console.log("MANAGEMENT restaurantOrder:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  
    //isStaff
    bytesCodeCall = abi.encodeCall(
    MANAGEMENT.isStaff,
        (0xa81B65ec3931F94Ce38C443dE6b77f067D16d38c)
    );
    console.log("MANAGEMENT isStaff:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 

    //MANAGEMENT.setPoints(address(POINTS));
     bytesCodeCall = abi.encodeCall(
    MANAGEMENT.setPoints,
        (address(POINTS)));
    console.log("MANAGEMENT setPoints:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
        //POINTS.getAllGroups
    bytesCodeCall = abi.encodeCall(
    POINTS.getAllGroups,
        ());
    console.log("POINTS getAllGroups:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    ); 
    //registerMember
    RegisterInPut memory input = RegisterInPut({
        _memberId: "12345647589",
        _phoneNumber: "0962345872",
        _firstName: "Hoan",
        _lastName: "Le",
        _whatsapp: "0962345872",
        _email: "hoan@gmail.com",
        _avatar: "avatar"

    });
    bytesCodeCall = abi.encodeCall(
    POINTS.registerMember,
        (
            input
        ));
    console.log("POINTS registerMember:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );   

    // //  getPointsInfo
    // bytesCodeCall = abi.encodeCall(
    // POINTS.getPointsInfo,
    //     (
    //     ));
    // console.log("POINTS getPointsInfo:");
    // console.logBytes(bytesCodeCall);
    // console.log(
    //     "-----------------------------------------------------------------------------"
    // );   

    //createMemberGroup
    bytesCodeCall = abi.encodeCall(
    POINTS.createMemberGroup,
        (
            "khach hang than thiet"
        ));
    console.log("POINTS createMemberGroup:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );   

    //POINTS.updateMemberGroup(address(MANAGEMENT));
    bytesCodeCall = abi.encodeCall(
    POINTS.updateMemberGroup,
        (
            0xda7c73023306e345b2c4351e72ee4d7fa304c38819cff86e08f3a35fac2b47b4,
            "Nhom 22",
            true
        ));
    console.log("POINTS updateMemberGroup:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );   
    //POINTS.setManagementSC(address(MANAGEMENT));
    bytesCodeCall = abi.encodeCall(
    POINTS.setManagementSC,
        (address(MANAGEMENT)));
    console.log("POINTS setManagementSC:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  
    // POINTS.setOrder(address(ORDER));
    bytesCodeCall = abi.encodeCall(
    POINTS.setOrder,
        (address(ORDER), 1));
    console.log("POINTS setOrder:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  

    // ORDER.setPointSC(address(POINTS));
    bytesCodeCall = abi.encodeCall(
    ORDER.setPointSC,
        (address(POINTS)));
    console.log("ORDER setPointSC:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  
    //MANAGEMENT.GetAllDiscounts();
     bytesCodeCall = abi.encodeCall(
    MANAGEMENT.GetAllDiscounts,
        ());
    console.log("MANAGEMENT GetAllDiscounts:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  
    //lay bytecode proxy
    bytes memory proxyBytecode = abi.encodePacked(
        type(ERC1967Proxy).creationCode,
        abi.encode(
            address(POINTS_IMP),
            abi.encodeWithSelector(
                RestaurantLoyaltySystem.initialize.selector,
                0xdf182ed5CF7D29F072C429edd8BFCf9C4151394B,
                0x1510151015101510151015101510151015101510
            )
        )
    );
    console.log("PROXY bytecode:");
    console.logBytes(bytesCodeCall);
    console.log(
        "-----------------------------------------------------------------------------"
    );  
    //     //SetMerchant
    //     address cardVisa = 0x10F4A365ff344b3Af382aBdB507c868F1c22f592;
    //     bytesCodeCall = abi.encodeCall(
    //     ORDER.SetCardVisa,
    //     (cardVisa)
    //     );
    //     console.log("ORDER SetCardVisa: ");
    //     console.logBytes(bytesCodeCall);
    //     console.log(
    //         "-----------------------------------------------------------------------------"
    //     );
    //     //SetMerchant
    //     address merchant = 0x896380B4Aba770c8E6D248B022525B141BaD32EE;
    //     bytesCodeCall = abi.encodeCall(
    //     ORDER.SetMerchant,
    //     (merchant)
    //     );
    //     console.log("ORDER SetMerchant: ");
    //     console.logBytes(bytesCodeCall);
    //     console.log(
    //         "-----------------------------------------------------------------------------"
    //     );
    //     //SetTax
    //     bytesCodeCall = abi.encodeCall(
    //     ORDER.SetTax,
    //     (        
    //      1)
    //     );
    //     console.log("ORDER SetTax: ");
    //     console.logBytes(bytesCodeCall);
    //     console.log(
    //         "-----------------------------------------------------------------------------"
    //     );
    //     //UpdateDish
    //     string memory _codeCat = "7";
    //     string memory _codeDish = "91";
    //     string memory _nameCategory =  "Dishes";
    //     string memory _name = "Egg Fried Rice";
    //     string memory _des = "";
    //     uint _price = 1000000000000000000*(100-1)/100;
    //     bool _available = true;
    //     bool _active = true;
    //     string memory _imgUrl = "https://img.fi.ai/food-order/egg_fried_rice.png";
    //     bytesCodeCall = abi.encodeCall(
    //     MANAGEMENT.UpdateDish,
    //     (        
    //      _codeCat,
    //      _codeDish,
    //      _nameCategory,
    //      _name,
    //      _des,
    //      _price,
    //      _available,
    //      _active,
    //      _imgUrl)
    //     );
    //     console.log("MANAGEMENT UpdateDish: ");
    //     console.logBytes(bytesCodeCall);
    //     console.log(
    //         "-----------------------------------------------------------------------------"
    //     );
    //     // bytesCodeCall = abi.encodeCall(
    //     //     MANAGEMENT.hasRole,
    //     //     (
    //     //        DEFAULT_ADMIN_ROLE,
    //     //        0xF898fc3d62bFC36f613eb28dE3E20847B4B34d70
    //     //     )
    //     // );
    //     // console.log("hasRole DEFAULT_ADMIN_ROLE:");
    //     // console.logBytes(bytesCodeCall);
    //     // console.log(
    //     //     "-----------------------------------------------------------------------------"
    //     // );  
    //     // bytesCodeCall = abi.encodeCall(
    //     //     MANAGEMENT.hasRole,
    //     //     (
    //     //        ROLE_ADMIN,
    //     //        0xF898fc3d62bFC36f613eb28dE3E20847B4B34d70
    //     //     )
    //     // );
    //     // console.log("hasRole ROLE_ADMIN:");
    //     // console.logBytes(bytesCodeCall);
    //     // console.log(
    //     //     "-----------------------------------------------------------------------------"
    //     // );  

    //     // bytesCodeCall = abi.encodeCall(
    //     // MANAGEMENT.ROLE_ADMIN,()
    //     // );
    //     // console.log("ROLE_ADMIN:");
    //     // console.logBytes(bytesCodeCall);
    //     // console.log(
    //     //     "-----------------------------------------------------------------------------"
    //     // );  
    //     //         bytesCodeCall = abi.encodeCall(
    //     //     MANAGEMENT.GetAllStaffs,()
    //     // );
    //     // console.log("GetAllStaffs:");
    //     // console.logBytes(bytesCodeCall);
    //     // console.log(
    //     //     "-----------------------------------------------------------------------------"
    //     // );  
        // bytesCodeCall = abi.encodeCall(
        //     MANAGEMENT.UpdateCategory,
        //     (
        //        "THITBO","thit bo my",1,"Cac mon voi thit bo my",true,"_imgURL3"
        //     )
        // );
        // console.log("UpdateCategory :");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // ); 
        // bytesCodeCall = abi.encodeCall(
        //     MANAGEMENT.GetCategory,
        //     (
        //        "THITBO"
        //     )
        // );
        // console.log("GetCategory :");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  

        // bytesCodeCall = abi.encodeCall(
        //     MANAGEMENT.CreateCategory,
        //     (
        //        category2
        //     )
        // );
        // console.log("CreateCategory 2:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  
        // bytesCodeCall = abi.encodeCall(
        //     MANAGEMENT.CreateCategory,
        //     (
        //        category2
        //     )
        // );
        // console.log("GetCategories:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  
        // bytes memory bytesCodeCall = abi.encodeCall(
        //     MANAGEMENT.CreateDish,
        //     (
        //        "THITBO",dish1,1000
        //     )
        // );
        // console.log("CreateDish 1:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  
        // bytesCodeCall = abi.encodeCall(
        //     MANAGEMENT.CreateDish,
        //     (
        //        "THITBO",dish2,200
        //     )
        // );
        // console.log("CreateDish 2:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  
        // bytesCodeCall = abi.encodeCall(
        //     MANAGEMENT.CreateDish,
        //     (
        //        "THITGA",dish3,500
        //     )
        // );
        // console.log("CreateDish 3:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  
        // bytes memory bytesCodeCall = abi.encodeCall(
        //     MANAGEMENT.CreateDiscount,
        //     (
        //         "KM20",
        //         "Chuong trinh kmai mua thu",
        //         20,
        //         "Kmai giam 15% tren tong chi phi",
        //         1730079957,    //8.46am 28/10/2024
        //         1730079957 + 365 days,
        //         true,
        //         "_imgIRL",
        //         100           
        //     )
        // );
        // console.log("CreateDiscount:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  
        // bytes memory bytesCodeCall = abi.encodeCall(
        //     MANAGEMENT.CreateCategory,
        //     (
        //        category1
        //     )
        // );
        // console.log("CreateCategory 1:");
        // console.logBytes(bytesCodeCall);
        // console.log(
        //     "-----------------------------------------------------------------------------"
        // );  



    }

}