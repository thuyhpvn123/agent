// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IRestaurant.sol";
import "./interfaces/IManagement.sol";
import "./lib/DateTimeTZ.sol";
// import "forge-std/console.sol";

contract RestaurantReporting is 
    Initializable, 
    AccessControlUpgradeable,
    OwnableUpgradeable 
    // UUPSUpgradeable    
{
    bytes32 public ROLE_ADMIN;
    bytes32 public ROLE_STAFF;
    
    IManagement public MANAGEMENT;
    
    // Additional reporting data
    mapping(uint => uint) public previousPeriodData; // period => value for comparison
    mapping(string => mapping(uint => uint)) public dishRankingHistory; // dishCode => period => ranking
    //
        // Split reporting data into separate mappings to avoid stack depth
    // Daily report basic data
    mapping(uint => uint) public dailyNewCustomers;
    mapping(uint => uint) public dailyFemaleCustomers;
    mapping(uint => uint) public dailyDineInOrders;
    mapping(uint => uint) public dailyTakeAwayOrders;
    mapping(uint => uint) public dailyDineInRevenue;
    mapping(uint => uint) public dailyTakeAwayRevenue;
    
    // Daily report customer segments
    mapping(uint => uint) public dailySingleCustomers;
    mapping(uint => uint) public dailyCoupleCustomers;
    mapping(uint => uint) public dailyTripleCustomers;
    mapping(uint => uint) public dailyGroupCustomers;
    
    // Age groups - separate mapping for each age group
    mapping(uint => mapping(uint8 => uint)) public dailyAgeGroups; // date => ageGroup => count
    mapping(uint => mapping(uint8 => uint)) public monthlyAgeGroups;
    
    // Ratings - separate mappings
    mapping(uint => mapping(uint8 => uint)) public dailyServiceRatings; // date => rating(1-5) => count
    mapping(uint => mapping(uint8 => uint)) public dailyFoodRatings;
    mapping(uint => mapping(uint8 => uint)) public monthlyServiceRatings;
    mapping(uint => mapping(uint8 => uint)) public monthlyFoodRatings;
    
    // Monthly data (similar structure)
    mapping(uint => uint) public monthlyNewCustomers;
    mapping(uint => uint) public monthlyFemaleCustomers;
    mapping(uint => uint) public monthlyDineInOrders;
    mapping(uint => uint) public monthlyTakeAwayOrders;
    mapping(uint => uint) public monthlyDineInRevenue;
    mapping(uint => uint) public monthlyTakeAwayRevenue;
    mapping(uint => uint) public monthlySingleCustomers;
    mapping(uint => uint) public monthlyCoupleCustomers;
    mapping(uint => uint) public monthlyTripleCustomers;
    mapping(uint => uint) public monthlyGroupCustomers;
    // Dish data
    mapping(string => uint) public dishRanking;
    mapping(string => bool) public dishIsNew;
    mapping(string => mapping(uint => uint)) public dishDailyRevenue; // dishCode => date => revenue
    mapping(string => mapping(uint => uint)) public dishDailyOrders; // dishCode => date => orders
    mapping(string => mapping(uint => uint)) public dishMonthlyRevenue; // dishCode => date => revenue
    mapping(string => mapping(uint => uint)) public dishMonthlyOrders; // dishCode => date => orders

    // Basic tracking for reports - split into smaller mappings
    mapping(uint => uint) public dailyRevenue;
    mapping(uint => uint) public dailyOrders;
    mapping(uint => uint) public dailyCustomers;
    mapping(uint => uint) public monthlyRevenue;
    mapping(uint => uint) public monthlyOrders;
    mapping(uint => uint) public monthlyCustomers;
    
    mapping(string => uint) public dishTotalRevenue;
    mapping(string => uint) public dishTotalOrders;
    mapping(string => uint) public dishStartTime;
    uint public totalCustomersAllTime;
    uint public totalOrdersAllTime;
    uint public totalRevenueAllTime;
    uint public serviceStartTime;
    mapping(uint => uint) public mRevenueTarget; //year-> revenue target
    Target[] public revenueTargets;
    mapping(uint => uint) public yearlyOrders;
    mapping(uint => uint) public yearlyRevenues;
    mapping(string =>uint[]) public orderCreatedTimes; //discode to order createdTimes
     mapping(string=> bool) public orderCreatedTimesSet;
    // RankReport[] public rankReport;
    mapping(uint => uint) public dailyReturningCustomersOneTime;
    mapping(uint => uint) public dailyReturningCustomersFromTwoTimes;
    mapping(uint => uint) public monthlyReturningCustomersOneTime;
    mapping(uint => uint) public monthlyReturningCustomersFromTwoTimes;

    uint256[44] private __gap;

    // constructor() {
    //     _disableInitializers();
    // }

    function initialize(address _management) public initializer {
        __Ownable_init(msg.sender);
        __AccessControl_init();
        // __UUPSUpgradeable_init();
        
        ROLE_ADMIN = keccak256("ROLE_ADMIN");
        ROLE_STAFF = keccak256("ROLE_STAFF");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ROLE_ADMIN, msg.sender);
        
        MANAGEMENT = IManagement(_management);
    }
    
    // function _authorizeUpgrade(address newImplementation) internal override  {}
    function setManangement(address _management) external onlyRole(ROLE_ADMIN) {
        MANAGEMENT = IManagement(_management);
    }
        // hàm này contract order gọi update
    function UpdateDailyStats(uint date, uint revenue, uint orders) external {
        dailyRevenue[date] += revenue;
        dailyOrders[date] += orders;
        
        uint month = _getMonth(date * 86400);
        monthlyRevenue[month] += revenue;
        monthlyOrders[month] += orders;
        
        uint year = _getYear(date * 86400);
        yearlyOrders[year] += orders;
        yearlyRevenues[year] += revenue;

        totalRevenueAllTime += revenue;
        totalOrdersAllTime += orders;
        
    }

    function UpdateServiceRating(uint date, uint8 rating, uint count) external {
        require(rating >= 1 && rating <= 5, "Invalid rating");
        dailyServiceRatings[date][rating] += count;
        
        uint month = _getMonth(date * 86400);
        monthlyServiceRatings[month][rating] += count;
    }

    function UpdateFoodRating(uint date, uint8 rating, uint count) external {
        require(rating >= 1 && rating <= 5, "Invalid rating");
        dailyFoodRatings[date][rating] += count;
        
        uint month = _getMonth(date * 86400);
        monthlyFoodRatings[month][rating] += count;
    }
    //Order gọi
    function UpdateDishDailyData(
        string memory dishCode,
        uint createdAt,
        uint revenue,
        uint orders
    ) external {
        orderCreatedTimes[dishCode].push(createdAt);
        orderCreatedTimesSet[dishCode] = true;
        uint date = _getDay(createdAt);
        uint month = _getMonth(createdAt);
        dishDailyRevenue[dishCode][date] += revenue;
        dishDailyOrders[dishCode][date] += orders;
        dishMonthlyRevenue[dishCode][month] += revenue;
        dishMonthlyOrders[dishCode][month] += orders;

    }
    function GetOrderCreatedTimes(
        string memory dishCode,
        uint from,
        uint to
    ) external view returns (uint[] memory) {
        uint[] storage allTimes = orderCreatedTimes[dishCode];
        uint totalLength = allTimes.length;
        
        if(totalLength == 0){
            return new uint[](0);
        }
        
        require(from <= to, "Invalid range");
        
        // Bước 1: Đếm số phần tử thỏa mãn điều kiện
        uint count = 0;
        for(uint i = 0; i < totalLength; i++){
            if(allTimes[i] >= from && allTimes[i] <= to){
                count++;
            }
        }
        
        if(count == 0){
            return new uint[](0);
        }
        
        // Bước 2: Copy dữ liệu
        uint[] memory result = new uint[](count);
        uint resultIndex = 0;
        
        for (uint i = 0; i < totalLength; i++) {  // ✅ Lặp qua TẤT CẢ allTimes
            if (allTimes[i] >= from && allTimes[i] <= to) {
                result[resultIndex] = allTimes[i];
                resultIndex++;
            }        
        }
        
        return result;
    }   
    function UpdateDishStats(string memory dishCode, uint revenue, uint orders) external {
        dishTotalRevenue[dishCode] += revenue;
        dishTotalOrders[dishCode] += orders;
        
    }
    // Hàm tối ưu - sử dụng dishOrderIndex đã được sort sẵn từ Management
    function AutoUpdateDishRankingsFromSortedIndex(uint date) public {
        // Lấy tất cả dish codes
        string[] memory dishCodes = MANAGEMENT.GetAllDishCodes();
        
        if (dishCodes.length == 0) return;
        
        // dishOrderIndex đã được sort trong SortDishesWithOrderRange
        // index trong dishesWithOrder chính là ranking (0 = rank 1, 1 = rank 2,...)
        for (uint i = 0; i < dishCodes.length; i++) {
            string memory dishCode = dishCodes[i];
            
            // Lấy index đã được sort từ Management
            uint sortedIndex = MANAGEMENT.getDishOrderIndex(dishCode);
            
            // sortedIndex là vị trí trong mảng đã sort (0-based)
            // Ranking bắt đầu từ 1, nên ranking = sortedIndex + 1
            uint ranking = sortedIndex + 1;
            
            // Cập nhật ranking
            dishRanking[dishCode] = ranking;
            dishRankingHistory[dishCode][date] = ranking;
        }
    }

    function BatchUpdateDishStats(
        string[] memory dishCodes,
        uint[] memory revenues,
        uint[] memory ordersList
    ) external {
        require(
            dishCodes.length == revenues.length && 
            dishCodes.length == ordersList.length,
            "Input length mismatch"
        );
        uint date = _getDay(block.timestamp);
        for (uint i = 0; i < dishCodes.length; i++) {
            dishTotalRevenue[dishCodes[i]] += revenues[i];
            dishTotalOrders[dishCodes[i]] += ordersList[i];
        }
        AutoUpdateDishRankingsFromSortedIndex(date);
    }
    function UpdateDishRanking(string memory dishCode, uint ranking) external onlyRole(ROLE_ADMIN) {
        dishRanking[dishCode] = ranking;
    }

    // Update dish rankings (to be called periodically by admin)
    function UpdateDishRankings(
        string[] memory dishCodes,
        uint[] memory rankings,
        uint period //date
    ) external onlyRole(ROLE_ADMIN) {
        require(dishCodes.length == rankings.length, "Arrays length mismatch");
        
        for (uint i = 0; i < dishCodes.length; i++) {
            dishRankingHistory[dishCodes[i]][period] = rankings[i];
            MANAGEMENT.UpdateDishRanking(dishCodes[i], rankings[i]);
        }
    }

    // Batch update functions for better gas efficiency
    function BatchUpdateDishRankings(
        string[] memory dishCodes,
        uint[] memory rankings,
        uint[] memory periods
    ) external onlyRole(ROLE_ADMIN) {
        require(dishCodes.length == rankings.length && rankings.length == periods.length, "Arrays length mismatch");
        
        for (uint i = 0; i < dishCodes.length; i++) {
            dishRankingHistory[dishCodes[i]][periods[i]] = rankings[i];
            MANAGEMENT.UpdateDishRanking(dishCodes[i], rankings[i]);
        }
    }
    //luong Order goi de demo
    function UpdateNewCustomerData( 
        uint date,
        uint numberOfVisit
    ) external{
        uint month = _getMonth(date * 86400);
        
        if(numberOfVisit == 1) {
            dailyNewCustomers[date] += 1;
            monthlyNewCustomers[month] += 1;
        }else if(numberOfVisit == 2){
            dailyReturningCustomersOneTime[date] += 1;
            monthlyReturningCustomersOneTime[month] +=1;
        }else{
            dailyReturningCustomersFromTwoTimes[date] += 1;
            monthlyReturningCustomersFromTwoTimes[month] +=1;
        }
    }
        // Batch update functions to avoid multiple transactions
    function BatchUpdateDailyData(
        uint date,
        uint newCustomers,
        uint femaleCustomers,
        uint dineInOrders,
        uint takeAwayOrders,
        uint dineInRevenue,
        uint takeAwayRevenue

    ) external {
        dailyNewCustomers[date] += newCustomers;
        dailyFemaleCustomers[date] += femaleCustomers;
        dailyDineInOrders[date] += dineInOrders;
        dailyTakeAwayOrders[date] += takeAwayOrders;
        dailyDineInRevenue[date] += dineInRevenue;
        dailyTakeAwayRevenue[date] += takeAwayRevenue;
        // Update monthly data
        uint month = _getMonth(date * 86400);
        monthlyNewCustomers[month] += newCustomers;
        monthlyFemaleCustomers[month] += femaleCustomers;
        monthlyDineInOrders[month] += dineInOrders;
        monthlyTakeAwayOrders[month] += takeAwayOrders;
        monthlyDineInRevenue[month] += dineInRevenue;
        monthlyTakeAwayRevenue[month] += takeAwayRevenue;
    }

    function BatchUpdateCustomerSegments(
        uint date,
        uint singleCustomers,
        uint coupleCustomers,
        uint tripleCustomers,
        uint groupCustomers
    ) external {
        dailySingleCustomers[date] += singleCustomers;
        dailyCoupleCustomers[date] += coupleCustomers;
        dailyTripleCustomers[date] += tripleCustomers;
        dailyGroupCustomers[date] += groupCustomers;
        
        uint month = _getMonth(date * 86400);
        monthlySingleCustomers[month] += singleCustomers;
        monthlyCoupleCustomers[month] += coupleCustomers;
        monthlyTripleCustomers[month] += tripleCustomers;
        monthlyGroupCustomers[month] += groupCustomers;
    }

    function UpdateAgeGroup(uint date, uint8 ageGroup, uint count) external {
        require(ageGroup < 10, "Invalid age group");
        dailyAgeGroups[date][ageGroup] += count;
        
        uint month = _getMonth(date * 86400);
        monthlyAgeGroups[month][ageGroup] += count;
    }

    //hàm này cameraAI sẽ gọi. tam thoi de Order goi
    function UpdateDailyStatsCustomer(uint date, uint customers) external {
        dailyCustomers[date] += customers;
        
        uint month = _getMonth(date * 86400);
        monthlyCustomers[month] += customers;
        
        totalCustomersAllTime += customers;
    }
  

    // Comparison functions - simplified to avoid stack depth issues
    function GetDailyComparison(uint currentDate, uint previousDate) 
        external view returns (ReportComparison memory comparison) 
    {
        DailyReport memory current = GetDailyReport(currentDate);
        DailyReport memory previous = GetDailyReport(previousDate);
        return _calculateBasicComparison(current, previous);
    }
    // vd tháng 1 trùyen la 1, năm 2025 truyen la 2025
    function GetMonthlyComparison(uint currentMonth, uint previousMonth,uint realCurrentYear,uint realPreviousYear) 
        external view returns (ReportComparison memory comparison) 
    {
        MonthlyReport memory current = GetMonthlyReport(realCurrentYear,currentMonth);
        MonthlyReport memory previous = GetMonthlyReport(realPreviousYear,previousMonth);
        
        return _calculateMonthlyComparison(current, previous);
    }

    function _calculateBasicComparison(
        DailyReport memory current,
        DailyReport memory previous
    ) internal pure returns (ReportComparison memory comparison) {
        // Customer growth
        if (previous.totalCustomers > 0) {
            if (current.totalCustomers >= previous.totalCustomers) {
                comparison.customerGrowthPercent = ((current.totalCustomers - previous.totalCustomers) * 100) / previous.totalCustomers;
                comparison.customerGrowthPositive = true;
            } else {
                comparison.customerGrowthPercent = ((previous.totalCustomers - current.totalCustomers) * 100) / previous.totalCustomers;
                comparison.customerGrowthPositive = false;
            }
        }
        // Revenue growth
        if (previous.totalRevenue > 0) {
            if (current.totalRevenue >= previous.totalRevenue) {
                comparison.revenueGrowthPercent = ((current.totalRevenue - previous.totalRevenue) * 100) / previous.totalRevenue;
                comparison.revenueGrowthPositive = true;
            } else {
                comparison.revenueGrowthPercent = ((previous.totalRevenue - current.totalRevenue) * 100) / previous.totalRevenue;
                comparison.revenueGrowthPositive = false;
            }
        }
        
        // Order growth
        if (previous.totalOrders > 0) {
            if (current.totalOrders >= previous.totalOrders) {
                comparison.orderGrowthPercent = ((current.totalOrders - previous.totalOrders) * 100) / previous.totalOrders;
                comparison.orderGrowthPositive = true;
            } else {
                comparison.orderGrowthPercent = ((previous.totalOrders - current.totalOrders) * 100) / previous.totalOrders;
                comparison.orderGrowthPositive = false;
            }
        }

        // Calculate percentages and averages
        comparison.averageOrderValue = current.totalOrders > 0 ? 
            current.totalRevenue / current.totalOrders : 0;
        comparison.previousAverageOrderValue = previous.totalOrders > 0 ? 
            previous.totalRevenue / previous.totalOrders : 0;
            
        if (current.totalCustomers > 0) {
            comparison.newCustomerPercentage = (current.newCustomers * 100) / current.totalCustomers;
            comparison.femaleCustomerPercentage = (current.femaleCustomers * 100) / current.totalCustomers;
        }
        
        if (current.totalOrders > 0) {
            comparison.dineInPercentage = (current.dineInOrders * 100) / current.totalOrders;
            comparison.takeAwayPercentage = (current.takeAwayOrders * 100) / current.totalOrders;
        }
        
        if (current.newCustomerOrders > 0) {
            comparison.averageNewCustomerOrderValue = current.newCustomerRevenue / current.newCustomerOrders;
        }
        if (current.returningCustomerOrders > 0) {
            comparison.averageReturningCustomerOrderValue = current.returningCustomerRevenue / current.returningCustomerOrders;
        }
        if (current.dineInOrders > 0) {
            comparison.averageDineInOrderValue = current.dineInRevenue / current.dineInOrders;
        }
        if (current.takeAwayOrders > 0) {
            comparison.averageTakeAwayOrderValue = current.takeAwayRevenue / current.takeAwayOrders;
        }
    }

    function _calculateMonthlyComparison(
        MonthlyReport memory current,
        MonthlyReport memory previous
    ) internal pure returns (ReportComparison memory comparison) {
        // Customer growth
        if (previous.totalCustomers > 0) {
            if (current.totalCustomers >= previous.totalCustomers) {
                comparison.customerGrowthPercent = ((current.totalCustomers - previous.totalCustomers) * 100) / previous.totalCustomers;
                comparison.customerGrowthPositive = true;
            } else {
                comparison.customerGrowthPercent = ((previous.totalCustomers - current.totalCustomers) * 100) / previous.totalCustomers;
                comparison.customerGrowthPositive = false;
            }
        }
        
        // Revenue growth
        if (previous.totalRevenue > 0) {
            if (current.totalRevenue >= previous.totalRevenue) {
                comparison.revenueGrowthPercent = ((current.totalRevenue - previous.totalRevenue) * 100) / previous.totalRevenue;
                comparison.revenueGrowthPositive = true;
            } else {
                comparison.revenueGrowthPercent = ((previous.totalRevenue - current.totalRevenue) * 100) / previous.totalRevenue;
                comparison.revenueGrowthPositive = false;
            }
        }
        
        // Order growth
        if (previous.totalOrders > 0) {
            if (current.totalOrders >= previous.totalOrders) {
                comparison.orderGrowthPercent = ((current.totalOrders - previous.totalOrders) * 100) / previous.totalOrders;
                comparison.orderGrowthPositive = true;
            } else {
                comparison.orderGrowthPercent = ((previous.totalOrders - current.totalOrders) * 100) / previous.totalOrders;
                comparison.orderGrowthPositive = false;
            }
        }

        comparison.averageOrderValue = current.totalOrders > 0 ? 
            current.totalRevenue / current.totalOrders : 0;
        comparison.previousAverageOrderValue = previous.totalOrders > 0 ? 
            previous.totalRevenue / previous.totalOrders : 0;
            
        if (current.totalCustomers > 0) {
            comparison.newCustomerPercentage = (current.newCustomers * 100) / current.totalCustomers;
            comparison.femaleCustomerPercentage = (current.femaleCustomers * 100) / current.totalCustomers;
        }
        
        if (current.totalOrders > 0) {
            comparison.dineInPercentage = (current.dineInOrders * 100) / current.totalOrders;
            comparison.takeAwayPercentage = (current.takeAwayOrders * 100) / current.totalOrders;
        }
    }

    // Dish comparison  rank 
    function GetDishRankMonthlyComparison(
        string memory dishCode,
        uint currentStartPeriod, //date
        uint currentEndPeriod,
        uint previousStartPeriod, //date
        uint previousEndPeriod
     ) external view returns (DishComparison memory comparison) {
        (,,uint currentAverragetRank,) = GetDishPerformanceSummary(dishCode,currentStartPeriod, currentEndPeriod);
        (,,uint previousAverragetRank,) = GetDishPerformanceSummary(dishCode, previousStartPeriod,previousEndPeriod);
        
        comparison.currentRanking = currentAverragetRank;
        comparison.previousRanking = previousAverragetRank;
        
        if (comparison.previousRanking > 0) {
            if (comparison.currentRanking < comparison.previousRanking) {
                comparison.rankingChange = comparison.previousRanking - comparison.currentRanking;
                comparison.rankingImproved = true;
            } else if (comparison.currentRanking > comparison.previousRanking) {
                comparison.rankingChange = comparison.currentRanking - comparison.previousRanking;
                comparison.rankingImproved = false;
            }
        }
        DishMonthlyReport memory current = GetDishMonthlyReport(dishCode, currentEndPeriod/30);
        (DishWithFirstPrice[] memory currentTopDishesMonthly,) = MANAGEMENT.Get5TopDishesByTime(currentEndPeriod/30,false);
         uint bestSellerOrderCount ;
        if(currentTopDishesMonthly.length >0){
            bestSellerOrderCount= currentTopDishesMonthly[0].dish.orderNum; 
        }
        // Order count comparison
        if (bestSellerOrderCount > 0) {
            if (current.orderCount >= bestSellerOrderCount) {
                comparison.orderCountGrowthPercent = ((current.orderCount - bestSellerOrderCount) * 100) / bestSellerOrderCount;
                comparison.orderCountGrowthPositive = true;
            } else {
                comparison.orderCountGrowthPercent = ((bestSellerOrderCount - current.orderCount) * 100) / bestSellerOrderCount;
                comparison.orderCountGrowthPositive = false;
            }
        }
    }
    function GetDishRankDailyComparison(
        string memory dishCode,
        uint currentPeriod,
        uint previousPeriod
    ) external view returns (DishComparison memory comparison) {
        DishDailyReport memory current = GetDishDailyReport(dishCode, currentPeriod);
        // DishDailyReport memory previous = GetDishDailyReport(dishCode, previousPeriod);
        
        comparison.currentRanking = dishRankingHistory[dishCode][currentPeriod];
        comparison.previousRanking = dishRankingHistory[dishCode][previousPeriod];
        
        if (comparison.previousRanking > 0) {
            if (comparison.currentRanking < comparison.previousRanking) {
                comparison.rankingChange = comparison.previousRanking - comparison.currentRanking;
                comparison.rankingImproved = true;
            } else if (comparison.currentRanking > comparison.previousRanking) {
                comparison.rankingChange = comparison.currentRanking - comparison.previousRanking;
                comparison.rankingImproved = false;
            }
        }
        (DishWithFirstPrice[] memory currentTopDishes,) = MANAGEMENT.Get5TopDishesByTime(currentPeriod,true);
        uint bestSellerOrderCount;
        if(currentTopDishes.length >0){
            bestSellerOrderCount = currentTopDishes[0].dish.orderNum; 
        }
        
        // Order count comparison with bestSeller
        if (bestSellerOrderCount > 0) {
            if (current.orderCount >= bestSellerOrderCount) {
                comparison.orderCountGrowthPercent = ((current.orderCount - bestSellerOrderCount) * 100) / bestSellerOrderCount;
                comparison.orderCountGrowthPositive = true;
            } else {
                comparison.orderCountGrowthPercent = ((bestSellerOrderCount - bestSellerOrderCount) * 100) / bestSellerOrderCount;
                comparison.orderCountGrowthPositive = false;
            }
        }
    }

    // Voucher comparison functions
    function GetVoucherComparison(
        uint currentFromTime,
        uint currentToTime,
        uint previousFromTime,
        uint previousToTime
    ) external view returns (VoucherComparison memory comparison) {
        VoucherReport memory current = MANAGEMENT.GetVoucherReport(currentFromTime, currentToTime);
        VoucherReport memory previous = MANAGEMENT.GetVoucherReport(previousFromTime, previousToTime);
        
        // Calculate growth percentages
        if (previous.totalUsed > 0) {
            if (current.totalUsed >= previous.totalUsed) {
                comparison.usedGrowthPercent = ((current.totalUsed - previous.totalUsed) * 100) / previous.totalUsed;
                comparison.usedGrowthPositive = true;
            } else {
                comparison.usedGrowthPercent = ((previous.totalUsed - current.totalUsed) * 100) / previous.totalUsed;
                comparison.usedGrowthPositive = false;
            }
        }
        
        if (previous.totalUnused > 0) {
            if (current.totalUnused >= previous.totalUnused) {
                comparison.unusedGrowthPercent = ((current.totalUnused - previous.totalUnused) * 100) / previous.totalUnused;
                comparison.unusedGrowthPositive = true;
            } else {
                comparison.unusedGrowthPercent = ((previous.totalUnused - current.totalUnused) * 100) / previous.totalUnused;
                comparison.unusedGrowthPositive = false;
            }
        }
        
        if (previous.totalExpired > 0) {
            if (current.totalExpired >= previous.totalExpired) {
                comparison.expiredGrowthPercent = ((current.totalExpired - previous.totalExpired) * 100) / previous.totalExpired;
                comparison.expiredGrowthPositive = true;
            } else {
                comparison.expiredGrowthPercent = ((previous.totalExpired - current.totalExpired) * 100) / previous.totalExpired;
                comparison.expiredGrowthPositive = false;
            }
        }
    }

    // Rating comparison functions
    function GetRatingComparison(
        uint currentPeriod,
        uint previousPeriod,
        bool isDaily,
        uint realYear
    ) external view returns (RatingComparison memory comparison) {
        uint[5] memory currentServiceRatings;
        uint[5] memory previousServiceRatings;
        uint[5] memory currentFoodRatings;
        uint[5] memory previousFoodRatings;
        
        if (isDaily) {
            DailyReport memory currentReport = GetDailyReport(currentPeriod);
            DailyReport memory previousReport = GetDailyReport(previousPeriod);
            
            currentServiceRatings = currentReport.serviceRatings;
            previousServiceRatings = previousReport.serviceRatings;
            currentFoodRatings = currentReport.foodRatings;
            previousFoodRatings = previousReport.foodRatings;
        } else {
            MonthlyReport memory currentReport = GetMonthlyReport(realYear,currentPeriod);
            MonthlyReport memory previousReport = GetMonthlyReport(realYear,previousPeriod);
            
            currentServiceRatings = currentReport.serviceRatings;
            previousServiceRatings = previousReport.serviceRatings;
            currentFoodRatings = currentReport.foodRatings;
            previousFoodRatings = previousReport.foodRatings;
        }
        
        comparison = _calculateRatingComparison(
            currentServiceRatings,
            previousServiceRatings,
            currentFoodRatings,
            previousFoodRatings
        );
    }


    function _calculateRatingComparison(
        uint[5] memory currentServiceRatings,
        uint[5] memory previousServiceRatings,
        uint[5] memory currentFoodRatings,
        uint[5] memory previousFoodRatings
    ) internal pure returns (RatingComparison memory comparison) {
        // Calculate totals
        uint totalCurrentService = 0;
        uint totalPreviousService = 0;
        uint totalCurrentFood = 0;
        uint totalPreviousFood = 0;
        
        for (uint i = 0; i < 5; i++) {
            totalCurrentService += currentServiceRatings[i];
            totalPreviousService += previousServiceRatings[i];
            totalCurrentFood += currentFoodRatings[i];
            totalPreviousFood += previousFoodRatings[i];
        }
        
        for (uint i = 0; i < 5; i++) {
            if (totalCurrentService > 0) {
                comparison.currentServicePercentages[i] = (currentServiceRatings[i] * 100) / totalCurrentService;
            }
            if (totalPreviousService > 0) {
                comparison.previousServicePercentages[i] = (previousServiceRatings[i] * 100) / totalPreviousService;
            }
            if (totalCurrentFood > 0) {
                comparison.currentFoodPercentages[i] = (currentFoodRatings[i] * 100) / totalCurrentFood;
            }
            if (totalPreviousFood > 0) {
                comparison.previousFoodPercentages[i] = (previousFoodRatings[i] * 100) / totalPreviousFood;
            }
            
            // Calculate changes
            if (comparison.previousServicePercentages[i] > 0) {
                if (comparison.currentServicePercentages[i] >= comparison.previousServicePercentages[i]) {
                    comparison.serviceRatingChanges[i] = comparison.currentServicePercentages[i] - comparison.previousServicePercentages[i];
                    comparison.serviceRatingIncreased[i] = true;
                } else {
                    comparison.serviceRatingChanges[i] = comparison.previousServicePercentages[i] - comparison.currentServicePercentages[i];
                    comparison.serviceRatingIncreased[i] = false;
                }
            }
            
            if (comparison.previousFoodPercentages[i] > 0) {
                if (comparison.currentFoodPercentages[i] >= comparison.previousFoodPercentages[i]) {
                    comparison.foodRatingChanges[i] = comparison.currentFoodPercentages[i] - comparison.previousFoodPercentages[i];
                    comparison.foodRatingIncreased[i] = true;
                } else {
                    comparison.foodRatingChanges[i] = comparison.previousFoodPercentages[i] - comparison.currentFoodPercentages[i];
                    comparison.foodRatingIncreased[i] = false;
                }
            }
        }
    }


    // Functions to get favorite dishes with more details
    function Get5FavoriteDishesByDay(uint256 dayOrMonth,bool isDay) external view returns (FavoriteDish[] memory favoriteDishes) {
        (DishWithFirstPrice[] memory topDishCodes,) = MANAGEMENT.Get5TopDishesByTime(dayOrMonth,isDay);
        favoriteDishes = new FavoriteDish[](topDishCodes.length);
        
        for (uint i = 0; i < topDishCodes.length; i++) {
            string memory dishCode = topDishCodes[i].dish.code;
            // Dish memory dish = MANAGEMENT.GetDish(dishCode);
            (uint revenue, uint orders, ) = GetDishStats(dishCode);
            
            favoriteDishes[i] = FavoriteDish({
                dishWithFirstPrice: topDishCodes[i],
                totalOrders: orders,
                orderPercentage: 0, // Would need more complex calculation
                totalRevenue: revenue,
                revenuePercentage: 0 // Would need more complex calculation
            });
        }
    }


    // Get dish ranking history
    function GetDishRankingHistory(string memory dishCode, uint period) external view returns (uint ranking) {
        return dishRankingHistory[dishCode][period];
    }

    // Get multiple periods ranking for a dish
    function GetDishRankingTrend(
        string memory dishCode, 
        uint[] memory periods
    ) external view returns (uint[] memory rankings) {
        rankings = new uint[](periods.length);
        for (uint i = 0; i < periods.length; i++) {
            rankings[i] = dishRankingHistory[dishCode][periods[i]];
        }
    }

    // Advanced analytics functions
    function GetDishPerformanceSummary(
        string memory dishCode,
        uint startPeriod,
        uint endPeriod
    ) public view returns (
        uint totalRevenue,
        uint totalOrders,
        uint averageRanking,
        bool isConsistentlyPopular
    ) {
        (totalRevenue, totalOrders, ) = GetDishStats(dishCode);
        
        uint rankingSum = 0;
        uint rankingCount = 0;
        uint highRankings = 0; // Rankings 1-5
        
        for (uint period = startPeriod; period <= endPeriod; period += 86400) { // Daily periods
            uint ranking = dishRankingHistory[dishCode][period];
            if (ranking > 0) {
                rankingSum += ranking;
                rankingCount++;
                if (ranking <= 5) {
                    highRankings++;
                }
            }
        }
        
        averageRanking = rankingCount > 0 ? rankingSum / rankingCount : 0;
        isConsistentlyPopular = rankingCount > 0 && (highRankings * 100 / rankingCount) >= 70; // 70% of time in top 5
    }

    // Restaurant performance overview
    function GetRestaurantOverview(uint period, bool isDaily) external view returns (
        uint totalRevenue,
        uint totalOrders,
        uint totalCustomers,
        uint averageOrderValue,
        uint topDishesCount,
        uint activeDishesCount
    ) {
        if (isDaily) {
            (totalRevenue, totalOrders, totalCustomers) = MANAGEMENT.GetDailyStats(period);
        } else {
            (totalRevenue, totalOrders, totalCustomers) = MANAGEMENT.GetMonthlyStats(period);
        }
        
        averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;
        
        // Get total dish count from management
        activeDishesCount = MANAGEMENT.GetDishCount();
        
        // Assume top dishes are top 10% or at least top 5
        topDishesCount = activeDishesCount > 50 ? activeDishesCount / 10 : (activeDishesCount > 5 ? 5 : activeDishesCount);
    }

    // Period comparison helper
    function ComparePeriods(
        uint currentPeriod,
        uint previousPeriod,
        bool isDaily,
        uint realCurrentYear,
        uint realPreviousYear
    ) external view returns (
        ReportComparison memory comparison,
        string memory performanceStatus
    ) {
        if (isDaily) {
            comparison = this.GetDailyComparison(currentPeriod, previousPeriod);
        } else {
            comparison = this.GetMonthlyComparison(currentPeriod, previousPeriod,realCurrentYear,realPreviousYear);
        }
        
        // Determine performance status
        uint positiveIndicators = 0;
        uint totalIndicators = 3;
        
        if (comparison.customerGrowthPositive) positiveIndicators++;
        if (comparison.revenueGrowthPositive) positiveIndicators++;
        if (comparison.orderGrowthPositive) positiveIndicators++;
        
        if (positiveIndicators == totalIndicators) {
            performanceStatus = "Excellent";
        } else if (positiveIndicators >= 2) {
            performanceStatus = "Good";
        } else if (positiveIndicators == 1) {
            performanceStatus = "Fair";
        } else {
            performanceStatus = "Needs Improvement";
        }
    }

    // Admin functions
    function SetManagement(address _management) external onlyRole(ROLE_ADMIN) {
        require(_management != address(0), "Invalid management address");
        MANAGEMENT = IManagement(_management);
    }

    function GrantStaffRole(address account) external onlyRole(ROLE_ADMIN) {
        require(account != address(0), "Invalid account address");
        _grantRole(ROLE_STAFF, account);
    }

    function RevokeStaffRole(address account) external onlyRole(ROLE_ADMIN) {
        _revokeRole(ROLE_STAFF, account);
    }

    // Helper function to check if address has admin or staff role
    function hasAdminOrStaffRole(address account) external view returns (bool) {
        return hasRole(ROLE_ADMIN, account) || hasRole(ROLE_STAFF, account);
    }

    // Get management contract address
    function getManagementAddress() external view returns (address) {
        return address(MANAGEMENT);
    }

    // Emergency functions
    function pause() external onlyRole(ROLE_ADMIN) {
        // Implementation would depend on if you want to add Pausable functionality
    }

    function unpause() external onlyRole(ROLE_ADMIN) {
        // Implementation would depend on if you want to add Pausable functionality
    }

    function GetDailyReport(uint date) public view returns (DailyReport memory) {
        DailyReport memory report;
        
        // Basic stats
        report.date = date;
        report.totalCustomers = dailyCustomers[date];
        report.totalRevenue = dailyRevenue[date];
        report.totalOrders = dailyOrders[date];
        
        // Customer segments
        report.newCustomers = dailyNewCustomers[date];
        report.femaleCustomers = dailyFemaleCustomers[date];
        report.returningCustomersOneTime = dailyReturningCustomersOneTime[date];
        report.returningCustomersFromTwoTimes = dailyReturningCustomersFromTwoTimes[date];
        // Order types
        report.dineInOrders = dailyDineInOrders[date];
        report.takeAwayOrders = dailyTakeAwayOrders[date];
        report.dineInRevenue = dailyDineInRevenue[date];
        report.takeAwayRevenue = dailyTakeAwayRevenue[date];
        
        // Customer groups
        report.singleCustomers = dailySingleCustomers[date];
        report.coupleCustomers = dailyCoupleCustomers[date];
        report.tripleCustomers = dailyTripleCustomers[date];
        report.groupCustomers = dailyGroupCustomers[date];
        
        // Age groups and ratings - build arrays
        for(uint8 i = 0; i < 10; i++) {
            report.ageGroups[i] = dailyAgeGroups[date][i];
        }
        
        for(uint8 i = 0; i < 5; i++) {
            report.serviceRatings[i] = dailyServiceRatings[date][i+1]; // ratings are 1-5
            report.foodRatings[i] = dailyFoodRatings[date][i+1];
        }
        
        return report;
    }
    
    function GetMonthlyReport(uint realYear, uint realMonth) public view returns (MonthlyReport memory) {
        uint monthKey = getMonthKey(realYear, realMonth);
        MonthlyReport memory report;
        
        report.month = monthKey;
        report.totalCustomers = monthlyCustomers[monthKey];
        report.totalRevenue = monthlyRevenue[monthKey];
        report.totalOrders = monthlyOrders[monthKey];
        report.newCustomers = monthlyNewCustomers[monthKey];
        report.femaleCustomers = monthlyFemaleCustomers[monthKey];
        report.dineInOrders = monthlyDineInOrders[monthKey];
        report.takeAwayOrders = monthlyTakeAwayOrders[monthKey];
        report.dineInRevenue = monthlyDineInRevenue[monthKey];
        report.takeAwayRevenue = monthlyTakeAwayRevenue[monthKey];
        report.singleCustomers = monthlySingleCustomers[monthKey];
        report.coupleCustomers = monthlyCoupleCustomers[monthKey];
        report.tripleCustomers = monthlyTripleCustomers[monthKey];
        report.groupCustomers = monthlyGroupCustomers[monthKey];
        report.returningCustomersOneTime = monthlyReturningCustomersOneTime[monthKey];
        report.returningCustomersFromTwoTimes = monthlyReturningCustomersFromTwoTimes[monthKey];
        
        for(uint8 i = 0; i < 10; i++) {
            report.ageGroups[i] = monthlyAgeGroups[monthKey][i];
        }
        
        for(uint8 i = 0; i < 5; i++) {
            report.serviceRatings[i] = monthlyServiceRatings[monthKey][i+1];
            report.foodRatings[i] = monthlyFoodRatings[monthKey][i+1];
        }
        
        return report;
    }
    function getMonthKey(uint realYear, uint realMonth) public pure returns (uint) {
        require(realMonth >= 1 && realMonth <= 12, "Invalid month");
        require(realYear >= 1970, "Year must be >= 1970");
        
        // Tính timestamp cho ngày đầu tháng đó
        uint yearsSince1970 = realYear - 1970;
        uint monthsSince1970 = (yearsSince1970 * 12) + (realMonth - 1);
        uint timestamp = monthsSince1970 * 30 days;
        
        return _getMonth(timestamp);
    }

    // Additional getter functions for individual data points
    function GetDailyNewCustomers(uint date) external view returns (uint) {
        return dailyNewCustomers[date];
    }

    function GetDailyFemaleCustomers(uint date) external view returns (uint) {
        return dailyFemaleCustomers[date];
    }

    function GetDailyDineInStats(uint date) external view returns (uint orders, uint revenue) {
        return (dailyDineInOrders[date], dailyDineInRevenue[date]);
    }

    function GetDailyTakeAwayStats(uint date) external view returns (uint orders, uint revenue) {
        return (dailyTakeAwayOrders[date], dailyTakeAwayRevenue[date]);
    }

    function GetDailyCustomerSegments(uint date) external view returns (
        uint single,
        uint couple,
        uint triple,
        uint group
    ) {
        return (
            dailySingleCustomers[date],
            dailyCoupleCustomers[date],
            dailyTripleCustomers[date],
            dailyGroupCustomers[date]
        );
    }

    function GetDailyAgeGroup(uint date, uint8 ageGroup) external view returns (uint) {
        require(ageGroup < 10, "Invalid age group");
        return dailyAgeGroups[date][ageGroup];
    }

    function GetDailyServiceRating(uint date, uint8 rating) external view returns (uint) {
        require(rating >= 1 && rating <= 5, "Invalid rating");
        return dailyServiceRatings[date][rating];
    }

    function GetDailyFoodRating(uint date, uint8 rating) external view returns (uint) {
        require(rating >= 1 && rating <= 5, "Invalid rating");
        return dailyFoodRatings[date][rating];
    }

    function GetDishDailyStats(string memory dishCode, uint date) external view returns (uint revenue, uint orders) {
        return (dishDailyRevenue[dishCode][date], dishDailyOrders[dishCode][date]);
    }

    function GetDishRanking(string memory dishCode) external view returns (uint) {
        return dishRanking[dishCode];
    }

    function IsDishNew(string memory dishCode) external view returns (bool) {
        return dishIsNew[dishCode];
    }

    // Batch getter functions for efficiency
    function GetDailyAgeGroups(uint date) external view returns (uint[10] memory ageGroups) {
        for (uint8 i = 0; i < 10; i++) {
            ageGroups[i] = dailyAgeGroups[date][i];
        }
    }

    function GetDailyServiceRatings(uint date) external view returns (uint[5] memory ratings) {
        for (uint8 i = 0; i < 5; i++) {
            ratings[i] = dailyServiceRatings[date][i+1]; // ratings are 1-5
        }
    }

    function GetDailyFoodRatings(uint date) external view returns (uint[5] memory ratings) {
        for (uint8 i = 0; i < 5; i++) {
            ratings[i] = dailyFoodRatings[date][i+1]; // ratings are 1-5
        }
    }

    function SetDishAsNotNew(string memory dishCode) external onlyRole(ROLE_ADMIN) {
        dishIsNew[dishCode] = false;
    }

    // Simple getter functions
    function GetDailyStats(uint date) external view returns (uint revenue, uint orders, uint customers) {
        return (dailyRevenue[date], dailyOrders[date], dailyCustomers[date]);
    }
    
    function GetMonthlyStats(uint month) external view returns (uint revenue, uint orders, uint customers) {
        return (monthlyRevenue[month], monthlyOrders[month], monthlyCustomers[month]);
    }
    
    function GetDishStats(string memory dishCode) public view returns (uint revenue, uint orders, uint startTime) {
        return (dishTotalRevenue[dishCode], dishTotalOrders[dishCode], dishStartTime[dishCode]);
    }
    function updateDishStartTime(string memory dishCode,uint createdAt) external {
        dishStartTime[dishCode] = createdAt;
    }
    function GetDishReport(string memory dishCode) external view returns (DishReport memory) {
        return DishReport({
            dishCode: dishCode,
            startSellingTime: dishStartTime[dishCode],
            totalRevenue: dishTotalRevenue[dishCode],
            totalOrders: dishTotalOrders[dishCode],
            ranking: dishRanking[dishCode],
            isNew: dishIsNew[dishCode]
        });
    }

    function GetDishDailyReport(string memory dishCode, uint date) public view returns (DishDailyReport memory) {
        return DishDailyReport({
            date: date,
            revenue: dishDailyRevenue[dishCode][date],
            orderCount: dishDailyOrders[dishCode][date],
            onceOrderCustomers: 0, // Would need additional tracking
            twiceOrderCustomers: 0  // Would need additional tracking
        });
    }
    function GetDishMonthlyReport(string memory dishCode, uint month) public view returns (DishMonthlyReport memory) {
        return DishMonthlyReport({
            month: month,
            revenue: dishMonthlyRevenue[dishCode][month],
            orderCount: dishMonthlyOrders[dishCode][month],
            onceOrderCustomers: 0, // Would need additional tracking
            twiceOrderCustomers: 0  // Would need additional tracking
        });
    }

    // Helper functions
    function _getDay(uint timestamp) internal pure returns (uint) {
        return timestamp / 86400;
        // DateTimeTZ.timestampToDate(timestamp)
    }
    
    function _getMonth(uint timestamp) internal pure returns (uint) {
        return timestamp / (86400 * 30);
    }

    function GetHistoricalSummary() external view returns (HistoricalSummary memory) {
        uint avgOrder = totalOrdersAllTime > 0 ? totalRevenueAllTime / totalOrdersAllTime : 0;
        return HistoricalSummary({
            serviceStartTime: serviceStartTime,
            totalCustomers: totalCustomersAllTime,
            totalOrders: totalOrdersAllTime,
            totalRevenue: totalRevenueAllTime,
            averageOrderValue: avgOrder
        });
    }

    // Emergency data correction functions
    function CorrectDailyStats(
        uint date,
        uint revenue,
        uint orders,
        uint customers
    ) external onlyRole(ROLE_ADMIN) {
        dailyRevenue[date] = revenue;
        dailyOrders[date] = orders;
        dailyCustomers[date] = customers;
    }

    function CorrectDishStats(
        string memory dishCode,
        uint revenue,
        uint orders
    ) external onlyRole(ROLE_ADMIN) {
        dishTotalRevenue[dishCode] = revenue;
        dishTotalOrders[dishCode] = orders;
    }
    function BatchSetDishRankings(
        string[] memory dishCodesArr,
        uint[] memory rankings
    ) external onlyRole(ROLE_ADMIN) {
        require(dishCodesArr.length == rankings.length, "Arrays length mismatch");
        
        for (uint i = 0; i < dishCodesArr.length; i++) {
            dishRanking[dishCodesArr[i]] = rankings[i];
        }
    }
    function SetTargetRevenue(uint year,uint revenueTarget)external {
        require(mRevenueTarget[year] == 0, "this year was set");
        mRevenueTarget[year] = revenueTarget;
        revenueTargets.push(Target({
            year: year,
            revenueTarget: revenueTarget
        })
        );
    }
    function updateTargetRevenue(uint year, uint newRevenueTarget) external {
        require(mRevenueTarget[year] > 0, "Target for this year does not exist");
        
        // Cập nhật mapping
        mRevenueTarget[year] = newRevenueTarget;
        
        // Cập nhật array
        for(uint i = 0; i < revenueTargets.length; i++) {
            if(revenueTargets[i].year == year) {
                revenueTargets[i].revenueTarget = newRevenueTarget;
                break;
            }
        }
    }
    function removeTargetRevenue(uint year ) external {
        delete mRevenueTarget[year];
        for(uint i; i< revenueTargets.length;i++){
            if(revenueTargets[i].year == year){
                revenueTargets[i] = revenueTargets[revenueTargets.length-1];
                revenueTargets.pop();
                break;
            }
        }
    }
    function getAllTargetRevenues()external view returns(Target[] memory){
        return revenueTargets;
    }
    function GetYearlyRevenueByRealYear(uint realYear) external view returns (uint) {
        uint yearKey = getYearKey(realYear);
        return yearlyRevenues[yearKey];
    }
    // Helper: Convert năm thực tế sang year key để query
    function getYearKey(uint realYear) public pure returns (uint) {
        // realYear = 2024 -> cần tính timestamp tương ứng
        // Ví dụ: 1/1/2024 00:00:00 UTC
        uint yearsSince1970 = realYear - 1970;
        uint timestamp = yearsSince1970 * 365 days;
        return _getYear(timestamp);
    }
    function _getYear(uint timestamp) internal pure returns (uint) {
            return 1970 + (timestamp / 365 days);
        }

}