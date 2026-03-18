// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {INetCafeSessionV2} from "./interfaces/INetCafeSessionV2.sol";
import {NetCafeStaffUpgradeable} from "./NetCafeStaffUpgradeable.sol";

contract NetCafeUserV2 is
    OwnableUpgradeable,
    UUPSUpgradeable,
    NetCafeStaffUpgradeable
{
    struct User {
        address wallet;
        string displayName;
        string cccd;
        string phone;
        string email;
        uint256 balanceVND;
        uint256 otp;
        uint256 otpExpire;
        bool active;
        bool online;
        uint256 lastLoginAt;
        string deviceName;
    }
    INetCafeSessionV2 public sessionContract;

    address[] public userList;
    mapping(address => User) public users;

    mapping(address => bool) public walletUsed;
    mapping(string => bool) private phoneUsed;
    mapping(string => bool) private emailUsed;
    mapping(string => bool) private cccdUsed;
    mapping(uint256 => address) public otpOwner;
    mapping(string => address) private phoneToWallet;
    mapping(string => address) private emailToWallet;
    mapping(string => address) private cccdToWallet;

    enum IdentityType {
        PHONE,
        EMAIL,
        CCCD
    }

    mapping(address => bool) public modules;

    event ModuleUpdated(address indexed module, bool allowed);
    event UserRegistered(address indexed wallet, uint256 initialVND);
    event OTPGenerated(address indexed wallet, uint256 otp, uint256 expiresAt);
    event BalanceUpdated(address indexed wallet, uint256 newBalanceVND);
    event UserLogin(address indexed wallet, string deviceName, uint256 loginAt);
    event AddressLogin(address indexed wallet);
    event UserLogout(address indexed wallet, uint256 logoutAt);
    event PublicOTPGenerated(
        address indexed caller,
        address indexed user,
        uint256 otp,
        uint256 expiresAt
    );
    event UserUpdated(
        address indexed wallet,
        string name,
        string email,
        string phone,
        string cccd
    );

    function initialize(address _staffContract) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __NetCafeStaff_init(_staffContract);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    modifier onlyModule() {
        require(modules[msg.sender], "Not module");
        _;
    }
    modifier onlyValidSession(
        address sessionWallet,
        bytes32 sessionKeyHash,
        bytes32 pcId
    ) {
        require(
            address(sessionContract) != address(0),
            "Session contract not set"
        );
        require(
            sessionContract.validateSession(
                sessionWallet,
                sessionKeyHash,
                pcId
            ),
            "Invalid or expired session"
        );
        _;
    }

    function setModule(address module, bool allowed) external onlyOwner {
        require(module != address(0), "Invalid module");
        modules[module] = allowed;
        emit ModuleUpdated(module, allowed);
    }

    function _generateOTP(address wallet) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, block.prevrandao, wallet)
                )
            ) % 1_000_000;
    }

    function registerUser(
        address wallet,
        string calldata displayName,
        string calldata cccd,
        string calldata phone,
        string calldata email,
        uint256 initialVND
    ) external {
        require(wallet != address(0), "Invalid wallet");
        require(!walletUsed[wallet], "Wallet already registered");
        require(!phoneUsed[phone], "Phone already registered");
        require(!emailUsed[email], "Email already registered");
        require(!cccdUsed[cccd], "CCCD already registered");
        require(initialVND > 0, "Initial VND required");

        uint256 otp = _generateOTP(wallet);

        users[wallet] = User({
            wallet: wallet,
            displayName: displayName,
            cccd: cccd,
            phone: phone,
            email: email,
            balanceVND: initialVND,
            otp: otp,
            otpExpire: block.timestamp + 5 minutes,
            active: true,
            online: false,
            lastLoginAt: 0,
            deviceName: ""
        });

        walletUsed[wallet] = true;
        phoneUsed[phone] = true;
        emailUsed[email] = true;
        cccdUsed[cccd] = true;
        otpOwner[otp] = wallet;
        phoneToWallet[phone] = wallet;
        emailToWallet[email] = wallet;
        cccdToWallet[cccd] = wallet;
        userList.push(wallet);

        emit UserRegistered(wallet, initialVND);
        emit OTPGenerated(wallet, otp, block.timestamp + 5 minutes);
        emit BalanceUpdated(wallet, initialVND);
    }

    function getUsers(
        uint256 offset,
        uint256 limit
    ) external view returns (User[] memory) {
        uint256 total = userList.length;

        if (offset >= total) {
            return new User[](0);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        User[] memory result = new User[](end - offset);

        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = users[userList[i]];
        }

        return result;
    }

    function getAddressByIdentity(
        IdentityType idType,
        string calldata value
    ) external view returns (address) {
        address wallet;

        if (idType == IdentityType.PHONE) {
            wallet = phoneToWallet[value];
        } else if (idType == IdentityType.EMAIL) {
            wallet = emailToWallet[value];
        } else if (idType == IdentityType.CCCD) {
            wallet = cccdToWallet[value];
        }

        require(wallet != address(0), "Not found");
        require(users[wallet].active, "User inactive");

        return wallet;
    }

    function generateOTPForTest(address userWallet) external {
        require(users[userWallet].active, "User not registered");

        uint256 oldOtp = users[userWallet].otp;
        if (oldOtp != 0) {
            delete otpOwner[oldOtp];
        }

        uint256 otp = _generateOTP(userWallet);

        users[userWallet].otp = otp;
        users[userWallet].otpExpire = block.timestamp + 3 minutes;
        otpOwner[otp] = userWallet;

        emit PublicOTPGenerated(
            msg.sender,
            userWallet,
            otp,
            users[userWallet].otpExpire
        );
    }

    function loginWithOTP(uint256 otp) external returns (address userWallet) {
        address wallet = otpOwner[otp];
        require(wallet != address(0), "OTP not found");

        User storage u = users[wallet];
        require(u.active, "User inactive");
        require(block.timestamp <= u.otpExpire, "OTP expired");
        require(u.otp == otp, "Invalid OTP");

        delete otpOwner[otp];
        u.otp = 0;
        u.otpExpire = 0;
        emit AddressLogin(wallet);
        return wallet;
    }

    function loginUser(address wallet, string calldata deviceName) external {
        require(users[wallet].active, "User inactive");

        User storage u = users[wallet];

        u.online = true;
        u.lastLoginAt = block.timestamp;
        u.deviceName = deviceName;

        emit UserLogin(wallet, deviceName, block.timestamp);
    }

    function logoutUser(address wallet) external {
        require(users[wallet].online, "User already logged out");
        User storage u = users[wallet];
        u.online = false;
        u.deviceName = "";
        u.lastLoginAt = 0;
        emit UserLogout(wallet, block.timestamp);
    }

    function getMyBalanceVND() external view returns (uint256) {
        require(users[msg.sender].active, "Not registered");
        return users[msg.sender].balanceVND;
    }

    function editUser(
        address wallet,
        string memory _name,
        string memory _email,
        string memory _phoneNumber,
        string memory _cccd
    ) external {
        require(walletUsed[wallet], "Wallet is not registered ");
        User storage user = users[wallet];
        user.displayName = _name;
        user.email = _email;
        user.phone = _phoneNumber;
        user.cccd = _cccd;
        emit UserUpdated(wallet, _name, _email, _phoneNumber, _cccd);
    }

    function isActive(address wallet) external view returns (bool) {
        return users[wallet].active;
    }

    function isOnline(address wallet) external view returns (bool) {
        return users[wallet].online;
    }

    function getDisplayName(
        address wallet
    ) external view returns (string memory) {
        return users[wallet].displayName;
    }

    function getUserStatus(
        address wallet,
        address sessionWallet, // thêm param
        bytes32 sessionKeyHash,
        bytes32 pcId
    )
        external
        onlyValidSession(sessionWallet, sessionKeyHash, pcId)
        returns (
            bool active,
            bool online,
            uint256 lastLoginAt,
            uint256 balanceVND
        )
    {
        User storage u = users[wallet];
        return (u.active, u.online, u.lastLoginAt, u.balanceVND);
    }

    function getUserStationData(
        address wallet,
        address sessionWallet, // thêm param
        bytes32 sessionKeyHash,
        bytes32 pcId
    )
        external
        onlyValidSession(sessionWallet, sessionKeyHash, pcId)
        returns (
            bool online,
            uint256 lastLoginAt,
            uint256 balanceVND,
            string memory displayName,
            string memory cccd,
            string memory email
        )
    {
        User storage u = users[wallet];
        return (
            u.online,
            u.lastLoginAt,
            u.balanceVND,
            u.displayName,
            u.cccd,
            u.email
        );
    }

    function increaseBalance(
        address wallet,
        uint256 amount
    ) external onlyModule {
        require(users[wallet].active, "User not found");
        users[wallet].balanceVND += amount;
        emit BalanceUpdated(wallet, users[wallet].balanceVND);
    }

    function decreaseBalance(
        address wallet,
        uint256 amount
    ) external onlyModule {
        require(users[wallet].active, "User not found");
        require(users[wallet].balanceVND >= amount, "Insufficient balance");
        users[wallet].balanceVND -= amount;
        emit BalanceUpdated(wallet, users[wallet].balanceVND);
    }

    function forceLogout(address wallet) external onlyModule {
        User storage u = users[wallet];
        if (!u.online) {
            return;
        }
        u.online = false;
        u.lastLoginAt = 0;
        u.deviceName = "";
        emit UserLogout(wallet, block.timestamp);
    }
    function setSessionContract(address _session) external onlyOwner {
        sessionContract = INetCafeSessionV2(_session);
    }

    uint256[50] private __gap;
}
