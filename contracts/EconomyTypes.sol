// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EconomyTypes
 *
 * TOKEN MODEL:
 *   Token A (Vault Xu)  — tích lũy từ topup / hóa đơn, dùng để spend
 *   Token B (Reward Xu) — điểm thưởng từ tier bonus hoặc campaign event, dùng để spend
 *   lifetimeTokenA      — tổng Token A earned, chỉ tăng, dùng xác định tier
 *
 * TIER MODEL:
 *   tierEnabled = false → effectiveTier = BASE (bytes32("BASE"))
 *   tierEnabled = true  → effectiveTier = TierManager.getTier(customer)
 *   Tier là metadata/policy input, không phải token/ledger riêng.
 */
library EconomyTypes {

    // ============ TIER BASE CONSTANT ============
    /// @dev BASE tier ID — dùng khi tierEnabled=false hoặc customer chưa được gán tier
    bytes32 constant TIER_BASE = bytes32("BASE");

    // ============ ACTION TYPES ============
    bytes32 constant ACTION_TOPUP  = keccak256("TOPUP");
    bytes32 constant ACTION_NET    = keccak256("NET");
    bytes32 constant ACTION_FOOD   = keccak256("FOOD");
    bytes32 constant ACTION_ALL    = keccak256("ALL");
    bytes32 constant ACTION_REDEEM = keccak256("REDEEM");
    bytes32 constant ACTION_MANUAL = keccak256("MANUAL");

    // ============ EVENT TYPES ============
    bytes32 constant EVENT_TOPUP       = keccak256("EVENT_TOPUP");
    bytes32 constant EVENT_NET_SETTLED = keccak256("EVENT_NET_SETTLED");
    bytes32 constant EVENT_FOOD_PAID   = keccak256("EVENT_FOOD_PAID");

    // ============ SPEND PRIORITY ============
    enum SpendPriority { B_FIRST, A_FIRST, SPLIT }

    // ============ POLICY STRUCTS ============
    struct TopupPolicy {
        uint256 rate;       // inputAmount / rate = tokenA
        uint256 minTopup;
        uint256 maxTopup;   // 0 = unlimited
        bool    active;
    }

    struct SpendPolicy {
        SpendPriority priority;
        uint256 rewardMaxPercent;   // base % tối đa Token B dùng 1 lần spend (0-100)
        uint256 rewardMaxAbsolute;  // base absolute cap, 0 = unlimited
    }

    struct RewardPolicy {
        bytes32[] allowedActionTypes;
        uint256   defaultExpiryDays; // 0 = no expiry
    }

    // ============ TIER STRUCTS ============

    /**
     * @dev Cấu hình 1 hạng thành viên
     *
     * tokenBBonusPercent:
     *   Khi earn Token A → tự động grant thêm Token B = tokenAEarned * tokenBBonusPercent / 100
     *   VD: Silver 10% → earn 100 Token A → nhận thêm 10 Token B. 0 = không bonus.
     *
     * campaignMultiplier:
     *   Nhân hệ số Token B grant từ campaign. base 100 = 1x, 150 = 1.5x.
     *   finalGrantB = baseGrantB * campaignMultiplier / 100
     *
     * rewardCapPercentBonus (DoD-T3):
     *   Cộng thêm vào rewardMaxPercent của SpendPolicy khi debit Token B.
     *   VD: policy base = 50%, Gold bonus = 20% → Gold được dùng B tối đa 70%.
     *   0 = không bonus thêm.
     *
     * rewardCapAbsoluteBonus (DoD-T3):
     *   Cộng thêm vào rewardMaxAbsolute của SpendPolicy khi debit Token B.
     *   VD: policy base = 100 Token B, Platinum bonus = 50 → tối đa 150.
     *   0 = không bonus thêm. (nếu base = 0 tức unlimited thì vẫn unlimited)
     */
    struct TierConfig {
        bytes32 id;
        string  name;
        uint256 pointsRequired;           // lifetimeTokenA tối thiểu
        uint256 pointsMax;                // tự động tính
        uint256 tokenBBonusPercent;       // % Token B tự động grant khi earn Token A
        uint256 campaignMultiplier;       // hệ số nhân Token B từ campaign (base 100)
        uint256 rewardCapPercentBonus;    // cộng thêm % vào spend cap Token B
        uint256 rewardCapAbsoluteBonus;   // cộng thêm absolute vào spend cap Token B
        string  colour;
    }

    // ============ CAMPAIGN STRUCT ============

    /**
     * @dev minTierID vs allowedTiers:
     *   minTierID    — tier tối thiểu (>= minTier thì eligible). bytes32(0) = tất cả.
     *   allowedTiers — danh sách tier cụ thể được phép. length=0 = tất cả.
     *   Nếu cả 2 đều set: customer phải thỏa CẢ HAI điều kiện.
     */
    struct Campaign {
        uint256   id;
        string    name;
        bytes32   eventType;
        uint256   minAmount;
        uint256   rewardAmount;       // Token B grant (fixed hoặc %)
        bool      isPercent;
        uint256   branchScope;        // 0 = all branches
        uint256   exclusiveGroup;     // 0 = không exclusive
        uint256   priority;
        bool      stackable;
        bool      active;
        uint256   expiresAt;          // 0 = không expire
        bytes32   minTierID;          // bytes32(0) = all tiers eligible
        bytes32[] allowedTiers;       // length=0 = all tiers; nếu có → chỉ tier trong list
        uint256   rewardExpiryDaysOverride; // override default expiry days in RewardPolicy, 0 = no override
    }

    // ============ LEDGER ENTRY ============
    struct LedgerEntry {
        address customer;
        int256  delta;
        bytes32 actionType;
        bytes32 refId;
        uint256 timestamp;
        string  note;
    }
}
