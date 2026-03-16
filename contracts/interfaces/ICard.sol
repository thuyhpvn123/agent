// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
    enum TxStatus { FAIL, BEING_PROCESSED, SUCCESS }

    struct CardToken {
        address owner;
        string region;
        uint256 issuedAt;
        bool isActive;
        uint256 totalUsage;
        bytes32 cardHash; // Mã định danh duy nhất của thẻ (hash)
    }

    struct MerchantRule {
        string[] allowedRegions;
        uint256 maxPerMinute;
        uint256 maxPerHour;
        uint256 maxPerDay;
        uint256 maxPerWeek;
    }

    // Rule toàn cục áp cho mọi token và card (ngoài rule của merchant)
    struct GlobalRule {
        uint256 maxPerMinute;
        uint256 maxPerHour;
        uint256 maxPerDay;
        uint256 maxPerWeek;
        uint256 maxTotal; // tổng số lượt quẹt được
    }
    struct PoolInfo {
        address ownerPool;
        bytes32 parentHash;
        address pool;
        uint256 parentValue;
    }

    struct TransactionStatus{
        string txID;
        TxStatus status;
        uint64 atTime;
        string reason;
    }