// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface INetCafeSessionV2 {
    struct Session {
        address user;
        address sessionWallet;
        bytes32 sessionKeyHash;
        bytes32 pcId;
        uint64 expiresAt;
        bool active;
    }

    function getSession(address sessionWallet) external view returns (Session memory);
    function closeSessionByModule(address sessionWallet) external;
}
