// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {RobotStaffUpgradeable} from "./RobotStaffUpgradeable.sol";
contract RobotQuestion is 
OwnableUpgradeable
//  UUPSUpgradeable 
 {
    struct Message {
        string request_id;
        string text;
        string lang_id;
        string pronoun;
        uint8 flag;
        string session_id;
        string key;
    }

    // lưu message theo request_id
    mapping(string => Message) public messages;

    event UpdatedQuestion(
        string indexed request_id,
        string text,
        string lang_id,
        string pronoun,
        uint8 flag,
        string session_id,
        string key
    );
    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }
    // function _authorizeUpgrade(
    //     address newImplemation
    // ) internal override onlyOwner {}

    function uploadQuestion(Message memory message) public {
        messages[message.request_id] = message;

        emit UpdatedQuestion(
            message.request_id,
            message.text,
            message.lang_id,
            message.pronoun,
            message.flag,
            message.session_id,
            message.key
        );
    }

    function getQuestions(
        string memory request_id
    ) public view returns (Message memory) {
        return messages[request_id];
    }
    uint256[49] private __gap;
}
