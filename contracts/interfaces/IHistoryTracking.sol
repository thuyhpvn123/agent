// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "./IRestaurant.sol";
    enum EntityType {
        DISH,
        CATEGORY,
        DISCOUNT,
        STAFF,
        TABLE,
        BANNER,
        TC,
        WORKING_SHIFT,
        UNIFORM,
        AREA,
        POSITION,
        DISH_OPTION,
        MANAGER,
        PAYMENT_INFO
    }

    enum ActionType {
        CREATE,
        UPDATE,
        DELETE
    }

    struct HistoryEntry {
        EntityType entityType;
        string entityId;           // code, id, hoặc unique identifier
        ActionType actionType;
        uint256 timestamp;
        address actor;            // wallet address của người thực hiện thay đổi
        // string nameActor;
        // string positionActor;
        string reason;
    }

    struct EntityHistory {
        uint256 lastUpdateTime;
        uint256 previousUpdateTime;
        bool exists;
    }

    // ==================== DATA SNAPSHOT STRUCTS ====================
    
    struct DishSnapshot {
        Dish dish;
        Variant[] variants;
        Attribute[][] attributes;
        uint256 timestamp;
    }
    struct PaymentInfoSnapshot {
        PaymentInfo paymentInfo;
        uint256 timestamp;
    }
    struct ManagerSnapshot {
        ManagerInfo manager;
        uint256 timestamp;
    }
    struct CategorySnapshot {
        Category category;
        uint256 timestamp;
    }
    
    struct DiscountSnapshot {
        Discount discount;
        uint256 timestamp;
    }
    
    struct StaffSnapshot {
        Staff staff;
        uint256 timestamp;
    }
    
    struct TableSnapshot {
        Table table;
        uint256 timestamp;
    }
    
    struct BannerSnapshot {
        Banner banner;
        uint256 timestamp;
    }
    
    struct TCSnapshot {
        TCInfo tc;
        uint256 timestamp;
    }
    
    struct WorkingShiftSnapshot {
        WorkingShift shift;
        uint256 timestamp;
    }
    
    struct UniformSnapshot {
        Uniform uniform;
        uint256 timestamp;
    }
    
    struct AreaSnapshot {
        Area area;
        uint256 timestamp;
    }
    
    struct PositionSnapshot {
        Position position;
        uint256 timestamp;
    }
    
    struct DishOptionSnapshot {
        DishOption option;
        uint256 timestamp;
    }

interface IHistoryTracking {
    // ==================== MANAGER HISTORY ====================
    function initialize(address _branchManagementSC,address _managementSC, address _agent) external;

    function recordManagerCreate(
        address wallet,
        ManagerInfo memory manager,
        string memory reason
    ) external;
    
    function recordManagerUpdate(
        address wallet,
        ManagerInfo memory manager,
        string memory reason
    ) external;
    
    function recordManagerDelete(
        address wallet,
        ManagerInfo memory manager,
        string memory reason
    ) external;
    
    // ==================== PAYMENT INFO HISTORY ====================
    
    function recordPaymentInfoUpdate(
        PaymentInfo memory oldPaymentInfo,
        PaymentInfo memory newPaymentInfo,
        string memory reason
    ) external;
    // ==================== DISH ====================
    function recordDishCreate(
        string memory dishCode,
        Dish memory dish,
        Variant[] memory variants,
        Attribute[][] memory attributes,
        string memory reason
    ) external;
    
    function recordDishUpdate(
        string memory dishCode,
        Dish memory dish,
        Variant[] memory variants,
        Attribute[][] memory attributes,
        string memory reason
    ) external;
    
    function recordDishDelete(
        string memory dishCode,
        Dish memory dish,
        Variant[] memory variants,
        Attribute[][] memory attributes,
        string memory reason
    ) external;
    
    // ==================== CATEGORY ====================
    function recordCategoryCreate(
        string memory code,
        Category memory category,
        string memory reason
    ) external;
    
    function recordCategoryUpdate(
        string memory code,
        Category memory category,
        string memory reason
    ) external;
    
    function recordCategoryDelete(
        string memory code,
        Category memory category,
        string memory reason
    ) external;
    
    // ==================== DISCOUNT ====================
    function recordDiscountCreate(
        string memory code,
        Discount memory discount,
        string memory reason
    ) external;
    
    function recordDiscountUpdate(
        string memory code,
        Discount memory discount,
        string memory reason
    ) external;
    
    function recordDiscountDelete(
        string memory code,
        Discount memory discount,
        string memory reason
    ) external;
    
    // ==================== STAFF ====================
    function recordStaffCreate(
        address wallet,
        Staff memory staff,
        string memory reason
    ) external;
    
    function recordStaffUpdate(
        address wallet,
        Staff memory staff,
        string memory reason
    ) external;
    
    function recordStaffDelete(
        address wallet,
        Staff memory staff,
        string memory reason
    ) external;
    
    // ==================== TABLE ====================
    function recordTableCreate(
        uint tableNumber,
        Table memory table,
        string memory reason
    ) external;
    
    function recordTableUpdate(
        uint tableNumber,
        Table memory table,
        string memory reason
    ) external;
    
    function recordTableDelete(
        uint tableNumber,
        Table memory table,
        string memory reason
    ) external;
    
    // ==================== BANNER ====================
    function recordBannerCreate(
        uint bannerId,
        Banner memory banner,
        string memory reason
    ) external;
    
    function recordBannerUpdate(
        uint bannerId,
        Banner memory banner,
        string memory reason
    ) external;
    
    function recordBannerDelete(
        uint bannerId,
        Banner memory banner,
        string memory reason
    ) external;
    
    // ==================== TC ====================
    function recordTCCreate(
        uint tcId,
        TCInfo memory tc,
        string memory reason
    ) external;
    
    function recordTCUpdate(
        uint tcId,
        TCInfo memory tc,
        string memory reason
    ) external;
    
    function recordTCDelete(
        uint tcId,
        TCInfo memory tc,
        string memory reason
    ) external;
    
    // ==================== WORKING SHIFT ====================
    function recordWorkingShiftCreate(
        uint shiftId,
        WorkingShift memory shift,
        string memory reason
    ) external;
    
    function recordWorkingShiftUpdate(
        uint shiftId,
        WorkingShift memory shift,
        string memory reason
    ) external;
    
    function recordWorkingShiftDelete(
        uint shiftId,
        WorkingShift memory shift,
        string memory reason
    ) external;
    
    // ==================== UNIFORM ====================
    function recordUniformCreate(
        uint uniformId,
        Uniform memory uniform,
        string memory reason
    ) external;
    
    function recordUniformUpdate(
        uint uniformId,
        Uniform memory uniform,
        string memory reason
    ) external;
    
    function recordUniformDelete(
        uint uniformId,
        Uniform memory uniform,
        string memory reason
    ) external;
    
    // ==================== AREA ====================
    function recordAreaCreate(
        uint areaId,
        Area memory area,
        string memory reason
    ) external;
    
    function recordAreaUpdate(
        uint areaId,
        Area memory area,
        string memory reason
    ) external;
    
    function recordAreaDelete(
        uint areaId,
        Area memory area,
        string memory reason
    ) external;
    
    // ==================== POSITION ====================
    function recordPositionCreate(
        string memory name,
        Position memory position,
        string memory reason
    ) external;
    
    function recordPositionUpdate(
        string memory name,
        Position memory position,
        string memory reason
    ) external;
    
    function recordPositionDelete(
        string memory name,
        Position memory position,
        string memory reason
    ) external;
    
    // ==================== DISH OPTION ====================
    function recordDishOptionCreate(
        bytes32 optionId,
        DishOption memory option,
        string memory reason
    ) external;
    
    function recordDishOptionUpdate(
        bytes32 optionId,
        DishOption memory option,
        string memory reason
    ) external;
    
    function recordDishOptionDelete(
        bytes32 optionId,
        DishOption memory option,
        string memory reason
    ) external;
}