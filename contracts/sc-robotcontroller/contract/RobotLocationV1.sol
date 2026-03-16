// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRobotRegistry.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RobotStaffUpgradeable} from "./RobotStaffUpgradeable.sol";

contract RobotLocation is
    OwnableUpgradeable,
    // UUPSUpgradeable,
    RobotStaffUpgradeable
{
    //struct
    struct Location {
        address robotAddress;
        string latlon;
    }

    struct Log {
        address robotAddress;
        uint workingTime;
        uint service;
        uint question;
        uint support;
    }
    //mapping
    IRobotRegistry public robotRegistry;

    mapping(address => Location) public robotLocation;
    mapping(address => Log) public robotLog;

    //event
    event LocationUpdated(address indexed robotAddress, string latlon);
    event LogUpdated(
        address indexed robotAddres,
        uint workingTIme,
        uint service,
        uint question,
        uint support
    );

    // constructor(address _robotRegistry) {
    //     require(_robotRegistry != address(0), "Invalid registry");
    //     robotRegistry = IRobotRegistry(_robotRegistry);
    // }
    function initialize(
        address _staffContract,
        address _robotRegistry
    ) public initializer {
        require(_robotRegistry != address(0), "Invalid registry");

        __Ownable_init(msg.sender);
        // __UUPSUpgradeable_init();
        __RobotStaffUpgradeable_init(_staffContract);

        robotRegistry = IRobotRegistry(_robotRegistry);
    }
    // function _authorizeUpgrade(
    //     address newImplemation
    // ) internal override onlyOwner {}

    modifier robotExist(address robotAddress) {
        require(
            robotRegistry.getRobotByAddress(robotAddress).robotAddress !=
                address(0),
            "Robot not exists"
        );
        _;
    }

    function updateLocation(
        address robotAddress,
        string calldata latlon
    ) public robotExist(robotAddress) {
        robotLocation[robotAddress] = Location({
            robotAddress: robotAddress,
            latlon: latlon
        });
        emit LocationUpdated(robotAddress, latlon);
    }

    function updateLog(
        address robotAddress,
        uint workingTime,
        uint service,
        uint question,
        uint support
    ) public robotExist(robotAddress) {
        robotLog[robotAddress] = Log({
            robotAddress: robotAddress,
            workingTime: workingTime,
            service: service,
            question: question,
            support: support
        });
        emit LogUpdated(robotAddress, workingTime, service, question, support);
    }
    function getLocation(
        address robotAddress
    )
        public
        view
        robotExist(robotAddress)
        onlyMerchantOwner
        onlyManager
        returns (Location memory)
    {
        return robotLocation[robotAddress];
    }
    function getLog(
        address robotAddress
    ) public view robotExist(robotAddress) returns (Log memory) {
        return robotLog[robotAddress];
    }
    uint256[49] private __gap;
}
