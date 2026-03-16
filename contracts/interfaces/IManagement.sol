// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./IRestaurant.sol";

interface IManagement {
    function CreateStaff(
        Staff memory staff
    )external;
    function CreatePosition(string memory _name, STAFF_ROLE[] memory _roles)external;
    function CreateWorkingShift(
        string memory _title,
        uint256 from,   //số giây tính từ 0h ngày hôm đó. vd 08:00 là 8*3600=28800
        uint256 to
    ) external returns(uint256);
    function checkRole(STAFF_ROLE role,address user)external view returns(bool rightRole);
    // Restaurant info
    function GetRestaurantInfo() external view returns (RestaurantInfo memory);
    
    // Staff management
    function GetStaffInfo(address wallet) external view returns (Staff memory);
    function GetAllStaffs() external view returns (Staff[] memory);
    
    // Table management
    function GetAllTables() external view returns (Table[] memory);
    function GetTable(uint number) external view returns (Table memory);
    
    // Category management
    function GetCategories() external view returns (Category[] memory);
    function GetCategory(string memory code) external view returns (Category memory);
    
    // Dish management
    function GetDish(string memory code) external view returns (Dish memory);
    function GetDishes(string memory categoryCode) external view returns (Dish[] memory);
    function GetAllDishCodes() external view returns (string[] memory);
    function GetDishCount() external view returns (uint);
    
    // Discount management
    function GetDiscount(string memory code) external view returns (Discount memory);
    function GetAllDiscounts() external view returns (Discount[] memory);
    
    // Reporting functions that RestaurantReporting expects
    function GetDailyReport(uint date) external view returns (DailyReport memory);
    function GetMonthlyReport(uint month) external view returns (MonthlyReport memory);
    function GetDishReport(string memory dishCode) external view returns (DishReport memory);
    function GetDishDailyReport(string memory dishCode, uint date) external view returns (DishDailyReport memory);
    function GetVoucherReport(uint fromTime, uint toTime) external view returns (VoucherReport memory);
    function GetHistoricalSummary() external view returns (HistoricalSummary memory);
    function GetTopDishes(uint limit) external view returns (string[] memory);
    function GetRecentDishes(uint fromTime, uint limit) external view returns (string[] memory);
    
    // Simple stats functions
    function GetDailyStats(uint date) external view returns (uint revenue, uint orders, uint customers);
    function GetMonthlyStats(uint month) external view returns (uint revenue, uint orders, uint customers);
    function GetDishStats(string memory dishCode) external view returns (uint revenue, uint orders, uint startTime);
    function GetVoucherStats() external view returns (uint totalUsed, uint totalMax, uint totalActive);
    
    // Update functions for external contracts
    function UpdateDailyStats(uint date, uint revenue, uint orders, uint customers) external;
    function UpdateDishStats(string memory dishCode, uint revenue, uint orders) external;
    function UpdateDailyReportData(
        uint date,
        uint newCustomers,
        uint newCustomerOrders,
        uint newCustomerRevenue,
        uint returningCustomerOrders,
        uint returningCustomerRevenue,
        uint dineInOrders,
        uint takeAwayOrders,
        uint dineInRevenue,
        uint takeAwayRevenue,
        uint femaleCustomers,
        uint8 ageGroup,
        uint ageGroupCount,
        uint8 serviceRating,
        uint8 foodRating
    ) external;
    
    function UpdateDishDailyData(
        string memory dishCode,
        uint date,
        uint revenue,
        uint orderCount,
        uint onceOrderCustomers,
        uint twiceOrderCustomers
    ) external;
    
    function UpdateDishRanking(string memory dishCode, uint ranking) external;
    function SetDishAsNotNew(string memory dishCode) external;
    function isStaff(address account) external view returns (bool);
    function GetDishBasic(string memory code) external view returns (string memory name, bool available, bool active,string memory imgUrl);
    function IsDishEnough(string memory code, uint quantity) external view returns (bool);
    function GetDiscountBasic(string memory code) external view returns (
        uint discountPercent, 
        bool active, 
        uint amountUsed, 
        uint amountMax, 
        uint from, 
        uint to,
        DiscountType discountType,
        bytes32[] memory targetGroupIds
    );   
    function UpdateDiscountCodeUsed(string memory code) external;
    function getWorkingShifts() external view returns(WorkingShift[] memory);
    function updateAverageStarDish(uint8 _newStar, string memory _codeDish) external;
    function getVariant(
        string memory _dishCode,
        bytes32 _variantID
    ) external view returns (Variant memory);
    function GetStaffRolePayment()external view returns(address[] memory staffsPayment);
    function UpdateOrderNum(
        string memory _codeDish,
        uint orderNumAdd,
        uint createdAt
    )external ;
    function UpdateTopDish() external;
    function UpdateTopADish(string memory _dishCode) external;
    function BatchUpdateTopDish(string[] memory dishCodes) external;
    function Get5TopDishesByTime(uint256 dayOrMonth,bool isDay) external view returns (
        DishWithFirstPrice[] memory result,
        uint256 totalCount
    );
    function UpdateTotalRevenueReport(uint createdAt, uint addRevenue) external ;

    // Add 21/01/2026
    function SortDishesWithOrderRange(uint256 from, uint256 topN) external;
    function UpdateRankDishes() external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function setStaffAgentStore(address _staffAgentSC)external ;
    function grantRole(bytes32 role, address account) external;
    function CalculateAndValidateOptions(
        string memory dishCode,
        SelectedOption[] memory selectedOptions
    ) external view returns (uint totalOptionsPrice, OptionSelected[] memory optionsSelected) ;
    function getDishOrderIndex(string memory dishCode) external view returns (uint) ;
    function GetActiveStaffAddressesByDate(uint date) external view returns (address[] memory);

    // Added 09/03/2026 
    function mergeTables(uint256[] memory _number, bytes32 sessionId, uint256 _numPeople, TABLE_STATUS _status) external;
    function separateTables(uint256[] memory _numbers) external;
    function isSessionAvailable(uint tableId, uint _numPeople) external returns(bool);
    function transferTable(uint256 _fromTable, uint256 _toTable) external;
    function removeTablesFromMerge(uint256[] memory _tableNumbers) external;
    function checkSessionIdFromTableMerge(uint256 tableNum) external returns(bytes32);
    function ClearTable(uint256 tableNum, bytes32 sessionId, uint _numPeople) external;
    function mergeMoreTables(uint256[] memory _tableNumbers, uint256 tableParent ,uint256 _numPeople) external;
     function updateTableFromOrder(
        uint256 _tableNumber, 
        bytes32 sessionId, 
        uint256 _numPeople
    ) external;

    function branchId() external view returns (uint256);
}
interface ICardTokenManager {
    function getPoolInfo(string memory _transactionID) external view returns(PoolInfo memory);
    function getTx(string memory txID)external view returns(TransactionStatus memory transaction);
}
interface IOrder {
    function isValidAmount(bytes32 _paymentId,uint _amount)external view returns(bool);
}

  