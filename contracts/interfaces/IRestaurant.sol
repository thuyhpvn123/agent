// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
enum CurrencyDisplay{ BEFORE, AFTER}
enum Currency {
    SAR, BDT, MMK, CNY, CZK, EUR, USD,INR, ILS, HUF, IDR, JPY, KRW, MYR, IRR, PLN, RON, RUB, KES, SEK, THB, TRY, UAH, PKR, VND, PHP
}
enum PaymentOrder {
    PAY_ADVANCE,
    PAY_AFTER
}
enum PaymentMethod {
    CASH,
    VISA,
    QR,
    POINTS
}
// Added 22/01/2026
enum PaymentType {
    PREPAID, 
    POSTPAID
}

enum SessionType {
    CREATED,
    PREPAID, 
    POSTPAID,
    MIXED
}

enum CustomerType {
    SINGLE, 
    COUPLE, 
    GROUP // từ 3 trở lên
}

enum BannerPosition {
    HOME,
    PAYMENT_PAGE
}
enum LinkBannerType {
    OUTSIDE_LINK,
    WEB_MEMBER_LINK,
    WRITING
}
enum DiscountType {
    MANUAL,        // Áp thủ công
    AUTO_ALL,      // Tự động cho mọi khách
    AUTO_GROUP     // Tự động cho nhóm
}
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
    STAFF_MANAGE,
    FINANCE,
    ACCOUNT_MANAGE,
    PC_MANAGE
}
// Added 22/01/2026
enum SESSION_STATUS {
    CREATED, 
    ACTIVE, 
    PAYMENT_PENDING, 
    READY_TO_CLOSE, 
    CLOSED
}

// Updated 22/01/2026
enum TABLE_STATUS {
    // EMPTY,
    // BUSY,
    // PAYING
    INACTIVE,
    // Chưa dùng
    AVAILABLE,   // Trống
    RESERVED,
    // Đặt trước (có cọc)
    ACTIVE,
    // Có khách
    FULL,
    // Đủ số session = số chỗ
    MERGED_PARENT,
    // Đang ghép (là bàn cha)
    MERGED,
    // Đang ghép
    BLOCKED,
    // Hỏng / dơ
    CLOSED
    // Kết thúc ca
}



enum PAYMENT_STATUS {
    CREATED,
    PAID,
    CONFIRMED_PAID,
    // CONFIRMED_BY_STAFF,
    // ABORT,
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

// enum ORDER_STATUS {
//     UNCONFIRMED,
//     CONFIRMED,
//     FINISHED,
//     CANCELED
// }

// Added 22/01/2026
enum ORDER_STATUS {
    CREATED, 
    PAID, 
    KITCHEN_CONFIRMED, // = confirm
    PREPARING, 
    SERVED, 
    CANCELLED, 
    REFUNDED
}

enum HistoryAction {
    ORDER_CREATED,
    ORDER_ACKNOWLEDGED,
    ORDER_CONFIRMED,
    ORDER_FINISHED,
    TRANSFER_REQUESTED,
    TRANSFER_ACCEPTED,
    TRANSFER_DECLINED,
    ORDER_CANCELLED,
    COURSE_STATUS_UPDATED,
    PAYMENT_COMPLETED,
    ORDER_REFUNDED
}

enum TransferStatus {
    NONE,
    PENDING,
    ACCEPTED,
    DECLINED,
    CANCELLED
}

struct TransferRequest {
    uint256 requestId;
    bytes32 orderId;
    address fromStaff;
    address toStaff;
    uint256 timestamp;
    TransferStatus status;
    string reason;
}

struct OrderHistory {
    uint256 id;
    bytes32 orderId;
    uint256 timestamp;
    HistoryAction action;
    address actor;
    string details;
    address targetStaff; // Dùng cho transfer
}

struct Area {
    uint id;
    string name;
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
    string icon;
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
    uint numPeople;          // Thay numPeople bằng maxSeats (sức chứa vật lý)
    uint occupiedSeats;     // Tổng ghế đã dùng (nhân 100, vd: 2.5 ghế = 250)
    TABLE_STATUS status;
    bool active;
    string name;
    Area area;
    
    // Nâng cấp quan trọng:
    bytes32[] sessionIds;   // Một bàn có thể chứa nhiều SessionId (khách ngồi chung)
    uint256 parentTableId;  // Dùng cho Case T3: Ghép bàn (Bàn phụ trỏ về bàn chính)
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
    // string[] featureNames;
    OptionSelected[] optionsSelected;
}

struct Order {
    bytes32 id;
    bytes32 sessionId;
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
    DiscountType discountType;       // Loại discount
    bytes32[] targetGroupIds;        // Danh sách group IDs (cho AUTO_GROUP)
    uint pointCost;                  // Điểm cần để redeem voucher
    bool isRedeemable;               // Có thể đổi bằng điểm không 
    string textDes;
}

struct Payment {
    bytes32 id;
    bytes32 sessionId;
    bytes32[] orderIds;
    uint foodCharge;
    uint tax;
    uint tip;
    uint discountAmount;
    string discountCode;
    PAYMENT_STATUS status;
    uint createdAt;
    string method;
    uint total;
    uint deductedInvoiceAmount;
}

struct PaymentInformation {
    bytes32 id;
    address customer;
    PaymentType typePayment;
    address staffConfirm;
    string reasonConfirm;

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
    BannerPosition location;
    
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
    uint returningCustomersOneTime;
    uint returningCustomersFromTwoTimes;

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
    uint returningCustomersOneTime;
    uint returningCustomersFromTwoTimes;
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
    // string dishCode;
    // string dishName;
    // // uint price;
    DishWithFirstPrice dishWithFirstPrice;
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
struct Target{
    uint year;
    uint revenueTarget;
}
// Struct helper để sort
struct DishWithOrder {
    Dish dish;
    uint orderNum;
    uint originalIndex;
    Variant variant;
    Attribute[] attributes;
}
struct DishWithFirstPrice{
    Dish dish;
    Variant variant;
    Attribute[] attributes; 
}
struct ChartTotalCustomers{
    uint time;
    uint totalCustomers;
}
struct ChartTotalRevenue{
    uint time;
    uint addRevenue;
}
struct ChartTotalOrder{
    uint time;
    uint addOrder;
}

struct NewDish {
    string name;
    string codeDish;
    uint createAt;
}
struct RankReport{
    uint createdAt;
    uint rank;
}

struct OptionFeature {
    bytes32 featureId;
    string featureName;
    uint256 featurePrice;
}
struct DishOption {
    bytes32 optionId;
    string optionName;
    OptionFeature[] features;
    bool isCompulsory;
    uint maximumSelection;
}
struct SelectedOption {
    bytes32 optionId;
    bytes32[] selectedFeatureIds;  // Multiple features can be selected per option
}
struct OptionSelected {
    string optionName;
    string[] selectedFeatureNames;
} 

    // ==================== STRUCTS BranchManager ====================
    
    struct Branch {
        uint256 branchId;
        string name;
        bool active;
        bool isMain;
    }
    
    struct ManagerInfo {
        address wallet;
        string name;
        string phone;
        string image;
        bool isCoOwner;              // true = Co-Owner, false = Branch Manager
        // DecisionType decisionType;
        uint256[] branchIds;         // Danh sách chi nhánh được quản lý
        bool hasFullAccess;          // true = Toàn bộ chi nhánh, false = Chi nhánh được chọn
        bool canViewData;
        bool canEditData;
        bool canProposeAndVote;
        uint256 createdAt;
        bool active;
    }
    
    struct Proposal {
        uint256 proposalId;
        address proposer;
        ProposalType proposalType;
        uint256 branchId;            // 0 nếu là proposal chung cho merchant
        bytes oldData;                  // Encoded data cho thay đổi
        bytes newData;
        ProposalStatus status;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 totalVoters;         // Tổng số người có quyền vote
        uint256 createdAt;
        uint256 executedAt;
    }
    struct PaginatedProposals {
        Proposal[] proposals;
        uint256 total;
        uint256 page;
        uint256 pageSize;
        uint256 totalPages;
    }
    struct Notification {
        uint256 notificationId;
        uint256 branchId;            // Chi nhánh liên quan
        address recipient;
        string title;
        string message;
        uint256 proposalId;          // ID proposal liên quan (nếu có)
        bool isRead;
        uint256 createdAt;
    }
    struct PaymentInfo {
        string bankAccount;
        string nameAccount;
        string nameOfBank;
        string taxCode;
        string wallet;
    }

    
    enum ProposalStatus {
        PENDING,
        APPROVED,
        REJECTED,
        EXECUTED, 
        EXPIRED
    }
    
    enum ProposalType {
        MERCHANT_INFO_CHANGE,     // Thay đổi thông tin merchant
        BRANCH_INFO_CHANGE,       // Thay đổi thông tin chi nhánh
        ADD_MANAGER,              // Thêm quản lý
        REMOVE_MANAGER,           // Xóa quản lý
        EDIT_STAFF,
        EDIT_BANKACCOUNT
    }

    struct ManagerProposalDashboard {
        Proposal[] votedProposals;      // Proposals đã vote
        Proposal[] unvotedProposals;    // Proposals chưa vote
        Proposal[] allProposals;        // Tất cả proposals
        uint256 totalVoted;             // Tổng số đã vote
        uint256 totalUnvoted;           // Tổng số chưa vote
        uint256 totalAll;               // Tổng số tất cả
        uint256 page;                   // Trang hiện tại
        uint256 pageSize;               // Kích thước trang
        uint256 totalPagesVoted;        // Tổng số trang (voted)
        uint256 totalPagesUnvoted;      // Tổng số trang (unvoted)
        uint256 totalPagesAll;          // Tổng số trang (all)
    }
    struct ManagerProposalByBranchDashboard {
        uint256 branchId;               // ID chi nhánh
        string branchName;              // Tên chi nhánh
        Proposal[] votedProposals;      // Proposals đã vote
        Proposal[] unvotedProposals;    // Proposals chưa vote
        Proposal[] allProposals;        // Tất cả proposals
        uint256 totalVoted;             // Tổng số đã vote
        uint256 totalUnvoted;           // Tổng số chưa vote
        uint256 totalAll;               // Tổng số tất cả
        uint256 page;                   // Trang hiện tại
        uint256 pageSize;               // Kích thước trang
        uint256 totalPagesVoted;        // Tổng số trang (voted)
        uint256 totalPagesUnvoted;      // Tổng số trang (unvoted)
        uint256 totalPagesAll;          // Tổng số trang (all)
    }
    struct UserRoleSummary {
        bool isAdmin;
        bool isStaff;
        bool isPaymentConfirm;
        bool isUpdateStatusDish;
        bool isTcManage;
        bool isTableManage;
        bool isMenuManage;
        bool isStaffManage;
        bool isFinance;
        bool isAccountManage;
        bool isPcManage;
    }
        // Added 22/01/2026
    struct Session {
        bytes32 sessionId;
        uint256 tableId;
        address customer;
        CustomerType cType; 
        SESSION_STATUS status;
        uint256 seatUsed; 
        address creator;
        SessionType typeSession;
        bytes32 reservationId;
    }

    // Rule trường hợp khách tới trễ
    struct ReservationRule {
        uint gracePeriod;      // 15, 30 phút...
        uint penaltyPercent;   // 50, 100%...
        uint256 minDeposit;       // Tiền cọc tối thiểu để được giữ chỗ
    }

    struct Reservation {
        bytes32 reservationId;
        uint256 reservationTime;  // Mốc giờ hẹn (Vd: 19:00)
        uint256 depositAmount;    // Số tiền khách đã cọc thực tế
        bool isCheckIn;           // Trạng thái khách đã đến chưa
        string name;
        string phone;
        uint numPeople;
        CustomerType customerType;
        uint penaltyFee;
        uint refund;
        uint invoiceDeductedAmount; // tiền cọc đã khấu trừ
        uint remainingDeposit; // tiền cọc còn thừa
        bool isConfirm;
        bool isCancel;
        // uint256 appliedGracePeriod;   // Lưu lại gracePeriod lúc khách bấm đặt
        // uint256 appliedPenaltyPercent; // Lưu lại mức phạt lúc khách bấm đặt
    }

    // Added 05/01/2026
    // --- Struct cho tính toán order thanh toán ---
    struct SelectedItemsParams {
        string dishCode;
        bytes32 variantID;
        uint256 quantity;
        SelectedOption[] selectedOptions;
    }

    struct ItemPriceDetail {
        string productID;
        uint256 confirmedPrice;
        uint256 itemTotal;
    }
    struct SearchTopResult {
        uint256[3] ids;
        string[3] names;
        int256[3] scores;
        string[3] imgs;
    }

    struct MakeOrderParams {
    uint table;
    bytes32 sessionId;
    string[] dishCodes;
    uint8[] quantities;
    string[] notes;
    bytes32[] variantIDs;
    SelectedOption[][] dishSelectedOptions;
    PaymentType paymentType;
}

