// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

enum ROLE {
    STAFF,
    ADMIN
}

enum STAFF_ROLE {
    UPDATE_STATUS_DISH,
    PAYMENT_CONFIRM,
    TC_MANAGE,
    TABLE_MANAGE,
    MENU_MANAGE,
    STAFF_MANAGE
}
enum TABLE_STATUS {
    EMPTY,
    BUSY,
    PAYING
}

enum PAYMENT_STATUS {
    CREATED,
    PAID,
    CONFIRMED_BY_STAFF,
    ABORT,
    REFUNDED
}

enum COURSE_STATUS {
    // CREATED,
    ORDERED,
    PREPARING,
    SERVED,
    CANCELED
}

enum TxStatus {
    PENDING,
    SUCCESS,
    FAILED
}

enum TCStatus {
    WAITTING_APPLY,
    APPLIED,
    UNAPPLIED
}

enum ORDER_STATUS {
    UNCONFIRMED,
    CONFIRMED,
    FINISHED
}
// Restaurant Information
struct RestaurantInfo {
    string name;
    string addr;
    string phone;
    string visaInfo;
    address walletAddress;
    uint workPlaceId;
    string imgLink;
    uint registeredAt;
    uint updatedAt;
}

// Customer Information
struct CustomerProfile {
    bytes32 customerID;
    uint8 gender; // 0=male, 1=female, 2=other
    uint8 ageGroup; // age groups: 0-9, 10-19, 20-29, etc.
    uint firstVisit; //time first visit
    uint visitCount;
}
// Existing structs
struct Category {
    string code;
    string name;
    uint rank;
    string desc;
    bool active;
    string imgUrl;
}   

struct DishInfo {
    Dish dish;
    Variant[] variants;
    Attribute[][] attributes;
}
struct Dish {
    string code;
    string nameCategory;
    string name;
    string des;
    bool available;
    bool active;
    string imgUrl;
    uint averageStar;
    uint cookingTime;
    string[] ingredients;
    bool showIngredient;
    string videoLink;
    uint totalReview;
    uint orderNum;
    uint createdAt;
}
struct Attribute{
    bytes32 id;
    string key; //size
    string value; // S/M/L
}
struct VariantParams{
    Attribute[] attrs;
    uint price;
}

struct Variant{
    bytes32 variantID;
    uint dishPrice;
}
struct Table {
    uint number;
    uint numPeople;
    TABLE_STATUS status;
    bytes32 paymentId;
    bool active;
}

struct Course {
    uint id;
    Dish dish;
    uint quantity;
    string note;
    COURSE_STATUS status;
}
struct SimpleCourse {
    uint id;
    string dishCode;
    string dishName;
    uint dishPrice;
    uint quantity;
    COURSE_STATUS status;
    string imgUrl;
    string note;
}

struct Order {
    bytes32 id;
    uint table;
    uint createdAt;
    // bool isDineIn; // true for dine-in, false for takeaway
    // uint groupSize;
    ORDER_STATUS status;
}

struct Discount {
    string code;
    string name;
    uint discountPercent;
    string desc;
    uint from;
    uint to;
    bool active;
    string imgURL;
    uint amountMax;
    uint amountUsed;
    uint updatedAt;   
}

struct Payment {
    bytes32 id;
    uint tableNum;
    bytes32[] orderIds;
    uint foodCharge;
    uint tax;
    uint tip;
    uint discountAmount;
    string discountCode;
    address customer;
    PAYMENT_STATUS status;
    uint createdAt;
    string method;
    address staffConfirm;
    string reasonConfirm;
    uint total;
}

struct Review {
    string nameCustomer;
    uint8 overalStar;
    string contribution;
    // DishReview[] dishReviews;
    uint createdAt;
    bytes32 paymentId;
}
struct DishReview {
    string nameCustomer;
    string dishCode;
    uint8 dishStar;
    string contribution;
    uint createdAt;
    bytes32 paymentId;
    bool isShow;
    bytes32 id;
}

struct DigitalMenu {
    uint256 id;
    string linkImg;
    string title;
}
struct Banner {
    uint256 id;
    string name;
    string linkImg;
    string description;
    string linkTo;
    bool active;
    uint256 from;
    uint256 to;
    
}
struct TCInfo {
    uint256 id;
    string title;
    string content;
    TCStatus status;
}

struct WorkingShift {
    string title;
    uint256 from; 
    uint256 to;
    uint256 shiftId;
}

struct Uniform {
    uint256 id;
    string name;
    string linkImgFront;
    string linkImgBack;
}

struct OrderInput {
    string dishCode;
    uint quantity;
    string note;
}
struct Position {
    uint id;
    string name;
    STAFF_ROLE[] positionRoles;
}
struct Staff {
    address wallet;
    string name;
    string code;
    string phone;
    string addr;
    string position; 
    ROLE role;
    bool active;
    string linkImgSelfie;
    string linkImgPortrait;
    WorkingShift[] shifts;
    STAFF_ROLE[] roles;
}

// Reporting Structs
struct DailyReport {
    uint date; // day timestamp
    uint totalCustomers;
    uint totalRevenue;
    uint totalOrders;
    uint newCustomers;
    uint newCustomerOrders;
    uint newCustomerRevenue;
    uint returningCustomerOrders;
    uint returningCustomerRevenue;
    uint dineInOrders;
    uint takeAwayOrders;
    uint dineInRevenue;
    uint takeAwayRevenue;
    uint onceReturningCustomers;
    uint twiceReturningCustomers;
    uint singleCustomers; // 1 person
    uint coupleCustomers; // 2 people  
    uint tripleCustomers; // 3 people
    uint groupCustomers; // 4+ people
    uint femaleCustomers;
    uint[10] ageGroups; // age groups by decade
    uint[5] serviceRatings; // 1-5 star ratings count
    uint[5] foodRatings; // 1-5 star ratings count
}

struct MonthlyReport {
    uint month; // month identifier
    uint totalCustomers;
    uint totalRevenue;
    uint totalOrders;
    uint newCustomers;
    uint newCustomerOrders;
    uint newCustomerRevenue;
    uint returningCustomerOrders;
    uint returningCustomerRevenue;
    uint dineInOrders;
    uint takeAwayOrders;
    uint dineInRevenue;
    uint takeAwayRevenue;
    uint onceReturningCustomers;
    uint twiceReturningCustomers;
    uint singleCustomers;
    uint coupleCustomers;
    uint tripleCustomers;
    uint groupCustomers;
    uint femaleCustomers;
    uint[10] ageGroups;
    uint[5] serviceRatings;
    uint[5] foodRatings;
}

struct DishReport {
    string dishCode;
    uint startSellingTime;
    uint totalRevenue;
    uint totalOrders;
    uint ranking;
    bool isNew;
}

struct DishDailyReport {
    uint date;
    uint revenue;
    uint orderCount;
    uint onceOrderCustomers;
    uint twiceOrderCustomers;
}

struct DishMonthlyReport {
    uint month;
    uint revenue;
    uint orderCount;
    uint onceOrderCustomers;
    uint twiceOrderCustomers;
}

struct VoucherReport {
    uint totalUsed;
    uint totalUnused;
    uint totalExpired;
    VoucherDetail[] details;
}

struct VoucherDetail {
    string code;
    string name;
    uint amountUsed;
    uint amountExpired;
    uint amountUnused;
    uint amountMax;
}

struct HistoricalSummary {
    uint serviceStartTime;
    uint totalCustomers;
    uint totalOrders;
    uint totalRevenue;
    uint averageOrderValue;
}

// Transaction and Card interfaces
struct TransactionStatus {
    TxStatus status;
    uint amount;
    address from;
    address to;
    uint timestamp;
}

struct PoolInfo {
    address ownerPool;
    uint parentValue;
    address tokenAddress;
}

// Additional reporting structs
struct ReportComparison {
    uint customerGrowthPercent;
    bool customerGrowthPositive;
    uint revenueGrowthPercent;
    bool revenueGrowthPositive;
    uint orderGrowthPercent;
    bool orderGrowthPositive;
    uint averageOrderValue;
    uint previousAverageOrderValue;
    uint newCustomerPercentage;
    uint dineInPercentage;
    uint takeAwayPercentage;
    uint femaleCustomerPercentage;
    uint averageNewCustomerOrderValue;
    uint averageReturningCustomerOrderValue;
    uint averageDineInOrderValue;
    uint averageTakeAwayOrderValue;
}

struct DishComparison {
    uint currentRanking;
    uint previousRanking;
    uint rankingChange;
    bool rankingImproved;
    uint orderCountGrowthPercent;
    bool orderCountGrowthPositive;
}

struct FavoriteDish {
    string dishCode;
    string dishName;
    // uint price;
    uint totalOrders;
    uint orderPercentage;
    uint totalRevenue;
    uint revenuePercentage;
}

struct VoucherComparison {
    uint usedGrowthPercent;
    bool usedGrowthPositive;
    uint unusedGrowthPercent;
    bool unusedGrowthPositive;
    uint expiredGrowthPercent;
    bool expiredGrowthPositive;
}

struct RatingComparison {
    uint[5] currentServicePercentages;
    uint[5] previousServicePercentages;
    uint[5] currentFoodPercentages;
    uint[5] previousFoodPercentages;
    uint[5] serviceRatingChanges;
    bool[5] serviceRatingIncreased;
    uint[5] foodRatingChanges;
    bool[5] foodRatingIncreased;
}
struct VoucherUse {
    uint time;
    uint amountUsed;
    uint amountExpired;
    uint amountUnused;
}
