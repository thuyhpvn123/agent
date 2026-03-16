// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {NetCafeStaffUpgradeable} from "./NetCafeStaffUpgradeable.sol";

contract NetCafeManagementV2 is
    OwnableUpgradeable,
    UUPSUpgradeable,
    NetCafeStaffUpgradeable
{
    struct StationMeta {
        bytes32 pcId;
        string name;
        bytes32 groupId;
        string ipAddress;
        string macAddress;
        string configuration;
        bool exists;
    }

    struct Group {
        bytes32 id;
        string name;
        bool active;
        bytes32 pricePolicyId;
        uint256 amount;
        uint256 price;
        string description;
        bool exists;
    }

    struct PricePolicy {
        bytes32 id;
        uint256 pricePerMinute;
        string namePrice;
        bool active;
        bool exists;
    }

    bytes32[] public stationIds;
    mapping(bytes32 => StationMeta) public stations;

    bytes32[] public groupIds;
    mapping(bytes32 => Group) public groups;

    bytes32[] public pricePolicyIds;
    mapping(bytes32 => PricePolicy) public pricePolicies;

    mapping(bytes32 => bytes32[]) private groupStations;
    mapping(bytes32 => mapping(bytes32 => bool)) private stationInGroup;

    event GroupAdded(bytes32 indexed id, string name);
    event GroupUpdated(bytes32 indexed id, string name);
    event StationAssigned(bytes32 indexed pcId, bytes32 indexed groupId);
    event StationRemoved(bytes32 indexed pcId, bytes32 indexed groupId);
    event PricePolicyAdded(bytes32 indexed id, uint256 pricePerMinute);
    event PricePolicyUpdated(bytes32 indexed id, uint256 pricePerMinute);
    event PricePolicyStatusChanged(bytes32 indexed id, bool active);
    event PricePolicyDeleted(bytes32 indexed id);

    function initialize(address _staffContract) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __NetCafeStaff_init(_staffContract);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /* =======================
        PRICE POLICY
    ======================= */
    function addPricePolicy(
        bytes32 id,
        uint256 pricePerMinute,
        string calldata namePrice
    ) external onlyFinanceStaff {
        require(id != bytes32(0), "Invalid id");
        require(!pricePolicies[id].exists, "Policy exists");
        require(pricePerMinute > 0, "Invalid price");

        pricePolicies[id] = PricePolicy({
            id: id,
            pricePerMinute: pricePerMinute,
            namePrice: namePrice,
            active: true,
            exists: true
        });
        pricePolicyIds.push(id);

        emit PricePolicyAdded(id, pricePerMinute);
    }

    function updatePricePolicy(
        bytes32 id,
        uint256 pricePerMinute
    ) external onlyFinanceStaff {
        require(pricePolicies[id].exists, "Policy not found");

        pricePolicies[id].pricePerMinute = pricePerMinute;

        for (uint256 i = 0; i < groupIds.length; i++) {
            bytes32 gid = groupIds[i];
            if (groups[gid].pricePolicyId == id) {
                groups[gid].price = pricePerMinute;
            }
        }

        emit PricePolicyUpdated(id, pricePerMinute);
    }

    function setActivePricePolicy(
        bytes32 id,
        bool active
    ) external onlyFinanceStaff {
        require(pricePolicies[id].exists, "Policy not found");

        pricePolicies[id].active = active;

        emit PricePolicyStatusChanged(id, active);
    }

    function isPolicyInUse(
        bytes32 policyId
    ) public view returns (bool, string memory) {
        string memory groupNames = "";
        uint256 count = 0;

        for (uint256 i = 0; i < groupIds.length; i++) {
            bytes32 gid = groupIds[i];
            if (groups[gid].pricePolicyId == policyId) {
                count++;
                if (bytes(groupNames).length > 0) {
                    groupNames = string(
                        abi.encodePacked(groupNames, ", ", groups[gid].name)
                    );
                } else {
                    groupNames = groups[gid].name;
                }
            }
        }

        if (count > 0) {
            return (true, groupNames);
        }
        return (false, "");
    }

    function deletePricePolicy(bytes32 id) external onlyFinanceStaff {
        require(pricePolicies[id].exists, "Policy not found");

        (bool inUse, string memory groupNames) = isPolicyInUse(id);
        require(
            !inUse,
            string(
                abi.encodePacked(
                    "Cannot delete: Policy is being used by groups: ",
                    groupNames
                )
            )
        );

        delete pricePolicies[id];

        for (uint256 i = 0; i < pricePolicyIds.length; i++) {
            if (pricePolicyIds[i] == id) {
                pricePolicyIds[i] = pricePolicyIds[pricePolicyIds.length - 1];
                pricePolicyIds.pop();
                break;
            }
        }

        emit PricePolicyDeleted(id);
    }

    /* =======================
            GROUP
    ======================= */
    function addGroup(
        bytes32 groupId,
        string calldata name,
        bytes32 pricePolicyId,
        bytes32[] calldata stationList,
        string calldata description
    ) external onlyFinanceStaff {
        require(groupId != bytes32(0), "Invalid group id");
        require(!groups[groupId].exists, "Group exists");
        require(pricePolicies[pricePolicyId].exists, "Policy not found");

        groups[groupId] = Group({
            id: groupId,
            name: name,
            active: true,
            pricePolicyId: pricePolicyId,
            amount: 0,
            price: pricePolicies[pricePolicyId].pricePerMinute,
            description: description,
            exists: true
        });

        groupIds.push(groupId);

        for (uint256 i = 0; i < stationList.length; i++) {
            _assignStationToGroup(stationList[i], groupId);
        }

        emit GroupAdded(groupId, name);
    }

    function updateGroup(
        bytes32 groupId,
        string calldata name,
        bool active,
        bytes32 pricePolicyId,
        bytes32[] calldata newStationList,
        string calldata description
    ) external onlyFinanceStaff {
        require(groups[groupId].exists, "Group not found");
        require(pricePolicies[pricePolicyId].exists, "Policy not found");

        _updateGroupInfo(groupId, name, active, pricePolicyId, description);
        _syncGroupStations(groupId, newStationList);

        emit GroupUpdated(groupId, name);
    }

    /* =======================
        STATION
    ======================= */
    function addStation(
        bytes32 pcId,
        string calldata name,
        bytes32 groupId,
        string calldata ipAddress,
        string calldata macAddress,
        string calldata configuration
    ) external onlyFinanceStaff {
        require(pcId != bytes32(0), "Invalid pcId");
        require(!stations[pcId].exists, "Station exists");

        if (groupId != bytes32(0)) {
            require(groups[groupId].exists, "Group not found");
        }

        stations[pcId] = StationMeta({
            pcId: pcId,
            name: name,
            groupId: bytes32(0),
            ipAddress: ipAddress,
            macAddress: macAddress,
            configuration: configuration,
            exists: true
        });

        stationIds.push(pcId);

        if (groupId != bytes32(0)) {
            _assignStationToGroup(pcId, groupId);
        }
    }

    function getStationMeta(
        bytes32 pcId
    ) external view returns (string memory name, bytes32 groupId, bool exists) {
        StationMeta storage s = stations[pcId];
        return (s.name, s.groupId, s.exists);
    }

    function getStationsOfGroup(
        bytes32 groupId
    ) external view returns (bytes32[] memory) {
        return groupStations[groupId];
    }

    function getStationPrice(bytes32 pcId) external view returns (uint256) {
        require(stations[pcId].exists, "Station not found");

        bytes32 gid = stations[pcId].groupId;
        if (gid == bytes32(0)) {
            return 0;
        }

        return groups[gid].price;
    }

    /* =======================
           GETTERS (PAGED)
    ======================= */
    function getStationIdsPaged(
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory, uint256 total) {
        total = stationIds.length;

        if (offset >= total) return (new bytes32[](0), total);

        uint256 end = offset + limit;
        if (end > total) end = total;

        bytes32[] memory list = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            list[i - offset] = stationIds[i];
        }

        return (list, total);
    }

    function getGroupIdsPaged(
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory, uint256 total) {
        total = groupIds.length;

        if (offset >= total) return (new bytes32[](0), total);

        uint256 end = offset + limit;
        if (end > total) end = total;

        bytes32[] memory list = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            list[i - offset] = groupIds[i];
        }

        return (list, total);
    }

    function getPricePolicyIdsPaged(
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory, uint256 total) {
        total = pricePolicyIds.length;

        if (offset >= total) return (new bytes32[](0), total);

        uint256 end = offset + limit;
        if (end > total) end = total;

        bytes32[] memory list = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            list[i - offset] = pricePolicyIds[i];
        }

        return (list, total);
    }

    /* =======================
        INTERNAL HELPERS
    ======================= */
    function _updateGroupInfo(
        bytes32 groupId,
        string calldata name,
        bool active,
        bytes32 pricePolicyId,
        string calldata description
    ) internal {
        Group storage g = groups[groupId];

        g.name = name;
        g.active = active;
        g.description = description;

        if (g.pricePolicyId != pricePolicyId) {
            g.pricePolicyId = pricePolicyId;
            g.price = pricePolicies[pricePolicyId].pricePerMinute;
        }
    }

    function _syncGroupStations(
        bytes32 groupId,
        bytes32[] calldata newStationList
    ) internal {
        bytes32[] storage oldList = groupStations[groupId];
        uint256 i = 0;
        while (i < oldList.length) {
            if (!_existsInArray(oldList[i], newStationList)) {
                _removeStationFromGroup(oldList[i], groupId);
            } else {
                i++;
            }
        }

        for (uint256 j = 0; j < newStationList.length; j++) {
            bytes32 pcId = newStationList[j];
            if (!stationInGroup[groupId][pcId]) {
                _assignStationToGroup(pcId, groupId);
            }
        }
    }

    function _existsInArray(
        bytes32 value,
        bytes32[] calldata arr
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == value) return true;
        }
        return false;
    }

    function _assignStationToGroup(bytes32 pcId, bytes32 groupId) internal {
        require(stations[pcId].exists, "Station not found");

        bytes32 oldGroup = stations[pcId].groupId;
        if (oldGroup != bytes32(0)) {
            _removeStationFromGroup(pcId, oldGroup);
        }

        stations[pcId].groupId = groupId;

        groupStations[groupId].push(pcId);
        stationInGroup[groupId][pcId] = true;
        groups[groupId].amount += 1;

        emit StationAssigned(pcId, groupId);
    }

    function _removeStationFromGroup(bytes32 pcId, bytes32 groupId) internal {
        if (!stationInGroup[groupId][pcId]) return;

        bytes32[] storage list = groupStations[groupId];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == pcId) {
                list[i] = list[list.length - 1];
                list.pop();
                break;
            }
        }

        stationInGroup[groupId][pcId] = false;
        stations[pcId].groupId = bytes32(0);
        groups[groupId].amount -= 1;

        emit StationRemoved(pcId, groupId);
    }

    uint256[50] private __gap;
}
