// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts/utils/Strings.sol";
// import "./interfaces/IPoint.sol";
// import "./interfaces/IManagement.sol";
// import "./interfaces/IMeos.sol";
// /**
//  * @title RestaurantLoyaltySystem
//  * @dev Hợp nhất RestaurantLoyaltySystem và agentLoyalty
//  * Token = Point, tích hợp đầy đủ tính năng loyalty và ERC20-like token
//  */
// contract RestaurantLoyaltySystem is
//     Initializable,
//     ReentrancyGuardUpgradeable,
//     OwnableUpgradeable,
//     PausableUpgradeable,
//     UUPSUpgradeable
// {
//     using Strings for uint256;

//     // ============ TOKEN INFO (ERC20-like) ============
//     string public name;
//     string public symbol;
//     uint8 public constant decimals = 18;
    
//     // ============ STATE VARIABLES ============
//     address public agent;
//     address public MANAGEMENT;
//     address public Order;
    
//     // Token/Point economics
//     uint256 public totalSupply;           // Tổng token đang lưu hành (= totalSupply)
//     uint256 public totalMinted;           // Tổng token đã phát hành
//     uint256 public totalBurned;           // Tổng token đã đốt
//     uint256 public totalRedeemed;         // Tổng token đã đổi quà
//     uint256 public exchangeRate;          // Tỷ giá: X VND = 1 token
//     uint256 public accumulationPercent;   // Tỷ lệ tích điểm trên hóa đơn
//     uint256 public maxPercentPerInvoice;  // % tối đa dùng token thanh toán
    
//     // Loyalty system
//     uint256 public pointExpiryPeriod;     // Thời gian hết hạn
//     uint256 public sessionDuration;
//     uint256 public validityPeriod;
//     bool public isUnlimitedIssue;
//     bool public isApplyWithOtherDiscount;
    
//     // Migration & Control
//     bool public frozen;
//     bool public redeemOnly;
//     uint256 public redeemDeadline;
//     bool public migrated;
//     address public migratedTo;
//     address public enhancedAgentSC;
    
//     // Counters
//     uint256 private transactionCounter;
//     uint256 private eventCounter;
//     uint256 private requestCounter;
    
//     // ERC20-like mappings
//     mapping(address => uint256) public balanceOf;           // Token balance của user
//     mapping(address => mapping(address => uint256)) public allowance;
    
//     // Member mappings
//     mapping(address => Member) public members;
//     mapping(string => address) public memberIdToAddress;
//     mapping(address => uint256[]) public memberTransactions;
//     mapping(address => bytes32[]) public memberToGroups; // Member có thể thuộc nhiều groups    
//     // System mappings
//     mapping(uint256 => Transaction) public transactions;
//     mapping(uint256 => Event) public events;
//     mapping(bytes32 => TierConfig) public tierConfigs;
//     mapping(uint256 => ManualRequest) public manualRequests;
//     mapping(bytes32 => bool) public processedInvoices;
//     mapping(bytes32 => MemberGroup) public memberGroups;
//     mapping(bytes32 => address[]) public groupMembers;
//     mapping(string => TierConfig) public mNameToTierConfig;
    
//     // Voucher & Payment
//     mapping(address => string[]) public memberVouchers;
//     mapping(address => mapping(string => MemberVoucher[])) public memberVoucherDetails;
//     mapping(address => PaymentTransaction[]) public memberPaymentHistory;
    
//     // Migration tracking
//     mapping(address => bool) public userMigrated;
//     uint256 public totalMigrated;
//     address[] public tokenHolders;
//     mapping(address => bool) public isTokenHolder;
    
//     // Arrays
//     Transaction[] public allTransactions;
//     TierConfig[] public allTiers;
//     Member[] public allMembers;
//     bytes32[] public allGroupIds;
//     MemberGroup[] public allMemberGroups;
//     RewardTransaction[] public rewardTransactions;
//     mapping(address => uint256) public lastRequestDate;
//     mapping(address => uint256) public staffDailyRequests; // Giới hạn yêu cầu/ngày

//     bytes32 constant ROLE_ADMIN = keccak256("ROLE_ADMIN");

//     struct RewardTransaction {
//         address user;
//         uint256 amount;
//         string transactionType;
//         uint256 timestamp;
//         string metadata;
//     }

//     Event[] public allEvents;
//     mapping(uint256 => bool) public processedBillDeposit;
//     uint256 public accumulationPercentDeposit;   // Tỷ lệ tích điểm trên hóa đơn
//     address public TopUp;
//     // ============ EVENTS ============
    
//     // ERC20-like events
//     event Transfer(address indexed from, address indexed to, uint256 value);
//     event Approval(address indexed owner, address indexed spender, uint256 value);
    
//     // Token management events
//     event Mint(address indexed to, uint256 amount, string metadata);
//     event Burn(address indexed from, uint256 amount, string metadata);
    
//     // Loyalty events
//     event MemberRegistered(address indexed wallet, string memberId, uint256 timestamp);
//     event PointsEarned(address indexed member, uint256 points, bytes32 invoiceId, uint256 timestamp);
//     event PointsRedeemed(address indexed member, uint256 points, uint256 rewardId, uint256 timestamp);
//     event TierUpdated(address indexed member, uint oldTierId, uint newTierId, uint256 timestamp);
//     event PointsExpired(address indexed member, uint256 points, uint256 timestamp);
//     event EventCreated(uint256 indexed eventId, string name, uint256 startTime, uint256 endTime);
//     event TransactionCreated(uint256 indexed txId, address indexed member, TransactionType txType, int256 points);
//     event MemberLocked(address indexed member, address indexed admin, string reason, uint256 timestamp);
//     event MemberUnlocked(address indexed member, address indexed admin, uint256 timestamp);
//     event PointsIssued(uint256 amount, address indexed issuedBy, uint256 timestamp);
//     event ManualRequestCreated(uint256 indexed requestId, address indexed member, address indexed staff, uint256 timestamp);
//     event ManualRequestProcessed(uint256 indexed requestId, bool approved, address indexed admin, uint256 timestamp);
//     event PointsRefunded(address indexed member, uint256 points, bytes32 invoiceId, string reason, uint256 timestamp);
//     event MemberGroupCreated(bytes32 indexed groupId, string name, uint256 timestamp);
//     event MemberAssignedToGroup(address indexed member, bytes32 indexed groupId, uint256 timestamp);
//     event VoucherRedeemed(address indexed member, string voucherCode, uint256 pointsSpent, uint256 timestamp);
//     event VoucherUsed(address indexed member, string voucherCode, uint256 timestamp);
//     event PointsUsedForPayment(address indexed member, bytes32 indexed paymentId, uint256 pointsUsed, uint256 orderAmount, uint256 timestamp);
    
//     // Migration events
//     event Frozen(uint256 timestamp);
//     event Unfrozen(uint256 timestamp);
//     event RedeemOnlyMode(uint256 deadline);
//     event MigrationInitiated(address indexed newContract, uint256 totalSupply, uint256 timestamp);
//     event UserBalanceMigrated(address indexed user, uint256 amount, address indexed newContract);
//     event MigrationCompleted(address indexed newContract, uint256 totalAmount, uint256 userCount);
//     event MemberGroupUpdated(bytes32 indexed groupId, string name, uint256 timestamp);
//     event MemberGroupDeleted(bytes32 indexed groupId, uint256 timestamp);
//     event MemberRemovedFromGroup(address indexed member, bytes32 indexed groupId, uint256 timestamp);
//     event MemberUpdated(
//         address indexed walletAddress,
//         string memberId,
//         uint256 timestamp
//     );
//     // ============ MODIFIERS ============
    
//     modifier onlyAdmin() {
//         require(IManagement(MANAGEMENT).hasRole(ROLE_ADMIN, msg.sender), "Only admin");
//         _;
//     }
    
//     modifier onlyStaffOrAdmin() {
//         require(IManagement(MANAGEMENT).isStaff(msg.sender), "Only staff or admin");
//         _;
//     }
    
//     modifier memberExists(address _member) {
//         require(members[_member].isActive, "Member not found");
//         _;
//     }
    
//     modifier notLocked(address _member) {
//         require(!members[_member].isLocked, "Account is locked");
//         _;
//     }
    
//     modifier onlyOrder() {
//         require(msg.sender == Order, "Only Order can call");
//         _;
//     }
    
//     modifier notFrozen() {
//         require(!frozen, "Contract is frozen");
//         _;
//     }
    
//     modifier canMint() {
//         require(!frozen && !redeemOnly && !migrated, "Cannot mint tokens");
//         _;
//     }
    
//     modifier notMigrated() {
//         require(!migrated, "Contract has been migrated");
//         _;
//     }
    
//     modifier onlyAgentSC() {
//         require(msg.sender == enhancedAgentSC, "Only enhancedAgent contract can call");
//         _;
//     }
    
//     uint256[50] private __gap;
    
//     // ============ INITIALIZATION ============
    
//     constructor() {
//         _disableInitializers();
//     }
    
//     function initialize(
//         address _agent,
//         address _enhancedAgentSC
//     ) public initializer {
//         __ReentrancyGuard_init();
//         __Ownable_init(msg.sender);
//         __Pausable_init();
//         __UUPSUpgradeable_init();
        
//         require(_agent != address(0), "Invalid agent address");
        
//         name = "Loyalty Point";
//         symbol = "LPT";
//         agent = _agent;
//         enhancedAgentSC = _enhancedAgentSC;
        
//         exchangeRate = 10000; // 10,000 VND = 1 token
//         pointExpiryPeriod = 365 days;
//         sessionDuration = 30 days;
//         accumulationPercent = 100; // 100%
//         maxPercentPerInvoice = 50; // 50%
//     }
    
//     function _authorizeUpgrade(address newImplementation) internal override  {}
    
//     // ============ CONFIGURATION FUNCTIONS ============
    
//     function setManagementSC(address _management) external onlyOwner {
//         MANAGEMENT = _management;
//     }
    
//     function setOrder(address _order) external onlyOwner {
//         Order = _order;
        
//     }
//     function setTopUp(address _topup) external onlyOwner {
//         TopUp = _topup;
//     }

//     function setAgent(address _agent) external onlyOwner {
//         agent = _agent;
//     }
//     function isRedeemOnly() external view returns (bool) {
//         return redeemOnly;
//     }
//     // ============ ERC20-LIKE FUNCTIONS ============
    
//     /**
//      * @dev Transfer tokens (chỉ khi không frozen và không migrated)
//      */
//     function transfer(address _to, uint256 _amount) 
//         external 
//         notFrozen 
//         notMigrated 
//         returns (bool) 
//     {
//         return _transfer(msg.sender, _to, _amount);
//     }
    
//     function transferFrom(address _from, address _to, uint256 _amount) 
//         external 
//         notFrozen 
//         notMigrated 
//         returns (bool) 
//     {
//         require(allowance[_from][msg.sender] >= _amount, "Insufficient allowance");
//         allowance[_from][msg.sender] -= _amount;
//         return _transfer(_from, _to, _amount);
//     }
    
//     function _transfer(address _from, address _to, uint256 _amount) internal returns (bool) {
//         require(_from != address(0) && _to != address(0), "Invalid addresses");
//         require(balanceOf[_from] >= _amount, "Insufficient balance");
        
//         balanceOf[_from] -= _amount;
//         balanceOf[_to] += _amount;
        
//         // Update member points
//         if (members[_from].isActive) {
//             members[_from].totalPoints = balanceOf[_from];
//         }
//         if (members[_to].isActive) {
//             members[_to].totalPoints = balanceOf[_to];
//         }
        
//         // Track token holders
//         if (balanceOf[_to] > 0 && !isTokenHolder[_to]) {
//             tokenHolders.push(_to);
//             isTokenHolder[_to] = true;
//         }
        
//         // Record transaction
//         _createTransaction(
//             _from,
//             TransactionType.Transfer,
//             -int256(_amount),
//             0,
//             bytes32(0),
//             string(abi.encodePacked("Transfer to ", Strings.toHexString(uint160(_to)))),
//             0
//         );
        
//         emit Transfer(_from, _to, _amount);
//         return true;
//     }
    
//     function approve(address _spender, uint256 _amount) external returns (bool) {
//         allowance[msg.sender][_spender] = _amount;
//         emit Approval(msg.sender, _spender, _amount);
//         return true;
//     }
    
//     // ============ MEMBER FUNCTIONS ============
    
//     function registerMember(RegisterInPut memory input) external {
//         require(bytes(input._memberId).length >= 8 && bytes(input._memberId).length <= 12, "Invalid member ID length");
//         require(!members[msg.sender].isActive, "Already registered");
//         require(memberIdToAddress[input._memberId] == address(0), "Member ID already exists");
        
//         members[msg.sender] = Member({
//             memberId: input._memberId,
//             walletAddress: msg.sender,
//             totalPoints: 0,
//             lifetimePoints: 0,
//             totalSpent: 0,
//             tierID: bytes32(0),
//             lastBuyActivityAt: 0,
//             isActive: true,
//             isLocked: false,
//             phoneNumber: input._phoneNumber,
//             firstName: input._firstName,
//             lastName: input._lastName,
//             whatsapp: input._whatsapp,
//             email: input._email,
//             avatar: input._avatar
//         });
        
//         memberIdToAddress[input._memberId] = msg.sender;
//         allMembers.push(members[msg.sender]);
        
//         // Track as token holder (even with 0 balance)
//         if (!isTokenHolder[msg.sender]) {
//             tokenHolders.push(msg.sender);
//             isTokenHolder[msg.sender] = true;
//         }
        
//         emit MemberRegistered(msg.sender, input._memberId, block.timestamp);
//     }
//     function updateMember(UpdateMemberInput memory input) external {
//         require(members[msg.sender].isActive, "Member not registered");
//         require(!members[msg.sender].isLocked, "Member account is locked");
//         require(bytes(input._memberId).length >= 8 && bytes(input._memberId).length <= 12, "Invalid member ID length");

//         Member storage member = members[msg.sender];
//         require(keccak256(abi.encodePacked(member.memberId)) == keccak256(abi.encodePacked(input._memberId)) || memberIdToAddress[input._memberId] == address(0), "Member ID already exists");
//         delete memberIdToAddress[member.memberId];
//         // Update member information
//         member.phoneNumber = input._phoneNumber;
//         member.firstName = input._firstName;
//         member.lastName = input._lastName;
//         member.whatsapp = input._whatsapp;
//         member.email = input._email;
//         member.avatar = input._avatar;
//         if(keccak256(abi.encodePacked(member.memberId)) != keccak256(abi.encodePacked(input._memberId)) ){
//             member.memberId = input._memberId;

//         }
        
//         // Update in allMembers array
//         for (uint i = 0; i < allMembers.length; i++) {
//             if (keccak256(bytes(allMembers[i].memberId)) == keccak256(bytes(member.memberId))) {
//                 allMembers[i] = member;
//                 break;
//             }
//         }
         
//         memberIdToAddress[input._memberId] = msg.sender;
//         emit MemberUpdated(
//             msg.sender, 
//             member.memberId, 
//             block.timestamp
//         );
//     }
//      //contract Order gọi
//     function updateLastBuyActivityAt(address user) external onlyOrder{
//         members[msg.sender].lastBuyActivityAt = block.timestamp;
//     }
//     function isMemberPointSystem(address _user) external view returns (bool){
//         return(members[_user].isActive);
//     }
//     function GetAllMembersPagination(
//         uint256 offset, 
//         uint256 limit
//     )
//         external
//         view
//         returns (Member[] memory result,uint totalCount)
//     {
//         uint length = allMembers.length;
//         if(offset >= length) {
//             return ( new Member[](0),length);
//         }

//         uint256 end = offset + limit;
//         if (end > length) {
//             end = length;
//         }

//         uint256 size = end - offset;
//         result = new Member[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = length - 1 - offset - i;
//             result[i] = allMembers[reverseIndex];
//         }

//         return (result,length);
//     }
// /**
//  * @dev Xóa member (đã fix)
//  */
// function DeleteMember(address _member) external onlyAdmin {
//     require(members[_member].walletAddress != address(0), "Member not found");
    
//     Member storage member = members[_member];
//     string memory memberId = member.memberId;
    
//     // Gỡ member khỏi tất cả groups
//     bytes32[] memory groups = memberToGroups[_member];
//     for (uint256 i = 0; i < groups.length; i++) {
//         _removeMemberFromGroupArray(groups[i], _member);
//     }
//     delete memberToGroups[_member];
    
//     // Xóa mapping
//     delete memberIdToAddress[memberId];
//     delete members[_member];
    
//     // Xóa khỏi allMembers array
//     for (uint256 i = 0; i < allMembers.length; i++) {
//         if (allMembers[i].walletAddress == _member) {
//             allMembers[i] = allMembers[allMembers.length - 1];
//             allMembers.pop();
//             break;
//         }
//     }
// }    
// function _isValidAmount(bytes32 _paymentId,uint _amount)internal view returns(bool){
//         require(Order != address(0),"Order address not set yet");
//         return IOrder(Order).isValidAmount(_paymentId,_amount);
//     } 
// function _isValidAmountDeposit(uint256 _paymentId,uint _amount)internal view returns(bool){
//         require(TopUp != address(0),"TopUp address not set yet");
//         return INetCafeTopUp(TopUp).isValidAmount(_paymentId,_amount);
//     } 

//     /**

//     // ============ TOKEN/POINT ISSUANCE ============
    
//    /**
//      * @dev Mint tokens trực tiếp cho user (admin only)
//      * Dùng để phát hành điểm thủ công cho member cụ thể
//      */
//     function mint(address _to, uint256 _amount, string memory _metadata) 
//         external 
//         onlyAdmin
//         canMint 
//     {
//         require(_to != address(0), "Cannot mint to zero address");
//         require(_amount > 0, "Amount must be greater than 0");
        
//         totalSupply += _amount;
//         totalMinted += _amount;
//         balanceOf[_to] += _amount;
        
//         // Update member if exists
//         if (members[_to].isActive) {
//             members[_to].totalPoints = balanceOf[_to];
//             members[_to].lifetimePoints += _amount;
//             _updateMemberTier(_to);
//         }
        
//         // Track token holder
//         if (!isTokenHolder[_to]) {
//             tokenHolders.push(_to);
//             isTokenHolder[_to] = true;
//         }
        
//         _recordRewardTransaction(_to, _amount, "mint", _metadata);
//         _createTransaction(
//             _to,
//             TransactionType.Earn,
//             int256(_amount),
//             0,
//             bytes32(0),
//             string(abi.encodePacked("Manual mint: ", _metadata)),
//             0
//         );
        
//         emit Mint(_to, _amount, _metadata);
//         emit PointsEarned(_to, _amount, bytes32(0), block.timestamp);
//         emit Transfer(address(0), _to, _amount);
//     }
//        // ============ STAFF FUNCTIONS ============
    
//     /**
//      * @dev Nhân viên tạo yêu cầu tích điểm thủ công
//      */
//     function createManualRequest(
//         string memory _memberID,
//         bytes32 _invoiceId,
//         uint256 _amount,
//         RequestEarnPointType _typeRequest,
//         string memory _img
//     ) external onlyStaffOrAdmin returns (uint256) {
//         address _member = memberIdToAddress[_memberID];
//         require(members[_member].isActive, "Member not found");
//         require(!processedInvoices[_invoiceId], "Invoice already processed");
        
//         // Kiểm tra giới hạn yêu cầu hàng ngày
//         if (block.timestamp / 1 days > lastRequestDate[msg.sender] / 1 days) {
//             staffDailyRequests[msg.sender] = 0;
//             lastRequestDate[msg.sender] = block.timestamp;
//         }
        
//         require(staffDailyRequests[msg.sender] < 50, "Daily request limit reached");
        
//         uint256 pointsToEarn = _amount / exchangeRate;
        
//         requestCounter++;
//         manualRequests[requestCounter] = ManualRequest({
//             id: requestCounter,
//             member: _member,
//             invoiceId: _invoiceId,
//             amount: _amount,
//             pointsToEarn: pointsToEarn,
//             requestedBy: msg.sender,
//             requestTime: block.timestamp,
//             status: RequestStatus.Pending,
//             approvedBy: address(0),
//             approvedTime: 0,
//             rejectReason: "",
//             typeRequest: _typeRequest,
//             img: _img
//         });
        
//         staffDailyRequests[msg.sender]++;
        
//         emit ManualRequestCreated(requestCounter, _member, msg.sender, block.timestamp);
        
//         return requestCounter;
//     }
//         /**
//      * @dev Nhân viên quét QR và trừ điểm cho khách
//      */
//     function redeemPointsForCustomer(
//         address _member,
//         uint256 _points,
//         string memory _note
//     ) external onlyStaffOrAdmin memberExists(_member) notLocked(_member) {
//         Member storage member = members[_member];
        
//         require(member.totalPoints >= _points, "Insufficient points");
        
//         member.totalPoints -= _points;
//         // member.lastBuyActivityAt = block.timestamp;
        
//         _createTransaction(
//             _member,
//             TransactionType.Redeem,
//             -int256(_points),
//             0,
//             "",
//             _note,
//             0
//         );
        
//         totalRedeemed += _points;
//     }

 
//    /**
//      * @dev Issue Points - Khởi tạo/cập nhật hệ thống điểm
//      * Thiết lập token name, tỷ giá, chính sách tích điểm
//      * _amount: số token phát hành ban đầu (nếu > 0, sẽ mint vào contract để phân phối sau)
//      */
//     function issuePoints(
//         uint256 _amount,
//         string memory _pointName,
//         bool _isUnlimitedIssue,
//         uint256 _accumulationPercent,
//         uint256 _maxPercentPerInvoice,
//         uint256 _newRate,
//         bool _isApplyWithOtherDiscount
//     ) external onlyAdmin {
//         require(_newRate > 0, "Invalid rate");
//         require(_amount > 0 || _isUnlimitedIssue, "Invalid amount");
//         require(bytes(_pointName).length > 0, "Point name required");
        
//         // Cập nhật token name = point name
//         name = _pointName;
//         symbol = _generateSymbol(_pointName); // Auto generate symbol từ name
        
//         accumulationPercent = _accumulationPercent;
//         maxPercentPerInvoice = _maxPercentPerInvoice;
//         isUnlimitedIssue = _isUnlimitedIssue;
//         exchangeRate = _newRate;
//         isApplyWithOtherDiscount = _isApplyWithOtherDiscount;
        
//         // Nếu có amount, mint tokens vào contract address để reserve
//         if (_amount > 0) {
//             totalSupply += _amount;
//             totalMinted += _amount;
//             balanceOf[address(this)] += _amount; // Store in contract
            
//             emit Mint(address(this), _amount, "Initial point issuance");
//             emit Transfer(address(0), address(this), _amount);
//         }
        
//         _createTransaction(
//             msg.sender,
//             TransactionType.Issue,
//             int256(_amount),
//             _amount,
//             bytes32(0),
//             string(abi.encodePacked("Issue points: ", _pointName)),
//             0
//         );
        
//         emit PointsIssued(_amount, msg.sender, block.timestamp);
//     }
//     function getPointsInfo() 
//         external view returns
//     (
//         string memory namePoint,
//         bool isUnlimitedIssuePoint,
//         uint accumulationPercentPoint,
//         uint maxPercentPerInvoicePoint,
//         uint exchangeRatePoint,
//         bool isApplyWithOtherDiscountPoint
//     ){
//         return(
//             name,
//             isUnlimitedIssue,
//             accumulationPercent,
//             maxPercentPerInvoice,
//             exchangeRate,
//             isApplyWithOtherDiscount
//         );
//     }
//      /**
//      * @dev Update cấu hình hệ thống điểm (không mint thêm token)
//      */
//     function updateIssuePoints(
//         string memory _pointName,
//         bool _isUnlimitedIssue,
//         uint256 _accumulationPercent,
//         uint256 _maxPercentPerInvoice,
//         uint256 _newRate,
//         bool _isApplyWithOtherDiscount
//     ) external onlyAdmin {
//         require(_newRate > 0, "Invalid rate");
        
//         if (bytes(_pointName).length > 0) {
//             name = _pointName;
//             symbol = _generateSymbol(_pointName);
//         }
        
//         accumulationPercent = _accumulationPercent;
//         maxPercentPerInvoice = _maxPercentPerInvoice;
//         isUnlimitedIssue = _isUnlimitedIssue;
//         exchangeRate = _newRate;
//         isApplyWithOtherDiscount = _isApplyWithOtherDiscount;
//     }

//     /**
//     * @dev Lấy config cho payment
//     */
//     function getPaymentConfig() external view returns (
//         uint256 exchangeRate,
//         uint256 maxPercentPerInvoice
//     ) {
//         return (exchangeRate, maxPercentPerInvoice);
//     }

//       /**
//      * @dev Phát hành thêm điểm (mint more tokens)
//      * Mint vào contract reserve hoặc trực tiếp cho address
//      */
//     function issueMorePoints(
//         uint256 _amount, 
//         address _recipient,
//         string memory _note
//     ) external onlyAdmin {
//         require(_amount > 0, "Amount must be greater than 0");
        
//         address target = _recipient == address(0) ? address(this) : _recipient;
        
//         totalSupply += _amount;
//         totalMinted += _amount;
//         balanceOf[target] += _amount;
        
//         if (target != address(this) && members[target].isActive) {
//             members[target].totalPoints = balanceOf[target];
//             members[target].lifetimePoints += _amount;
//             _updateMemberTier(target);
//         }
        
//         if (!isTokenHolder[target]) {
//             tokenHolders.push(target);
//             isTokenHolder[target] = true;
//         }
        
//         _createTransaction(
//             msg.sender,
//             TransactionType.Issue,
//             int256(_amount),
//             _amount,
//             bytes32(0),
//             _note,
//             0
//         );
        
//         emit Mint(target, _amount, _note);
//         emit PointsIssued(_amount, msg.sender, block.timestamp);
//         emit Transfer(address(0), target, _amount);
//     }

//     /**
//      * @dev Generate symbol từ point name
//      * VD: "Loyalty Point" -> "LP", "VIP Rewards" -> "VR"
//      */
//     function _generateSymbol(string memory _name) internal pure returns (string memory) {
//         bytes memory nameBytes = bytes(_name);
//         if (nameBytes.length == 0) return "LYT";
        
//         // Lấy chữ cái đầu của mỗi từ
//         bytes memory result = new bytes(10);
//         uint8 symbolLength = 0;
//         bool isNewWord = true;
        
//         for (uint i = 0; i < nameBytes.length && symbolLength < 10; i++) {
//             if (nameBytes[i] == " ") {
//                 isNewWord = true;
//             } else if (isNewWord) {
//                 // Chuyển sang chữ hoa
//                 if (nameBytes[i] >= 0x61 && nameBytes[i] <= 0x7A) {
//                     result[symbolLength] = bytes1(uint8(nameBytes[i]) - 32);
//                 } else {
//                     result[symbolLength] = nameBytes[i];
//                 }
//                 symbolLength++;
//                 isNewWord = false;
//             }
//         }
        
//         // Nếu chỉ có 1 ký tự, thêm "PT" (Point)
//         if (symbolLength == 1) {
//             result[1] = "P";
//             result[2] = "T";
//             symbolLength = 3;
//         }
        
//         bytes memory finalResult = new bytes(symbolLength);
//         for (uint i = 0; i < symbolLength; i++) {
//             finalResult[i] = result[i];
//         }
        
//         return string(finalResult);
//     }
//         /**
//      * @dev Duyệt yêu cầu tích điểm thủ công
//      */
//     function approveManualRequest(uint256 _requestId) external onlyAdmin {
//         ManualRequest storage request = manualRequests[_requestId];
        
//         // require(request.status == RequestStatus.Pending, "Request already processed");
//         // require(!processedInvoices[request.invoiceId], "Invoice already processed");
//         require(request.status != RequestStatus.Approved, "Request already approved");
        
//         Member storage member = members[request.member];
        
//         // Tính điểm với hệ số hạng
//         uint256 tierMultiplier = _getTierMultiplier(member.tierID);
//         uint256 points = (request.pointsToEarn * tierMultiplier) / 100;
        
//         // Cộng điểm
//         member.totalPoints += points;
//         member.lifetimePoints += points;
//         member.totalSpent += request.amount;
//         // member.lastBuyActivityAt = block.timestamp;
        
//         // Cập nhật yêu cầu
//         request.status = RequestStatus.Approved;
//         request.approvedBy = msg.sender;
//         request.approvedTime = block.timestamp;
        
//         // Đánh dấu hóa đơn
//         processedInvoices[request.invoiceId] = true;
        
//         // Cập nhật hạng
//         _updateMemberTier(request.member);

//         totalSupply += points;
        
//         emit ManualRequestProcessed(_requestId, true, msg.sender, block.timestamp);
//     }
//     /**
//      * @dev Từ chối yêu cầu tích điểm thủ công
//      */
//     function rejectManualRequest(uint256 _requestId, string memory _reason) external onlyAdmin {
//         ManualRequest storage request = manualRequests[_requestId];
        
//         // require(request.status == RequestStatus.Pending, "Request already processed");
//         require(request.status != RequestStatus.Rejected, "Request already rejected");
    
//         request.status = RequestStatus.Rejected;
//         request.approvedBy = msg.sender;
//         request.approvedTime = block.timestamp;
//         request.rejectReason = _reason;
        
//         emit ManualRequestProcessed(_requestId, false, msg.sender, block.timestamp);
//     }
    
//     /**
//      * @dev Phân phối token từ reserve của contract cho user
//      */
//     function distributeFromReserve(
//         address _to,
//         uint256 _amount,
//         string memory _reason
//     ) external onlyAdmin {
//         require(_to != address(0), "Invalid recipient");
//         require(balanceOf[address(this)] >= _amount, "Insufficient reserve");
        
//         balanceOf[address(this)] -= _amount;
//         balanceOf[_to] += _amount;
        
//         if (members[_to].isActive) {
//             members[_to].totalPoints = balanceOf[_to];
//             members[_to].lifetimePoints += _amount;
//             _updateMemberTier(_to);
//         }
        
//         if (!isTokenHolder[_to]) {
//             tokenHolders.push(_to);
//             isTokenHolder[_to] = true;
//         }
        
//         _createTransaction(
//             _to,
//             TransactionType.Earn,
//             int256(_amount),
//             0,
//             bytes32(0),
//             string(abi.encodePacked("Distribution: ", _reason)),
//             0
//         );
        
//         emit Transfer(address(this), _to, _amount);
//         emit PointsEarned(_to, _amount, bytes32(0), block.timestamp);
//     }
//     // ============ EARN POINTS (TÍCH ĐIỂM) ============
    
//     /**
//      * @dev Tích điểm tự động khi thanh toán
//      */
//     function earnPoints(
//         string memory _memberID,
//         uint256 _amount,
//         bytes32 _invoiceId,
//         uint256[] memory _eventIds
//     ) external {
//         address _member = memberIdToAddress[_memberID];
//         require(members[_member].isActive, "Member not found");
//         require(!members[_member].isLocked, "Account is locked");
//         require(!processedInvoices[_invoiceId], "Invoice already processed");
//         require(_amount > 0, "Invalid amount");
//         require(_isValidAmount(_invoiceId,_amount),"amount earnPoint not match invoiceId");

//         Member storage member = members[_member];
        
//        // tính điểm sau khi áp dụng tỷ lệ tích điểm trên hóa đơn
//         uint256 amountAfter = _amount * accumulationPercent / 100;
//         // Tính điểm dựa trên số tiền và tỷ giá
//         uint256 basePoints = amountAfter / exchangeRate;
        
//         // Áp dụng hệ số hạng thành viên tier multiplier
//         uint256 tierMultiplier = _getTierMultiplier(member.tierID);
//         uint256 points = (basePoints * tierMultiplier) / 100;
//         for(uint i; i< _eventIds.length; i++){
//             uint256 _eventId = _eventIds[i];
//             // Áp dụng event bonus
//             if (_eventId > 0 && _isEventValidForMember(_eventId, member.tierID)) {
//                 Event storage evt = events[_eventId];
//                 points += evt.pointPlus;
//             }
//         }
        
//         // Mint tokens = tích điểm
//          // Đây là nơi token được tạo ra khi khách mua hàng
//         totalSupply += points;
//         totalMinted += points;
//         balanceOf[_member] += points;
        
//         // Update member data (sync token balance với member points)
//         member.totalPoints = balanceOf[_member];
//         member.lifetimePoints += points;
//         member.totalSpent += _amount;
        
//         // Track token holder
//         if (!isTokenHolder[_member]) {
//             tokenHolders.push(_member);
//             isTokenHolder[_member] = true;
//         }
        
//         // Update tier
//         _updateMemberTier(_member);
        
//         // Record transaction
//         _createTransaction(
//             _member,
//             TransactionType.Earn,
//             int256(points),
//             _amount,
//             _invoiceId,
//             string(abi.encodePacked("Earn ", points.toString(), " ", symbol, " from purchase")),            
//             // _eventId
//             0
//         );
//          _recordRewardTransaction(
//             _member, 
//             points, 
//             "earn_from_purchase", 
//             string(abi.encodePacked("Invoice: ", uint256(_invoiceId).toString()))
//         );
//         processedInvoices[_invoiceId] = true;
        
//         emit PointsEarned(_member, points, _invoiceId, block.timestamp);
//         emit Mint(_member, points, string(abi.encodePacked("Purchase ", _amount.toString(), " VND")));
//         emit Transfer(address(0), _member, points);
//     }
//     function earnPointsFromDeposit(
//         string memory _memberID,
//         uint256 _amount,
//         uint256 _invoiceId,
//         uint256[] memory _eventIds
//     ) external {
//         address _member = memberIdToAddress[_memberID];
//         require(members[_member].isActive, "Member not found");
//         require(!members[_member].isLocked, "Account is locked");
//         require(!processedBillDeposit[_invoiceId], "Invoice already processed");
//         require(_amount > 0, "Invalid amount");
//         require(_isValidAmountDeposit(_invoiceId,_amount),"amount earnPoint not match invoiceId deposit");

//         Member storage member = members[_member];
        
//        // tính điểm sau khi áp dụng tỷ lệ tích điểm trên hóa đơn
//         uint256 amountAfter = _amount * accumulationPercent / 100;
//         // Tính điểm dựa trên số tiền và tỷ giá
//         uint256 basePoints = amountAfter / exchangeRate;
        
//         // Áp dụng hệ số hạng thành viên tier multiplier
//         uint256 tierMultiplier = _getTierMultiplier(member.tierID);
//         uint256 points = (basePoints * tierMultiplier) / 100;   
//         for(uint i; i< _eventIds.length; i++){
//             uint256 _eventId = _eventIds[i];
//             // Áp dụng event bonus
//             if (_eventId > 0 && _isEventValidForMember(_eventId, member.tierID)) {
//                 Event storage evt = events[_eventId];
//                 points += evt.pointPlus;
//             }
//         }
     
//         // Mint tokens = tích điểm
//          // Đây là nơi token được tạo ra khi khách mua hàng
//         totalSupply += points;
//         totalMinted += points;
//         balanceOf[_member] += points;
        
//         // Update member data (sync token balance với member points)
//         member.totalPoints = balanceOf[_member];
//         member.lifetimePoints += points;
//         member.totalSpent += _amount;
        
//         // Track token holder
//         if (!isTokenHolder[_member]) {
//             tokenHolders.push(_member);
//             isTokenHolder[_member] = true;
//         }
        
//         // Update tier
//         _updateMemberTier(_member);
        
//         // Record transaction
//         _createTransaction(
//             _member,
//             TransactionType.Earn,
//             int256(points),
//             _amount,
//             bytes32(0),
//             string(abi.encodePacked("Earn ", points.toString(), " ", symbol, " from deposit")),            
//             // _eventId
//             0
//         );
//          _recordRewardTransaction(
//             _member, 
//             points, 
//             "earn_from_purchase", 
//             string(abi.encodePacked("Invoice: ", uint256(_invoiceId).toString()))
//         );
//         processedBillDeposit[_invoiceId] = true;
        
//         emit PointsEarned(_member, points, bytes32(0), block.timestamp);
//         emit Mint(_member, points, string(abi.encodePacked("Deposit ", _amount.toString(), " VND")));
//         emit Transfer(address(0), _member, points);
//     }

//     // ============ REDEEM FUNCTIONS (ĐỔI ĐIỂM) ============
    
//     /**
//      * @dev Burn tokens (đổi điểm)
//      */
//     function burn(address _from, uint256 _amount, string memory _metadata) 
//         external 
//         onlyAdmin
//         notMigrated 
//     {
//         require(_from != address(0), "Cannot burn from zero address");
//         require(balanceOf[_from] >= _amount, "Insufficient balance");

//          // BURN TOKEN = TRỪ ĐIỂM
//         balanceOf[_from] -= _amount;
//         totalSupply -= _amount;
//         totalBurned += _amount;
        
//         // Update member(sync)
//         if (members[_from].isActive) {
//             members[_from].totalPoints = balanceOf[_from];
//         }
        
//         _recordRewardTransaction(_from, _amount, "burn", _metadata);
        
//          _createTransaction(
//             _from,
//             TransactionType.Redeem,
//             -int256(_amount),
//             0,
//             bytes32(0),
//             string(abi.encodePacked("Burn ", _amount.toString(), " ", symbol, ": ", _metadata)),
//             0
//         );
        
//         emit Burn(_from, _amount, _metadata);
//         emit PointsRedeemed(_from, _amount, 0, block.timestamp);
//         emit Transfer(_from, address(0), _amount);
//     }
//    /**
//      * @dev Redeem tokens (staff scan QR trừ điểm cho khách)
//      * Đây là cách BURN TOKEN khi khách đổi quà/dịch vụ
//      */
//     function redeem(address _user, uint256 _amount, string memory _reward) 
//         external 
//         onlyStaffOrAdmin
//         notMigrated 
//     {
//         require(_user != address(0), "Invalid user address");
//         require(balanceOf[_user] >= _amount, "Insufficient balance");
//         require(!frozen || redeemOnly, "Cannot redeem when frozen");
        
//         if (redeemOnly) {
//             require(block.timestamp <= redeemDeadline, "Redeem period expired");
//         }
        
//         // BURN TOKEN = ĐỔI ĐIỂM
//         balanceOf[_user] -= _amount;
//         totalSupply -= _amount;
//         totalRedeemed += _amount;
        
//         // Update member (sync)
//         if (members[_user].isActive) {
//             members[_user].totalPoints = balanceOf[_user]; // SYNC
//         }
        
//         _createTransaction(
//             _user,
//             TransactionType.Redeem,
//             -int256(_amount),
//             0,
//             bytes32(0),
//             string(abi.encodePacked("Redeem ", _amount.toString(), " ", symbol, " for: ", _reward)),
//             0
//         );
        
//         _recordRewardTransaction(_user, _amount, "redeem", _reward);
        
//         emit PointsRedeemed(_user, _amount, 0, block.timestamp);
//         emit Burn(_user, _amount, _reward);
//         emit Transfer(_user, address(0), _amount);
//     }
    
//    /**
//      * @dev Đổi voucher bằng points/tokens
//      * BURN TOKEN để nhận voucher discount
//      */
//     function redeemVoucher(string memory _voucherCode) 
//         external 
//         memberExists(msg.sender) 
//         notLocked(msg.sender) 
//         nonReentrant 
//     {
//         Member storage member = members[msg.sender];
        
//         // Get voucher info from Management
//         Discount memory discount = IManagement(MANAGEMENT).GetDiscount(_voucherCode);
        
//         require(bytes(discount.code).length > 0, "Voucher not found");
//         require(discount.active, "Voucher inactive");
//         // require(discount.isRedeemable, "Voucher not redeemable with points");
//         // require(discount.pointCost > 0, "Invalid point cost");
//         require(block.timestamp >= discount.from && block.timestamp <= discount.to, "Voucher expired");
//         require(discount.amountUsed < discount.amountMax, "Voucher limit reached");
//         // require(discount.discountType == DiscountType.AUTO_ALL, "Only AUTO_ALL type can be redeemed");
//         // require(balanceOf[msg.sender] >= discount.pointCost, "Insufficient points");
        
//         // BURN TOKENS để đổi voucher
//         // balanceOf[msg.sender] -= discount.pointCost;
//         // totalSupply -= discount.pointCost;
//         // totalRedeemed += discount.pointCost;
        
//         // Update member (sync)
//         member.totalPoints = balanceOf[msg.sender]; // SYNC
        
//         // Save voucher
//         bool codeExists = false;
//         for (uint256 i = 0; i < memberVouchers[msg.sender].length; i++) {
//             if (keccak256(bytes(memberVouchers[msg.sender][i])) == keccak256(bytes(_voucherCode))) {
//                 codeExists = true;
//                 break;
//             }
//         }
        
//         if (!codeExists) {
//             memberVouchers[msg.sender].push(_voucherCode);
//         }
        
//         memberVoucherDetails[msg.sender][_voucherCode].push(MemberVoucher({
//             code: _voucherCode,
//             redeemedAt: block.timestamp,
//             isUsed: false,
//             usedAt: 0,
//             voucherDetail: discount
//         }));
        
//         _createTransaction(
//             msg.sender,
//             TransactionType.Redeem,
//             -int256(discount.pointCost),
//             0,
//             bytes32(0),
//             string(abi.encodePacked("Redeem ", discount.pointCost.toString(), " ", symbol, " for voucher: ", _voucherCode)),
//             0
//         );
        
//         _recordRewardTransaction(
//             msg.sender,
//             discount.pointCost,
//             "redeem_voucher",
//             string(abi.encodePacked("Voucher: ", _voucherCode))
//         );
        
//         emit VoucherRedeemed(msg.sender, _voucherCode, discount.pointCost, block.timestamp);
//         emit Burn(msg.sender, discount.pointCost, string(abi.encodePacked("Voucher: ", _voucherCode)));
//         emit Transfer(msg.sender, address(0), discount.pointCost);
//     }
//     // ============ PAYMENT WITH POINTS ============
    
//     /**
//      * @dev Sử dụng tokens để thanh toán
//      */
//     function usePointsForPayment(
//         address _member,
//         uint256 _pointsToUse,
//         uint256 _orderAmount
//     ) external memberExists(_member) notLocked(_member) {
//         require(msg.sender == MANAGEMENT || IManagement(MANAGEMENT).hasRole(ROLE_ADMIN, msg.sender), "Unauthorized");
        
//         Member storage member = members[_member];
//         require(balanceOf[_member] >= _pointsToUse, "Insufficient points");
        
//         // Burn tokens
//         balanceOf[_member] -= _pointsToUse;
//         totalSupply -= _pointsToUse;
//         totalRedeemed += _pointsToUse;
        
//         // Update member
//         member.totalPoints = balanceOf[_member];
//         member.lastBuyActivityAt = block.timestamp;
        
//         bytes32 paymentId = keccak256(abi.encodePacked(_member, _pointsToUse, block.timestamp));
        
//         _createTransaction(
//             _member,
//             TransactionType.Redeem,
//             -int256(_pointsToUse),
//             _orderAmount,
//             paymentId,
//             string(abi.encodePacked("Payment with points: ", _pointsToUse.toString())),
//             0
//         );
        
//         memberPaymentHistory[_member].push(PaymentTransaction({
//             paymentId: paymentId,
//             pointsUsed: _pointsToUse,
//             orderAmount: _orderAmount,
//             timestamp: block.timestamp
//         }));
        
//         emit PointsUsedForPayment(_member, paymentId, _pointsToUse, _orderAmount, block.timestamp);
//         emit Transfer(_member, address(0), _pointsToUse);
//     }
    
//     // ============ ADMIN FUNCTIONS ============
    
//     /**
//      * @dev Điều chỉnh điểm thủ công
//      */
//     function adjustPoints(
//         address _member,
//         int256 _points,
//         string memory _reason
//     ) external onlyAdmin memberExists(_member) {
//         require(bytes(_reason).length > 0, "Reason required");
        
//         Member storage member = members[_member];
        
//         if (_points > 0) {
//             uint256 amount = uint256(_points);
//             balanceOf[_member] += amount;
//             totalSupply += amount;
//             totalMinted += amount;
//             emit Transfer(address(0), _member, amount);
//         } else {
//             uint256 amount = uint256(-_points);
//             require(balanceOf[_member] >= amount, "Insufficient balance");
//             balanceOf[_member] -= amount;
//             totalSupply -= amount;
//             totalBurned += amount;
//             emit Transfer(_member, address(0), amount);
//         }
        
//         member.totalPoints = balanceOf[_member];
//         if (_points > 0) {
//             member.lifetimePoints += uint256(_points);
//         }
        
//         _createTransaction(
//             _member,
//             TransactionType.ManualAdjust,
//             _points,
//             0,
//             bytes32(0),
//             _reason,
//             0
//         );
        
//         _updateMemberTier(_member);
//     }
    
//     /**
//      * @dev Hoàn điểm khi khách hủy/trả món
//      */
//     function refundPoints(
//         address _member,
//         bytes32 _invoiceId,
//         string memory _reason
//     ) external onlyAdmin memberExists(_member) {
//         require(processedInvoices[_invoiceId], "Invoice not found");
        
//         uint256[] memory txIds = memberTransactions[_member];
//         uint256 pointsToRefund = 0;
        
//         for (uint256 i = 0; i < txIds.length; i++) {
//             Transaction storage _tx = transactions[txIds[i]];
//             if (_tx.invoiceId == _invoiceId && _tx.txType == TransactionType.Earn) {
//                 pointsToRefund = uint256(_tx.points);
//                 break;
//             }
//         }
        
//         require(pointsToRefund > 0, "Transaction not found");
//         require(balanceOf[_member] >= pointsToRefund, "Insufficient points");
        
//         Member storage member = members[_member];
        
//         // Burn tokens
//         balanceOf[_member] -= pointsToRefund;
//         totalSupply -= pointsToRefund;
//         totalBurned += pointsToRefund;
        
//         member.totalPoints = balanceOf[_member];
//         if (member.lifetimePoints >= pointsToRefund) {
//             member.lifetimePoints -= pointsToRefund;
//         }
        
//         _createTransaction(
//             _member,
//             TransactionType.Refund,
//             -int256(pointsToRefund),
//             0,
//             _invoiceId,
//             _reason,
//             0
//         );
        
//         processedInvoices[_invoiceId] = false;
        
//         emit PointsRefunded(_member, pointsToRefund, _invoiceId, _reason, block.timestamp);
//         emit Transfer(_member, address(0), pointsToRefund);
//     }
    
//     /**
//      * @dev Lock/Unlock member
//      */
//     function lockMember(address _member, string memory _reason) external onlyAdmin memberExists(_member) {
//         require(!members[_member].isLocked, "Member already locked");
//         require(bytes(_reason).length > 0, "Reason required");
//         members[_member].isLocked = true;
//         emit MemberLocked(_member, msg.sender, _reason, block.timestamp);
//     }
    
//     function unlockMember(address _member) external onlyAdmin memberExists(_member) {
//         require(members[_member].isLocked, "Member not locked");
//         members[_member].isLocked = false;
//         emit MemberUnlocked(_member, msg.sender, block.timestamp);
//     }
    
//     // ============ TIER MANAGEMENT ============
    
// function createTierConfig(
//     string memory _nameTier,
//     uint256 _pointsRequired,
//     uint256 _multiplier,
//     string memory _colour
// ) external onlyAdmin {
//     require(_pointsRequired >= 0, "Points required must be >= 0");
//     require(_multiplier > 0, "Multiplier must be > 0");
//     require(bytes(_nameTier).length > 0, "Tier name required");
    
//     bytes32 tierID = keccak256(abi.encodePacked(_nameTier, block.timestamp));
//     require(mNameToTierConfig[_nameTier].id == bytes32(0), "_nameTier duplicate");
    
//     // Kiểm tra trùng pointsRequired với tier đã tồn tại
//     for (uint256 i = 0; i < allTiers.length; i++) {
//         require(
//             allTiers[i].pointsRequired != _pointsRequired, 
//             "Points required already exists in another tier"
//         );
//     }
    
//     // Tạo tier mới với pointsMax tạm thời = max uint256
//     TierConfig memory newTier = TierConfig({
//         id: tierID,
//         nameTier: _nameTier,
//         pointsRequired: _pointsRequired,
//         pointsMax: type(uint256).max,
//         multiplier: _multiplier,
//         colour: _colour
//     });
    
//     tierConfigs[tierID] = newTier;
//     allTiers.push(newTier);
//     mNameToTierConfig[_nameTier] = newTier;
    
//     // Sort tiers và tự động cập nhật pointsMax
//     _sortAndUpdateTierRanges();
// }

// // ============ UPDATE TIER CONFIG (Fixed) ============

// function updateTierConfig(
//     bytes32 _tierID,
//     string memory _nameTier,
//     uint256 _pointsRequired,
//     uint256 _multiplier,
//     string memory _colour
// ) external onlyAdmin {
//     require(tierConfigs[_tierID].id != bytes32(0), "Tier not found");
//     require(_pointsRequired >= 0, "Points required must be >= 0");
    
//     TierConfig storage tier = tierConfigs[_tierID];
//     string memory oldName = tier.nameTier;
    
//     // Kiểm tra trùng pointsRequired (trừ tier hiện tại)
//     if (_pointsRequired > 0 && _pointsRequired != tier.pointsRequired) {
//         for (uint256 i = 0; i < allTiers.length; i++) {
//             if (allTiers[i].id != _tierID) {
//                 require(
//                     allTiers[i].pointsRequired != _pointsRequired,
//                     "Points required already exists in another tier"
//                 );
//             }
//         }
//         tier.pointsRequired = _pointsRequired;
//     }
    
//     // Cập nhật tên tier
//     if (bytes(_nameTier).length > 0 && keccak256(bytes(_nameTier)) != keccak256(bytes(oldName))) {
//         require(mNameToTierConfig[_nameTier].id == bytes32(0), "_nameTier duplicate");
//         delete mNameToTierConfig[oldName];
//         tier.nameTier = _nameTier;
//         mNameToTierConfig[_nameTier] = tier;
//     }
    
//     // Cập nhật các trường khác
//     if (bytes(_colour).length > 0) {
//         tier.colour = _colour;
//     }
//     if (_multiplier > 0) {
//         tier.multiplier = _multiplier;
//     }
    
//     // Cập nhật trong allTiers array
//     for (uint256 i = 0; i < allTiers.length; i++) {
//         if (allTiers[i].id == _tierID) {
//             allTiers[i] = tier;
//             break;
//         }
//     }
    
//     // Sort và cập nhật lại pointsMax
//     _sortAndUpdateTierRanges();
// }

// // ============ DELETE TIER CONFIG (Fixed) ============

// function deleteTierConfig(bytes32 _tierID) external onlyAdmin {
//     require(tierConfigs[_tierID].id != bytes32(0), "Tier not found");
    
//     string memory tierName = tierConfigs[_tierID].nameTier;
//     delete tierConfigs[_tierID];
//     delete mNameToTierConfig[tierName];
    
//     // Remove from allTiers
//     for (uint256 i = 0; i < allTiers.length; i++) {
//         if (allTiers[i].id == _tierID) {
//             allTiers[i] = allTiers[allTiers.length - 1];
//             allTiers.pop();
//             break;
//         }
//     }
    
//     // Sort và cập nhật lại pointsMax cho các tier còn lại
//     _sortAndUpdateTierRanges();
// }

// // ============ HELPER FUNCTIONS (New Logic) ============

// /**
//  * @dev Sort tiers theo pointsRequired và tự động cập nhật pointsMax
//  * Logic: pointsMax của tier[i] = pointsRequired của tier[i+1] - 1
//  * Tier cuối cùng có pointsMax = type(uint256).max
//  */
// function _sortAndUpdateTierRanges() internal {
//     if (allTiers.length == 0) return;
    
//     // 1. Sort tiers theo pointsRequired (ascending)
//     _sortTiers();
    
//     // 2. Cập nhật pointsMax cho từng tier
//     for (uint256 i = 0; i < allTiers.length; i++) {
//         bytes32 tierId = allTiers[i].id;
        
//         if (i < allTiers.length - 1) {
//             // Tier không phải cuối cùng: pointsMax = pointsRequired của tier tiếp theo - 1
//             uint256 nextTierPoints = allTiers[i + 1].pointsRequired;
            
//             // Kiểm tra logic: tier tiếp theo phải có pointsRequired lớn hơn
//             require(
//                 nextTierPoints > allTiers[i].pointsRequired,
//                 "Invalid tier order: overlapping ranges"
//             );
            
//             tierConfigs[tierId].pointsMax = nextTierPoints - 1;
//             allTiers[i].pointsMax = nextTierPoints - 1;
//         } else {
//             // Tier cuối cùng: pointsMax = unlimited
//             tierConfigs[tierId].pointsMax = type(uint256).max;
//             allTiers[i].pointsMax = type(uint256).max;
//         }
        
//         // Cập nhật lại mNameToTierConfig
//         mNameToTierConfig[allTiers[i].nameTier] = allTiers[i];
//     }
// }

// /**
//  * @dev Sort tiers theo pointsRequired (Bubble Sort)
//  */
// function _sortTiers() internal {
//     if (allTiers.length <= 1) return;
    
//     for (uint256 i = 0; i < allTiers.length - 1; i++) {
//         for (uint256 j = 0; j < allTiers.length - i - 1; j++) {
//             if (allTiers[j].pointsRequired > allTiers[j + 1].pointsRequired) {
//                 TierConfig memory temp = allTiers[j];
//                 allTiers[j] = allTiers[j + 1];
//                 allTiers[j + 1] = temp;
//             }
//         }
//     }
// }

// /**
//  * @dev Calculate tier dựa trên lifetime points (Logic không thay đổi)
//  */
// function _calculateTier(uint256 _lifetimePoints) internal view returns (bytes32) {
//     bytes32 currentTierID = bytes32(0);
    
//     for (uint256 i = 0; i < allTiers.length; i++) {
//         TierConfig memory tier = allTiers[i];
        
//         // Kiểm tra nếu điểm nằm trong range [pointsRequired, pointsMax]
//         if (_lifetimePoints >= tier.pointsRequired && _lifetimePoints <= tier.pointsMax) {
//             return tier.id;
//         }
//     }
    
//     return currentTierID; // Trả về bytes32(0) nếu không thuộc tier nào
// }

// // ============ VIEW FUNCTIONS (Updated) ============

// /**
//  * @dev Lấy thông tin tier range
//  */
// function getTierRange(bytes32 _tierID) external view returns (
//     string memory nameTier,
//     uint256 pointsRequired,
//     uint256 pointsMax,
//     uint256 multiplier,
//     string memory colour
// ) {
//     TierConfig storage config = tierConfigs[_tierID];
//     require(config.id != bytes32(0), "Tier not found");
    
//     return (
//         config.nameTier,
//         config.pointsRequired,
//         config.pointsMax,
//         config.multiplier,
//         config.colour
//     );
// }

// /**
//  * @dev Lấy tất cả tiers với ranges đã được tính
//  */
// function getAllTiersWithRanges() external view returns (
//     TierConfig[] memory tiers,
//     string[] memory rangeDescriptions
// ) {
//     tiers = allTiers;
//     rangeDescriptions = new string[](allTiers.length);
    
//     for (uint256 i = 0; i < allTiers.length; i++) {
//         if (allTiers[i].pointsMax == type(uint256).max) {
//             rangeDescriptions[i] = string(
//                 abi.encodePacked(
//                     Strings.toString(allTiers[i].pointsRequired),
//                     "+ points"
//                 )
//             );
//         } else {
//             rangeDescriptions[i] = string(
//                 abi.encodePacked(
//                     Strings.toString(allTiers[i].pointsRequired),
//                     " - ",
//                     Strings.toString(allTiers[i].pointsMax),
//                     " points"
//                 )
//             );
//         }
//     }
    
//     return (tiers, rangeDescriptions);
// }
//     function setValidityPeriod(uint _validityPeriod) external onlyAdmin {
//         validityPeriod = _validityPeriod;
//     }
//     /**
//      * @dev Lấy cấu hình hạng
//      */
//     function getTierConfig(bytes32 _tierID) external view returns (
//         string memory nameTier,
//         uint256 pointsRequired,
//         uint256 multiplier,
//         // uint256 validityPeriod
//         uint256 pointsMax
//     ) {
//         TierConfig storage config = tierConfigs[_tierID];
//         return (
//             config.nameTier,
//             config.pointsRequired,
//             config.multiplier,
//             config.pointsMax
//             // config.validityPeriod
//         );
//     }
//     function getTierConfigFromName(string memory _nameTier) external view returns(TierConfig memory){
//         return mNameToTierConfig[_nameTier];
//     }
//     function getAllTiers() external view returns (TierConfig[] memory) {
//         return allTiers;
//     }
//     function getAllTiersWithMemberCount() external view returns (
//         TierConfig[] memory tiers,
//         uint256[] memory memberCounts
//     ) {
//         tiers = allTiers;
//         memberCounts = new uint256[](allTiers.length);
        
//         // Đếm members cho từng tier
//         for (uint256 i = 0; i < allTiers.length; i++) {
//             uint256 count = 0;
//             bytes32 tierID = allTiers[i].id;
            
//             for (uint256 j = 0; j < allMembers.length; j++) {
//                 if (allMembers[j].isActive && allMembers[j].tierID == tierID) {
//                     count++;
//                 }
//             }
            
//             memberCounts[i] = count;
//         }
        
//         return (tiers, memberCounts);
//     }

//     function GetAllTierDatas() external view returns (TierData[] memory tierDatas){
//        tierDatas = _getAllTierDatas();
//     }
//         // Thêm hàm lấy thống kê tất cả tier:
//     function _getAllTierDatas() internal view returns (
//         TierData[] memory tierDatas
//     ) {
//         TierConfig[] memory tiers = allTiers;       
//         tierDatas = new TierData[](tiers.length);

        
//         // Đếm members cho từng tier
//         for (uint256 i = 0; i < allTiers.length; i++) {
//             uint256 count = 0;
//             bytes32 tierID = allTiers[i].id;
            
//             for (uint256 j = 0; j < allMembers.length; j++) {
//                 if (allMembers[j].isActive && allMembers[j].tierID == tierID) {
//                     count++;
//                 }
//             }
            
//             tierDatas[i].tierConfig = allTiers[i];
//             tierDatas[i].memberCount = count;
//         }
        
//         return tierDatas;
//     }
//     function getAllTierDatasPagination(uint256 offset, uint256 limit)
//         external
//         view
//         returns (TierData[] memory result,uint totalCount)
//     {
//         if(offset >= allTiers.length) {
//             return ( new TierData[](0),allTiers.length);
//         }

//         uint256 end = offset + limit;
//         if (end > allTiers.length) {
//             end = allTiers.length;
//         }

//         uint256 size = end - offset;
//         result = new TierData[](size);
//         TierData[] memory tierDatas = _getAllTierDatas();
//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = tierDatas.length - 1 - offset - i;
//             result[i] = tierDatas[reverseIndex];
//         }

//         return (result,tierDatas.length);
//     }


//     // Thêm hàm lấy số member None tier (không thuộc tier nào):
//     function getNoneTierMemberCount() external view returns (uint256) {
//         uint256 count = 0;
        
//         for (uint256 i = 0; i < allMembers.length; i++) {
//             Member memory member = allMembers[i];
            
//             if (member.isActive && member.tierID == bytes32(0)) {
//                 count++;
//             }
//         }
        
//         return count;
//     }
    

//     function GetAllTiersPagination(uint256 offset, uint256 limit)
//         external
//         view
//         returns (TierConfig[] memory result,uint totalCount)
//     {
//         if(offset >= allTiers.length) {
//             return ( new TierConfig[](0),allTiers.length);
//         }

//         uint256 end = offset + limit;
//         if (end > allTiers.length) {
//             end = allTiers.length;
//         }

//         uint256 size = end - offset;
//         result = new TierConfig[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = allTiers.length - 1 - offset - i;
//             result[i] = allTiers[reverseIndex];
//         }

//         return (result,allTiers.length);
//     }


//     /**
//      * @dev Cập nhật tỷ giá quy đổi
//      */
//     function updateExchangeRate(uint256 _newRate) external onlyAdmin {
//         require(_newRate > 0, "Invalid rate");
//         exchangeRate = _newRate;
//     }
    
//     /**
//      * @dev Cập nhật thời gian hết hạn điểm
//      */
//     function updatePointExpiryPeriod(uint256 _newPeriod) external onlyAdmin {
//         pointExpiryPeriod = _newPeriod;
//     }
    
//     /**
//      * @dev Cập nhật thời gian lưu phiên
//      */
//     function updateSessionDuration(uint256 _newDuration) external onlyAdmin {
//         sessionDuration = _newDuration;
//     }

//     // ============ EVENT MANAGEMENT ============
    
//     function createEvent(
//         string memory _name,
//         uint256 _startTime,
//         uint256 _endTime,
//         uint256 _pointPlus,
//         bytes32 _minTierID
//     ) external onlyAdmin returns (uint256) {
//         require(_startTime < _endTime, "Invalid time range");
        
//         eventCounter++;
//         events[eventCounter] = Event({
//             id: eventCounter,
//             name: _name,
//             startTime: _startTime,
//             endTime: _endTime,
//             pointPlus: _pointPlus,
//             minTierID: _minTierID,
//             isActive: true
//         });
//         allEvents.push(events[eventCounter]);
//         emit EventCreated(eventCounter, _name, _startTime, _endTime);
//         return eventCounter;
//     }
//     function updateEvent(
//         uint256 _eventId,
//         string memory _name,
//         uint256 _startTime,
//         uint256 _endTime,
//         uint256 _pointPlus,
//         bytes32 _minTierID,
//         bool isActive
//     ) external onlyAdmin returns (uint256) {
//         require(_startTime < _endTime, "Invalid time range");
//         Event storage eventKQ = events[_eventId];
//         eventKQ.name = _name;
//         eventKQ.startTime = _startTime;
//         eventKQ.endTime = _endTime;
//         eventKQ.pointPlus = _pointPlus;
//         eventKQ.minTierID = _minTierID;
//         eventKQ.isActive = true;
//         for(uint i; i< allEvents.length; i++){
//             if(allEvents[i].id == _eventId){
//                 allEvents[i] = eventKQ;
//             }
//         }
//     }
// /**
//  * @dev Lấy danh sách sự kiện đang hoạt động với pagination
//  */
// function getActiveEventsPagination(
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     Event[] memory result,
//     uint256 totalCount
// ) {
//     // Đếm số events active
//     uint256 count = 0;
//     for (uint256 i = 1; i <= eventCounter; i++) {
//         Event storage evt = events[i];
//         if (
//             evt.isActive &&
//             block.timestamp >= evt.startTime &&
//             block.timestamp <= evt.endTime
//         ) {
//             count++;
//         }
//     }
    
//     if (count == 0 || offset >= count) {
//         return (new Event[](0), count);
//     }
    
//     // Tạo mảng tạm chứa tất cả active events
//     Event[] memory activeEvents = new Event[](count);
//     uint256 index = 0;
    
//     for (uint256 i = 1; i <= eventCounter; i++) {
//         Event storage evt = events[i];
//         if (
//             evt.isActive &&
//             block.timestamp >= evt.startTime &&
//             block.timestamp <= evt.endTime
//         ) {
//             activeEvents[index] = evt;
//             index++;
//         }
//     }
    
//     // Pagination
//     uint256 end = offset + limit;
//     if (end > count) {
//         end = count;
//     }
    
//     uint256 size = end - offset;
//     result = new Event[](size);
    
//     for (uint256 i = 0; i < size; i++) {
//         uint256 reverseIndex = count - 1 - offset - i;
//         result[i] = activeEvents[reverseIndex];
//     }
    
//     return (result, count);
// }

//     function toggleEvent(uint256 _eventId, bool _isActive) external onlyAdmin {
//         require(events[_eventId].id > 0, "Event not found");
//         events[_eventId].isActive = _isActive;
//         for(uint i; i< allEvents.length; i++){
//             if(allEvents[i].id == _eventId){
//                 allEvents[i].isActive = _isActive;
//             }
//         }
//     }
    
//     // ============ MEMBER GROUP MANAGEMENT ============
    
//     function createMemberGroup(string memory _name) external onlyAdmin returns (bytes32) {
//         require(bytes(_name).length > 0, "Group name required");
        
//         bytes32 groupId = keccak256(abi.encodePacked(_name, block.timestamp));
//         require(memberGroups[groupId].id == bytes32(0), "Group already exists");
        
//         MemberGroup memory newGroup = MemberGroup({
//             id: groupId,
//             name: _name,
//             isActive: true
//         });
        
//         memberGroups[groupId] = newGroup;
//         allGroupIds.push(groupId);
//         allMemberGroups.push(newGroup);
//         emit MemberGroupCreated(groupId, _name, block.timestamp);
        
//         return groupId;
//     }
//     function getAllGroups() external view returns (MemberGroup[] memory) {
//         return allMemberGroups;
//     }
//     function isMemberGroupId(bytes32 groupId) external view returns (bool) {
//         return (memberGroups[groupId].id != bytes32(0));
//     }
    
//     /**
//     * @dev Cập nhật thông tin nhóm khách hàng
//     */
//     function updateMemberGroup(
//         bytes32 _groupId,
//         string memory _name,
//         bool _isActive
//     ) external onlyAdmin {
//         require(memberGroups[_groupId].id != bytes32(0), "Group not found");
//         require(bytes(_name).length > 0, "Group name required");
        
//         MemberGroup storage group = memberGroups[_groupId];
//         group.name = _name;
//         group.isActive = _isActive;
//         for(uint256 i=0; i< allMemberGroups.length; i++){
//             if(allMemberGroups[i].id == _groupId){
//                 allMemberGroups[i] = MemberGroup({
//                     id: _groupId,
//                     name: _name,
//                     isActive: _isActive
//                 });
//                 break;
//             }
//         }
//         emit MemberGroupUpdated(_groupId, _name, block.timestamp);
//     }

// /**
//  * @dev Xóa nhóm khách hàng (đã fix)
//  */
// function deleteMemberGroup(bytes32 _groupId) external onlyAdmin {
//     require(memberGroups[_groupId].id != bytes32(0), "Group not found");
    
//     // Gỡ tất cả members khỏi group
//     address[] memory membersInGroup = groupMembers[_groupId];
//     for (uint256 i = 0; i < membersInGroup.length; i++) {
//         address member = membersInGroup[i];
        
//         // Remove groupId khỏi memberToGroups
//         bytes32[] storage groups = memberToGroups[member];
//         for (uint256 j = 0; j < groups.length; j++) {
//             if (groups[j] == _groupId) {
//                 groups[j] = groups[groups.length - 1];
//                 groups.pop();
//                 break;
//             }
//         }
//     }
    
//     // Xóa group
//     delete groupMembers[_groupId];
//     delete memberGroups[_groupId];
    
//     // Xóa khỏi allGroupIds
//     for (uint256 i = 0; i < allGroupIds.length; i++) {
//         if (allGroupIds[i] == _groupId) {
//             allGroupIds[i] = allGroupIds[allGroupIds.length - 1];
//             allGroupIds.pop();
//             break;
//         }
//     }
    
//     // Xóa khỏi allMemberGroups
//     for (uint256 i = 0; i < allMemberGroups.length; i++) {
//         if (allMemberGroups[i].id == _groupId) {
//             allMemberGroups[i] = allMemberGroups[allMemberGroups.length - 1];
//             allMemberGroups.pop();
//             break;
//         }
//     }
    
//     emit MemberGroupDeleted(_groupId, block.timestamp);
// }
// /**
//  * @dev Batch assign member vào nhiều groups
//  * Xóa tất cả groups cũ và thay bằng groups mới
//  */
// function batchAssignMemberToGroups(
//     address _member, 
//     bytes32[] memory _groupIds
// ) external onlyAdmin memberExists(_member) {
//     require(_groupIds.length > 0, "Group IDs array cannot be empty");
    
//     // Validate tất cả groupIds trước
//     for (uint256 i = 0; i < _groupIds.length; i++) {
//         require(memberGroups[_groupIds[i]].id != bytes32(0), "Group not found");
//         require(memberGroups[_groupIds[i]].isActive, "Group not active");
//     }
    
//     // Xóa member khỏi tất cả groups cũ
//     bytes32[] memory oldGroups = memberToGroups[_member];
//     for (uint256 i = 0; i < oldGroups.length; i++) {
//         _removeMemberFromGroupArray(oldGroups[i], _member);
//     }
    
//     // Clear mảng groups của member
//     delete memberToGroups[_member];
    
//     // Assign member vào các groups mới
//     for (uint256 i = 0; i < _groupIds.length; i++) {
//         bytes32 groupId = _groupIds[i];
        
//         // Thêm member vào group
//         groupMembers[groupId].push(_member);
        
//         // Thêm groupId vào danh sách groups của member
//         memberToGroups[_member].push(groupId);
        
//         emit MemberAssignedToGroup(_member, groupId, block.timestamp);
//     }
// }
// /**
//  * @dev Assign member vào một group (giữ lại groups cũ)
//  */
// function assignMemberToGroup(address _member, bytes32 _groupId) 
//     external 
//     onlyAdmin 
//     memberExists(_member) 
// {
//     require(memberGroups[_groupId].id != bytes32(0), "Group not found");
//     require(memberGroups[_groupId].isActive, "Group not active");
    
//     // Kiểm tra member đã trong group này chưa
//     bytes32[] memory currentGroups = memberToGroups[_member];
//     for (uint256 i = 0; i < currentGroups.length; i++) {
//         require(currentGroups[i] != _groupId, "Member already in this group");
//     }
    
//     // Thêm member vào group
//     groupMembers[_groupId].push(_member);
//     memberToGroups[_member].push(_groupId);
    
//     emit MemberAssignedToGroup(_member, _groupId, block.timestamp);
// }
//     function getMemberToGroups(address _member) external view returns(bytes32[] memory){
//         return memberToGroups[_member];
//     }
// /**
//  * @dev Remove member khỏi một group cụ thể
//  */
// function removeMemberFromGroup(address _member, bytes32 _groupId) 
//     external 
//     onlyAdmin 
// {
//     require(_isMemberInGroup(_member, _groupId), "Member not in this group");
    
//     // Remove từ groupMembers
//     _removeMemberFromGroupArray(_groupId, _member);
    
//     // Remove từ memberToGroups
//     bytes32[] storage groups = memberToGroups[_member];
//     for (uint256 i = 0; i < groups.length; i++) {
//         if (groups[i] == _groupId) {
//             groups[i] = groups[groups.length - 1];
//             groups.pop();
//             break;
//         }
//     }
    
//     emit MemberRemovedFromGroup(_member, _groupId, block.timestamp);
// }
// /**
//  * @dev Remove member khỏi TẤT CẢ groups
//  */
// function removeMemberFromAllGroups(address _member) external onlyAdmin {
//     bytes32[] memory groups = memberToGroups[_member];
    
//     for (uint256 i = 0; i < groups.length; i++) {
//         _removeMemberFromGroupArray(groups[i], _member);
//         emit MemberRemovedFromGroup(_member, groups[i], block.timestamp);
//     }
    
//     delete memberToGroups[_member];
// }
// /**
//  * @dev Internal: Remove member khỏi groupMembers array
//  */
// function _removeMemberFromGroupArray(bytes32 _groupId, address _member) internal {
//     address[] storage members = groupMembers[_groupId];
    
//     for (uint256 i = 0; i < members.length; i++) {
//         if (members[i] == _member) {
//             members[i] = members[members.length - 1];
//             members.pop();
//             break;
//         }
//     }
// }

// /**
//  * @dev Kiểm tra member có trong group không
//  */
// function _isMemberInGroup(address _member, bytes32 _groupId) 
//     internal 
//     view 
//     returns (bool) 
// {
//     bytes32[] memory groups = memberToGroups[_member];
//     for (uint256 i = 0; i < groups.length; i++) {
//         if (groups[i] == _groupId) {
//             return true;
//         }
//     }
//     return false;
// }

// /**
//  * @dev Lấy tất cả groups của member
//  */
// function getMemberGroups(address _member) 
//     external 
//     view 
//     returns (bytes32[] memory groupIds, MemberGroup[] memory groupDetails) 
// {
//     groupIds = memberToGroups[_member];
//     groupDetails = new MemberGroup[](groupIds.length);
    
//     for (uint256 i = 0; i < groupIds.length; i++) {
//         groupDetails[i] = memberGroups[groupIds[i]];
//     }
    
//     return (groupIds, groupDetails);
// }

// /**
//  * @dev Lấy tất cả members của một group với pagination
//  */
// function getGroupMembersPagination(
//     bytes32 _groupId,
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     address[] memory members,
//     uint256 totalCount
// ) {
//     require(memberGroups[_groupId].id != bytes32(0), "Group not found");
    
//     address[] memory allMembers = groupMembers[_groupId];
//     totalCount = allMembers.length;
    
//     if (offset >= totalCount) {
//         return (new address[](0), totalCount);
//     }
    
//     uint256 end = offset + limit;
//     if (end > totalCount) {
//         end = totalCount;
//     }
    
//     uint256 size = end - offset;
//     members = new address[](size);
    
//     for (uint256 i = 0; i < size; i++) {
//         members[i] = allMembers[offset + i];
//     }
    
//     return (members, totalCount);
// }

// /**
//  * @dev Kiểm tra member có trong group không (public)
//  */
// function isMemberInGroup(address _member, bytes32 _groupId) 
//     external 
//     view 
//     returns (bool) 
// {
//     return _isMemberInGroup(_member, _groupId);
// }
//     // ============ MIGRATION FUNCTIONS ============
    
//     function freeze() external {
//         require(msg.sender == enhancedAgentSC || msg.sender == agent, "Unauthorized");
//         frozen = true;
//         emit Frozen(block.timestamp);
//     }
    
//     function unfreeze() external  {
//         require(msg.sender == enhancedAgentSC || msg.sender == agent, "Unauthorized");
//         frozen = false;
//         emit Unfrozen(block.timestamp);
//     }
    
//     function setRedeemOnly(uint256 _days) external {
//         require(msg.sender == owner() || msg.sender == agent, "Unauthorized");
//         redeemOnly = true;
//         redeemDeadline = block.timestamp + (_days * 1 days);
//         emit RedeemOnlyMode(redeemDeadline);
//     }
    
//     function unlockTokens() external onlyAgentSC returns (uint256) {
//         require(frozen || redeemOnly, "Contract must be frozen or redeem-only");
        
//         uint256 contractBalance = balanceOf[address(this)];
//         if (contractBalance > 0) {
//             balanceOf[address(this)] = 0;
//             balanceOf[owner()] += contractBalance;
//             emit Transfer(address(this), owner(), contractBalance);
//         }
        
//         return contractBalance;
//     }
    
//     /**
//      * @dev Initiate migration to new contract
//      */
//     function migrateTo(address _newContract) external onlyAgentSC returns (uint256) {
//         require(_newContract != address(0), "Invalid new contract");
//         require(!migrated, "Already migrated");
        
//         frozen = true;
//         migrated = true;
//         migratedTo = _newContract;
//         redeemOnly = true;
//         redeemDeadline = block.timestamp + (30 * 1 days);
        
//         emit MigrationInitiated(_newContract, totalSupply, block.timestamp);
//         return totalSupply;
//     }
    
//     /**
//      * @dev Get migration data for user
//      */
//     function getMigrationData(address _user) 
//         external 
//         view 
//         returns (
//             uint256 balance,
//             bool hasBalance,
//             bool alreadyMigrated
//         ) 
//     {
//         return (balanceOf[_user], balanceOf[_user] > 0, userMigrated[_user]);
//     }
    
//     /**
//      * @dev Mark user as migrated
//      */
//     function markUserMigrated(address _user, uint256 _amount) external {
//         require(msg.sender == migratedTo, "Only new contract can mark migrated");
//         require(migrated, "Contract not in migration state");
//         require(balanceOf[_user] >= _amount, "Invalid migration amount");
        
//         userMigrated[_user] = true;
//         totalMigrated += _amount;
        
//         balanceOf[_user] -= _amount;
//         totalSupply -= _amount;
        
//         if (members[_user].isActive) {
//             members[_user].totalPoints = balanceOf[_user];
//         }
        
//         emit UserBalanceMigrated(_user, _amount, migratedTo);
//     }
    
//     /**
//      * @dev Receive migration from old contract (NEW CONTRACT)
//      */
//     function receiveMigration(
//         address _oldContract,
//         address[] memory _users,
//         uint256[] memory _amounts
//     ) external onlyAgentSC returns (uint256 totalReceived) {
//         require(_oldContract != address(0), "Invalid old contract");
//         require(_users.length == _amounts.length, "Arrays length mismatch");
        
//         RestaurantLoyaltySystem oldContract = RestaurantLoyaltySystem(_oldContract);
//         require(oldContract.migrated(), "Old contract not migrated");
//         require(oldContract.migratedTo() == address(this), "Migration target mismatch");
        
//         uint256 successCount = 0;
        
//         for (uint256 i = 0; i < _users.length; i++) {
//             address user = _users[i];
//             uint256 amount = _amounts[i];
            
//             if (amount == 0) continue;
            
//             (, bool hasBalance, bool alreadyMigrated) = oldContract.getMigrationData(user);
            
//             if (alreadyMigrated || !hasBalance) continue;
            
//             // Mint tokens in new contract
//             totalSupply += amount;
//             totalMinted += amount;
//             balanceOf[user] += amount;
            
//             if (!isTokenHolder[user]) {
//                 tokenHolders.push(user);
//                 isTokenHolder[user] = true;
//             }
            
//             // Update member if exists
//             if (members[user].isActive) {
//                 members[user].totalPoints = balanceOf[user];
//             }
            
//             oldContract.markUserMigrated(user, amount);
            
//             totalReceived += amount;
//             successCount++;
            
//             emit Transfer(address(0), user, amount);
//             emit UserBalanceMigrated(user, amount, _oldContract);
//         }
        
//         emit MigrationCompleted(_oldContract, totalReceived, successCount);
//         return totalReceived;
//     }
    
//     // ============ INTERNAL HELPER FUNCTIONS ============
    
//     function _createTransaction(
//         address _member,
//         TransactionType _txType,
//         int256 _points,
//         uint256 _amount,
//         bytes32 _invoiceId,
//         string memory _note,
//         uint256 _eventId
//     ) internal {
//         transactionCounter++;
//         transactions[transactionCounter] = Transaction({
//             id: transactionCounter,
//             member: _member,
//             txType: _txType,
//             points: _points,
//             amount: _amount,
//             invoiceId: _invoiceId,
//             processedBy: msg.sender,
//             timestamp: block.timestamp,
//             note: _note,
//             eventId: _eventId,
//             status: PointTransactionStatus.Completed
//         });
        
//         memberTransactions[_member].push(transactionCounter);
//         allTransactions.push(transactions[transactionCounter]);
//         emit TransactionCreated(transactionCounter, _member, _txType, _points);
//     }
    
//     function _recordRewardTransaction(
//         address _user,
//         uint256 _amount,
//         string memory _type,
//         string memory _metadata
//     ) internal {
//         RewardTransaction memory transaction = RewardTransaction({
//             user: _user,
//             amount: _amount,
//             transactionType: _type,
//             timestamp: block.timestamp,
//             metadata: _metadata
//         });
        
//         rewardTransactions.push(transaction);
//     }
    
//     function _updateMemberTier(address _member) internal {
//         Member storage member = members[_member];
//         bytes32 oldTierID = member.tierID;
//         bytes32 newTierID = _calculateTier(member.lifetimePoints);
        
//         if (newTierID != oldTierID) {
//             member.tierID = newTierID;
            
//             emit TierUpdated(
//                 _member, 
//                 uint256(uint160(address(uint160(uint256(oldTierID))))), 
//                 uint256(uint160(address(uint160(uint256(newTierID))))), 
//                 block.timestamp
//             );
//         }
//     }
    

    
//     function _getTierMultiplier(bytes32 _tierID) internal view returns (uint256) {
//         if (_tierID == bytes32(0)) {
//             return 100;
//         }
        
//         TierConfig storage config = tierConfigs[_tierID];
//         if (config.id == bytes32(0)) {
//             return 100;
//         }
        
//         return config.multiplier;
//     }
    
//     function _getTierLevel(bytes32 _tierID) internal view returns (uint256) {
//         if (_tierID == bytes32(0)) return 0;
        
//         for (uint256 i = 0; i < allTiers.length; i++) {
//             if (allTiers[i].id == _tierID) {
//                 return i + 1;
//             }
//         }
//         return 0;
//     }
    
//     function _isEventValidForMember(uint256 _eventId, bytes32 _memberTierID) internal view returns (bool) {
//         if (_eventId == 0 || _eventId > eventCounter) {
//             return false;
//         }
        
//         Event storage evt = events[_eventId];
//         uint256 memberTierLevel = _getTierLevel(_memberTierID);
//         uint256 eventMinTierLevel = _getTierLevel(evt.minTierID);
        
//         return (
//             evt.isActive &&
//             block.timestamp >= evt.startTime &&
//             block.timestamp <= evt.endTime &&
//             memberTierLevel >= eventMinTierLevel
//         );
//     }
    
//     // ============ VIEW FUNCTIONS ============
    
//     function getMember(address _member) external view returns (
//         string memory memberId,
//         uint256 totalPoints,
//         uint256 lifetimePoints,
//         uint256 totalSpent,
//         bytes32 tierID,
//         string memory tierName,
//         bool isActive,
//         bool isLocked,
//         uint256 lastBuyActivityAt,
//         string memory phoneNumber,
//         string memory email,
//         string memory avatar
//     ) {
//         Member storage member = members[_member];
//         string memory tName = "";
        
//         if (member.tierID != bytes32(0)) {
//             tName = tierConfigs[member.tierID].nameTier;
//         }       
//          return (
//             member.memberId,
//             member.totalPoints,
//             member.lifetimePoints,
//             member.totalSpent,
//             member.tierID,
//             tName,
//             member.isActive,
//             member.isLocked,
//             member.lastBuyActivityAt,
//             member.phoneNumber,
//             member.email,
//             member.avatar
//         );
//     }
//     function getEachMember(address _member) external view returns (Member memory){
//         return members[_member];
//     }

//     function getTokenStats() external view returns (
//         uint256 _totalSupply,
//         uint256 _totalMinted,
//         uint256 _totalBurned,
//         uint256 _totalRedeemed,
//         uint256 _totalMigrated
//     ) {
//         return (totalSupply, totalMinted, totalBurned, totalRedeemed, totalMigrated);
//     }
    
//     function isFrozen() external view returns (bool) {
//         return frozen;
//     }
    
//     function isMigrated() external view returns (bool) {
//         return migrated;
//     }
    
//     function getMigrationInfo() external view returns (
//         bool _migrated,
//         address _migratedTo,
//         uint256 _totalMigrated,
//         uint256 _remainingSupply
//     ) {
//         return (migrated, migratedTo, totalMigrated, totalSupply);
//     }
    
//         /**
//      * @dev Get all token holders (for migration)
//      */
//     function getTokenHolders() external view returns (address[] memory) {
//         return tokenHolders;
//     }
//     function getTokenHoldersWithBalances() 
//         external 
//         view 
//         returns (
//             address[] memory holders,
//             uint256[] memory balances
//         ) 
//     {
//         uint256 count = 0;
        
//         for (uint256 i = 0; i < tokenHolders.length; i++) {
//             if (balanceOf[tokenHolders[i]] > 0) {
//                 count++;
//             }
//         }
        
//         holders = new address[](count);
//         balances = new uint256[](count);
        
//         uint256 index = 0;
//         for (uint256 i = 0; i < tokenHolders.length; i++) {
//             if (balanceOf[tokenHolders[i]] > 0) {
//                 holders[index] = tokenHolders[i];
//                 balances[index] = balanceOf[tokenHolders[i]];
//                 index++;
//             }
//         }
//     }
    
//     function calculatePointsFromAmount(
//         uint256 _amount,
//         address _member,
//         uint256 _eventId
//     ) external view returns (uint256) {
//         uint256 amountAfter = _amount * accumulationPercent / 100;
//         uint256 basePoints = amountAfter / exchangeRate;
        
//         if (!members[_member].isActive) {
//             return basePoints;
//         }
        
//         Member storage member = members[_member];
//         uint256 tierMultiplier = _getTierMultiplier(member.tierID);
//         uint256 points = (basePoints * tierMultiplier) / 100;
        
//         if (_eventId > 0 && _isEventValidForMember(_eventId, member.tierID)) {
//             Event storage evt = events[_eventId];
//             points += evt.pointPlus;
//         }
        
//         return points;
//     }
    
//     function canPayWithPoints(
//         address _member,
//         uint256 _amount
//     ) external view returns (
//         bool canPay,
//         uint256 pointsNeeded,
//         uint256 currentPoints,
//         uint256 maxPayableAmount
//     ) {
//         if (!members[_member].isActive) {
//             return (false, 0, 0, 0);
//         }
        
//         Member storage member = members[_member];
        
//         if (member.isLocked) {
//             return (false, 0, balanceOf[_member], 0);
//         }
        
//         maxPayableAmount = (_amount * maxPercentPerInvoice) / 100;
//         pointsNeeded = maxPayableAmount / exchangeRate;
//         currentPoints = balanceOf[_member];
        
//         canPay = (currentPoints >= pointsNeeded);
        
//         return (canPay, pointsNeeded, currentPoints, maxPayableAmount);
//     }
//         /**
//      * @dev Xử lý điểm hết hạn (gọi định kỳ bởi backend)
//      */
//    function expirePoints(address _member) external onlyAdmin memberExists(_member) {
//     Member storage member = members[_member];
    
//     // Kiểm tra thời gian không hoạt động
//     if (block.timestamp - member.lastBuyActivityAt > pointExpiryPeriod) {
//         uint256 expiredPoints = member.totalPoints;
        
//         if (expiredPoints > 0) {
//             member.totalPoints = 0;
            
//             _createTransaction(
//                 _member,
//                 TransactionType.Expire,
//                 -int256(expiredPoints),
//                 0,
//                 bytes32(0),
//                 "Points expired due to inactivity",
//                 0
//             );
            
//             emit PointsExpired(_member, expiredPoints, block.timestamp);
//         }
        
//         // Hạ hạng về None
//         if (member.tierID != bytes32(0)) {
//             bytes32 oldTierID = member.tierID;
//             member.tierID = bytes32(0);
//             // member.tierUpdatedAt = block.timestamp;
            
//             emit TierUpdated(
//                 _member, 
//                 uint256(uint160(address(uint160(uint256(oldTierID))))), 
//                 uint256(uint160(address(uint160(uint256(bytes32(0)))))), 
//                 block.timestamp
//             );
//         }
//     }
// }
//     /**
//  * @dev Lấy danh sách members có điểm sắp hết hạn
//  */
// function getMembersNearExpiry(uint256 _daysBeforeExpiry) external view returns (address[] memory) {
//     uint256 expiryThreshold = block.timestamp - pointExpiryPeriod + (_daysBeforeExpiry * 1 days);
//     address[] memory nearExpiryMembers = new address[](allMembers.length);
//     uint256 count = 0;
    
//     for (uint256 i = 0; i < allMembers.length; i++) {
//         Member memory member = allMembers[i];
        
//         if (
//             member.isActive && 
//             !member.isLocked &&
//             member.totalPoints > 0 &&
//             member.lastBuyActivityAt <= expiryThreshold
//         ) {
//             nearExpiryMembers[count] = member.walletAddress;
//             count++;
//         }
//     }
    
//     // Tạo mảng với kích thước chính xác
//     address[] memory result = new address[](count);
//     for (uint256 i = 0; i < count; i++) {
//         result[i] = nearExpiryMembers[i];
//     }
    
//     return result;
// }

//     // Thêm hàm kiểm tra member có điểm sắp hết hạn không:
//     /**
//     * @dev Kiểm tra member có điểm sắp hết hạn không
//     */
//     function isPointsNearExpiry(address _member) external view returns (
//         bool isExpiring,
//         uint256 daysUntilExpiry,
//         uint256 pointsToExpire
//     ) {
//         if (!members[_member].isActive) {
//             return (false, 0, 0);
//         }
        
//         Member storage member = members[_member];
//         uint256 inactiveDuration = block.timestamp - member.lastBuyActivityAt;
        
//         if (inactiveDuration >= pointExpiryPeriod) {
//             return (true, 0, member.totalPoints);
//         }
        
//         uint256 timeUntilExpiry = pointExpiryPeriod - inactiveDuration;
//         uint256 daysData = timeUntilExpiry / 1 days;
        
//         // Coi là "sắp hết hạn" nếu còn <= 30 ngày
//         bool expiring = daysData <= 30;
        
//         return (expiring, daysData, member.totalPoints);
//     }
//     function GetAllTransactionsPaginationByType(
//         uint256 offset, 
//         uint256 limit,
//         TransactionType _txType
//     )
//         external
//         view
//         returns (Transaction[] memory result,uint totalCount)
//     {
//         uint count = 0;
//         for(uint i; i< allTransactions.length;i++){
//             Transaction memory transaction = allTransactions[i];
//             if(transaction.txType == _txType){
//                 count++;
//             }
//         }
//         totalCount = count;
//         Transaction[] memory transactionArr= new Transaction[](count);
//         uint index = 0;
//         for(uint i; i< allTransactions.length;i++){
//             Transaction memory transaction = allTransactions[i];
//             if(transaction.txType == _txType){
//                 transactionArr[index] = transaction;
//                 index++;
//             }
//         }
//         if(offset >= count) {
//             return ( new Transaction[](0),count);
//         }

//         uint256 end = offset + limit;
//         if (end > count) {
//             end = count;
//         }

//         uint256 size = end - offset;
//         result = new Transaction[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = count - 1 - offset - i;
//             result[i] = transactionArr[reverseIndex];
//         }

//         return (result,count);
//     }


//     function GetAllTransactionsPagination(
//         uint256 offset, 
//         uint256 limit
//     )
//         external
//         view
//         returns (Transaction[] memory result,uint totalCount)
//     {
//         uint length = allTransactions.length;
//         if(offset >= length) {
//             return ( new Transaction[](0),length);
//         }

//         uint256 end = offset + limit;
//         if (end > length) {
//             end = length;
//         }

//         uint256 size = end - offset;
//         result = new Transaction[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = length - 1 - offset - i;
//             result[i] = allTransactions[reverseIndex];
//         }

//         return (result,length);
//     }
// /**
//  * @dev Lấy transactions của member theo pagination
//  */
// function getMemberTransactionsPagination(
//     address _member,
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     Transaction[] memory result,
//     uint256 totalCount
// ) {
//     uint256[] memory txIds = memberTransactions[_member];
//     uint256 length = txIds.length;
    
//     if (offset >= length) {
//         return (new Transaction[](0), length);
//     }
    
//     uint256 end = offset + limit;
//     if (end > length) {
//         end = length;
//     }
    
//     uint256 size = end - offset;
//     result = new Transaction[](size);
    
//     // Lấy transactions theo thứ tự đảo ngược (mới nhất trước)
//     for (uint256 i = 0; i < size; i++) {
//         uint256 reverseIndex = length - 1 - offset - i;
//         uint256 txId = txIds[reverseIndex];
//         result[i] = transactions[txId];
//     }
    
//     return (result, length);
// }

   
//     /**
//      * @dev Lấy thông tin thành viên theo Member ID
//      */
//     function getMemberByMemberId(string memory _memberId) external view returns (
//         address walletAddress,
//         uint256 totalPoints,
//         uint256 lifetimePoints,
//         bytes32 tierID,
//         bool isActive,
//         bool isLocked
//     ) {
//         address wallet = memberIdToAddress[_memberId];
//         require(wallet != address(0), "Member not found");
        
//         Member storage member = members[wallet];
//         return (
//             member.walletAddress,
//             member.totalPoints,
//             member.lifetimePoints,
//             member.tierID,
//             member.isActive,
//             member.isLocked
//         );
//     }
    
//     /**
//      * @dev Lấy lịch sử giao dịch của thành viên
//      */
//     function getMemberTransactions(address _member) external view returns (uint256[] memory) {
//         return memberTransactions[_member];
//     }
    
// /**
//  * @dev Lấy transactions của member trong khoảng thời gian với pagination
//  */
// function getMemberTransactionsByDateRange(
//     address _member,
//     uint256 _startTime,
//     uint256 _endTime,
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     Transaction[] memory result,
//     uint256 totalCount
// ) {
//     require(_startTime <= _endTime, "Invalid time range");
    
//     uint256[] memory txIds = memberTransactions[_member];
    
//     uint256 count = 0;
//     for (uint256 i = 0; i < txIds.length; i++) {
//         Transaction memory tx = transactions[txIds[i]];
//         if (tx.timestamp >= _startTime && tx.timestamp <= _endTime) {
//             count++;
//         }
//     }
    
//     if (count == 0 || offset >= count) {
//         return (new Transaction[](0), count);
//     }
    
//     Transaction[] memory filtered = new Transaction[](count);
//     uint256 index = 0;
    
//     for (uint256 i = 0; i < txIds.length; i++) {
//         uint256 reverseIndex = txIds.length - 1 - i;
//         uint256 txId = txIds[reverseIndex];
//         Transaction memory tx = transactions[txId];
        
//         if (tx.timestamp >= _startTime && tx.timestamp <= _endTime) {
//             filtered[index] = tx;
//             index++;
//         }
//     }
    
//     uint256 end = offset + limit;
//     if (end > count) {
//         end = count;
//     }
    
//     uint256 size = end - offset;
//     result = new Transaction[](size);
    
//     for (uint256 i = 0; i < size; i++) {
//         result[i] = filtered[offset + i];
//     }
    
//     return (result, count);
// }
//     /**
//      * @dev Lấy chi tiết giao dịch
//      */
//     function getTransaction(uint256 _txId) external view returns (
//         address member,
//         TransactionType txType,
//         int256 points,
//         uint256 amount,
//         bytes32 invoiceId,
//         uint256 timestamp,
//         string memory note
//     ) {
//         Transaction storage _tx = transactions[_txId];
//         return (
//             _tx.member,
//             _tx.txType,
//             _tx.points,
//             _tx.amount,
//             _tx.invoiceId,
//             _tx.timestamp,
//             _tx.note
//         );
//     }
//         /**
//      * @dev Lấy thông tin sự kiện
//      */
//     function getEvent(uint256 _eventId) external view returns (
//         string memory name,
//         uint256 startTime,
//         uint256 endTime,
//         uint256 pointPlus,
//         bytes32 minTier,
//         bool isActive
//     ) {
//         Event storage evt = events[_eventId];
//         return (
//             evt.name,
//             evt.startTime,
//             evt.endTime,
//             evt.pointPlus,
//             evt.minTierID,
//             evt.isActive
//         );
//     }
//     function getAllEvents()
//         external
//         view
//         returns (Event[] memory )
//     {
//         return allEvents;
//     }
//     function GetAllEventsPagination(uint256 offset, uint256 limit)
//         external
//         view
//         returns (Event[] memory result,uint totalCount)
//     {
//         if(offset >= allEvents.length) {
//             return ( new Event[](0),allEvents.length);
//         }

//         uint256 end = offset + limit;
//         if (end > allEvents.length) {
//             end = allEvents.length;
//         }

//         uint256 size = end - offset;
//         result = new Event[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = allEvents.length - 1 - offset - i;
//             result[i] = allEvents[reverseIndex];
//         }

//         return (result,allEvents.length);
//     }


//     /**
//      * @dev Lấy danh sách sự kiện đang hoạt động
//      */
//     function getActiveEvents() external view returns (uint256[] memory) {
//         uint256[] memory activeEventIds = new uint256[](eventCounter);
//         uint256 count = 0;
        
//         for (uint256 i = 1; i <= eventCounter; i++) {
//             Event storage evt = events[i];
//             if (
//                 evt.isActive &&
//                 block.timestamp >= evt.startTime &&
//                 block.timestamp <= evt.endTime
//             ) {
//                 activeEventIds[count] = evt.id;
//                 count++;
//             }
//         }
        
//         // Tạo mảng với kích thước chính xác
//         uint256[] memory result = new uint256[](count);
//         for (uint256 i = 0; i < count; i++) {
//             result[i] = activeEventIds[i];
//         }
        
//         return result;
//     }
    
//     /**
//      * @dev Lấy thông tin yêu cầu tích điểm thủ công
//      */
//     function getManualRequest(uint256 _requestId) external view returns (
//         address member,
//         bytes32 invoiceId,
//         uint256 amount,
//         uint256 pointsToEarn,
//         address requestedBy,
//         RequestStatus status,
//         RequestEarnPointType typeRequest
//     ) {
//         ManualRequest storage request = manualRequests[_requestId];
//         return (
//             request.member,
//             request.invoiceId,
//             request.amount,
//             request.pointsToEarn,
//             request.requestedBy,
//             request.status,
//             request.typeRequest
//         );
//     }
    
//     /**
//      * @dev Lấy danh sách yêu cầu đang chờ duyệt
//      */
//     function getRequestsByStatusPagination(
//         RequestStatus _requestStatus, 
//         uint offset, 
//         uint limit
//     ) external view returns (ManualRequest[] memory, uint totalCount) {
        
//         uint256 count = 0;
        
//         for (uint256 i = 1; i <= requestCounter; i++) {
//             if (manualRequests[i].status == _requestStatus) {
//                 count++;
//             }
//         }
//         ManualRequest[] memory requests = new ManualRequest[](count);
//         uint256 index = 0;
//         for (uint256 i = 1; i <= requestCounter; i++) {
//             if (manualRequests[i].status == _requestStatus) {
//                 requests[index] = manualRequests[i];
//                 index++;
//             }
//         }
//         if(offset > count) return (new ManualRequest[](0),count);
        
//         uint end = offset + limit;
//         if(end > count) end = count;
//         uint size = end - offset;
//         ManualRequest[] memory result = new ManualRequest[](size);

//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = requests.length - 1 - offset - i;
//             result[i] = requests[reverseIndex];
//         }

//         return (result,count);
//     }
//     /**
//     * @dev Lấy toàn bộ requests (không filter status) có phân trang
//     */
//     function getAllRequestsPagination(
//         uint offset,
//         uint limit
//     ) external view returns (ManualRequest[] memory, uint totalCount) {

//         uint total = requestCounter;
//         if (offset >= total) {
//             return (new ManualRequest[](0), total);
//         }

//         uint end = offset + limit;
//         if (end > total) end = total;

//         uint size = end - offset;
//         ManualRequest[] memory result = new ManualRequest[](size);

//         for (uint i = 0; i < size; i++) {
//             // reverse order: requestCounter → 1
//             uint256 reverseIndex = total - offset - i;
//             result[i] = manualRequests[reverseIndex];
//         }

//         return (result, total);
//     }
//     /**
//      * @dev Kiểm tra hóa đơn đã được xử lý chưa
//      */
//     function isInvoiceProcessed(bytes32 _invoiceId) external view returns (bool) {
//         return processedInvoices[_invoiceId];
//     }
    
//     /**
//      * @dev Lấy số lượng yêu cầu hàng ngày của nhân viên
//      */
//     function getStaffDailyRequests(address _staff) external view returns (uint256) {
//         if (block.timestamp / 1 days > lastRequestDate[_staff] / 1 days) {
//             return 0;
//         }
//         return staffDailyRequests[_staff];
//     }
    
//     /**
//      * @dev Lấy tổng số thành viên theo hạng
//      */
//     function getMemberCountByTier(bytes32 _tierID) external view returns (uint256) {
//         uint256 count = 0;
        
//         // Duyệt qua tất cả members trong allMembers
//         for (uint256 i = 0; i < allMembers.length; i++) {
//             Member memory member = allMembers[i];
            
//             // Chỉ đếm member đang active và có tierID khớp
//             if (member.isActive && member.tierID == _tierID) {
//                 count++;
//             }
//         }
        
//         return count;
//     }
//         /**
//         * @dev Lấy thống kê tổng quan hệ thống
//         */
//         function getSystemStats() external view returns (
//             uint256 totalPointApprovedKq,
//             uint256 totalIssued,
//             uint256 totalRedeemed,
//             uint256 totalMembers,
//             uint256 totalTransactions,
//             uint256 totalEvents
//         ) {
//             return (
//                 totalPointApprovedKq,
//                 totalSupply,
//                 totalRedeemed,
//                 0, // Cần implement counter riêng cho members
//                 transactionCounter,
//                 eventCounter
//             );
//         }
        

//     /**
//     * @dev Lấy danh sách voucher của member với pagination
//     */
//     function getMemberVouchersPagination(
//         address _member,
//         uint256 offset,
//         uint256 limit
//     ) external view returns (
//         MemberVoucher[] memory result,
//         uint256 totalCount
//     ) {
//         string[] memory codes = memberVouchers[_member];
        
//         // Đếm tổng số vouchers (có thể có nhiều voucher cùng code)
//         uint256 count = 0;
//         for (uint256 i = 0; i < codes.length; i++) {
//             count += memberVoucherDetails[_member][codes[i]].length;
//         }
        
//         if (count == 0 || offset >= count) {
//             return (new MemberVoucher[](0), count);
//         }
        
//         // Tạo mảng tất cả vouchers
//         MemberVoucher[] memory allVouchers = new MemberVoucher[](count);
//         uint256 index = 0;
//         for (uint256 i = 0; i < codes.length; i++) {
//             MemberVoucher[] memory vouchersForCode = memberVoucherDetails[_member][codes[i]];
//             for (uint256 j = 0; j < vouchersForCode.length; j++) {
//                 allVouchers[index] = vouchersForCode[j];
//                 index++;
//             }
//         }
        
//         // Pagination
//         uint256 end = offset + limit;
//         if (end > count) {
//             end = count;
//         }
        
//         uint256 size = end - offset;
//         result = new MemberVoucher[](size);
        
//         // Lấy từ mới nhất (reverse order)
//         for (uint256 i = 0; i < size; i++) {
//             uint256 reverseIndex = count - 1 - offset - i;
//             result[i] = allVouchers[reverseIndex];
//         }
        
//         return (result, count);    
//     }

// /**
//  * @dev Lấy danh sách voucher CHƯA SỬ DỤNG của member với pagination
//  */
// function getUnusedVouchersPagination(
//     address _member,
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     MemberVoucher[] memory result,
//     uint256 totalCount
// ) {
//     string[] memory codes = memberVouchers[_member];
    
//     // Đếm số vouchers chưa dùng
//     uint256 count = 0;
//     for (uint256 i = 0; i < codes.length; i++) {
//         MemberVoucher[] memory vouchersForCode = memberVoucherDetails[_member][codes[i]];
//         for (uint256 j = 0; j < vouchersForCode.length; j++) {
//             if (!vouchersForCode[j].isUsed) {
//                 count++;
//             }
//         }
//     }
    
//     if (count == 0 || offset >= count) {
//         return (new MemberVoucher[](0), count);
//     }
    
//     // Tạo mảng vouchers chưa dùng
//     MemberVoucher[] memory unusedVouchers = new MemberVoucher[](count);
//     uint256 index = 0;
    
//     for (uint256 i = 0; i < codes.length; i++) {
//         MemberVoucher[] memory vouchersForCode = memberVoucherDetails[_member][codes[i]];
//         for (uint256 j = 0; j < vouchersForCode.length; j++) {
//             if (!vouchersForCode[j].isUsed) {
//                 unusedVouchers[index] = vouchersForCode[j];
//                 index++;
//             }
//         }
//     }
    
//     // Pagination
//     uint256 end = offset + limit;
//     if (end > count) {
//         end = count;
//     }
    
//     uint256 size = end - offset;
//     result = new MemberVoucher[](size);
    
//     // Lấy từ mới nhất (reverse order)
//     for (uint256 i = 0; i < size; i++) {
//         uint256 reverseIndex = count - 1 - offset - i;
//         result[i] = unusedVouchers[reverseIndex];
//     }
    
//     return (result, count);
// }
// /**
//  * @dev Lấy lịch sử thanh toán bằng points của member
//  */
// function getMemberPaymentHistory(
//     address _member,
//     uint256 offset,
//     uint256 limit
// ) external view returns (
//     PaymentTransaction[] memory result,
//     uint256 totalCount
// ) {
//     PaymentTransaction[] memory history = memberPaymentHistory[_member];
//     uint256 length = history.length;
    
//     if (offset >= length) {
//         return (new PaymentTransaction[](0), length);
//     }
    
//     uint256 end = offset + limit;
//     if (end > length) {
//         end = length;
//     }
    
//     uint256 size = end - offset;
//     result = new PaymentTransaction[](size);
    
//     // Lấy từ mới nhất (reverse order)
//     for (uint256 i = 0; i < size; i++) {
//         uint256 reverseIndex = length - 1 - offset - i;
//         result[i] = history[reverseIndex];
//     }
    
//     return (result, length);
// }
// /**
//  * @dev Hoàn points khi hủy/hoàn order
//  */
// function refundPaymentPoints(
//     address _member,
//     bytes32 _paymentId,
//     uint256 _pointsToRefund,
//     string memory _reason
// ) external onlyAdmin memberExists(_member) {
//     require(_pointsToRefund > 0, "Invalid points amount");
    
//     Member storage member = members[_member];
    
//     // Hoàn điểm
//     member.totalPoints += _pointsToRefund;
//     // member.lastActivityAt = block.timestamp;
    
//     // Tạo giao dịch hoàn điểm
//     _createTransaction(
//         _member,
//         TransactionType.Refund,
//         int256(_pointsToRefund),
//         0,
//         _paymentId,
//         _reason,
//         0
//     );
    
//     emit PointsRefunded(_member, _pointsToRefund, _paymentId, _reason, block.timestamp);
// }




// }

