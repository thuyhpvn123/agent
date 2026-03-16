// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RobotRegistry} from "../contracts/sc-robotcontroller/contract/RobotRegistryV1.sol";
import {RobotLocation} from "../contracts/sc-robotcontroller/contract/RobotLocationV1.sol";
import {RobotQuestion} from "../contracts/sc-robotcontroller/contract/RobotQuestionV1.sol";
import {RobotActive} from "../contracts/sc-robotcontroller/contract/RobotActiveV1.sol";
import {RobotObservationTraining} from "../contracts/sc-robotcontroller/contract/RobotTrainV1.sol";
import {RobotTesting} from "../contracts/sc-robotcontroller/contract/RobotTestingV1.sol";
import {RobotDataUploadTraining} from "../contracts/sc-robotcontroller/contract/RobotLoadDataV1.sol";
import {RobotCheckpoint} from "../contracts/sc-robotcontroller/contract/RobotDashBoardV1.sol";
import {Robot_Role} from "../contracts/sc-robotcontroller/contract/Constant.sol";

contract MockStaffManagement {
    mapping(Robot_Role => mapping(address => bool)) public roles;

    function setRole(Robot_Role role, address user, bool enabled) external {
        roles[role][user] = enabled;
    }

    function checkRole(
        Robot_Role role,
        address user
    ) external view returns (bool rightRole) {
        return roles[role][user];
    }
}

contract RobotFullFlowV2Test is Test {
    MockStaffManagement public staff;
    RobotRegistry public registry;
    RobotLocation public location;
    RobotQuestion public question;
    RobotActive public active;
    RobotObservationTraining public observation;
    RobotTesting public testing;
    RobotDataUploadTraining public upload;
    RobotCheckpoint public checkpoint;

    address public operator;
    address public robot1;
    address public chat1;

    constructor() {
        operator = makeAddr("operator");
        robot1 = makeAddr("robot1");
        chat1 = makeAddr("chat1");

        staff = new MockStaffManagement();

        registry = new RobotRegistry();
        registry.initialize(address(staff));

        location = new RobotLocation();
        location.initialize(address(staff), address(registry));

        question = new RobotQuestion();
        question.initialize();

        active = new RobotActive();
        active.initialize(address(staff), address(registry));

        observation = new RobotObservationTraining();
        observation.initialize(address(staff), address(registry));

        testing = new RobotTesting();
        testing.initialize(address(staff), address(registry));

        upload = new RobotDataUploadTraining();
        upload.initialize(address(staff), address(registry));

        checkpoint = new RobotCheckpoint();
        checkpoint.initialize(address(staff));

        _grantSuperAdmin(operator);
        _grantSuperAdmin(address(registry));
        _grantSuperAdmin(address(location));
        _grantSuperAdmin(address(active));
        _grantSuperAdmin(address(observation));
        _grantSuperAdmin(address(testing));
        _grantSuperAdmin(address(upload));
        _grantSuperAdmin(address(checkpoint));
    }

    function _grantSuperAdmin(address user) internal {
        staff.setRole(Robot_Role.PLATFORM_SUPER_ADMIN, user, true);
    }

    function _registerRobot() internal returns (uint256 groupId) {
        groupId = registry.registerGroupRobot("Group A");
        vm.prank(operator);
        registry.registerRobot(
            robot1,
            "Robot-1",
            groupId,
            80,
            "img-1",
            chat1
        );
    }

    function testFullFlowV2() public {
        uint256 groupId = _registerRobot();

        assertEq(registry.getGroupCount(), 1);
        assertEq(registry.getRobotCount(), 1);

        vm.prank(robot1);
        registry.updateStatus(RobotRegistry.RobotStatus.CHARGING);
        vm.prank(robot1);
        registry.updateBattery(100);

        vm.prank(operator);
        RobotRegistry.Robot memory robot = registry.getRobotByAddress(robot1);
        assertEq(robot.groupId, groupId);
        assertEq(robot.batteryLevel, 100);
        assertEq(
            uint256(robot.status),
            uint256(RobotRegistry.RobotStatus.ACTIVE)
        );

        vm.prank(operator);
        location.updateLocation(robot1, "10.0,20.0");
        vm.prank(operator);
        RobotLocation.Location memory loc = location.getLocation(robot1);
        assertEq(loc.robotAddress, robot1);
        assertEq(loc.latlon, "10.0,20.0");

        vm.prank(operator);
        location.updateLog(robot1, 100, 2, 3, 4);
        RobotLocation.Log memory log = location.getLog(robot1);
        assertEq(log.workingTime, 100);
        assertEq(log.service, 2);
        assertEq(log.question, 3);
        assertEq(log.support, 4);

        RobotQuestion.Message memory message = RobotQuestion.Message({
            request_id: "req-1",
            text: "hello",
            lang_id: "vi",
            pronoun: "ban",
            flag: 1,
            session_id: "s-1",
            key: "k-1"
        });
        question.uploadQuestion(message);
        RobotQuestion.Message memory messageOut = question.getQuestions("req-1");
        assertEq(messageOut.text, "hello");
        assertEq(messageOut.lang_id, "vi");

        vm.prank(operator);
        uint256 activityId = active.startActivity(robot1, "support");
        vm.warp(block.timestamp + 10);
        vm.prank(operator);
        active.endCurrentActivity(robot1);

        assertEq(active.getActivityCount(robot1), 1);
        assertEq(active.getTotalActivityCount(), 1);
        assertEq(active.getTotalActiveTime(robot1), 10);

        RobotActive.RobotActiveInfo memory activity = active.getActivityById(
            robot1,
            activityId
        );
        assertEq(
            uint256(activity.status),
            uint256(RobotActive.ActivityStatus.COMPLETED)
        );

        vm.prank(operator);
        uint256 sessionId = observation.startObservationSession(
            robot1,
            "Obs 1",
            "desc",
            "cam-1"
        );
        observation.recordObservation(
            sessionId,
            "data://1",
            100,
            "video",
            "notes"
        );
        vm.prank(operator);
        observation.updateTrainingResult(
            robot1,
            sessionId,
            "model-v1",
            90,
            "url://result"
        );
        vm.warp(block.timestamp + 5);
        vm.prank(operator);
        observation.endObservationSession(robot1);

        RobotObservationTraining.ObservationSession memory obs = observation
            .getSessionById(robot1, sessionId);
        assertEq(
            uint256(obs.status),
            uint256(RobotObservationTraining.TrainingStatus.COMPLETED)
        );
        assertEq(obs.accuracy, 90);

        vm.prank(operator);
        uint256 testId = testing.startTestSession(robot1, "Test 1");
        vm.prank(operator);
        testing.addTestFile(testId, "key-1", "file-1");
        vm.prank(operator);
        testing.addTestFile(testId, "key-2", "file-2");
        vm.prank(operator);
        testing.removeTestFile(testId, 0);
        vm.prank(operator);
        testing.submitTestResult(
            testId,
            10,
            7,
            700,
            7000,
            true,
            "result-1"
        );
        vm.prank(operator);
        testing.endTestSession(robot1);

        (
            uint256 totalTests,
            uint256 passedTests,
            uint256 failedTests,
            uint256 avgScore,
            uint256 avgPassRate
        ) = testing.getTestStats(robot1);
        assertEq(totalTests, 1);
        assertEq(passedTests, 1);
        assertEq(failedTests, 0);
        assertEq(avgScore, 700);
        assertEq(avgPassRate, 7000);

        vm.prank(operator);
        uint256 uploadId = upload.startUploadSession(
            robot1,
            "Upload 1",
            "desc"
        );
        vm.prank(operator);
        upload.addFile(robot1, uploadId, "f1", "k1", "img", 100);
        vm.prank(operator);
        upload.addFile(robot1, uploadId, "f2", "k2", "img", 200);
        vm.prank(operator);
        upload.updateFileProgress(robot1, uploadId, 0, 100);
        vm.prank(operator);
        upload.endUploadSession(robot1);

        RobotDataUploadTraining.UploadSession[] memory uploads = upload
            .getSessionsByRobot(robot1);
        assertEq(uploads.length, 1);
        assertEq(uploads[0].totalFiles, 2);
        assertEq(uploads[0].totalDataSize, 300);

        uint256 dayTs = checkpoint.getDayTimestamp(block.timestamp);
        string[] memory questions = new string[](2);
        questions[0] = "q1";
        questions[1] = "q2";
        uint256[] memory counts = new uint256[](2);
        counts[0] = 5;
        counts[1] = 3;

        checkpoint.addDailyFAQ(dayTs, questions, counts);
        checkpoint.addMonthlyFAQ(202603, questions, counts);
        checkpoint.addYearlyFAQ(2026, questions, counts);

        string[] memory types = new string[](1);
        types[0] = "Mini";
        uint256[] memory typeCounts = new uint256[](1);
        typeCounts[0] = 1;
        checkpoint.addDailyRobotStat(dayTs, types, typeCounts, 1, 100, 5);
        checkpoint.addMonthlyRobotStat(202603, types, typeCounts, 1, 100, 5);
        checkpoint.addYearlyRobotStat(2026, types, typeCounts, 1, 100, 5);

        checkpoint.addCheckpoint(
            robot1,
            block.timestamp,
            5,
            10,
            8,
            7,
            3,
            2
        );
        checkpoint.addIncident(
            robot1,
            RobotCheckpoint.IncidentCategory.Move,
            RobotCheckpoint.IncidentDetail.Stuck,
            block.timestamp,
            "stuck"
        );

        vm.prank(operator);
        (string[] memory monthQs, uint256[] memory monthCounts) = checkpoint
            .getMonthlyFAQ(202603);
        assertEq(monthQs.length, 2);
        assertEq(monthCounts[0], 5);

        vm.prank(operator);
        (
            address[] memory robotAddresses,
            uint256[] memory timestamps,
            uint8[] memory satisfactions,
            uint256[] memory customerCounts,
            uint256[] memory correctAnswers,
            uint256[] memory successful,
            uint256[] memory unsuccesfull,
            uint256[] memory incorrectAnswer
        ) = checkpoint.getGlobalStatsByTimeRange(
                block.timestamp - 1,
                block.timestamp + 1
            );
        assertEq(robotAddresses.length, 1);
        assertEq(robotAddresses[0], robot1);
        assertEq(timestamps.length, 1);
        assertEq(satisfactions[0], 5);
        assertEq(customerCounts[0], 10);
        assertEq(correctAnswers[0], 8);
        assertEq(successful[0], 7);
        assertEq(unsuccesfull[0], 3);
        assertEq(incorrectAnswer[0], 2);

        vm.prank(operator);
        (
            address[] memory issueRobots,
            RobotCheckpoint.IncidentCategory[] memory categories,
            RobotCheckpoint.IncidentDetail[] memory details,
            uint256[] memory issueTimestamps,
            uint256 totalCount,
            string[] memory descriptions
        ) = checkpoint.getIssuesCountsByTimeRange(
                RobotCheckpoint.IncidentCategory.Move,
                block.timestamp - 1,
                block.timestamp + 1,
                10,
                0
            );
        assertEq(totalCount, 1);
        assertEq(issueRobots.length, 1);
        assertEq(uint256(categories[0]), uint256(RobotCheckpoint.IncidentCategory.Move));
        assertEq(uint256(details[0]), uint256(RobotCheckpoint.IncidentDetail.Stuck));
        assertEq(issueTimestamps.length, 1);
        assertEq(descriptions[0], "stuck");
    }
}
