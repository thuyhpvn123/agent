// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.20;

// import {Test, console} from "forge-std/Test.sol";
// import  "../contracts/Management.sol";
// import "../contracts/interfaces/IRestaurant.sol";
// import  "../contracts/order.sol";
// import  "../contracts/report.sol";
// import  "../contracts/timekeeping.sol";
// import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


// contract RestaurantTest is Test {
//     Management public MANAGEMENT;
//     Management public MANAGEMENT_IMP;
//     RestaurantOrder public ORDER;
//     RestaurantOrder public ORDER_IMP;
//     RestaurantReporting public REPORT;
//     RestaurantReporting public REPORT_IMP;
//     AttendanceSystem public TIMEKEEPING;
//     AttendanceSystem public TIMEKEEPING_IMP;
//     address public pos = address(0x11);
//     address public Deployer = address(0x1);
//     address admin = address(0x2);
//     address staff1 = address(0xA620249dc17f23887226506b3eB260f4802a7efc);
//     address staff2 = address(0xE730d4572f20A4d701EBb80b8b5aFA99b36d5e49);
//     address staff3 = address(0x11111111);
//     address customer1 = address(0x5);
//     address customer2 = address(0x6);
//     bytes32 public ROLE_ADMIN = keccak256("ROLE_ADMIN");
//     bytes32 public ROLE_STAFF = keccak256("ROLE_STAFF");
//     bytes32 public ROLE_HASH_STATUS_ORDER = keccak256("ROLE_HASH_STATUS_ORDER");
//     bytes32 public ROLE_HASH_PAYMENT_CONFIRM = keccak256("ROLE_HASH_PAYMENT_CONFIRM");
//     bytes32 public ROLE_HASH_UPDATE_TC = keccak256("ROLE_HASH_UPDATE_TC");
//     bytes32 public ROLE_HASH_TABLE_MANAGE = keccak256("ROLE_HASH_TABLE_MANAGE");
//     bytes32 public ROLE_HASH_STAFF_MANAGE = keccak256("ROLE_HASH_STAFF_MANAGE");
//     // bytes32 public DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
//     // Proxies
//     ERC1967Proxy public MANAGEMENT_PROXY;
//     ERC1967Proxy public ORDER_PROXY;
//     ERC1967Proxy public REPORT_PROXY;
//     ERC1967Proxy public TIMEKEEPING_PROXY;
//     WorkPlace[] public workPlaces;
//     uint[] public workPlaceIds;
//     constructor() {
//         vm.startPrank(Deployer);
//          // Deploy implementation contracts
//          MANAGEMENT_IMP = new Management();
//          ORDER_IMP = new RestaurantOrder();
//          REPORT_IMP = new RestaurantReporting();
//          TIMEKEEPING_IMP = new AttendanceSystem();
//         // Deploy proxies
//         MANAGEMENT_PROXY = new ERC1967Proxy(
//             address(MANAGEMENT_IMP),
//             abi.encodeWithSelector(Management.initialize.selector)
//         );
//         ORDER_PROXY = new ERC1967Proxy(
//             address(ORDER_IMP),
//             abi.encodeWithSelector(RestaurantOrder.initialize.selector)
//         );
//         REPORT_PROXY = new ERC1967Proxy(
//             address(REPORT_IMP),
//             abi.encodeWithSelector(RestaurantReporting.initialize.selector,
//             address(MANAGEMENT_PROXY))
//         );
//         bytes memory initData = abi.encodeWithSelector(
//             AttendanceSystem.initialize.selector,
//             address(MANAGEMENT_PROXY)
//         );
        
//         TIMEKEEPING_PROXY = new ERC1967Proxy(address(TIMEKEEPING_IMP), initData);        
// //         // Set BE
// //         attendanceSystem.setBE(be);
//         // Wrap proxies
//         MANAGEMENT = Management(address(MANAGEMENT_PROXY));
//         ORDER = RestaurantOrder(address(ORDER_PROXY));
//         REPORT = RestaurantReporting(address(REPORT_PROXY));
//         TIMEKEEPING = AttendanceSystem(address(TIMEKEEPING_PROXY));
//         //SET
//         ORDER.setConfig(address(MANAGEMENT),address(0x456),address(0x789),10,address(0x999),address(REPORT));
//         MANAGEMENT.setRestaurantOrder(address(ORDER));
//         MANAGEMENT.setReport(address(REPORT));
//         MANAGEMENT.setTimeKeeping(address(TIMEKEEPING));
//         MANAGEMENT.setStaffAgentStore(address(0x123));
//         REPORT.setManangement(address(MANAGEMENT));
//         TIMEKEEPING.setManagement(address(MANAGEMENT));
//         vm.stopPrank();
//         SetUpRestaurant();
//         SetAttendance();
//     }
//     function SetUpRestaurant()public{
//         SetUpStaff();
//         SetUpCategory();
//         SetUpDish();
//         SetUpDiscount();
//         SetUpTable();
//     }
//     function SetUpTable()public {
//         vm.startPrank(admin);
//         MANAGEMENT.CreateArea(1,"Khu A");
//         // bytes memory bytesCodeCall = abi.encodeCall(
//         // MANAGEMENT.CreateArea,
//         //     (
//         //         1,"Khu A"          
//         //     )
//         // );
//         // console.log("MANAGEMENT CreateArea:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  

//         MANAGEMENT.CreateTable(2,6,true,"2",1);
//         // bytesCodeCall = abi.encodeCall(
//         // MANAGEMENT.CreateTable,
//         //     (
//         //         2,6,true,"2",1            
//         //     )
//         // );
//         // console.log("MANAGEMENT CreateTable:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  
//     }
//     function SetAttendance()public {
//         SetTimeKeeping();
//     }
//     function SetTimeKeeping()public {
//         vm.startPrank(Deployer);
//         WorkPlace[] memory _workPlaces = new WorkPlace[](1);
//         _workPlaces[0] = WorkPlace({
//             WorkPlaceId: 0,
//             LocationName: "ibe",
//             LocationAddress:"location",
//             LatLon: "10.791129697817134|106.69827066494396"
//         });
//         uint[] memory ids = TIMEKEEPING.createSettingAddress(_workPlaces);
//         assertEq(ids[0],1,"workplace id should start from 1");
//         workPlaces.push(_workPlaces[0]);
//         workPlaceIds.push(ids[0]);
//         vm.stopPrank();
//         // bytes memory bytesCodeCall = abi.encodeCall(
//         // TIMEKEEPING.createSettingAddress,
//         //     (_workPlaces
//         //     )
//         // );
//         // console.log("MANAGEMENT createSettingAddress:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  

//     }
//     function SetUpStaff()public{
//         vm.startPrank(Deployer);
//         bytes32 role = MANAGEMENT.DEFAULT_ADMIN_ROLE();
//         MANAGEMENT.grantRole(role,admin);
//         vm.startPrank(admin);
//         MANAGEMENT.grantRole(ROLE_ADMIN,admin);
//         //CreatePosition
//         STAFF_ROLE[] memory staff1Roles = new STAFF_ROLE[](1);
//         staff1Roles[0] = STAFF_ROLE.UPDATE_STATUS_DISH;

//         MANAGEMENT.CreatePosition("phuc vu ban",staff1Roles);
//         bytes memory bytesCodeCall = abi.encodeCall(
//         MANAGEMENT.CreatePosition,
//             (
//                "phuc vu ban",staff1Roles            
//             )
//         );
//         console.log("MANAGEMENT CreatePosition:");
//         console.logBytes(bytesCodeCall);
//         console.log(
//             "-----------------------------------------------------------------------------"
//         );  
//         //CreateWorkingShift
//         MANAGEMENT.CreateWorkingShift("ca sang",28800,43200); ////số giây tính từ 0h ngày hôm đó. vd 08:00 là 8*3600=28800
//         MANAGEMENT.CreateWorkingShift("ca chieu",46800,61200); //tu 13:00 den 17:00
//         // bytesCodeCall = abi.encodeCall(
//         // MANAGEMENT.CreateWorkingShift,
//         //     (
//         //         "ca sang",28800,43200            
//         //     )
//         // );
//         // console.log("MANAGEMENT CreateWorkingShift:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  

//         WorkingShift[] memory shifts = MANAGEMENT.getWorkingShifts();
//         assertEq(shifts[0].title,"ca sang","working shift title should equal");
//         // MANAGEMENT.UpdateWorkingShift("full time",28800,61200,0);

//         //
//         WorkingShift[] memory staff1Shifts = new WorkingShift[](2);
//         staff1Shifts[0] = shifts[0];
//         staff1Shifts[1] = shifts[1];

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
//         MANAGEMENT.CreateStaff(staff);
//         // bytesCodeCall = abi.encodeCall(
//         // MANAGEMENT.CreateStaff,
//         //     (
//         //         staff            
//         //     )
//         // );
//         // console.log("MANAGEMENT CreateStaff:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  

//         staff = Staff({
//             wallet: staff2,
//             name:"han",
//             code:"NV2",
//             phone:"0914526387",
//             addr:"quan 7",
//             position: "phuc vu ban",
//             role:ROLE.STAFF,
//             active: true,
//             linkImgSelfie: "linkImgSelfie",
//             linkImgPortrait:"linkImgPortrait",
//             shifts:staff1Shifts,
//             roles: staff1Roles
//         });
//         MANAGEMENT.CreateStaff(staff);

//         (Staff[] memory staffs,uint totalCount) = MANAGEMENT.GetStaffsPagination(0,100);

//         assertEq(staffs.length,2,"should be equal");
//         Staff memory staffInfo = MANAGEMENT.GetStaffInfo(staff1);
//         assertEq(staffInfo.name,"thuy","should be equal");
//         assertEq(staffInfo.phone,"0913088965","should be equal");
//         MANAGEMENT.grantRole(ROLE_STAFF,staff1);
//         MANAGEMENT.UpdateStaffInfo(staff1,"thanh thuy","NV1","1111111111","phu nhuan",staff1Roles,staff1Shifts,"linkImgSelfie","linkImgPortrait","phuc vu ban",true);
//         staffInfo = MANAGEMENT.GetStaffInfo(staff1);
//         assertEq(staffInfo.name,"thanh thuy","should be equal");
//         assertEq(staffInfo.phone,"1111111111","should be equal");
//         bool kq = MANAGEMENT.isStaff(staff1);
//         assertEq(kq,true,"should be equal"); 
//         (staffs,totalCount) = MANAGEMENT.GetStaffsPagination(0,100);
//         assertEq(staffs[0].name,"han","should be equal");
//         assertEq(staffs[0].phone,"0914526387","should be equal");

//         MANAGEMENT.grantRole(ROLE_ADMIN,staff2);
        
//         vm.stopPrank();
//         vm.prank(staff2);
//         staff = Staff({
//             wallet: staff3,
//             name:"han",
//             code:"NV3",
//             phone:"11111111",
//             addr:"quan 7",
//             position: "phuc vu ban",
//             role:ROLE.STAFF,
//             active: true,
//             linkImgSelfie: "linkImgSelfie",
//             linkImgPortrait:"linkImgPortrait",
//             shifts:staff1Shifts,
//             roles: staff1Roles
//         });
//         MANAGEMENT.CreateStaff(staff);
//         MANAGEMENT.GetStaffsPagination(0,10);
//         vm.prank(staff2);
//         MANAGEMENT.removeStaff(staff3);
        
//     }
//     function SetUpCategory()public {
//         vm.startPrank(admin);
//         Category memory category1 = Category({
//             code:"THITBO",
//             name:"thit bo",
//             rank:1,
//             desc:"Cac mon voi thit bo",
//             active:true,
//             imgUrl:"_imgURL1"
//         });
//         MANAGEMENT.CreateCategory(category1);

//         Category memory category2 = Category({
//             code:"THITGA",
//             name:"thit ga",
//             rank:2,
//             desc:"Cac mon voi thit ga",
//             active:true,
//             imgUrl:"_imgURL2"
//         });
//         MANAGEMENT.CreateCategory(category2);
//         Category[] memory categories = MANAGEMENT.GetCategories();
//         assertEq(categories.length,2,"should be equal");
//         Category memory cat2 = MANAGEMENT.GetCategory("THITGA");
//         assertEq(cat2.name,"thit ga","should be equal");
//         assertEq(cat2.imgUrl,"_imgURL2","should be equal");
//         MANAGEMENT.UpdateCategory("THITGA","thit ga ta",1,"Cac mon voi thit ga",true,"_imgURL3");
//         cat2 = MANAGEMENT.GetCategory("THITGA");
//         assertEq(cat2.name,"thit ga ta","should be equal");
//         assertEq(cat2.imgUrl,"_imgURL3","should be equal");
//         Category[] memory categoriesUpdate = MANAGEMENT.GetCategories();
//         assertEq(categoriesUpdate[1].name,"thit ga ta","should be equal");
//         assertEq(categoriesUpdate[1].imgUrl,"_imgURL3","should be equal");
//         MANAGEMENT.GetCategoriesPagination(0,10);

//         vm.stopPrank();
//     }
//     function SetUpDish()public {
//         vm.startPrank(admin);
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
//         Dish memory dish2 = Dish({
//             code:"dish2_code",
//             nameCategory:"Thit bo",
//             name:"Bo nuong tang",
//             des:"Thit bo nuong tang an kem phomai",
//             available:true,
//             active:true,
//             imgUrl:"img_bo2",
//             averageStar: 0,
//             cookingTime: 30,
//             ingredients:ingredients,
//             showIngredient: true,
//             videoLink: "videoLink",
//             totalReview:0,
//             orderNum:0,
//             createdAt:0
//         });
//         Dish memory dish3 = Dish({
//             code:"dish3_code",
//             nameCategory:"Thit ga",
//             name:"Ga luoc",
//             des:"Thit ga luoc an kem com chien",
//             available:true,
//             active:true,
//             imgUrl:"img_ga1",
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

//         MANAGEMENT.CreateDish("THITBO",dish1,variants);
//         MANAGEMENT.CreateDish("THITBO",dish2,variants);
//         MANAGEMENT.CreateDish("THITGA",dish3,variants);
//         Dish[] memory dishes = MANAGEMENT.GetDishes("THITBO");
//         assertEq(dishes.length,2,"should be equal");
//         Dish memory dish = MANAGEMENT.GetDish("dish2_code");
//         assertEq(dish.name,"Bo nuong tang","should be equal");
//         bytes32 variantID = hashAttributes(variants[0].attrs);
//         Variant memory orderVariant = MANAGEMENT.getVariant("dish1_code", variantID);
//         uint dishPrice = orderVariant.dishPrice;
//         assertEq(dishPrice,1000 ,"should be equal");
//         variants[0].price = 1500;
//         string[] memory  _ingredients = new string[](0);
//         MANAGEMENT.UpdateDish(
//             "THITBO",
//             "dish2_code",
//             "Thit bo",
//             "Bo xong khoi",
//             "Thit bo xong khoi an kem salad",
//             true,
//             true,
//             "img_bo2",
//             30,
//             true,
//             "",
//             variants,
//             _ingredients
//         );
//         dish = MANAGEMENT.GetDish("dish2_code");
//         orderVariant = MANAGEMENT.getVariant("dish2_code", variantID);
//         dishPrice = orderVariant.dishPrice;
//         assertEq(dish.name,"Bo xong khoi","should be equal");
//         assertEq(dishPrice,1500,"should be equal");
//         assertEq(dish.available,true,"should be equal");
//         Dish[] memory dishesUpdate = MANAGEMENT.GetDishes("THITBO");
//         assertEq(dishesUpdate[1].name,"Bo xong khoi","should be equal");
//         assertEq(dishesUpdate[1].available,true,"should be equal");

//         vm.stopPrank();
//         vm.startPrank(staff1);
//         MANAGEMENT.UpdateDishStatus("THITBO","dish2_code",false);
//         dish = MANAGEMENT.GetDish("dish2_code");
//         assertEq(dish.available,false,"should be equal");
//         vm.stopPrank();
//         MANAGEMENT.GetTopDishesWithLimit(0,10);

//     }
//     function SetUpDiscount()public{
//         vm.startPrank(admin);
//         MANAGEMENT.CreateDiscount(
//             "KM20",
//             "Chuong trinh kmai mua thu",
//             15,
//             "Kmai giam 15% tren tong chi phi",
//             block.timestamp,
//             block.timestamp + 30 days,
//             true,
//             "_imgIRL",
//             100
//         );
//         Discount memory discount = MANAGEMENT.GetDiscount("KM20");
//         assertEq(discount.amountMax,100,"should be equal");
//         MANAGEMENT.UpdateDiscount(
//             "KM20",
//             "Chuong trinh kmai mua dong",
//             20,
//             "Kmai giam 20% tren tong chi phi",
//             block.timestamp,
//             block.timestamp + 30 days,
//             true,
//             "_imgIRL",
//             200
//         ); 
//         discount = MANAGEMENT.GetDiscount("KM20");
//         assertEq(discount.amountMax,200,"should be equal");
//         Discount[] memory discounts = MANAGEMENT.GetAllDiscounts();
//         assertEq(discounts.length,1,"should be equal");
//         assertEq(discounts[0].amountMax,200,"should be equal");
//         assertEq(discounts[0].discountPercent,20,"should be equal");
//         vm.stopPrank();
//         // GetByteCode();
//     }
//     function testAttendance()public{
//         vm.warp(1759724234);//4h17 -6/10/2025
//         vm.startBroadcast(staff1);
//         SettingAddress memory settingAddress = TIMEKEEPING.getSettingAddress();
//         WorkPlace[] memory workplaces = settingAddress.WorkPlaces;
//         WorkPlaceAttendance memory workPlace = WorkPlaceAttendance({
//             WorkPlaceId:workplaces[0].WorkPlaceId,
//             LatLon:workplaces[0].LatLon
//         });
//         TIMEKEEPING.checkIn(staff1,workPlace);
//         TIMEKEEPING.checkOut(staff1,workPlace);
//         vm.stopBroadcast();
//         // bytes memory bytesCodeCall = abi.encodeCall(
//         // TIMEKEEPING.checkIn,
//         //     (
//         //         staff1,
//         //         workPlace
//         //     )
//         // );
//         // console.log("MANAGEMENT checkIn:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  
//         vm.prank(staff2);
//         TIMEKEEPING.ReportCheckin(staff2,workPlace);
//         AttendanceRecord[] memory records = TIMEKEEPING.getStaffDailyReport(staff1,20251006);
//         assertEq(records.length,1,"should be equal");
//         records = TIMEKEEPING.getStaffDailyReport(staff2,20251006);
//         assertEq(records.length,0,"should be equal");
//         records = TIMEKEEPING.getStaffDailyReport(customer1,20251006);
//         assertEq(records.length,0,"should be equal");
//         //hr set absent day
//         address[] memory _staffs = new address[](1);
//         _staffs[0] = staff1;
//         uint256[] memory _dates = new uint256[](1);
//         _dates[0] = 20251005;
//         AttendanceStatus[] memory _statuses = new AttendanceStatus[](1);
//         _statuses[0] = AttendanceStatus.ABSENT;
//         ABSENT_TYPE[] memory _absentTypes = new ABSENT_TYPE[](1);
//         _absentTypes[0] = ABSENT_TYPE.UNAUTHORIZED;
//         string memory _notes = "";
//         address approver = Deployer;
//         vm.prank(Deployer);
//         TIMEKEEPING.setBulkAttendanceData(_staffs,_dates,_statuses,_absentTypes,_notes,approver);
//                 //hr set absent day
//         _staffs[0] = staff1;
//         _dates[0] = 20251005;
//         _statuses[0] = AttendanceStatus.ABSENT;
//         _absentTypes[0] = ABSENT_TYPE.VACATION;
//         vm.prank(Deployer);
//         TIMEKEEPING.setBulkAttendanceData(_staffs,_dates,_statuses,_absentTypes,_notes,approver);

//             vm.warp(1759831318);//4h17 -7/10/2025
//         StaffMonthlyReport memory report = TIMEKEEPING.getStaffMonthlyReportRealtime(staff1,202510);
//         // console.log("report.workingDayArr.length:",report.workingDayArr.length);
//         // console.log("report.absentVacationDayArr.length:",report.absentVacationDayArr.length);
//         // console.log("report.lateDayArr.length:",report.lateDayArr.length);
//         // console.log("report.absentUnauthorizedDayArr.length:",report.lateDayArr.length);

//     }

//     function testMakeOrder()public{
//         vm.warp(1759724234);//11h17 -7/10/2025
//         //order lan 1 table1
 
//         uint table =1;
//         string[] memory dishCodes = new string[](3);
//         dishCodes[0] = "dish1_code";
//         dishCodes[1] = "dish3_code";
//         dishCodes[2] = "dish1_code";      
//         uint8[] memory quantities = new uint8[](3);
//         quantities[0] = 2;
//         quantities[1] = 5;
//         quantities[2] = 2;
//         string[] memory notes = new string[](3);
//         notes[0] = "";
//         notes[1] = "";
//         notes[2] = "medium";
//         //
//         DishInfo memory dishInfo = MANAGEMENT.getDishInfo("dish1_code");       
//         bytes32[] memory variantIDs = new bytes32[](3);
//         variantIDs[0] = dishInfo.variants[0].variantID;
//         variantIDs[1] = dishInfo.variants[1].variantID;
//         variantIDs[2] = dishInfo.variants[2].variantID;
//         bytes32 orderId1T1 = ORDER.makeOrder(
//             table,
//             dishCodes,
//             quantities,
//             notes,
//             variantIDs
//         );

//         //order lan 2 table1
//         string[] memory dishCodes1 = new string[](1);
//         dishCodes1[0] = "dish3_code";
//         uint8[] memory quantities1 = new uint8[](1);
//         quantities1[0] = 10;
//         string[] memory notes1 = new string[](1);
//         notes1[0] = "";
//         bytes32[] memory variantIDs1 = new bytes32[](1);
//         variantIDs1[0] = dishInfo.variants[0].variantID;
//         bytes32 orderId2T1 = ORDER.makeOrder(
//             table,
//             dishCodes1,
//             quantities1,
//             notes1,
//             variantIDs1
//         );
//         //order lan 1 table2
//         table = 2;
//         string[] memory dishCodes2 = new string[](1);
//         dishCodes2[0] = "dish3_code";
//         uint8[] memory quantities2 = new uint8[](1);
//         quantities2[0] = 10;
//         string[] memory notes2 = new string[](1);
//         notes2[0] = "";
//         bytes32[] memory variantIDs2 = new bytes32[](1);
//         variantIDs2[0] = dishInfo.variants[0].variantID;
//         bytes32 orderId1T2 = ORDER.makeOrder(
//             table,
//             dishCodes2,
//             quantities2,
//             notes2,
//             variantIDs2
//         );

//         //order lan 1 table3
//         table = 3;
//         string[] memory dishCodes3 = new string[](1);
//         dishCodes3[0] = "dish1_code";
//         uint8[] memory quantities3 = new uint8[](1);
//         quantities3[0] = 4;
//         string[] memory notes3 = new string[](1);
//         notes3[0] = "";
//         bytes32[] memory variantIDs3 = new bytes32[](1);
//         variantIDs3[0] = dishInfo.variants[0].variantID;

//         bytes32 orderId1T3 = ORDER.makeOrder(
//             table,
//             dishCodes2,
//             quantities2,
//             notes2,
//             variantIDs2
//         );
//         //get orders by table
//         Order[] memory orders1 = ORDER.GetOrders(1);
//         assertEq(orders1.length,2,"should be equal");
//         Order[] memory orders2 = ORDER.GetOrders(2);
//         assertEq(orders2.length,1,"should be equal");
//         Order[] memory orders3 = ORDER.GetOrders(3);
//         assertEq(orders3.length,1,"should be equal");
//         Order[] memory allOrders = ORDER.GetAllOrders();
//         assertEq(allOrders.length,4,"should be equal");

//         //get courses
//         SimpleCourse memory course = ORDER.getTableCourse(1,0);
//         assertEq(course.quantity, 2);
//         SimpleCourse[] memory coursesByOrder1 = ORDER.GetCoursesByOrderId(orderId1T1);
//         assertEq(coursesByOrder1.length,3,"should be equal");
//         SimpleCourse[] memory coursesByOrder3 = ORDER.GetCoursesByOrderId(orderId1T2);
//         assertEq(coursesByOrder3.length,1,"should be equal");
//         SimpleCourse[] memory coursesByTable1 = ORDER.GetCoursesByTable(1);
//         assertEq(coursesByTable1.length,4,"should be equal");
//         Payment memory payment = ORDER.getTablePayment(1);
//         assertEq(payment.foodCharge,28000 );
//         uint taxPercent = ORDER.getTaxPercent();
//         assertEq(payment.tax,28000  * taxPercent/100);

//         //update order table 1 order 1 more quantity
//         uint[] memory updateCourseIds = new uint[](1);
//         updateCourseIds[0] = coursesByTable1[0].id;
//         uint[] memory updateQuantities = new uint[](1);
//         updateQuantities[0]  = 3;
//         ORDER.UpdateOrder(1,orderId1T1,updateCourseIds,updateQuantities);
//         // bytesCodeCall = abi.encodeCall(
//         //     ORDER.UpdateOrder,
//         //     (
//         //         1,orderId1T1,updateCourseIds,updateQuantities
//         //     )
//         // );
//         // console.log("UpdateOrder table 1 order 1:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  

//         course = ORDER.getTableCourse(1,0);
//         assertEq(course.quantity, 3);
//         coursesByOrder1 = ORDER.GetCoursesByOrderId(orderId1T1);
//         assertEq(coursesByOrder1[0].quantity,3);
//         coursesByTable1 = ORDER.GetCoursesByTable(1);
//         assertEq(coursesByTable1[0].quantity,3);
//         payment = ORDER.getTablePayment(1);
//         assertEq(payment.foodCharge,29000 );
//         assertEq(payment.tax,29000  * taxPercent/100);

//         //update order table 1 order 1 less quantity
//         updateCourseIds[0] = coursesByTable1[3].id; //4
//         updateQuantities[0]  = 5;
//         ORDER.UpdateOrder(1,orderId2T1,updateCourseIds,updateQuantities);
//         payment = ORDER.getTablePayment(1);
//         assertEq(payment.foodCharge,24000); //=(29000- 5*1500)
//         assertEq(payment.tax,2400); //=3250*8/100

//         // //pay by usdt table 1
//         // vm.startPrank(customer);
//         // USDT_ERC.approve(address(ORDER),1_000_000*ONE_USDT);
//         // uint tip = 5 *ONE_USDT;
//         // bytes32 idPayment = ORDER.PayUSDT(customer,"KM20",tip);
//         // uint paymentAmount1 = foodCharge*80/100 +tax+ tip;
//         // assertEq(USDT_ERC.balanceOf(address(MONEY_POOL)),paymentAmount1);
//         // vm.stopPrank();
//         // bytesCodeCall = abi.encodeCall(
//         //     ORDER.PayUSDT,
//         //     (
//         //         customer,"KM20",tip
//         //     )
//         // );
//         // console.log("PayUSDT table 1:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  

//         //pay by visa table 2
//         vm.startPrank(customer1);
//         // bytes32 idCalldata = ORDER.SetCallData(customer,"KM20",tip);
//         // uint256 paymentAmount2 = (7*50*(80/100 + 8/100) + 5)*ONE_USDT;
//         // bytes memory getCallData = ORDER.GetCallData(idCalldata);
//         string memory discountCode = "";
//         uint tip = 0;
//         uint256 paymentAmount = 70400;
//         string memory txID = "";
//         ORDER.executeOrder(1,discountCode,tip,paymentAmount,txID);
//         ORDER.UpdateForReport(1);
//         vm.stopPrank();
//         MANAGEMENT.SortDishesWithOrderRange(0,10);
//         (DishWithFirstPrice[] memory dishes1, uint totalCount) =MANAGEMENT.GetTopDishesWithLimit(0,10);
//         console.log("dishesWithOrder.length:",dishes1.length);
//         console.log(dishes1[0].dish.code);
//         console.log(dishes1[1].dish.code);
//         console.log(dishes1[2].dish.code);
//         // ORDER.executeOrder(2,discountCode,tip,paymentAmount,txID);
//         // ORDER.UpdateForReport(2);
//         // MANAGEMENT.SortDishesWithOrderRange(0,10);
//         // ( DishWithFirstPrice[] memory dishes2, ) =MANAGEMENT.GetTopDishesWithLimit(0,10);
//         // console.log("dishesWithOrder.length:",dishes2.length);
//         // console.log(dishes2[0].dish.code);
//         // console.log(dishes2[1].dish.code);
//         // console.log(dishes2[2].dish.code);

//         // //staff comfirm payment 1,2
//         // vm.startPrank(staff1);
//         // ORDER.ComfirmPayment(customer,idPayment,"paid");
//         // Payment memory payment = ORDER.GetPaymentById(idPayment);
//         // assertEq(payment.staffComfirm,staff1);
//         // assertEq(payment.reasonComfirm,"paid");
//         // assertEq(payment.total,paymentAmount1,"total payment1 should be equal");
//         // vm.stopPrank();
//         // vm.startPrank(staff2);
//         // bytes32 idPayment2 = ORDER.GetLastIdPaymentByAdd(customer);
//         // ORDER.ComfirmPayment(customer,idPayment2,"paid");
//         // payment = ORDER.GetPaymentById(idPayment2);
//         // assertEq(payment.staffComfirm,staff2);
//         // assertEq(payment.reasonComfirm,"paid");
//         // assertEq(payment.total,paymentAmount2,"total payment2 should be equal");

//         // //staff update course status
//         // address _numAdd = customer;
//         // bytes32 _orderId = orderId1T3;
//         // uint _courseId = 1;   
//         // ORDER.UpdateCourseStatus(_numAdd,_orderId,_courseId,COURSE_STATUS.PREPARING);
//         // Course[] memory coursesByOrder4 = ORDER.GetCoursesByOrderId(orderId1T3);
//         // assertEq(uint(coursesByOrder4[0].status),uint(COURSE_STATUS.PREPARING),"should equal");
//         // coursesByOrder4 = ORDER.GetCoursesByAdd(customer);
//         // assertEq(uint(coursesByOrder4[0].status),uint(COURSE_STATUS.PREPARING),"should equal");
//         // Course memory courseByOrder4 = ORDER.GetCourseByAddAndIdCourse(customer,1);
//         // assertEq(uint(courseByOrder4.status),uint(COURSE_STATUS.PREPARING),"should equal");
//         // vm.stopPrank();

//         // //get history payments
//         // Payment[] memory payments = ORDER.GetPaymentHistory();
//         // assertEq(payments.length,2,"should equal");
//         // assertEq(payments[0].total,paymentAmount1,"total payment1 should be equal");
//         // assertEq(payments[1].total,paymentAmount2,"total payment2 should be equal");
//         // Course[] memory courseArr = ORDER.GetCoursesByPaymentId(payments[0].id);
//         // assertEq(courseArr.length,4,"should be equal");
//         // courseArr = ORDER.GetCoursesByPaymentId(payments[1].id);
//         // assertEq(courseArr.length,1,"should be equal");

//         // //customer review 
//         // vm.startPrank(customer);
//         // bytes32 _idPayment = payments[0].id;
//         // uint8 _serviceQuality = 4;
//         // uint8 _foodQuality = 5;
//         // string memory _contribution = "improve attitude";
//         // string memory _needAprove = "improve decoration";
//         // ORDER.MakeReview(_idPayment,_serviceQuality,_foodQuality,_contribution,_needAprove);
//         // vm.stopPrank();
//         // GetByteCode();
//     }
//     function hashAttributes(
//         Attribute[] memory attrs
//     ) internal pure returns (bytes32) {
//         bytes memory attributesHash;

//         for (uint256 i = 0; i < attrs.length; i++) {
//             attributesHash = abi.encodePacked(
//                 attributesHash,
//                 attrs[i].key,
//                 attrs[i].value
//             );
//         }

//         return keccak256(attributesHash);
//     }

//     function GetByteCode()public {
//     //
//     bytes memory bytesCodeCall = abi.encodeCall(
//     MANAGEMENT.GetStaffRolePayment,
//         (
//         )
//     );
//     console.log("MANAGEMENT GetStaffRolePayment:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     );  
//     bytesCodeCall = abi.encodeCall(
//     MANAGEMENT.removeTable,
//         (1
//         )
//     );
//     console.log("MANAGEMENT removeTable:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     );  
//     bytesCodeCall = abi.encodeCall(
//     MANAGEMENT.GetCategoriesPagination,
//         (0,10
//         )
//     );
//     console.log("MANAGEMENT GetCategoriesPagination:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     );  

//     bytesCodeCall = abi.encodeCall(
//     MANAGEMENT.hasRole,
//         (
//             ROLE_ADMIN,
//             0x2896112faFe802B8529A722D40616436D10Fca3f
//         )
//     );
//     console.log("MANAGEMENT hasRole:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     );  
//     //MANAGEMENT.GetStaffsPagination(0,10);
//     bytesCodeCall = abi.encodeCall(
//     MANAGEMENT.GetStaffsPagination,
//         (
//             0,
//             10
//         )
//     );
//     console.log("MANAGEMENT GetStaffsPagination:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     );  
//     // MANAGEMENT.grantRole(ROLE_ADMIN,staff2); 
//     bytesCodeCall = abi.encodeCall(
//     MANAGEMENT.grantRole,
//         (
//             ROLE_HASH_STAFF_MANAGE,
//             0x940438880ab4655424D494df5376595a98B3fE37
//         )
//     );
//     console.log("MANAGEMENT grantRole:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     );  
//     //MANAGEMENT.setReport(address(REPORT));
//     bytesCodeCall = abi.encodeCall(
//     MANAGEMENT.setReport,
//         (0x5583857dEc4317aCB87C50E09056e3862fF127bc));
//     console.log("MANAGEMENT setReport:");
//     console.logBytes(bytesCodeCall);
//     console.log(
//         "-----------------------------------------------------------------------------"
//     );  
//     //     //SetMerchant
//     //     address cardVisa = 0x10F4A365ff344b3Af382aBdB507c868F1c22f592;
//     //     bytesCodeCall = abi.encodeCall(
//     //     ORDER.SetCardVisa,
//     //     (cardVisa)
//     //     );
//     //     console.log("ORDER SetCardVisa: ");
//     //     console.logBytes(bytesCodeCall);
//     //     console.log(
//     //         "-----------------------------------------------------------------------------"
//     //     );
//     //     //SetMerchant
//     //     address merchant = 0x896380B4Aba770c8E6D248B022525B141BaD32EE;
//     //     bytesCodeCall = abi.encodeCall(
//     //     ORDER.SetMerchant,
//     //     (merchant)
//     //     );
//     //     console.log("ORDER SetMerchant: ");
//     //     console.logBytes(bytesCodeCall);
//     //     console.log(
//     //         "-----------------------------------------------------------------------------"
//     //     );
//     //     //SetTax
//     //     bytesCodeCall = abi.encodeCall(
//     //     ORDER.SetTax,
//     //     (        
//     //      1)
//     //     );
//     //     console.log("ORDER SetTax: ");
//     //     console.logBytes(bytesCodeCall);
//     //     console.log(
//     //         "-----------------------------------------------------------------------------"
//     //     );
//     //     //UpdateDish
//     //     string memory _codeCat = "7";
//     //     string memory _codeDish = "91";
//     //     string memory _nameCategory =  "Dishes";
//     //     string memory _name = "Egg Fried Rice";
//     //     string memory _des = "";
//     //     uint _price = 1000000000000000000*(100-1)/100;
//     //     bool _available = true;
//     //     bool _active = true;
//     //     string memory _imgUrl = "https://img.fi.ai/food-order/egg_fried_rice.png";
//     //     bytesCodeCall = abi.encodeCall(
//     //     MANAGEMENT.UpdateDish,
//     //     (        
//     //      _codeCat,
//     //      _codeDish,
//     //      _nameCategory,
//     //      _name,
//     //      _des,
//     //      _price,
//     //      _available,
//     //      _active,
//     //      _imgUrl)
//     //     );
//     //     console.log("MANAGEMENT UpdateDish: ");
//     //     console.logBytes(bytesCodeCall);
//     //     console.log(
//     //         "-----------------------------------------------------------------------------"
//     //     );
//     //     // bytesCodeCall = abi.encodeCall(
//     //     //     MANAGEMENT.hasRole,
//     //     //     (
//     //     //        DEFAULT_ADMIN_ROLE,
//     //     //        0xF898fc3d62bFC36f613eb28dE3E20847B4B34d70
//     //     //     )
//     //     // );
//     //     // console.log("hasRole DEFAULT_ADMIN_ROLE:");
//     //     // console.logBytes(bytesCodeCall);
//     //     // console.log(
//     //     //     "-----------------------------------------------------------------------------"
//     //     // );  
//     //     // bytesCodeCall = abi.encodeCall(
//     //     //     MANAGEMENT.hasRole,
//     //     //     (
//     //     //        ROLE_ADMIN,
//     //     //        0xF898fc3d62bFC36f613eb28dE3E20847B4B34d70
//     //     //     )
//     //     // );
//     //     // console.log("hasRole ROLE_ADMIN:");
//     //     // console.logBytes(bytesCodeCall);
//     //     // console.log(
//     //     //     "-----------------------------------------------------------------------------"
//     //     // );  

//     //     // bytesCodeCall = abi.encodeCall(
//     //     // MANAGEMENT.ROLE_ADMIN,()
//     //     // );
//     //     // console.log("ROLE_ADMIN:");
//     //     // console.logBytes(bytesCodeCall);
//     //     // console.log(
//     //     //     "-----------------------------------------------------------------------------"
//     //     // );  
//     //     //         bytesCodeCall = abi.encodeCall(
//     //     //     MANAGEMENT.GetAllStaffs,()
//     //     // );
//     //     // console.log("GetAllStaffs:");
//     //     // console.logBytes(bytesCodeCall);
//     //     // console.log(
//     //     //     "-----------------------------------------------------------------------------"
//     //     // );  
//         // bytesCodeCall = abi.encodeCall(
//         //     MANAGEMENT.UpdateCategory,
//         //     (
//         //        "THITBO","thit bo my",1,"Cac mon voi thit bo my",true,"_imgURL3"
//         //     )
//         // );
//         // console.log("UpdateCategory :");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // ); 
//         // bytesCodeCall = abi.encodeCall(
//         //     MANAGEMENT.GetCategory,
//         //     (
//         //        "THITBO"
//         //     )
//         // );
//         // console.log("GetCategory :");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  

//         // bytesCodeCall = abi.encodeCall(
//         //     MANAGEMENT.CreateCategory,
//         //     (
//         //        category2
//         //     )
//         // );
//         // console.log("CreateCategory 2:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  
//         // bytesCodeCall = abi.encodeCall(
//         //     MANAGEMENT.CreateCategory,
//         //     (
//         //        category2
//         //     )
//         // );
//         // console.log("GetCategories:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  
//         // bytes memory bytesCodeCall = abi.encodeCall(
//         //     MANAGEMENT.CreateDish,
//         //     (
//         //        "THITBO",dish1,1000
//         //     )
//         // );
//         // console.log("CreateDish 1:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  
//         // bytesCodeCall = abi.encodeCall(
//         //     MANAGEMENT.CreateDish,
//         //     (
//         //        "THITBO",dish2,200
//         //     )
//         // );
//         // console.log("CreateDish 2:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  
//         // bytesCodeCall = abi.encodeCall(
//         //     MANAGEMENT.CreateDish,
//         //     (
//         //        "THITGA",dish3,500
//         //     )
//         // );
//         // console.log("CreateDish 3:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  
//         // bytes memory bytesCodeCall = abi.encodeCall(
//         //     MANAGEMENT.CreateDiscount,
//         //     (
//         //         "KM20",
//         //         "Chuong trinh kmai mua thu",
//         //         20,
//         //         "Kmai giam 15% tren tong chi phi",
//         //         1730079957,    //8.46am 28/10/2024
//         //         1730079957 + 365 days,
//         //         true,
//         //         "_imgIRL",
//         //         100           
//         //     )
//         // );
//         // console.log("CreateDiscount:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  
//         // bytes memory bytesCodeCall = abi.encodeCall(
//         //     MANAGEMENT.CreateCategory,
//         //     (
//         //        category1
//         //     )
//         // );
//         // console.log("CreateCategory 1:");
//         // console.logBytes(bytesCodeCall);
//         // console.log(
//         //     "-----------------------------------------------------------------------------"
//         // );  



//     }

// }