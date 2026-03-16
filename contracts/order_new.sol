// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IManagement.sol";
import "./interfaces/INoti.sol";
import "./interfaces/IReport.sol";
import "./interfaces/IAgent.sol";
import "./interfaces/IPoint.sol";
// import "forge-std/console.sol";

interface IIQRAgent {
    function createOrder(
        bytes32 _paymentId,
        uint256 _amount
    ) external ;
}

contract RestaurantOrder is 
    Initializable, 
    ReentrancyGuardUpgradeable, 
    OwnableUpgradeable, 
    PausableUpgradeable 
    // UUPSUpgradeable 
    {

    using Strings for uint256;

    // State variables
    IManagement public MANAGEMENT;
    IERC20 public SCUsdt;
    ICardTokenManager public ICARD_VISA;
    
    address public MasterPool;
    address public merchant;
    uint8 public taxPercent;

    // Added 22/01/2026
    ReservationRule public currentReservationRule;
    mapping(bytes32 => Reservation) public mIdToReservations;
    mapping(uint => bytes32[]) public mTableToSessionIds;
    // mapping(bytes32 => uint) public mSessionToTable;
    mapping(bytes32 => uint[]) public mSessionToTableMerge;
    mapping(bytes32 => bytes32[]) public mSessionToOrderIds;
    mapping(bytes32 => Order[]) public sessionOrders;
    mapping(bytes32 => SimpleCourse[]) public mSessionToCourses;
    mapping(bytes32 => mapping(uint => SimpleCourse)) public mSessionToIdToCourse;
    mapping(bytes32 =>mapping(uint => uint)) public mSessionToCoursePrice;
    // mapping(bytes32 => bytes32) public mSessionToIdPayment;
    mapping(bytes32 => bytes32) public mOrderIdToPaymentId; 
    mapping(bytes32 => Session) public mIdToSession;
    mapping(bytes32 => Payment[]) public mSessionToPayment;
    mapping(bytes32 => PaymentInformation[]) public mSessionToPaymentInformation;
    // mapping(uint256 => Order) public mSessionToOrder;

    // Added 24/02/2026 address => reservation
    mapping(address => bytes32[]) public customerReservations;
    bytes32[] private allReservationIds;

    // Core mappings
    // mapping(uint => Order[]) public tableOrders;
    // mapping(uint => SimpleCourse[]) public mTableToCourses;
    // ===
    // mapping(uint => Payment[]) public mTableToPayment;

    mapping(bytes32 => Payment) public mIdToPayment;
    mapping(bytes32 => PaymentInformation) public mIdToPaymentInformation;
    mapping(bytes32 => SimpleCourse[]) public paymentCourses;
    mapping(bytes32 => Review) public reviews;
    mapping(string => DishReview[]) public mDishCodeToReviews;
    mapping(address => mapping(string => uint)) public customerDishCounts;
    mapping(string => bool) public usedTxIds;
    mapping(bytes32 => SimpleCourse[]) public mOrderIdToCourses;
    // mapping(uint => mapping(uint => SimpleCourse)) public mTableToIdToCourse;

    // NEW: Staff assignment và transfer tracking
    mapping(bytes32 => address) public orderPrimaryStaff; // orderId => staff đang phụ trách
    mapping(bytes32 => address[]) public orderStaffHistory; // orderId => lịch sử staff phục vụ
    mapping(bytes32 => mapping(address => uint8)) public orderStaffShare; // orderId => staff => % share (0-100)
    mapping(bytes32 => TransferRequest[]) public pendingTransfers; // orderId => mảng transfer requests
    mapping(bytes32 => mapping(address => bool)) public hasTransferRequest; // orderId => staff => đã có request chưa
    mapping(address => bytes32[]) public staffActiveOrders; // staff => danh sách order đang xử lý
    mapping(bytes32 => bool) public orderAcknowledged; // orderId => đã được acknowledge chưa
    mapping(bytes32 => OrderHistory[]) public orderHistories; // orderId => lịch sử thao tác
    uint256 public orderHistoryCounter; // Counter cho history ID

    // Arrays
    bytes32[] public allPaymentIds;
    Payment[] public paymentHistory;
    PaymentInformation[] public paymentInfoHistory;
    mapping(bytes32 => CustomerProfile) public customerProfiles;
    mapping(uint => GroupFeature ) public mTimeToGroupFeature;
    Order[] public allOrders;
    // mapping(uint => bytes32[]) public mTableToOrderIds;
    // mapping(uint => bytes32) public mTableToIdPayment;
    
    INoti public noti;
    mapping(string => mapping(bytes32 => uint)) mDishReviewIndex; 
    IRestaurantReporting public Report;
    mapping(uint256 => Review[]) private reviewsByDate;
    // mapping(uint =>mapping(uint => uint)) public mTableToCoursePrice;
    mapping(bytes32 => Order) public mOrderIdToOrder;
    address public iqrAgentSC;
    address public agent;
    address public revenueSC;
    IPoint public POINTS;
    mapping(bytes32 => uint256) public paymentPointsUsed;
    mapping(uint256 => Review[]) private reviewsByMonth;
    mapping(address => uint) public numberOfVisit;
    mapping(bytes32 => OrderHistory[]) public paymentHistories; // paymentId => tất cả history của các orders thuộc payment
    // NEW: Struct cho transfer request
    // Events
    event OrderMade(uint indexed table, bytes32 indexed sessionId ,bytes32 indexed orderId, uint courseCount);
    event PaymentMade(bytes32 indexed sessionId, bytes32 indexed paymentId, uint total);
    event PaymentConfirmed(bytes32 indexed paymentId, address staff);
    event PaymentWithPoints(bytes32 indexed paymentId, address indexed customer, uint256 pointsUsed, uint256 pointsValue, uint256 remainingCash);
    // event OrderConfirmed(uint table, bytes32 orderId);
    event OrderConfirmed(bytes32 sessionId, bytes32 orderId);
    event CallStaff(uint table, uint amount);
    event BatchCourseStatusUpdated(bytes32 indexed sessionId, bytes32 _orderId, COURSE_STATUS newStatus);
    event CourseStatusUpdated(bytes32 indexed sessionId, bytes32 _orderId, uint _courseId, COURSE_STATUS newStatus);

    // NEW: Events cho staff management
    event OrderAcknowledged(bytes32 indexed orderId, address indexed staff, uint timestamp);
    event OrderTransferRequested(bytes32 indexed orderId, address indexed fromStaff,string nameTransferer, address[] toStaffs, string reason, uint256 requestId);
    event OrderTransferAccepted(bytes32 indexed orderId, address indexed fromStaff, address indexed toStaff,string nameTransfer, uint256 requestId);
    event OrderTransferDeclined(bytes32 indexed orderId, address indexed toStaff, uint256 requestId);
    event OrderTransferCancelled(bytes32 indexed orderId, address indexed fromStaff, uint256 requestId);
    event OrderNotificationSent(bytes32 indexed orderId, uint table, address[] recipients);
    event OrderNotificationDismissed(bytes32 indexed orderId, address[] dismissedFor);
    event OrderCancelled(bytes32 indexed orderId, address indexed staff, bool refund);
    event OrderHistoryAdded(bytes32 indexed orderId, uint256 historyId, HistoryAction action, address actor);

    // Added 22/01/2026
    event ReservationRuleUpdated(uint256 gracePeriod, uint256 penaltyPercent, uint256 minDeposit);
    event TableReserved(bytes32 indexed reservationId,uint256 deposit, uint256 time);
    event SessionCreated(uint indexed table, bytes32 indexed sessionId, bytes32 indexed reservationId, address sender);
    event SessionReservationCreated(uint[] table, bytes32 indexed sessionId, bytes32 indexed reservationId, address sender);
    event LockTableSession(uint[] table, bytes32 indexed sessionId, uint256 time);
    event MergeTableFromStaff(uint[] table, bytes32 indexed sessionId, uint256 time);
    event MergeMoreTableFromStaff(uint[] table, uint indexed tableParent ,bytes32 indexed sessionId, uint256 time);
    event SeparateTableFromStaff(uint[] table, bytes32 indexed sessionId, uint256 time);
    event NoShowHandled(uint[] table,bytes32 indexed sessionId, bytes32 indexed reservationId, bool isCancel, uint256 time);
    event CustomerCheckIn(uint[] table,bytes32 indexed sessionId, bytes32 indexed reservationId, uint256 time);
    event ReservationUpdated(
        bytes32 indexed reservationId, 
        uint256 newTime, 
        uint256 newNumPeople
    );

    event ReservationCancelled(
        bytes32 indexed reservationId, 
        uint256 cancelledAt
    );
    
    // constructor() {
    //     _disableInitializers();
    // }

    function initialize() public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(msg.sender);
        __Pausable_init();
        // __UUPSUpgradeable_init();
        taxPercent = 10;
        currentReservationRule.gracePeriod = 30;
        currentReservationRule.minDeposit = 0;
        currentReservationRule.penaltyPercent = 0;
    }    


    // function _authorizeUpgrade(address newImplementation) internal override {}

    modifier onlyStaff() {
        require(MANAGEMENT.isStaff(msg.sender), "Not staff");
        _;
    }

    // Added 22/01/2026 set config rule đến trễ / hủy hẹn
    function setConfigRuleNoShow(
      uint256 _gracePeriod, 
      uint256 _penaltyPercent, 
      uint256 _minDeposit
  ) external onlyOwner {

      require(_penaltyPercent <= 100, "Penalty cannot exceed 100%");

         currentReservationRule = ReservationRule({
          gracePeriod: _gracePeriod,
          penaltyPercent: _penaltyPercent,
          minDeposit: _minDeposit
      });

      emit ReservationRuleUpdated(_gracePeriod, _penaltyPercent, _minDeposit);
  }

    // Configuration functions
    function setConfig(
        address _management,
        address _merchant,
        address _cardVisa,
        uint8 _taxPercent,
        address _noti,
        address _report
    ) external onlyOwner {
        if (_management != address(0)) MANAGEMENT = IManagement(_management);
        if (_merchant != address(0)) merchant = _merchant;
        if (_cardVisa != address(0)) ICARD_VISA = ICardTokenManager(_cardVisa);
        if (_taxPercent <= 100) taxPercent = _taxPercent;
        if (_noti != address(0)) noti = INoti(_noti);
        if (_report != address(0)) Report = IRestaurantReporting(_report);
    }

    function setPointSC(address _pointSC) external {
        POINTS = IPoint(_pointSC);
    }

    function setIQRAgent(address _iqrAgentSC, address _agent, address revenueManager) external onlyOwner {
        iqrAgentSC = _iqrAgentSC;
        revenueSC = revenueManager;
        agent = _agent;
    }

    struct GroupFeature {
        uint time;
        bool isDineIn;
        uint8 groupSize;
        bytes32[] customerIDs;
    }

    function setFeatureCustomers(
        bool isDineIn,
        uint8 groupSize,
        bytes32[] memory customerIDs,
        uint8[] memory genders,
        uint8[] memory age,
        uint time
    ) external {
        GroupFeature storage groups = mTimeToGroupFeature[time];
        groups.isDineIn = isDineIn;
        groups.groupSize = groupSize;
        groups.customerIDs = customerIDs;
        for(uint i; i < customerIDs.length; i++) {
            CustomerProfile storage profile = customerProfiles[customerIDs[i]];
            profile.gender = genders[i];
            profile.ageGroup = age[i];
            if (profile.firstVisit == 0) {
                profile.firstVisit = block.timestamp;
            }
            profile.visitCount++;
        }
    }

    
     // Helper logic cho acknowledgeOrder
    function _internalAcknowledgeOrder(bytes32 orderId, address actor) internal returns (bool) {
        require(!orderAcknowledged[orderId], "Order already acknowledged");
        require(mOrderIdToOrder[orderId].id != bytes32(0), "Order not found");
        
        orderPrimaryStaff[orderId] = actor;
        orderAcknowledged[orderId] = true;
        orderStaffHistory[orderId].push(actor);
        orderStaffShare[orderId][actor] = 100;
        staffActiveOrders[actor].push(orderId);

        address[] memory allStaff = MANAGEMENT.GetActiveStaffAddressesByDate(block.timestamp);
        if(allStaff.length > 0){
            _dismissOrderNotification(orderId, allStaff);
        }
        
        _addOrderHistory(orderId, HistoryAction.ORDER_ACKNOWLEDGED, actor, unicode"Nhân viên đã xác nhận đơn", address(0));
        emit OrderAcknowledged(orderId, actor, block.timestamp);
        return true;
    }

    
    // NEW: Acknowledge order - nhân viên nhận đơn
    function acknowledgeOrder(bytes32 orderId) internal  returns (bool) {
       _internalAcknowledgeOrder(orderId, msg.sender);
    }

    
    
    function requestTransferOrder(
        bytes32 orderId,
        address[] memory toStaffs,
        string memory reason
    ) external onlyStaff returns (uint256 requestId) {
        require(orderPrimaryStaff[orderId] == msg.sender, "Only primary staff can transfer");
        require(toStaffs.length > 0, "Must specify at least one staff");
        
        requestId = block.timestamp;
        
        for (uint i = 0; i < toStaffs.length; i++) {
            require(MANAGEMENT.isStaff(toStaffs[i]), "Recipient is not staff");
            require(toStaffs[i] != msg.sender, "Cannot transfer to yourself");
            require(!hasTransferRequest[orderId][toStaffs[i]], "Already has pending request for this staff");
            
            // Tạo transfer request
            TransferRequest memory request = TransferRequest({
                requestId: requestId,
                orderId: orderId,
                fromStaff: msg.sender,
                toStaff: toStaffs[i],
                timestamp: block.timestamp,
                status: TransferStatus.PENDING,
                reason: reason
            });
            
            pendingTransfers[orderId].push(request);
            hasTransferRequest[orderId][toStaffs[i]] = true;
            
            // Gửi thông báo cho staff
            // if (address(noti) != address(0)) {
            //     Order memory order = mOrderIdToOrder[orderId];
            //     NotiParams memory param = NotiParams({
            //         title: "Transfer Request",
            //         body: string(abi.encodePacked(
            //             "Table ", 
            //             order.table.toString(), 
            //             " - Reason: ", 
            //             reason
            //         ))
            //     });
            //     noti.AddNoti(param, toStaffs[i]);
            // }
        }
        Staff memory staff = MANAGEMENT.GetStaffInfo(msg.sender);
        // Ghi lịch sử
        string memory details = string(abi.encodePacked(unicode"Đã chuyển đơn - ", reason));
        emit OrderTransferRequested(orderId, msg.sender,staff.name, toStaffs, reason, requestId);
        _addOrderHistory(orderId, HistoryAction.TRANSFER_REQUESTED, msg.sender, details, toStaffs[0]);
        
        return requestId;
    }

    
    // NEW: Accept transfer - ai accept trước thì nhận
    function acceptTransfer(bytes32 orderId, uint256 requestId) external onlyStaff returns (bool) {
        _internalAcceptTransfer( orderId,  requestId, msg.sender);
        return true;
    }

    
    function _internalAcceptTransfer(bytes32 orderId, uint256 requestId, address staffSender) internal {
        TransferRequest[] storage requests = pendingTransfers[orderId];
        require(requests.length > 0, "No pending transfers");
        
        bool found = false;
        uint requestIndex;
        address fromStaff;
        
        // Tìm request của staff này
        for (uint i = 0; i < requests.length; i++) {
            if (requests[i].requestId == requestId && 
                requests[i].toStaff == staffSender && 
                requests[i].status == TransferStatus.PENDING) {
                found = true;
                requestIndex = i;
                fromStaff = requests[i].fromStaff;
                break;
            }
        }
        
        require(found, "No valid pending request found");
        
        // Cập nhật staff chính
        orderPrimaryStaff[orderId] = staffSender;
        
        // Thêm vào lịch sử
        orderStaffHistory[orderId].push(staffSender);
        
        // Chia share 50-50
        orderStaffShare[orderId][fromStaff] = 50;
        orderStaffShare[orderId][staffSender] = 50;
        
        // Cập nhật danh sách active orders
        _removeFromStaffActiveOrders(fromStaff, orderId);
        staffActiveOrders[staffSender].push(orderId);
        
        // Đánh dấu request này là ACCEPTED
        requests[requestIndex].status = TransferStatus.ACCEPTED;
        
        // Hủy tất cả request còn lại của order này
        for (uint i = 0; i < requests.length; i++) {
            if (i != requestIndex && requests[i].status == TransferStatus.PENDING) {
                requests[i].status = TransferStatus.CANCELLED;
                hasTransferRequest[orderId][requests[i].toStaff] = false;
            }
        }
        
        // Gửi thông báo cho staff gốc
        // if (address(noti) != address(0)) {
        //     Order memory order = mOrderIdToOrder[orderId];
        //     NotiParams memory param = NotiParams({
        //         title: "Transfer Accepted",
        //         body: string(abi.encodePacked("Table ", order.table.toString()))
        //     });
        //     noti.AddNoti(param, fromStaff);
        // }
        
        // Ghi lịch sử
        Staff memory staff = MANAGEMENT.GetStaffInfo(staffSender);
        emit OrderTransferAccepted(orderId, fromStaff, staffSender,staff.name, requestId);

        _addOrderHistory(orderId, HistoryAction.TRANSFER_ACCEPTED, staffSender, unicode"Đã nhận đơn chuyển giao", fromStaff);
    }

    
    // NEW: Decline transfer
    function declineTransfer(bytes32 orderId, uint256 requestId) external onlyStaff returns (bool) {
        TransferRequest[] storage requests = pendingTransfers[orderId];
        require(requests.length > 0, "No pending transfers");
        
        bool found = false;
        
        for (uint i = 0; i < requests.length; i++) {
            if (requests[i].requestId == requestId && 
                requests[i].toStaff == msg.sender && 
                requests[i].status == TransferStatus.PENDING) {
                requests[i].status = TransferStatus.DECLINED;
                hasTransferRequest[orderId][msg.sender] = false;
                found = true;
                
                // // Gửi thông báo cho staff gốc
                // if (address(noti) != address(0)) {
                //     Order memory order = mOrderIdToOrder[orderId];
                //     NotiParams memory param = NotiParams({
                //         title: "Transfer Declined",
                //         body: string(abi.encodePacked(
                //             "Table ", 
                //             order.table.toString()
                //         ))
                //     });
                //     noti.AddNoti(param, requests[i].fromStaff);
                // }
                
                // Ghi lịch sử
                string memory details = unicode"Từ chối nhận đơn";
                _addOrderHistory(orderId, HistoryAction.TRANSFER_DECLINED, msg.sender, details, requests[i].fromStaff);
                
                emit OrderTransferDeclined(orderId, msg.sender, requestId);
                break;
            }
        }
        
        require(found, "No valid pending request found");
        return true;
    }
    struct StaffDeclinedInfo {
        address staffAddress;
        string staffName;
        uint256 declinedAt;
        uint256 requestId;
        string linkImgPortrait;
    }

    
    // Lấy danh sách tất cả staff đã decline transfer của 1 order
    function getDeclinedStaffByOrder(bytes32 orderId) 
        external 
        view 
        returns (StaffDeclinedInfo[] memory) 
    {
        TransferRequest[] memory requests = pendingTransfers[orderId];
        
        // Đếm số staff declined
        uint declinedCount = 0;
        for (uint i = 0; i < requests.length; i++) {
            if (requests[i].status == TransferStatus.DECLINED) {
                declinedCount++;
            }
        }
        
        // Tạo mảng kết quả
        StaffDeclinedInfo[] memory result = new StaffDeclinedInfo[](declinedCount);
        uint index = 0;
        
        for (uint i = 0; i < requests.length; i++) {
            if (requests[i].status == TransferStatus.DECLINED) {
                Staff memory staff = MANAGEMENT.GetStaffInfo(requests[i].toStaff);
                result[index] = StaffDeclinedInfo({
                    staffAddress: requests[i].toStaff,
                    staffName: staff.name,
                    declinedAt: requests[i].timestamp,
                    requestId: requests[i].requestId,
                    linkImgPortrait: staff.linkImgPortrait
                });
                index++;
            }
        }
        
        return result;
    }
    struct TransferOverview {
        StaffDeclinedInfo[] acceptedStaff;   // Danh sách đã nhận (thường chỉ 1 người)
        StaffDeclinedInfo[] declinedStaff;   // Danh sách đã từ chối
        StaffDeclinedInfo[] pendingStaff;    // Danh sách đang chờ
        StaffDeclinedInfo[] cancelledStaff;  // Danh sách bị hủy (do người khác accept trước)
    }

    
    // HÀM CHÍNH - Lấy tổng quan đầy đủ về transfer của 1 order
    function getTransferOverview(bytes32 orderId) 
        external 
        view 
        returns (TransferOverview memory) 
    {
        TransferRequest[] memory requests = pendingTransfers[orderId];
        
        // Đếm số lượng từng loại
        uint acceptedCount = 0;
        uint declinedCount = 0;
        uint pendingCount = 0;
        uint cancelledCount = 0;
        
        for (uint i = 0; i < requests.length; i++) {
            if (requests[i].status == TransferStatus.ACCEPTED) acceptedCount++;
            else if (requests[i].status == TransferStatus.DECLINED) declinedCount++;
            else if (requests[i].status == TransferStatus.PENDING) pendingCount++;
            else if (requests[i].status == TransferStatus.CANCELLED) cancelledCount++;
        }
        
        // Tạo các mảng
        StaffDeclinedInfo[] memory accepted = new StaffDeclinedInfo[](acceptedCount);
        StaffDeclinedInfo[] memory declined = new StaffDeclinedInfo[](declinedCount);
        StaffDeclinedInfo[] memory pending = new StaffDeclinedInfo[](pendingCount);
        StaffDeclinedInfo[] memory cancelled = new StaffDeclinedInfo[](cancelledCount);
        
        // Fill data
        uint aIndex = 0;
        uint dIndex = 0;
        uint pIndex = 0;
        uint cIndex = 0;
        
        for (uint i = 0; i < requests.length; i++) {
            Staff memory staff = MANAGEMENT.GetStaffInfo(requests[i].toStaff);
            
            StaffDeclinedInfo memory info = StaffDeclinedInfo({
                staffAddress: requests[i].toStaff,
                staffName: staff.name,
                declinedAt: requests[i].timestamp,
                requestId: requests[i].requestId,
                linkImgPortrait: staff.linkImgPortrait
            });
            
            if (requests[i].status == TransferStatus.ACCEPTED) {
                accepted[aIndex++] = info;
            } else if (requests[i].status == TransferStatus.DECLINED) {
                declined[dIndex++] = info;
            } else if (requests[i].status == TransferStatus.PENDING) {
                pending[pIndex++] = info;
            } else if (requests[i].status == TransferStatus.CANCELLED) {
                cancelled[cIndex++] = info;
            }
        }
        
        return TransferOverview({
            acceptedStaff: accepted,
            declinedStaff: declined,
            pendingStaff: pending,
            cancelledStaff: cancelled
        });
    }
    
    // NEW: Cancel transfer request (staff gửi request có thể hủy)
    function cancelTransferRequest(bytes32 orderId, uint256 requestId) external onlyStaff returns (bool) {
        TransferRequest[] storage requests = pendingTransfers[orderId];
        require(requests.length > 0, "No pending transfers");
        
        uint cancelCount = 0;
        
        for (uint i = 0; i < requests.length; i++) {
            if (requests[i].requestId == requestId && 
                requests[i].fromStaff == msg.sender && 
                requests[i].status == TransferStatus.PENDING) {
                requests[i].status = TransferStatus.CANCELLED;
                hasTransferRequest[orderId][requests[i].toStaff] = false;
                cancelCount++;
            }
        }
        
        require(cancelCount > 0, "No valid pending request found");
        
        emit OrderTransferCancelled(orderId, msg.sender, requestId);
        return true;
    }


    
    // Helper: Add order history
    function _addOrderHistory(
        bytes32 orderId,
        HistoryAction action,
        address actor,
        string memory details,
        address targetStaff
    ) internal {
        orderHistoryCounter++;
        
        OrderHistory memory history = OrderHistory({
            id: orderHistoryCounter,
            orderId: orderId,
            timestamp: block.timestamp,
            action: action,
            actor: actor,
            details: details,
            targetStaff: targetStaff
        });
        
        // Lưu vào order history
        orderHistories[orderId].push(history);
        
        // TÌM PAYMENT ID và lưu vào payment history
        Order memory order = mOrderIdToOrder[orderId];
        if (order.id != bytes32(0)) {
            
            bytes32 paymentId = mOrderIdToPaymentId[orderId];
            if (paymentId != bytes32(0)) {
                paymentHistories[paymentId].push(history);
            }
        }
        
        emit OrderHistoryAdded(orderId, orderHistoryCounter, action, actor);
    }

    
    // Helper function để remove order khỏi staff active list
    function _removeFromStaffActiveOrders(address staff, bytes32 orderId) internal {
        bytes32[] storage orders = staffActiveOrders[staff];
        for (uint i = 0; i < orders.length; i++) {
            if (orders[i] == orderId) {
                orders[i] = orders[orders.length - 1];
                orders.pop();
                break;
            }
        }
    }

    
    // Helper function để dismiss notification cho staff khác
    function _dismissOrderNotification(bytes32 orderId, address[] memory allStaff) internal {
        // if (allStaff.length == 0) return;

        address acknowledgedStaff = orderPrimaryStaff[orderId];
        address[] memory dismissList = new address[](allStaff.length);
        uint count = 0;
        
        for (uint i = 0; i < allStaff.length; i++) {
            if (allStaff[i] != acknowledgedStaff) {
                dismissList[count] = allStaff[i];
                count++;
            }
        }
        
        emit OrderNotificationDismissed(orderId, dismissList);
    }

    
    function _processCourses(
        bytes32 sessionId,
        bytes32 orderId,
        string[] memory dishCodes,
        uint8[] memory quantities,
        string[] memory notes,
        bytes32[] memory variantIDs,
        SelectedOption[][] memory dishSelectedOptions
    ) internal returns (uint totalPrice)
    {
        uint courseIdStart = mSessionToCourses[sessionId].length + 1;
        
        for (uint i = 0; i < dishCodes.length; i++) {
            totalPrice += _addCourse(
                sessionId, 
                orderId, 
                courseIdStart + i, 
                dishCodes[i], 
                quantities[i], 
                notes[i],
                variantIDs[i],
                dishSelectedOptions[i] 
            );
        }
    }

    
    function _addCourse(
        bytes32 sessionId,
        bytes32 orderId,
        uint courseId,
        string memory dishCode,
        uint8 quantity,
        string memory note,
        bytes32 variantID,
        SelectedOption[] memory selectedOptions
    ) internal returns (uint coursePrice)
     {
        require(quantity > 0, "quantity can be zero");
        (string memory dishName, bool available, bool active, string memory imgUrl) = MANAGEMENT.GetDishBasic(dishCode);
        require(available && active, "Dish unavailable");
        Variant memory orderVariant = MANAGEMENT.getVariant(dishCode, variantID);
        require(orderVariant.variantID != bytes32(0), "Variant not found");

        (uint optionsPrice, OptionSelected[] memory optionsSelected) = MANAGEMENT.CalculateAndValidateOptions(dishCode, selectedOptions);
       
        uint dishPrice = orderVariant.dishPrice;
        SimpleCourse memory course = SimpleCourse({
            id: courseId,
            dishCode: dishCode,
            dishName: dishName,
            dishPrice: dishPrice + optionsPrice,
            quantity: quantity,
            status: COURSE_STATUS.ORDERED,
            imgUrl: imgUrl,
            note: note,
            optionsSelected: optionsSelected
        });
        
        mOrderIdToCourses[orderId].push(course);
        mSessionToCourses[sessionId].push(course);
        mSessionToIdToCourse[sessionId][course.id] = course;
        coursePrice = dishPrice * quantity;
        mSessionToCoursePrice[sessionId][course.id] = coursePrice;
    }


   function _createOrUpdatePayment(
        bytes32 sessionId,
        bytes32 orderId,
        uint totalPrice,
        PaymentType _type
    ) internal {
        _updateSessionType(sessionId, _type);
        
        uint taxAmount = (totalPrice * taxPercent) / 100;
        bytes32 currentPaymentId;

        if (_type == PaymentType.POSTPAID) {
            (bool found, uint index) = _findExistingPostpaidIndex(sessionId);
            
            if (found) {
                currentPaymentId = _updateExistingPayment(sessionId, index, orderId, totalPrice, taxAmount);
            } else {
                currentPaymentId = _createNewPayment(sessionId, orderId, totalPrice, taxAmount, _type);
            }
        } else {
            currentPaymentId = _createNewPayment(sessionId, orderId, totalPrice, taxAmount, _type);
        }

        _copyOrderCoursesToPayment(orderId, currentPaymentId);
    }

    // Hàm bổ trợ giúp giảm tải stack cho hàm chính
    function _findExistingPostpaidIndex(bytes32 sessionId) internal view returns (bool found, uint index) {
        Payment[] storage payments = mSessionToPayment[sessionId];
        PaymentInformation[] storage paymentInfos = mSessionToPaymentInformation[sessionId];
        
        for (uint i = payments.length; i > 0; i--) {
            uint idx = i - 1;
            if (paymentInfos[idx].typePayment == PaymentType.POSTPAID && 
                payments[idx].status == PAYMENT_STATUS.CREATED) {
                return (true, idx);
            }
        }
        return (false, 0);
    }

    // --- HÀM HỖ TRỢ ĐỂ GIẢM STACK ---

    function _updateSessionType(bytes32 sessionId, PaymentType _type) private {
        Session storage sess = mIdToSession[sessionId];
        Payment[] storage payments = mSessionToPayment[sessionId];
        SessionType targetSType = _type == PaymentType.POSTPAID ? SessionType.POSTPAID : SessionType.PREPAID;

        if (payments.length == 0) {
            sess.typeSession = targetSType;
        } else if (sess.typeSession != SessionType.MIXED && sess.typeSession != targetSType) {
            sess.typeSession = SessionType.MIXED;
        }
    }

    function _createNewPayment(
        bytes32 sessionId, 
        bytes32 orderId, 
        uint totalPrice, 
        uint taxAmount, 
        PaymentType _type
    ) private returns (bytes32) {
        bytes32 pId = keccak256(abi.encodePacked(sessionId, block.timestamp, orderId));
        
        Payment storage p = mSessionToPayment[sessionId].push();
        p.id = pId;
        p.sessionId = sessionId;
        p.foodCharge = totalPrice;
        p.tax = taxAmount;
        p.total = totalPrice + taxAmount;
        p.status = PAYMENT_STATUS.CREATED;
        p.orderIds = mSessionToOrderIds[sessionId];
        p.createdAt = block.timestamp;
        // p.typePayment = _type; // Nhớ uncomment nếu struct có field này

        PaymentInformation storage pInfo = mSessionToPaymentInformation[sessionId].push();
        pInfo.id = pId;
        pInfo.typePayment = _type;

        mIdToPaymentInformation[pId] = pInfo; 
        mIdToPayment[pId] = p;
        allPaymentIds.push(pId);

        return pId;
    }

    function _updateExistingPayment(
        bytes32 sessionId,
        uint index,
        bytes32 orderId,
        uint totalPrice,
        uint taxAmount
    ) private returns (bytes32) {
        Payment storage p = mSessionToPayment[sessionId][index];
        p.orderIds.push(orderId);
        p.foodCharge += totalPrice;
        p.tax += taxAmount;
        p.total = p.foodCharge + p.tax + p.tip - p.discountAmount;

        PaymentInformation storage pInfo = mSessionToPaymentInformation[sessionId].push();
        pInfo.id = p.id;

        mIdToPaymentInformation[p.id] = pInfo;
        mIdToPayment[p.id] = p;

        return p.id;
    }

    

    // Hàm bổ trợ để chia nhỏ stack
    function _copyOrderCoursesToPayment(bytes32 orderId, bytes32 paymentId) internal {
        SimpleCourse[] storage orderCourses = mOrderIdToCourses[orderId];
        SimpleCourse[] storage pCourses = paymentCourses[paymentId];
        mOrderIdToPaymentId[orderId] = paymentId;
        
        for(uint i = 0; i < orderCourses.length; i++) {
            pCourses.push(orderCourses[i]);
        }
    }



    function UpdateOrder(
        bytes32 sessionId,
        bytes32 _orderId,
        uint[] memory _courseIds,
        uint[] memory _quantities
    ) external returns(bool) {
        require(_courseIds.length == _quantities.length, "mismatch length");

        bytes32 paymentId = mOrderIdToPaymentId[_orderId];
        require(paymentId != bytes32(0), "Order not linked");

        Payment storage payment = mIdToPayment[paymentId];
        SimpleCourse[] storage courseArr = mOrderIdToCourses[_orderId];
        
        {
            for(uint i = 0; i < _courseIds.length; i++) {
                require(mSessionToIdToCourse[sessionId][_courseIds[i]].status == COURSE_STATUS.ORDERED, "cannot change");
            }
        }

        for (uint i = 0; i < _courseIds.length; i++) {
            uint currentQty = _quantities[i];
            uint courseId = _courseIds[i];

            for (uint j = 0; j < courseArr.length; j++) {
                if (courseArr[j].id == courseId) {
                    _updatePayment(payment, courseArr[j], currentQty); // Gọi hàm phụ để tránh stack too deep
                    courseArr[j].quantity = uint8(currentQty);
                    break;
                }
            }

            _updateSessionCourses(sessionId, courseId, currentQty);
        }

        return true;
    }

    function _updatePayment(Payment storage p, SimpleCourse storage c, uint newQty) internal {
        if(c.quantity == newQty) return;

        uint diff;
        if(c.quantity > newQty) {
            diff = (c.quantity - newQty) * c.dishPrice;
            p.foodCharge -= diff;
            p.tax -= (diff * taxPercent / 100);
            p.total -= (diff + (diff * taxPercent / 100));
        } else {
            diff = (newQty - c.quantity) * c.dishPrice;
            p.foodCharge += diff;
            p.tax += (diff * taxPercent / 100);
            p.total += (diff + (diff * taxPercent / 100));
        }
    }

    function _updateSessionCourses(bytes32 sessionId, uint courseId, uint newQty) internal {
        SimpleCourse[] storage courses = mSessionToCourses[sessionId];
        for (uint j = 0; j < courses.length; j++) {
            if (courses[j].id == courseId) {
                courses[j].quantity = uint8(newQty);
                break;
            }
        }
        mSessionToIdToCourse[sessionId][courseId].quantity = uint8(newQty);
    }




    
    function _applyDiscount(
        Payment storage payment,
        string memory discountCode,
        bytes32[] memory customerGroup
    ) internal returns (uint discountAmount) {
        if (bytes(discountCode).length == 0) return 0;
        
        (
            uint discountPercent,
            bool active,
            uint amountUsed,
            uint amountMax,
            uint from,
            uint to,
            DiscountType discountType,
            bytes32[] memory targetGroupIds
        ) = MANAGEMENT.GetDiscountBasic(discountCode);
        
        require(active, "Discount inactive");
        require(amountUsed < amountMax, "Discount limit reached");
        require(block.timestamp >= from && block.timestamp <= to, "Discount expired");
        
        if (discountType == DiscountType.AUTO_GROUP) {
            bool inTargetGroup = false;
            for (uint i = 0; i < targetGroupIds.length; i++) {
                for (uint j = 0; j < customerGroup.length; j++) {
                    if (targetGroupIds[i] == customerGroup[j]) {
                        inTargetGroup = true;
                        break;
                    }
                }
            }
            require(inTargetGroup, "Not eligible for this group discount");
        }
        
        MANAGEMENT.UpdateDiscountCodeUsed(discountCode);
        return (payment.foodCharge * discountPercent) / 100;
    }
    
    
    function callStaff(uint table, uint amount) external {
        address[] memory staffsPayment = MANAGEMENT.GetStaffRolePayment();
        emit CallStaff(table, amount);
    }

    
    function _internalBatchUpdateCourseStatus(
        bytes32 sessionId,
        bytes32 _orderId,
        COURSE_STATUS newStatus
    ) internal {
        SimpleCourse[] memory courses = mOrderIdToCourses[_orderId];
        for(uint i = 0; i < courses.length; i++) {
            if(courses[i].status == COURSE_STATUS.CANCELED || courses[i].status == COURSE_STATUS.SERVED) {
                continue;
            }
            _updateCourseStatus(sessionId, _orderId, courses[i].id, newStatus);
        }
        emit BatchCourseStatusUpdated(sessionId, _orderId, newStatus);
    }

    
    function BatchUpdateCourseStatus(
        bytes32 sessionId,
        bytes32 _orderId,
        COURSE_STATUS newStatus
    ) external onlyStaff {
        _internalBatchUpdateCourseStatus(sessionId, _orderId, newStatus);
    }

    function updateCourseStatus(
        bytes32 sessionId,
        bytes32 _orderId,
        uint _courseId,
        COURSE_STATUS newStatus
    ) external onlyStaff {
        _updateCourseStatus(sessionId, _orderId, _courseId, newStatus);
    }

    
    function _updateCourseStatus(
        bytes32 sessionId,
        bytes32 _orderId,
        uint _courseId,
        COURSE_STATUS newStatus
    ) internal {
        require(newStatus != COURSE_STATUS.ORDERED,
                "course status of ORDERED autonomically set when make a new order"
        );
        SimpleCourse storage course = mSessionToIdToCourse[sessionId][_courseId];
        if (
            (newStatus == COURSE_STATUS.PREPARING && course.status != COURSE_STATUS.ORDERED) ||
            (newStatus == COURSE_STATUS.SERVED && course.status != COURSE_STATUS.PREPARING)
        ) {
            revert("Invalid Status");
        }
        
        course.status = newStatus;
        SimpleCourse[] storage coursesOrder = mOrderIdToCourses[_orderId];
        for(uint i; i < coursesOrder.length; i++) {
            if (_courseId == coursesOrder[i].id) {
                coursesOrder[i].status = newStatus;
                break;
            }
        }
        SimpleCourse[] storage coursesSession = mSessionToCourses[sessionId];
        for(uint i; i < coursesSession.length; i++) {
            if (_courseId == coursesSession[i].id) {
                coursesSession[i].status = newStatus;
                break;
            }
        }
    
        SimpleCourse[] storage coursesPayment = paymentCourses[mOrderIdToPaymentId[_orderId]];
        for(uint i; i < coursesPayment.length; i++) {
            if (_courseId == coursesPayment[i].id) {
                coursesPayment[i].status = newStatus;
                break;
            }        
        }
        emit CourseStatusUpdated(sessionId, _orderId, _courseId, newStatus);
    }
    
    // 26/01/2026 update lại dựa trên sessionId khách
    function _clearTable(uint table, bytes32 sessionId) internal {

        uint256[] storage _tableNumber = mSessionToTableMerge[sessionId];
        if(_tableNumber.length > 0)
        {
            for (uint i = 0; i < _tableNumber.length; i++) {
                _removeFromTableSessionList(_tableNumber[i], sessionId);
            }
            MANAGEMENT.separateTables(_tableNumber);  
            delete mSessionToTableMerge[sessionId];
        }
        else {
            Session memory sessionData = mIdToSession[sessionId];
            _removeFromTableSessionList(table, sessionId);
            MANAGEMENT.ClearTable(table, sessionId, sessionData.seatUsed);
        }
        
        mIdToSession[sessionId].status = SESSION_STATUS.CLOSED;
    }

    function _removeFromTableSessionList(uint table, bytes32 sessionId) internal {
        bytes32[] storage sessions = mTableToSessionIds[table];
        uint length = sessions.length;
        if (length == 0) return;
        for (uint i = 0; i < length; i++) {
            if (sessions[i] == sessionId) {
                sessions[i] = sessions[length - 1];
                sessions.pop();
                break; 
            }
        }
    }

    function _processPointPayment(
        address customer,
        uint256 totalAmount,
        bytes32 paymentId, 
        PaymentType pType
    )
        internal
        returns (
            uint256 pointsUsed,
            uint256 pointsValue,
            uint256 remainingAmount
        )
    {
        uint256 totalPoints;
        {
            bool isActive;
            bool isLocked;

            (
                ,
                totalPoints,
                ,
                ,
                ,
                ,
                isActive,
                isLocked,
                ,
                ,
            ) = POINTS.getMember(customer);

            require(isActive, "Member not active");
            require(!isLocked, "Member account is locked");
            require(totalPoints > 0, "No points available");
        }

        uint256 exchangeRate;
        uint256 maxPercentPerInvoice;
        {
            (exchangeRate, maxPercentPerInvoice) = POINTS.getPaymentConfig();
        }

        uint256 maxPayableAmount = (totalAmount * maxPercentPerInvoice) / 100;
        uint256 totalPointsValue = totalPoints * exchangeRate;

        if (totalPointsValue >= maxPayableAmount) {
            pointsValue = maxPayableAmount;
            pointsUsed = pointsValue / exchangeRate;
        } else {
            pointsValue = totalPointsValue;
            pointsUsed = totalPoints;
        }

        remainingAmount = totalAmount > pointsValue
            ? totalAmount - pointsValue
            : 0;

        if (pType == PaymentType.PREPAID) {
            POINTS.lockPoints(customer, pointsUsed, paymentId);
        } else {
            POINTS.usePointsForPayment(customer, pointsUsed, totalAmount,MANAGEMENT.branchId());
        }
    }

    function previewPointPayment(
        bytes32 paymentId,
        address customer,
        string memory discountCode
    ) external 
    view returns (
        uint256 totalAmount,
        uint256 maxPointsCanUse,
        uint256 maxValueCanPay,
        uint256 remainingAmount,
        bool canPayFully
    ) 
    {
        require((address(POINTS) != address(0)), "Points contract not set yet");
        Payment storage payment = mIdToPayment[paymentId];
        
        // bytes32 customerGroup = bytes32(0);
        // if (address(POINTS) != address(0)) {
        //     customerGroup = POINTS.getMemberToGroups(customer);
        // }

        uint discountAmount = 0;
        if (bytes(discountCode).length > 0) {
            (
                uint discountPercent,
                bool active,
                uint amountUsed,
                uint amountMax,
                uint from,
                uint to,
                DiscountType discountType,
                bytes32[] memory targetGroupIds
            ) = MANAGEMENT.GetDiscountBasic(discountCode);
            require(address(POINTS) != address(0), "Points contract not set yet");
            bytes32[] memory customerGroup = POINTS.getMemberToGroups(msg.sender);
            if (discountType == DiscountType.AUTO_GROUP && customerGroup.length > 0) {
            // require(customerGroup.length > 0, "Customer not in any group");
            bool inTargetGroup = false;
            for (uint i = 0; i < targetGroupIds.length; i++) {
                for (uint j = 0; j < customerGroup.length; j++) {
                    if (targetGroupIds[i] == customerGroup[j]) {
                        inTargetGroup = true;
                        break;
                    }
                }
            }
            require(inTargetGroup, "Not eligible for this group discount");
        }

            if (active && amountUsed < amountMax && block.timestamp >= from && block.timestamp <= to) {
                discountAmount = (payment.foodCharge * discountPercent) / 100;
            }
        }
        
        totalAmount = payment.foodCharge + payment.tax + payment.tip - discountAmount;
        
        (
            ,
            uint256 totalPoints,
            ,
            ,
            ,
            ,
            bool isActive,
            bool isLocked,
            ,
            ,
        ) = POINTS.getMember(customer);
        
        if (!isActive || isLocked || totalPoints == 0) {
            return (totalAmount, 0, 0, totalAmount, false);
        }
        
        (uint256 exchangeRate, uint256 maxPercentPerInvoice) = POINTS.getPaymentConfig();
        uint256 maxPayableAmount = (totalAmount * maxPercentPerInvoice) / 100;
        uint256 totalPointsValue = totalPoints * exchangeRate;
        
        if (totalPointsValue >= maxPayableAmount) {
            maxPointsCanUse = maxPayableAmount / exchangeRate;
            maxValueCanPay = maxPayableAmount;
            remainingAmount = totalAmount - maxPayableAmount;
            canPayFully = (maxPayableAmount >= totalAmount);
        } else {
            maxPointsCanUse = totalPoints;
            maxValueCanPay = totalPointsValue;
            remainingAmount = totalAmount - totalPointsValue;
            canPayFully = (totalPointsValue >= totalAmount);
        }
        
        return (totalAmount, maxPointsCanUse, maxValueCanPay, remainingAmount, canPayFully);
    }

    
    function getPaymentPointsInfo(bytes32 paymentId) external view returns (
        uint256 pointsUsed,
        uint256 pointsValue,
        string memory paymentMethod
    ) {
        pointsUsed = paymentPointsUsed[paymentId];
        Payment storage payment = mIdToPayment[paymentId];
        
        if (pointsUsed > 0 && address(POINTS) != address(0)) {
            (uint256 exchangeRate,) = POINTS.getPaymentConfig();
            pointsValue = pointsUsed * exchangeRate;
        }
        
        return (pointsUsed, pointsValue, payment.method);
    }

    function _UpdateForReport(SimpleCourse[] memory courses, bytes32 sessionId) internal {
        for (uint i = 0; i < courses.length; i++) {
            SimpleCourse memory course = courses[i];
            if(course.quantity > 0) {
                MANAGEMENT.UpdateOrderNum(course.dishCode, course.quantity, block.timestamp);
                uint dishPrice = mSessionToCoursePrice[sessionId][course.id];
                Report.UpdateDishDailyData(course.dishCode, block.timestamp, dishPrice, 1);
            }
        }
        uint256 date = _getDay(block.timestamp);
        Report.UpdateDailyStatsCustomer(date, 1);
        numberOfVisit[msg.sender] ++;
        Report.UpdateNewCustomerData(date,numberOfVisit[msg.sender]);
    }
    
    function getPaymentCourses(bytes32 _paymentID) external view returns(SimpleCourse[] memory courses) {
        return paymentCourses[_paymentID];
    }

    function makeReview(
        bytes32 paymentId,
        uint8 overalStar,
        string[] memory dishCodes,
        uint8[] memory dishStars,
        string memory contribution,
        string memory nameCustomer
    ) external returns (bool) {
        require(mIdToPayment[paymentId].id != bytes32(0), "Payment not found");
        require(overalStar >= 1 && overalStar <= 5, "Invalid food rating");
        require(dishCodes.length == dishStars.length, "number of dishCodes and stars not match");
        bytes32 id = keccak256(abi.encodePacked(block.timestamp, paymentId, contribution));
        
        if (dishCodes.length > 0) {
            for (uint i = 0; i < dishCodes.length; i++) {
                DishReview memory dishReview = DishReview({
                    nameCustomer: nameCustomer,
                    dishCode: dishCodes[i],
                    dishStar: dishStars[i],
                    contribution: contribution,
                    createdAt: block.timestamp,
                    paymentId: paymentId,
                    isShow: true,
                    id: id
                });
                mDishCodeToReviews[dishCodes[i]].push(dishReview);
                mDishReviewIndex[dishCodes[i]][id] = mDishCodeToReviews[dishCodes[i]].length - 1;
                MANAGEMENT.updateAverageStarDish(dishStars[i], dishCodes[i]);
            }
        }

        reviews[paymentId] = Review({
            nameCustomer: nameCustomer,
            overalStar: overalStar,
            contribution: contribution,
            createdAt: block.timestamp,
            paymentId: paymentId
        });
        
        uint256 date = _getDay(block.timestamp);
        uint256 month = _getMonth(block.timestamp);
        reviewsByDate[date].push(reviews[paymentId]);
        reviewsByMonth[month].push(reviews[paymentId]);
        return true;
    }

    
    function _getDay(uint timestamp) internal pure returns (uint) {
        return timestamp / 86400;
    }

    
    function _getMonth(uint timestamp) internal pure returns (uint) {
        return timestamp / (86400 * 30);
    }

        
    function getReviewsByMonth(
        uint256 month,
        uint256 page,
        uint256 pageSize
    ) external view returns (Review[] memory, uint256 totalCount, uint256 totalPages, uint256 currentPage) 
    {
        require(pageSize > 0, "Page size must be greater than 0");
        
        Review[] storage allReviews = reviewsByMonth[month];
        totalCount = allReviews.length;
        totalPages = (totalCount + pageSize - 1) / pageSize;
        
        if (totalCount == 0) {
            return (new Review[](0), 0, 0, page);
        }
        
        if (page >= totalPages) {
            return (new Review[](0), totalCount, totalPages, page);
        }
        
        uint256 startIndex = page * pageSize;
        uint256 endIndex = startIndex + pageSize;
        
        if (endIndex > totalCount) {
            endIndex = totalCount;
        }
        
        uint256 resultSize = endIndex - startIndex;
        Review[] memory result = new Review[](resultSize);
        
        for (uint256 i = 0; i < resultSize; i++) {
            uint256 reverseIndex = totalCount - 1 - startIndex - i;
            result[i] = allReviews[reverseIndex];
        }
        
        return (result, totalCount, totalPages, page);
    }

    
    function getReviewsByDate(
        uint256 date,
        uint256 page,
        uint256 pageSize
    ) external view returns (Review[] memory, uint256 totalCount, uint256 totalPages, uint256 currentPage)
     {
        require(pageSize > 0, "Page size must be greater than 0");
        
        Review[] storage allReviews = reviewsByDate[date];
        totalCount = allReviews.length;
        totalPages = (totalCount + pageSize - 1) / pageSize;
        
        if (totalCount == 0) {
            return (new Review[](0), 0, 0, page);
        }
        
        if (page > totalPages) {
            return (new Review[](0), totalCount, totalPages, page);
        }
        
        uint256 startIndex = page * pageSize;
        uint256 endIndex = startIndex + pageSize;
        
        if (endIndex > totalCount) {
            endIndex = totalCount;
        }
        
        uint256 resultSize = endIndex - startIndex;
        Review[] memory result = new Review[](resultSize);
        
        for (uint256 i = 0; i < resultSize; i++) {
            uint256 reverseIndex = totalCount - 1 - startIndex - i;
            result[i] = allReviews[reverseIndex];
        }
        
        return (result, totalCount, totalPages, page);
    }
        
    function BatchUpdateHideReview(bytes32[] memory reviewIds, string memory dishCode) external {
        require(reviewIds.length > 0, "reviewid array can be empty");  
        for(uint i; i < reviewIds.length; i++) {
            _hideReview(reviewIds[i], dishCode);
        }
    }
    
    function _hideReview(bytes32 reviewId, string memory dishCode) internal {
        uint index = mDishReviewIndex[dishCode][reviewId];
        DishReview storage review = mDishCodeToReviews[dishCode][index];
        review.isShow = false;
    }
    
    function getReviewByDish(string memory dishCodes) external view returns (DishReview[] memory) {
        return mDishCodeToReviews[dishCodes];
    }

    
    // NEW: View functions cho staff management
    function getOrderStaffInfo(bytes32 orderId) external view returns (
        address primaryStaff,
        address[] memory staffHistory,
        uint8 primaryStaffShare
    ) {
        primaryStaff = orderPrimaryStaff[orderId];
        staffHistory = orderStaffHistory[orderId];
        primaryStaffShare = orderStaffShare[orderId][primaryStaff];
        return (primaryStaff, staffHistory, primaryStaffShare);
    }

    
    function getStaffShareForOrder(bytes32 orderId, address staff) external view returns (uint8) {
        return orderStaffShare[orderId][staff];
    }
    
    function getPendingTransfers(bytes32 orderId) external view returns (TransferRequest[] memory) {
        return pendingTransfers[orderId];
    }
    
    function getPendingTransfersByStaff(bytes32 orderId, address staff) external view returns (TransferRequest[] memory) {
        TransferRequest[] memory allRequests = pendingTransfers[orderId];
        uint count = 0;
        
        // Đếm số request của staff này
        for (uint i = 0; i < allRequests.length; i++) {
            if (allRequests[i].toStaff == staff && allRequests[i].status == TransferStatus.PENDING) {
                count++;
            }
        }
        
        // Tạo mảng kết quả
        TransferRequest[] memory result = new TransferRequest[](count);
        uint index = 0;
        for (uint i = 0; i < allRequests.length; i++) {
            if (allRequests[i].toStaff == staff && allRequests[i].status == TransferStatus.PENDING) {
                result[index] = allRequests[i];
                index++;
            }
        }
        
        return result;
    }

    
    function getStaffActiveOrders(address staff) external view returns (bytes32[] memory) {        
        return staffActiveOrders[staff];
    }

    
    function GetOrdersAcknowlegdePaginationByStatus(
        address staff,
        uint offset, 
        uint limit,
        ORDER_STATUS _status
    ) external 
    view returns(Order[] memory orders, uint totalCount)
     {
        totalCount = 0;
        for(uint i; i < staffActiveOrders[staff].length; i++) {
            if(mOrderIdToOrder[staffActiveOrders[staff][i]].status == _status) {
                totalCount++;
            }
        }
        if(offset >= totalCount) {
            return (new Order[](0), totalCount);
        }
        uint remaining = totalCount - offset;
        uint count = remaining < limit ? remaining : limit;
        orders = new Order[](count);
        uint foundCount = 0;
        uint skipped = 0;
        for (uint i = staffActiveOrders[staff].length; i > 0 && foundCount < count; i--) {
            uint index = i - 1;
            if(mOrderIdToOrder[staffActiveOrders[staff][index]].status == _status) {
                if(skipped < offset) {
                    skipped++;
                    continue;
                }
                orders[foundCount] = mOrderIdToOrder[staffActiveOrders[staff][index]];
                foundCount++;
            }
        }
        return (orders, totalCount);
    }

    
    function getStaffActiveOrdersCount(address staff) external view returns (uint) {
        return staffActiveOrders[staff].length;
    }
    
    function isOrderAcknowledged(bytes32 orderId) external view returns (bool) {
        return orderAcknowledged[orderId];
    }
    
    
    // NEW: Get order history
    function getOrderHistory(bytes32 orderId) external view returns (OrderHistory[] memory) {
        return orderHistories[orderId];
    }
    
    
    function getOrderHistoryPaginated(
        bytes32 orderId,
        uint offset,
        uint limit
    ) external view returns (OrderHistory[] memory, uint totalCount) {
        OrderHistory[] storage allHistory = orderHistories[orderId];
        totalCount = allHistory.length;
        
        if (totalCount == 0 || offset >= totalCount) {
            return (new OrderHistory[](0), totalCount);
        }
        
        uint remaining = totalCount - offset;
        uint count = remaining < limit ? remaining : limit;
        OrderHistory[] memory result = new OrderHistory[](count);
        
        // Lấy từ mới nhất (reverse order)
        for (uint i = 0; i < count; i++) {
            result[i] = allHistory[totalCount - 1 - offset - i];
        }
        
        return (result, totalCount);
    }
    
    
    function getLatestOrderHistory(bytes32 orderId, uint count) external view returns (OrderHistory[] memory) {
        OrderHistory[] storage allHistory = orderHistories[orderId];
        uint totalCount = allHistory.length;
        
        if (totalCount == 0) {
            return new OrderHistory[](0);
        }
        
        if (count > totalCount) {
            count = totalCount;
        }
        
        OrderHistory[] memory result = new OrderHistory[](count);
        for (uint i = 0; i < count; i++) {
            result[i] = allHistory[totalCount - 1 - i];
        }
        
        return result;
    }

    
    // Existing view functions
    function getSessionOrderCount(bytes32 sessionId) external view returns (uint) {
        return sessionOrders[sessionId].length;
    }

    
    function GetOrders(bytes32 sessionId) external view returns(Order[] memory) {
        return sessionOrders[sessionId];
    }

    
    function GetOrderById(bytes32 orderId) external view returns(Order memory) {
        return mOrderIdToOrder[orderId];
    }

    
    function GetOrdersPaginationByStatus(
        uint offset, 
        uint limit,
        ORDER_STATUS _status
    ) external view returns(Order[] memory, uint totalCount)
     {
        totalCount = 0;

        for(uint i; i < allOrders.length; i++) {
            if(allOrders[i].status == _status) {
                totalCount++;
            }
        }
        if(offset >= totalCount) {
            return (new Order[](0), totalCount);
        }
        uint remaining = totalCount - offset;
        uint count = remaining < limit ? remaining : limit;
        Order[] memory orders = new Order[](count);
        uint foundCount = 0;
        uint skipped = 0;
        for (uint i = allOrders.length; i > 0 && foundCount < count; i--) {
            uint index = i - 1;
            if(allOrders[index].status == _status) {
                if(skipped < offset) {
                    skipped++;
                    continue;
                }
                orders[foundCount] = allOrders[index];
                foundCount++;
            }
        }
        return (orders, totalCount);
    }

    
    function GetOrdersByStatus(
        ORDER_STATUS _status
    ) external view returns(Order[] memory) {
        uint totalCount = 0;

        for(uint i; i < allOrders.length; i++) {
            if(allOrders[i].status == _status) {
                totalCount++;
            }
        }
        Order[] memory orders = new Order[](totalCount);
        uint foundCount = 0;
        for (uint i = allOrders.length; i > 0 && foundCount < totalCount; i--) {
            uint index = i - 1;
            if(allOrders[index].status == _status) {
                orders[foundCount] = allOrders[index];
                foundCount++;
            }
        }
        return (orders);
    }

    
    function getSessionCourseCount(bytes32 sessionId) external view returns (uint) {
        return mSessionToCourses[sessionId].length;
    }

    
    function getSessionOrder(bytes32 sessionId, uint index) external view returns (Order memory) {
        require(index < sessionOrders[sessionId].length, "Index out of bounds");
        return sessionOrders[sessionId][index];
    }

    
    function getSessionCourse(bytes32 sessionId, uint index) external view returns (SimpleCourse memory) {
        require(index < mSessionToCourses[sessionId].length, "Index out of bounds");
        return mSessionToCourses[sessionId][index];
    }

    
    function GetCoursesBySession(bytes32 sessionId) external view returns(SimpleCourse[] memory) {
        return mSessionToCourses[sessionId];
    }

    
    function GetAllOrders() external view returns(Order[] memory) {
        return allOrders;
    }

    
    function GetCoursesByOrderId(bytes32 _idOrder) external view returns(SimpleCourse[] memory) {
        return mOrderIdToCourses[_idOrder];
    }

    
    function getPayment(bytes32 paymentId) public view returns (Payment memory) {
        return mIdToPayment[paymentId];
    }

      function getPaymentInfo(bytes32 paymentId) public view returns (PaymentInformation memory) {
        return mIdToPaymentInformation[paymentId];
    }

    
    function isValidAmount(bytes32 _paymentId, uint _amount) external view returns(bool) {
        Payment memory payment = getPayment(_paymentId);
        return (payment.foodCharge - payment.discountAmount) == _amount;
    }

    // Sửa
    // function getTablePayment(uint table) external view returns (Payment memory) {
    //     Payment memory payment = mTableToPayment[table];
    //     return payment;
    // }

    // Sửa
    // function GetLastIdPaymentBySession(bytes32 sessionId) external view returns(bytes32) {
    //     return mSessionToIdPayment[sessionId];
    // }

    
    function getReview(bytes32 paymentId) external view returns (Review memory) {
        return reviews[paymentId];
    }

    
    function getPaymentHistoryCount() external view returns (uint) {
        return paymentHistory.length;
    }

    
    function getPaymentHistoryItem(uint index) external view returns (Payment memory) {
        require(index < paymentHistory.length, "Index out of bounds");
        return paymentHistory[index];
    }

    function getPaymentInfoHistoryItem(uint index) external view returns (PaymentInformation memory) {
        require(index < paymentInfoHistory.length, "Index out of bounds");
        return paymentInfoHistory[index];
    }

    
    function getPaymentsWithStatus(uint offset, uint limit) external view returns (Payment[] memory payments, uint totalCount) {
        uint paymentCount = paymentHistory.length;
        totalCount = paymentCount;
        
        if (paymentCount == 0 || offset >= paymentCount) {
            return (new Payment[](0), totalCount);
        }
        
        uint remainingItems = paymentCount - offset;
        if (limit > remainingItems) {
            limit = remainingItems;
        }
        if (limit == 0) {
            return (new Payment[](0), totalCount);
        }
        
        return (_getPaymentsNotPaid(offset, limit));
    }

    
    function _getPaymentsNotPaid(uint offset, uint limit) internal view returns (Payment[] memory payments, uint totalCount) {
        uint paymentCount = paymentHistory.length;
        Payment[] memory paymentsNotPaid = new Payment[](paymentCount);
        uint count;
        for(uint i; i < paymentCount; i++) {
            if(paymentHistory[i].status == PAYMENT_STATUS.CREATED) {
                paymentsNotPaid[count] = paymentHistory[i];
                count++;
            }
        }
        Payment[] memory result = new Payment[](limit);
        for (uint i = 0; i < limit; i++) {
            result[i] = paymentsNotPaid[offset + i];
        }
        return (result, paymentCount);
    }


        
    function getPaymentInfosWithStatus(uint offset, uint limit) external view returns (PaymentInformation[] memory payments, uint totalCount) {
        uint paymentCount = paymentInfoHistory.length;
        totalCount = paymentCount;
        
        if (paymentCount == 0 || offset >= paymentCount) {
            return (new PaymentInformation[](0), totalCount);
        }
        
        uint remainingItems = paymentCount - offset;
        if (limit > remainingItems) {
            limit = remainingItems;
        }
        if (limit == 0) {
            return (new PaymentInformation[](0), totalCount);
        }
        
        return (_getPaymentInfosNotPaid(offset, limit));
    }

    
    function _getPaymentInfosNotPaid(uint offset, uint limit) internal view returns (PaymentInformation[] memory payments, uint totalCount) {
        uint paymentCount = paymentHistory.length;
        PaymentInformation[] memory paymentsNotPaid = new PaymentInformation[](paymentCount);
        uint count;
        for(uint i; i < paymentCount; i++) {
            if(paymentHistory[i].status == PAYMENT_STATUS.CREATED) {
                paymentsNotPaid[count] = paymentInfoHistory[i];
                count++;
            }
        }
        PaymentInformation[] memory result = new PaymentInformation[](limit);
        for (uint i = 0; i < limit; i++) {
            result[i] = paymentsNotPaid[offset + i];
        }
        return (result, paymentCount);
    }

    struct PaymentInfoStruct {
        Payment payment;
        PaymentInformation paymentInfo;
        SimpleCourse[] courses;
    }

    
    function getPaymentsPagination(uint offset, uint limit) external view returns (PaymentInfoStruct[] memory payments, uint totalCount) {
        uint paymentCount = allPaymentIds.length;
        totalCount = paymentCount;
        
        if (paymentCount == 0 || offset >= paymentCount) {
            return (new PaymentInfoStruct[](0), totalCount);
        }
        
        uint remainingItems = paymentCount - offset;
        if (limit > remainingItems) {
            limit = remainingItems;
        }
        if (limit == 0) {
            return (new PaymentInfoStruct[](0),totalCount);
        }
        
        return (_getPayments(offset, limit));
    }

    
    function _getPayments(uint offset, uint limit) internal view returns (PaymentInfoStruct[] memory payments, uint totalCount) {
        uint paymentCount = allPaymentIds.length;
        PaymentInfoStruct[] memory result = new PaymentInfoStruct[](limit);
        for (uint i = 0; i < limit; i++) {
            uint256 reverseIndex = paymentCount - 1 - offset - i;
            result[i] = PaymentInfoStruct({
                payment: mIdToPayment[allPaymentIds[reverseIndex]],
                paymentInfo: mIdToPaymentInformation[allPaymentIds[reverseIndex]],
                courses: paymentCourses[allPaymentIds[reverseIndex]]
            });
        }
        return (result, paymentCount);
    }

    
    function getTaxPercent() external view returns (uint8) {
        return taxPercent;
    }

    
    function createOrderDataForAgentManagement(bytes32 paymentId, uint amount) internal {
        require(iqrAgentSC != address(0) && revenueSC != address(0), "revenueSC or iqrAgentSC not set yet");
        IIQRAgent(iqrAgentSC).createOrder(paymentId, amount);
    }
    
    function getPaymentHistory(bytes32 paymentId) external view returns (OrderHistory[] memory) {
        OrderHistory[] storage allHistory = paymentHistories[paymentId];
        uint totalCount = allHistory.length;
        
        if (totalCount == 0) {
            return new OrderHistory[](0);
        }
        
        // Reverse order - mới nhất ở trên
        OrderHistory[] memory result = new OrderHistory[](totalCount);
        for (uint i = 0; i < totalCount; i++) {
            result[i] = allHistory[totalCount - 1 - i];
        }
        
        return result;
    }

    
    // Lấy history của payment với phân trang (mới nhất ở trên)
    function getPaymentHistoryPaginated(
        bytes32 paymentId,
        uint offset,
        uint limit
    ) external view returns (OrderHistory[] memory, uint totalCount) {
        OrderHistory[] storage allHistory = paymentHistories[paymentId];
        totalCount = allHistory.length;
        
        if (totalCount == 0 || offset >= totalCount) {
            return (new OrderHistory[](0), totalCount);
        }
        
        uint remaining = totalCount - offset;
        uint count = remaining < limit ? remaining : limit;
        OrderHistory[] memory result = new OrderHistory[](count);
        
        // Lấy từ mới nhất (reverse order)
        for (uint i = 0; i < count; i++) {
            result[i] = allHistory[totalCount - 1 - offset - i];
        }
        
        return (result, totalCount);
    }

    
    // Lấy N history mới nhất của payment
    function getLatestPaymentHistory(bytes32 paymentId, uint count) external view returns (OrderHistory[] memory) {
        OrderHistory[] storage allHistory = paymentHistories[paymentId];
        uint totalCount = allHistory.length;
        
        if (totalCount == 0) {
            return new OrderHistory[](0);
        }
        
        if (count > totalCount) {
            count = totalCount;
        }
        
        OrderHistory[] memory result = new OrderHistory[](count);
        for (uint i = 0; i < count; i++) {
            result[i] = allHistory[totalCount - 1 - i];
        }
        
        return result;
    }

    
    // Lấy history của payment theo action type
    function getPaymentHistoryByAction(
        bytes32 paymentId,
        HistoryAction action
    ) external view returns (OrderHistory[] memory) {
        OrderHistory[] storage allHistory = paymentHistories[paymentId];
        uint totalCount = allHistory.length;
        
        if (totalCount == 0) {
            return new OrderHistory[](0);
        }
        
        // Đếm số lượng history match
        uint matchCount = 0;
        for (uint i = 0; i < totalCount; i++) {
            if (allHistory[i].action == action) {
                matchCount++;
            }
        }
        
        if (matchCount == 0) {
            return new OrderHistory[](0);
        }
        
        // Tạo mảng kết quả (reverse order - mới nhất trước)
        OrderHistory[] memory result = new OrderHistory[](matchCount);
        uint resultIndex = 0;
        
        for (uint i = totalCount; i > 0; i--) {
            if (allHistory[i - 1].action == action) {
                result[resultIndex] = allHistory[i - 1];
                resultIndex++;
            }
        }
        
        return result;
    }

    
    // Lấy history của payment theo staff
    function getPaymentHistoryByStaff(
        bytes32 paymentId,
        address staff
    ) external view returns (OrderHistory[] memory) {
        OrderHistory[] storage allHistory = paymentHistories[paymentId];
        uint totalCount = allHistory.length;
        
        if (totalCount == 0) {
            return new OrderHistory[](0);
        }
        
        // Đếm số lượng history của staff này
        uint matchCount = 0;
        for (uint i = 0; i < totalCount; i++) {
            if (allHistory[i].actor == staff || allHistory[i].targetStaff == staff) {
                matchCount++;
            }
        }
        
        if (matchCount == 0) {
            return new OrderHistory[](0);
        }
        
        // Tạo mảng kết quả (reverse order - mới nhất trước)
        OrderHistory[] memory result = new OrderHistory[](matchCount);
        uint resultIndex = 0;
        
        for (uint i = totalCount; i > 0; i--) {
            if (allHistory[i - 1].actor == staff || allHistory[i - 1].targetStaff == staff) {
                result[resultIndex] = allHistory[i - 1];
                resultIndex++;
            }
        }
        
        return result;
    }

    
    // Lấy tổng số history của payment
    function getPaymentHistoryCount(bytes32 paymentId) external view returns (uint) {
        return paymentHistories[paymentId].length;
    }

    // ============================================
    // Dùng khi cần rebuild lại payment history từ các orders
    
    function rebuildPaymentHistory(bytes32 paymentId) external onlyOwner returns (bool) {
        Payment storage payment = mIdToPayment[paymentId];
        require(payment.id != bytes32(0), "Payment not found");
        
        // Xóa history cũ
        delete paymentHistories[paymentId];
        
        // Rebuild từ tất cả orders của payment
        bytes32[] memory orderIds = payment.orderIds;
        for (uint i = 0; i < orderIds.length; i++) {
            OrderHistory[] memory orderHistory = orderHistories[orderIds[i]];
            for (uint j = 0; j < orderHistory.length; j++) {
                paymentHistories[paymentId].push(orderHistory[j]);
            }
        }
        
        // Sort theo timestamp (bubble sort - đơn giản cho smart contract)
        _sortPaymentHistory(paymentId);
        
        return true;
    }

    
    // Helper function để sort history theo timestamp
    function _sortPaymentHistory(bytes32 paymentId) internal {
        OrderHistory[] storage history = paymentHistories[paymentId];
        uint n = history.length;
        
        if (n <= 1) return;
        
        // Bubble sort
        for (uint i = 0; i < n - 1; i++) {
            for (uint j = 0; j < n - i - 1; j++) {
                if (history[j].timestamp > history[j + 1].timestamp) {
                    // Swap
                    OrderHistory memory temp = history[j];
                    history[j] = history[j + 1];
                    history[j + 1] = temp;
                }
            }
        }
    }


    function cancelOrder(bytes32 orderId) external onlyStaff nonReentrant returns (bool) {
        Order storage order = mOrderIdToOrder[orderId];
        require(order.id != bytes32(0), "Order not found");
        require(order.status == ORDER_STATUS.CREATED, "Only CREATED orders can be cancelled");

        bytes32 sessionId = order.sessionId;
        bytes32 paymentId = mOrderIdToPaymentId[orderId];
        ORDER_STATUS cancelStatus;
        PaymentType typeP;
        {
            Payment storage payment = mIdToPayment[paymentId];
            PaymentInformation memory pInfo = mIdToPaymentInformation[paymentId];

            if (pInfo.typePayment == PaymentType.PREPAID && payment.status == PAYMENT_STATUS.PAID) {
                payment.status = PAYMENT_STATUS.REFUNDED;
                _handleRefund(paymentId, pInfo.customer);
            }
            cancelStatus = (pInfo.typePayment == PaymentType.PREPAID) 
            ? ORDER_STATUS.REFUNDED 
            : ORDER_STATUS.CANCELLED;
            typeP = pInfo.typePayment;
        }

         
        order.status = cancelStatus;
        _cancelOrderDetails(orderId, sessionId, cancelStatus);

        // 4. Dọn dẹp Staff
        address primaryStaff = orderPrimaryStaff[orderId];
        if (primaryStaff != address(0)) {
            _removeFromStaffActiveOrders(primaryStaff, orderId);
        }

        emit OrderCancelled(orderId, msg.sender, typeP == PaymentType.PREPAID);
        return true;
    }

    // Hàm phụ xử lý hoàn tiền/điểm
    function _handleRefund(bytes32 paymentId, address customer) internal {
        uint256 pointsToUnlock = paymentPointsUsed[paymentId];
        if (pointsToUnlock > 0 && address(POINTS) != address(0)) {
            if(customer != address(0)) {
                POINTS.unlockPoints(customer, paymentId,MANAGEMENT.branchId());
            }
            paymentPointsUsed[paymentId] = 0;
        }
        // _addOrderHistory có thể gọi ở đây để giảm tải cho hàm chính
    }

    // Hàm phụ xử lý các mảng và mapping (Giảm Gas & Stack)
    function _cancelOrderDetails(bytes32 orderId, bytes32 sessionId, ORDER_STATUS status) internal {
        // Cập nhật trạng thái các món ăn
        SimpleCourse[] storage coursesOrder = mOrderIdToCourses[orderId];
        for (uint i = 0; i < coursesOrder.length; i++) {
            coursesOrder[i].status = COURSE_STATUS.CANCELED;
        }

        // Cập nhật mảng global/session
        _updateOrderStatusInArrays(orderId, sessionId, status);

        // Ghi log lịch sử
        _addOrderHistory(
            orderId, 
            status == ORDER_STATUS.REFUNDED ? HistoryAction.ORDER_REFUNDED : HistoryAction.ORDER_CANCELLED, 
            msg.sender, 
            unicode"Nhân viên đã hủy đơn", 
            address(0)
        );
    }

    
    // Helper để code gọn hơn
    function _updateOrderStatusInArrays(bytes32 orderId, bytes32 sessionId, ORDER_STATUS status) internal {
        for (uint i = 0; i < allOrders.length; i++) {
            if (allOrders[i].id == orderId) { allOrders[i].status = status; break; }
        }
        Order[] storage sOrders = sessionOrders[sessionId];
        for (uint j = 0; j < sOrders.length; j++) {
            if (sOrders[j].id == orderId) { sOrders[j].status = status; break; }
        }
    }



    function batchTransferOrders(
        address[] memory toStaffs,
        string memory reason
    ) external onlyStaff returns (uint256[] memory requestIds) {
        bytes32[] storage activeOrders = staffActiveOrders[msg.sender];
        uint256 totalOrders = activeOrders.length;
        
        require(totalOrders > 0, "No orders");
        require(toStaffs.length > 0, "No recipients");

        requestIds = new uint256[](totalOrders);
        uint256 timestamp = block.timestamp;

        // 1. Kiểm tra danh sách nhân viên 1 lần duy nhất bên ngoài vòng lặp
        for (uint256 k = 0; k < toStaffs.length; k++) {
            require(MANAGEMENT.isStaff(toStaffs[k]), "Invalid staff");
            require(toStaffs[k] != msg.sender, "Self transfer forbidden");
        }

        // Lấy thông tin staff 1 lần duy nhất
        string memory staffName = MANAGEMENT.GetStaffInfo(msg.sender).name;

        for (uint256 i = 0; i < totalOrders; i++) {
            bytes32 orderId = activeOrders[i];
            uint256 requestId = uint256(keccak256(abi.encodePacked(orderId, timestamp, i)));
            requestIds[i] = requestId;

            // Tách xử lý nội bộ để giải phóng stack
            _processTransferRequest(orderId, toStaffs, requestId, timestamp, reason);

            // Ghi lịch sử đơn giản hơn để tiết kiệm gas
            _addOrderHistory(orderId, HistoryAction.TRANSFER_REQUESTED, msg.sender, reason, toStaffs[0]);
            
            emit OrderTransferRequested(orderId, msg.sender, staffName, toStaffs, reason, requestId);
        }

        return requestIds;
    }

    function _processTransferRequest(
        bytes32 orderId,
        address[] memory toStaffs,
        uint256 requestId,
        uint256 timestamp,
        string memory reason
    ) internal {
        for (uint256 j = 0; j < toStaffs.length; j++) {
            address recipient = toStaffs[j];
            if (!hasTransferRequest[orderId][recipient]) {
                pendingTransfers[orderId].push(TransferRequest({
                    requestId: requestId,
                    orderId: orderId,
                    fromStaff: msg.sender,
                    toStaff: recipient,
                    timestamp: timestamp,
                    status: TransferStatus.PENDING,
                    reason: reason
                }));
                hasTransferRequest[orderId][recipient] = true;
            }
        }
    }

    function batchAcceptTransfers(
        bytes32[] calldata orderIds, 
        uint256[] calldata requestIds
    ) external onlyStaff {
        require(orderIds.length == requestIds.length, "The table is not consistent");
        
        for (uint i = 0; i < orderIds.length; i++) {
            _internalAcceptTransfer(orderIds[i], requestIds[i], msg.sender);
        }
    }

    
    // Bếp xác nhận đơn
    function ConfirmOrder(bytes32 orderId, ORDER_STATUS _status) public onlyStaff {
      _internalConfirmOrder(orderId, _status, msg.sender);
    }
    // Tách phần xử lý báo cáo ra hàm riêng để giải phóng stack
    function _handleOrderReporting(Payment storage payment, bytes32 sessionId) internal {
        SimpleCourse[] memory courses = this.getPaymentCourses(payment.id);
        _UpdateForReport(courses, sessionId); 

        uint256 len = courses.length;
        string[] memory dishCodes = new string[](len);
        uint[] memory revenues = new uint[](len);
        uint[] memory orders = new uint[](len);

        for (uint i = 0; i < len; i++) {
            dishCodes[i] = courses[i].dishCode;
            orders[i] = courses[i].quantity;
            
            uint256 itemGross = courses[i].dishPrice * courses[i].quantity;
            if (payment.discountAmount > 0 && payment.foodCharge > 0) {
                uint256 itemDiscount = (itemGross * payment.discountAmount) / payment.foodCharge;
                revenues[i] = itemGross - itemDiscount;
            } else {
                revenues[i] = itemGross;
            }
        }
        
        Report.BatchUpdateDishStats(dishCodes, revenues, orders);
        MANAGEMENT.UpdateTotalRevenueReport(block.timestamp, payment.total);
        MANAGEMENT.SortDishesWithOrderRange(0, 50);
        MANAGEMENT.UpdateRankDishes();
    }

    function _internalConfirmOrder(bytes32 orderId, ORDER_STATUS _status, address actor) internal {
        require(_status != ORDER_STATUS.CREATED, "can not turn back status");
        
        {
            SimpleCourse[] storage courses = mOrderIdToCourses[orderId];
            for (uint i = 0; i < courses.length; i++) {
                if(_status == ORDER_STATUS.KITCHEN_CONFIRMED) {
                    require(courses[i].status == COURSE_STATUS.PREPARING || courses[i].status == COURSE_STATUS.CANCELED, "Invalid status");
                } else if(_status == ORDER_STATUS.SERVED) {
                    require(courses[i].status == COURSE_STATUS.SERVED || courses[i].status == COURSE_STATUS.CANCELED, "Invalid status");
                }
            }
        }

        bytes32 sessionId = _updateOrderStatusInLists(orderId, _status, actor);
        
        if(_status == ORDER_STATUS.KITCHEN_CONFIRMED){
            _internalAcknowledgeOrder(orderId, actor); 
        }

        {
            PaymentInformation storage pInfo = mIdToPaymentInformation[mOrderIdToPaymentId[orderId]];
            if(_status == ORDER_STATUS.SERVED && pInfo.typePayment == PaymentType.PREPAID) {
                
                Payment storage payment = mIdToPayment[mOrderIdToPaymentId[orderId]];

                // Xử lý Points
                if (paymentPointsUsed[payment.id] > 0 && address(POINTS) != address(0) && pInfo.customer != address(0)) {
                    POINTS.confirmLockedPoints(pInfo.customer, payment.id, payment.total, MANAGEMENT.branchId());
                }

                // Xử lý Staff
                for (uint i = 0; i < payment.orderIds.length; i++) {
                    address primaryStaff = orderPrimaryStaff[payment.orderIds[i]];
                    if (primaryStaff != address(0)) {
                        _removeFromStaffActiveOrders(primaryStaff, payment.orderIds[i]);
                    }
                }
                
                Report.UpdateDailyStats(block.timestamp/86400, payment.foodCharge, 1);
                if(iqrAgentSC != address(0)) {
                    createOrderDataForAgentManagement(payment.id, payment.foodCharge);
                }

                // Gọi hàm báo cáo đã tách ở trên
                _handleOrderReporting(payment, sessionId);
            }
        }
        
        emit OrderConfirmed(sessionId, orderId);
    }

    // Hàm phụ để cập nhật trạng thái đơn hàng (giúp giảm biến cho hàm chính)
    function _updateOrderStatusInLists(bytes32 orderId, ORDER_STATUS _status, address actor) internal returns (bytes32 sessionId) {
        bool found = false;
        for (uint i = 0; i < allOrders.length; i++) {
            if (allOrders[i].id == orderId) {
                if(_status == ORDER_STATUS.KITCHEN_CONFIRMED) require(allOrders[i].status == ORDER_STATUS.CREATED, "Confirmed");
                if(_status == ORDER_STATUS.SERVED) require(allOrders[i].status != ORDER_STATUS.SERVED, "Finished");
                
                allOrders[i].status = _status;
                mOrderIdToOrder[orderId].status = _status;
                sessionId = allOrders[i].sessionId;
                found = true;

                _addOrderHistory(orderId, 
                    (_status == ORDER_STATUS.KITCHEN_CONFIRMED) ? HistoryAction.ORDER_CONFIRMED : HistoryAction.ORDER_FINISHED, 
                    actor, 
                    (_status == ORDER_STATUS.KITCHEN_CONFIRMED) ? unicode"Đã xác nhận" : unicode"Hoàn thành", 
                    address(0)
                );
                break;
            }
        }
        require(found, "Order not found");

        Order[] storage tOrders = sessionOrders[sessionId];
        for (uint j = 0; j < tOrders.length; j++) {
            if (tOrders[j].id == orderId) {
                tOrders[j].status = _status;
                break;
            }
        }
    }
    

    
    function makeOrder(
        MakeOrderParams calldata orderData
    ) external returns (bytes32 orderId) {
        orderId = _makeOrderForGuestOrStaff(orderData,unicode"Đơn hàng mới được tạo", "customer");
    }
    
    function staffCreateOrderForGuest(
       MakeOrderParams calldata orderData
    ) external onlyStaff returns (bytes32 orderId) {
        orderId = _makeOrderForGuestOrStaff(orderData,unicode"Nhân viên lên đơn hộ khách hàng", "staff");
    }

    function _makeOrderForGuestOrStaff(
        MakeOrderParams calldata orderData,
        string memory details,
        string memory orderedBy
    ) internal returns (bytes32 orderId) {
        require(orderData.dishCodes.length == orderData.quantities.length, "Len mismatch");
        require(orderData.dishCodes.length == orderData.dishSelectedOptions.length, "Option mismatch");

        orderId = keccak256(abi.encodePacked(orderData.sessionId, block.timestamp, orderData.dishCodes.length));
        
        {
            Order memory order = Order({
                id: orderId,
                sessionId: orderData.sessionId,
                createdAt: block.timestamp,
                status: ORDER_STATUS.CREATED
            });

            mSessionToOrderIds[orderData.sessionId].push(orderId);
            mOrderIdToOrder[orderId] = order;
            sessionOrders[orderData.sessionId].push(order);
            allOrders.push(order);
        }

        uint256 totalPrice = _processCourses(
            orderData.sessionId, 
            orderId, 
            orderData.dishCodes, 
            orderData.quantities, 
            orderData.notes, 
            orderData.variantIDs, 
            orderData.dishSelectedOptions
        );
        
        _createOrUpdatePayment(orderData.sessionId, orderId, totalPrice, orderData.paymentType);
        
        emit OrderMade(orderData.table, orderData.sessionId, orderId, orderData.dishCodes.length);

        _handleOrderPostLogic(orderId, orderData, details, orderedBy);

        return orderId;
    }

    function _handleOrderPostLogic(
        bytes32 orderId, 
        MakeOrderParams memory orderData,
        string memory details, 
        string memory orderedBy
    ) internal {
        if (keccak256(bytes(orderedBy)) == keccak256(bytes("customer"))) {
            string memory historyNote = bytes(details).length > 0 ? details : unicode"Đơn hàng mới được tạo";
            _addOrderHistory(orderId, HistoryAction.ORDER_CREATED, msg.sender, historyNote, address(0));
            

            MANAGEMENT.GetActiveStaffAddressesByDate(block.timestamp);
        } else {

            _internalBatchUpdateCourseStatus(orderData.sessionId, orderId, COURSE_STATUS.PREPARING);
            _internalConfirmOrder(orderId, ORDER_STATUS.KITCHEN_CONFIRMED, msg.sender);
        }
    }


    // function executeOrder(
    //     bytes32 sessionId,
    //     bytes32 paymentId,
    //     string memory discountCode,
    //     uint tip,
    //     uint256 paymentAmount,
    //     string memory txID,
    //     bool usePoint
    // ) external whenNotPaused nonReentrant returns (bool) {
    //     Payment storage payment = mIdToPayment[paymentId];
    //     require(payment.id != bytes32(0), "Payment not found"); 
    //     require(payment.status == PAYMENT_STATUS.CREATED, "Invalid payment status");

    //     _internalHandleFinancials(payment, sessionId, tip, discountCode);


    //     {
    //         uint256 remainingAmount = payment.total;
    //         PaymentInformation storage pInfo = mIdToPaymentInformation[paymentId];

    //         if (usePoint && address(POINTS) != address(0)) {
    //             (uint256 pUsed, , uint256 rem) = _processPointPayment(
    //                 msg.sender, payment.total, payment.id, pInfo.typePayment
    //             );
    //             paymentPointsUsed[payment.id] = pUsed;
    //             remainingAmount = rem;
    //             // Emit ngay để giải phóng bộ nhớ
    //             emit PaymentWithPoints(payment.id, msg.sender, pUsed, 0, rem); 
    //         }

    //         if (remainingAmount > 0) {
    //             _verifyExternalPayment(payment, txID, remainingAmount, paymentAmount, usePoint);
    //         } else {
    //             payment.method = "POINTS";
    //         }

    //         pInfo.customer = msg.sender;
    //         paymentInfoHistory.push(pInfo);


    //     }

    //     payment.status = PAYMENT_STATUS.PAID;
    //     payment.createdAt = block.timestamp;
    //     paymentHistory.push(payment);

    //     // 4. Báo cáo & Hoàn tất
    //     _internalPostExecution(paymentId, sessionId);

    //     return true;
    // }

    function executeOrder(
        bytes32 sessionId,
        bytes32 paymentId,
        string calldata discountCode, 
        uint tip,
        uint256 paymentAmount,
        string calldata txID,
        bool usePoint
    ) external whenNotPaused nonReentrant returns (bool) {
        Payment storage payment = mIdToPayment[paymentId];
        require(payment.id != bytes32(0), "Payment not found"); 
        require(payment.status == PAYMENT_STATUS.CREATED, "Invalid payment status");

        _internalHandleFinancials(payment, sessionId, tip, discountCode);

        _handlePaymentFlow(payment, paymentAmount, txID, usePoint);

        payment.status = PAYMENT_STATUS.PAID;
        payment.createdAt = block.timestamp;
        
        paymentHistory.push(payment);

        _internalPostExecution(paymentId, sessionId);

        return true;
    }

    function _handlePaymentFlow(
        Payment storage payment,
        uint256 paymentAmount,
        string calldata txID,
        bool usePoint
    ) private {
        uint256 remainingAmount = payment.total;
        PaymentInformation storage pInfo = mIdToPaymentInformation[payment.id];

        if (usePoint && address(POINTS) != address(0)) {
            (uint256 pUsed, , uint256 rem) = _processPointPayment(
                msg.sender, payment.total, payment.id, pInfo.typePayment
            );
            paymentPointsUsed[payment.id] = pUsed;
            remainingAmount = rem;
            emit PaymentWithPoints(payment.id, msg.sender, pUsed, 0, rem); 
        }

        if (remainingAmount > 0) {
            _verifyExternalPayment(payment, txID, remainingAmount, paymentAmount, usePoint);
        } else {
            payment.method = "POINTS";
        }

        pInfo.customer = msg.sender;
        paymentInfoHistory.push(pInfo);
    }


    function _internalHandleFinancials(
        Payment storage payment,
        bytes32 sessionId,
        uint256 tip,
        string memory discountCode
    ) internal {
        {
            Reservation storage res = mIdToReservations[mIdToSession[sessionId].reservationId];
            // bytes32 customerGroup = (address(POINTS) != address(0)) ? POINTS.getMemberToGroups(msg.sender) : bytes32(0);
            uint discountAmount;
            if (address(POINTS) != address(0)) {
                bytes32[] memory customerGroup = POINTS.getMemberToGroups(msg.sender);
                discountAmount = _applyDiscount(payment, discountCode, customerGroup);
            } else {
                bytes32[] memory customerGroup = new bytes32[](0);
                discountAmount = _applyDiscount(payment, discountCode, customerGroup);
            }

            // payment.discountAmount = _applyDiscount(payment, discountCode, customerGroup);
            payment.discountAmount = discountAmount;
            payment.discountCode = discountCode;
            payment.tip = tip;

            uint256 billTotal = payment.foodCharge + payment.tax + tip - payment.discountAmount;
            
            uint256 availableDeposit = 0;
            if (res.depositAmount > (res.penaltyFee + res.refund + res.invoiceDeductedAmount)) {
                availableDeposit = res.depositAmount - res.penaltyFee - res.refund - res.invoiceDeductedAmount;
            }

            uint256 actualDeduction = (availableDeposit > billTotal) ? billTotal : availableDeposit;
            payment.total = billTotal - actualDeduction;
            res.invoiceDeductedAmount += actualDeduction;
        }
    }

    function _verifyExternalPayment(
        Payment storage payment,
        string memory txID,
        uint256 remainingAmount,
        uint256 paymentAmount,
        bool usePoint
    ) internal {
        if (bytes(txID).length != 0) {
            require(!usedTxIds[txID], "Tx used");
            {
                TransactionStatus memory ts = ICARD_VISA.getTx(txID);
                require(ts.status == TxStatus.SUCCESS, "Tx fail");
            }
            {
                PoolInfo memory pool = ICARD_VISA.getPoolInfo(txID);
                require(pool.ownerPool == merchant, "Merchant mismatch");
                require(pool.parentValue >= remainingAmount, "Amount mismatch");
            }
            usedTxIds[txID] = true;
            payment.method = usePoint ? "VISA + POINTS" : "VISA";
        } else {
            require(paymentAmount >= remainingAmount, "Insufficient cash");
            payment.method = usePoint ? "CASH + POINTS" : "CASH";
        }
    }

    function _internalPostExecution(bytes32 paymentId, bytes32 sessionId) internal {
        if (address(POINTS) != address(0) && POINTS.isMemberPointSystem(msg.sender)) {
            POINTS.updateLastBuyActivityAt(msg.sender);
        }

        if (mIdToPaymentInformation[paymentId].typePayment == PaymentType.POSTPAID) {
            _handleOrderReporting(mIdToPayment[paymentId], sessionId);
        }
        
        emit PaymentMade(sessionId, paymentId, mIdToPayment[paymentId].total);
    }


    function staffExecuteOrderCash(
        bytes32 sessionId,
        bytes32 paymentId,
        string calldata discountCode, 
        uint tip,
        uint256 paymentAmount,
        bool usePoint,
        address customer
    ) external onlyStaff whenNotPaused nonReentrant returns (bool) {
        Payment storage payment = mIdToPayment[paymentId];
        require(payment.id != bytes32(0), "No active invoice");
        require(payment.status == PAYMENT_STATUS.CREATED, "Invalid payment status");
        
        _internalHandleFinancialsForStaff(payment, sessionId, tip, discountCode, customer);

        PaymentType pType = _staffExecuteCashHelper(payment, paymentAmount, usePoint, customer);

        payment.status = PAYMENT_STATUS.PAID;
        payment.createdAt = block.timestamp;
        paymentHistory.push(payment);

        if (pType == PaymentType.POSTPAID) {
            _handleOrderReporting(payment, sessionId);
        }

        emit PaymentMade(sessionId, paymentId, payment.total);
        return true;
    }

    function _staffExecuteCashHelper(
        Payment storage payment,
        uint256 paymentAmount,
        bool usePoint,
        address customer
    ) private returns (PaymentType) {
        uint256 reqAmount = payment.total;
        PaymentInformation storage pInfo = mIdToPaymentInformation[payment.id];
        PaymentType pType = pInfo.typePayment;

        if (customer != address(0)) {
            if (usePoint && address(POINTS) != address(0)) {
                (uint256 pUsed, uint256 pValue, uint256 rem) = _processPointPayment(
                    customer, reqAmount, payment.id, pType
                );
                paymentPointsUsed[payment.id] = pUsed;
                reqAmount = rem;
                emit PaymentWithPoints(payment.id, customer, pUsed, pValue, rem);
            }

            pInfo.customer = customer;
            if (address(POINTS) != address(0) && POINTS.isMemberPointSystem(customer)) {
                POINTS.updateLastBuyActivityAt(customer);
            }
        }

        require(paymentAmount >= reqAmount, "Insufficient cash");
        payment.method = (usePoint && customer != address(0)) ? "CASH + POINTS" : "CASH";
        paymentInfoHistory.push(pInfo);

        return pType;
    }

    function _internalHandleFinancialsForStaff(
        Payment storage payment,
        bytes32 sessionId,
        uint256 tip,
        string memory discountCode,
        address customer
    ) internal {
        {
            Reservation storage res = mIdToReservations[mIdToSession[sessionId].reservationId];
            
            uint256 discountAmount = 0;
            if (customer != address(0) && address(POINTS) != address(0)) {
                bytes32[] memory  customerGroup = POINTS.getMemberToGroups(customer);
                discountAmount = _applyDiscount(payment, discountCode, customerGroup);
            }else {
                bytes32[] memory customerGroup = new bytes32[](0);
                discountAmount = _applyDiscount(payment, discountCode, customerGroup);
            }

            payment.tip = tip;
            payment.discountAmount = discountAmount;
            payment.discountCode = discountCode;

            uint256 grossTotal = payment.foodCharge + payment.tax + tip - discountAmount;
            
            uint256 availableDeposit = 0;
            if (res.depositAmount > (res.penaltyFee + res.refund + res.invoiceDeductedAmount)) {
                availableDeposit = res.depositAmount - res.penaltyFee - res.refund - res.invoiceDeductedAmount;
            }

            uint256 actualDeduction = (availableDeposit > grossTotal) ? grossTotal : availableDeposit;
            payment.total = grossTotal - actualDeduction;
            res.invoiceDeductedAmount += actualDeduction;
        }
    }
    
    // function confirmPayment(
    //     uint table,
    //     bytes32 paymentId,
    //     string memory reason
    // ) external onlyStaff returns (bool) {
    //     Payment storage payment = mIdToPayment[paymentId];
    //     require(payment.status == PAYMENT_STATUS.PAID, "Payment not paid");
        
    //     payment.status = PAYMENT_STATUS.CONFIRMED_PAID;     
    //     PaymentType pType;
    //     {
    //         PaymentInformation storage pInfo = mIdToPaymentInfo[paymentId];
    //         pInfo.staffConfirm = msg.sender;
    //         pInfo.reasonConfirm = reason;
    //         pType = pInfo.typePayment;
    //     }
        
    //     // 1. Xử lý tập trung cho danh sách đơn hàng (Order IDs)
    //     {
    //         bytes32[] memory orderIds = payment.orderIds;
    //         bool isPostpaid = (pType.typePayment == PaymentType.POSTPAID);
            
    //         for (uint i = 0; i < orderIds.length; i++) {
    //             bytes32 currentOrderId = orderIds[i];

    //             // Nếu là trả sau: Xóa khỏi danh sách active của Staff
    //             if (isPostpaid) {
    //                 address primaryStaff = orderPrimaryStaff[currentOrderId];
    //                 if (primaryStaff != address(0)) {
    //                     _removeFromStaffActiveOrders(primaryStaff, currentOrderId);
    //                 }
    //             }

    //             _addOrderHistory(currentOrderId, HistoryAction.PAYMENT_COMPLETED, msg.sender, unicode"Thanh toán thành công", address(0));
    //         }
    //     }

    //     if (pType.typePayment == PaymentType.POSTPAID) {
    //         _clearTable(table, payment.sessionId);
    //         Report.UpdateDailyStats(block.timestamp / 86400, payment.foodCharge, 1);
            
    //         if (iqrAgentSC != address(0)) {
    //             createOrderDataForAgentManagement(paymentId, payment.foodCharge);
    //         }
    //     }
        
    //     emit PaymentConfirmed(paymentId, msg.sender);
    //     return true;
    // }

    function confirmPayment(
        uint table,
        bytes32 paymentId,
        string calldata reason 
    ) external onlyStaff returns (bool) {
        Payment storage payment = mIdToPayment[paymentId];
        require(payment.status == PAYMENT_STATUS.PAID, "Payment not paid");
        
        payment.status = PAYMENT_STATUS.CONFIRMED_PAID;
        
        PaymentInformation storage pInfo = mIdToPaymentInformation[paymentId];
        pInfo.staffConfirm = msg.sender;
        pInfo.reasonConfirm = reason;

        _processOrderIds(payment.orderIds, pInfo.typePayment == PaymentType.POSTPAID);

        if (pInfo.typePayment == PaymentType.POSTPAID) {
            _handlePostpaidCompletion(table, paymentId, payment.sessionId, payment.foodCharge);
        }
        
        emit PaymentConfirmed(paymentId, msg.sender);
        return true;
    }

    function _processOrderIds(bytes32[] storage orderIds, bool isPostpaid) internal {
        for (uint i = 0; i < orderIds.length; i++) {
            if (isPostpaid) {
                address primaryStaff = orderPrimaryStaff[orderIds[i]];
                if (primaryStaff != address(0)) {
                    _removeFromStaffActiveOrders(primaryStaff, orderIds[i]);
                }
            }
            _addOrderHistory(orderIds[i], HistoryAction.PAYMENT_COMPLETED, msg.sender, unicode"Thanh toán thành công", address(0));
        }
    }

    function _handlePostpaidCompletion(uint table, bytes32 paymentId, bytes32 sessionId, uint256 foodCharge) internal {
        _clearTable(table, sessionId);
        Report.UpdateDailyStats(block.timestamp / 86400, foodCharge, 1);
        
        if (iqrAgentSC != address(0)) {
            createOrderDataForAgentManagement(paymentId, foodCharge);
        }
    }

    // Added 26/01/2026 nhân viên đóng session cho khách
    
    function closeSessionByStaff(uint table, bytes32 sessionId) external onlyStaff returns (bool) {
        _clearTable(table, sessionId);
        return true;
    }

     // Added 22/01/2026 Xử lý khách tới trễ/hủy bàn 

    function handleNoShow(uint[] calldata _table,bytes32 sessionId ,bytes32 reservationId, bool isCancel) external onlyStaff {
        Reservation storage res = mIdToReservations[reservationId];
        
        require(!res.isCheckIn, "The guests have arrived.");
        uint256 deadline = res.reservationTime + (currentReservationRule.gracePeriod * 1 minutes);
        require(block.timestamp > deadline, "The allotted time for late arrivals has not yet expired.");

        uint256 deposit = res.depositAmount;

        uint256 penalty = (res.depositAmount * currentReservationRule.penaltyPercent) / 100;
        uint256 refund = deposit - penalty;

        res.penaltyFee = penalty;
        res.refund = refund;
        res.isCheckIn = true;
        // res.depositAmount = 0;
        if(isCancel) {
            MANAGEMENT.separateTables(_table);  
        }
        
        emit NoShowHandled(_table, sessionId, reservationId, isCancel, block.timestamp);
    }

    // Xác nhận khách đến nhận bàn
    function handleCustomerCheckIn(uint[] calldata _table,bytes32 sessionId ,bytes32 reservationId) external onlyStaff {
        Reservation storage res = mIdToReservations[reservationId];
        
        require(!res.isCheckIn, "The guests have arrived.");

        res.isCheckIn = true;
        // res.depositAmount = 0;
        
        emit CustomerCheckIn(_table, sessionId, reservationId, block.timestamp);
    }

    //Đặt bàn trước
    function reserveTable(uint256 _time, uint256 _deposit, string calldata _name, string calldata _phone ,uint256 _numPeople, bool _isConfirm) external {
        require(_time > block.timestamp, "The time must be set in the future.");
        require(_deposit >= currentReservationRule.minDeposit, "Deposit not enough.");
        require(_numPeople >= 0, "The number of guests must be greater than 0.");
      // Table storage table = mTableToSession[_tableId];
      // uint256 sessionId = _createNewSession(_tableId, _numPeople, _type);

        bytes32 newReservationId = keccak256(abi.encodePacked(
            block.timestamp, 
            _name, 
            _phone,
            _time
        ));

        mIdToReservations[newReservationId] = Reservation({
            reservationId: newReservationId,
            reservationTime: _time,
            depositAmount: _deposit,
            name: _name,
            phone: _phone,
            numPeople: _numPeople,
            customerType: _numPeople == 1 ? CustomerType.SINGLE : _numPeople == 2 ? CustomerType.COUPLE : CustomerType.GROUP,
            // appliedGracePeriod: currentReservationRule.gracePeriod,
            // appliedPenaltyPercent: currentReservationRule.penaltyPercent,
            isCheckIn: false,
            penaltyFee: 0,
            refund: 0,
            invoiceDeductedAmount: 0,
            remainingDeposit: _deposit,
            isConfirm: _isConfirm,
            isCancel: false
        });
        allReservationIds.push(newReservationId);
        if(!MANAGEMENT.isStaff(msg.sender)) customerReservations[msg.sender].push(newReservationId);
        emit TableReserved(newReservationId, _deposit , _time);
    }

    function getAllReservationsByPage(uint256 page, uint256 limit) 
        external 
        view 
        returns (Reservation[] memory) 
    {
        require(page > 0, "The page must be bigger 0");
        uint256 total = allReservationIds.length;
        uint256 offset = (page - 1) * limit;

        if (total == 0 || offset >= total) {
            return new Reservation[](0);
        }

        uint256 count = limit;
        if (offset + limit > total) {
            count = total - offset;
        }

        Reservation[] memory results = new Reservation[](count);

        for (uint256 i = 0; i < count; i++) {
            bytes32 id = allReservationIds[total - 1 - offset - i];
            results[i] = mIdToReservations[id];
        }

        return results;
    }


    function updateReservation(
        bytes32 _reservationId, 
        uint256 _newTime, 
        uint256 _newNumPeople,
        string calldata _newName,
        string calldata _newPhone
    ) external {
        Reservation storage res = mIdToReservations[_reservationId];

        require(res.reservationTime > 0, "Reservation does not exist.");
        require(!res.isCancel, "Cannot update a cancelled reservation.");
        require(!res.isCheckIn, "Already checked in, cannot update.");
        if(!MANAGEMENT.isStaff(msg.sender)) require(!res.isConfirm, "Already confirmed.");
        
        require(_newTime > block.timestamp, "New time must be in the future.");

        res.reservationTime = _newTime;
        res.numPeople = _newNumPeople;
        res.name = _newName;
        res.phone = _newPhone;

        res.customerType = _newNumPeople == 1 ? CustomerType.SINGLE : 
                        _newNumPeople == 2 ? CustomerType.COUPLE : 
                        CustomerType.GROUP;

        emit ReservationUpdated(_reservationId, _newTime, _newNumPeople);
    }


    function cancelReservation(bytes32 _reservationId) external {
        Reservation storage res = mIdToReservations[_reservationId];
        
        require(res.reservationTime > 0, "Reservation does not exist.");
        if(!MANAGEMENT.isStaff(msg.sender)) require(!res.isConfirm, "Already confirmed.");
        
        res.isCancel = true;
        
        // delete mIdToReservations[_reservationId];

        emit ReservationCancelled(_reservationId, block.timestamp);
    }



    function getReservationDetails(bytes32 _reservationId) external view returns (Reservation memory) {
        require(mIdToReservations[_reservationId].reservationTime > 0, "Reservation not found.");
        return mIdToReservations[_reservationId];
    }

    function getMyReservations() external view returns (bytes32[] memory) {
        return customerReservations[msg.sender];
    }

    // Tạo session cho khách
    function _createSession(uint256 _tableNumber, uint256 _numPeople,bytes32 _reservationId) internal returns(bytes32) {
        // Lấy thông tin bàn từ Management Contract
        Table memory table = MANAGEMENT.GetTable(_tableNumber);
        
        require(table.active, "Table service temporarily suspended.");
        require(
            // table.status != TABLE_STATUS.RESERVED && 
            table.status != TABLE_STATUS.FULL
            // && table.status != TABLE_STATUS.MERGED, 
            ,"That table is already full."
        );
        require(MANAGEMENT.isSessionAvailable(_tableNumber, _numPeople),"Not enough seats in the session.");

        bytes32 newSessionId = keccak256(abi.encodePacked(
            block.timestamp, 
            _tableNumber, 
            _numPeople,
            msg.sender
        ));

        Session memory session = Session({
            sessionId: newSessionId,
            tableId: table.number,
            customer: address(0),
            cType: _numPeople == 1 ? CustomerType.SINGLE : _numPeople == 2 ? CustomerType.COUPLE : CustomerType.GROUP,
            status: SESSION_STATUS.CREATED,
            seatUsed: _numPeople,
            creator: msg.sender,
            typeSession: SessionType.CREATED,
            reservationId: _reservationId
        });
        // if(_numPeople == table.numPeople) MANAGEMENT.mergeTables([_tableNumber], newSessionId, _numPeople,_status);
        // else 
        MANAGEMENT.updateTableFromOrder(_tableNumber, newSessionId, _numPeople);
        mTableToSessionIds[_tableNumber].push(newSessionId); 
        // mSessionToTable[newSessionId] = _tableNumber;
        mIdToSession[newSessionId] = session;

        emit SessionCreated(_tableNumber, newSessionId, _reservationId ,msg.sender);
        return newSessionId;
    }

    function _internalCreateSessionForReservation(uint256[] memory _tableNumber, uint256 _numPeople,bytes32 _reservationId, TABLE_STATUS _status) internal returns(bytes32) {
        // Lấy thông tin bàn từ Management Contract
        uint length = _tableNumber.length;
        for(uint i = 0; i <  length; i++)
        {
            Table memory table = MANAGEMENT.GetTable(_tableNumber[i]);
            
            require(table.active, "Table service temporarily suspended.");
            require(
                table.status != TABLE_STATUS.RESERVED && 
                table.status != TABLE_STATUS.FULL 
                && table.status != TABLE_STATUS.MERGED
                && table.status != TABLE_STATUS.MERGED_PARENT, 
                "That table is already full or reserved."
            );
        }
        

        bytes32 newSessionId = keccak256(abi.encodePacked(
            block.timestamp, 
            _tableNumber, 
            _numPeople,
            msg.sender
        ));

        Session memory session = Session({
            sessionId: newSessionId,
            tableId: _tableNumber[0],
            customer: address(0),
            cType: _numPeople == 1 ? CustomerType.SINGLE : _numPeople == 2 ? CustomerType.COUPLE : CustomerType.GROUP,
            status: SESSION_STATUS.CREATED,
            seatUsed: _numPeople,
            creator: msg.sender,
            typeSession: SessionType.CREATED,
            reservationId: _reservationId
        });
        MANAGEMENT.mergeTables(_tableNumber, newSessionId, _numPeople,_status);
        // for(i = 0; i <  length; i++)
        // {
        //     mTableToSessionsId[_tableNumber[i]].push(newSessionId); 
        //     mSessionToTable[newSessionId] = _tableNumber[i];
        // }
        // mIdToSession[newSessionId] = session;

        mTableToSessionIds[_tableNumber[0]].push(newSessionId); 
        // mSessionToTable[newSessionId] = _tableNumber[0];
        mIdToSession[newSessionId] = session;

        emit SessionReservationCreated(_tableNumber, newSessionId, _reservationId ,msg.sender);
        return newSessionId;
    }

    // Khóa bàn lại cho khách đặt trước
    function LockTableForReservation(uint[] calldata _table, uint256 _numPeople, bytes32 _reservationId) external onlyStaff {
        bytes32 sessionId = _internalCreateSessionForReservation(_table,_numPeople,_reservationId, TABLE_STATUS.RESERVED);
        mSessionToTableMerge[sessionId] =_table;
        emit LockTableSession(_table, sessionId, block.timestamp);
    }

    // merge table từ nhân viên
    function MergeTableByStaff(uint[] calldata _table, uint256 _numPeople, bytes32 _reservationId) external onlyStaff {
        bytes32 sessionId = _internalCreateSessionForReservation(_table,_numPeople,_reservationId, TABLE_STATUS.MERGED_PARENT);
        mSessionToTableMerge[sessionId] =_table;
        emit MergeTableFromStaff(_table, sessionId, block.timestamp);
    }

    // tách table từ nhân viên
    function SeparateTableByStaff(bytes32 sessionId) external onlyStaff {
        uint256[] memory _tableNumber = mSessionToTableMerge[sessionId];
        MANAGEMENT.separateTables(_tableNumber);
        delete mSessionToTableMerge[sessionId];
        emit SeparateTableFromStaff(_tableNumber, sessionId, block.timestamp);
    }

    // đổi session từ table này qua table khác
    function TransferTable(uint256 _fromTable, uint256 _toTable) external onlyStaff {
        MANAGEMENT.transferTable(_fromTable,_toTable);
        bytes32[] storage oldSessions = mTableToSessionIds[_fromTable];
        bytes32[] storage newSessions = mTableToSessionIds[_toTable];

        for (uint i = 0; i < oldSessions.length; i++) {
            bytes32 sId = oldSessions[i];
            
            newSessions.push(sId);

            uint256[] storage mergedTables = mSessionToTableMerge[sId];
            for (uint j = 0; j < mergedTables.length; j++) {
                if (mergedTables[j] == _fromTable) {
                    mergedTables[j] = _toTable; 
                    break; 
                }
            }
        }
        delete mTableToSessionIds[_fromTable];
    }

     // merge thêm table từ nhân viên
    function MergeMoreTableByStaff(uint[] calldata _table, uint256 _numPeople, bytes32 sessionId) external onlyStaff {
        uint256 tableNum = mIdToSession[sessionId].tableId;
        require(tableNum != 0, "Session not found");
        uint256[] storage mergedTables = mSessionToTableMerge[sessionId];
        for (uint256 i = 0; i < _table.length; i++) {
            mergedTables.push(_table[i]);
        }   

        MANAGEMENT.mergeMoreTables(_table,tableNum,_numPeople);
        emit MergeMoreTableFromStaff(_table,tableNum, sessionId, block.timestamp);
    }

    // Lấy sessionId từ các bàn merge
    function _getSessionIdFromtableMerge(uint256 _table) internal returns(bytes32) {
        return MANAGEMENT.checkSessionIdFromTableMerge(_table);
    }

    // Loại bỏ bớt bàn nếu merge quá bàn
    function RemoveSomeTablesFromSession(bytes32 sessionId, uint256[] calldata tablesToRemove) external onlyStaff {
        uint256[] storage mergedTables = mSessionToTableMerge[sessionId];
        require(mergedTables.length > 0, "This session has no merged tables");

        // Gọi Management để giải phóng các bàn về trạng thái AVAILABLE
        MANAGEMENT.removeTablesFromMerge(tablesToRemove);

        // Cập nhật mảng mSessionToTableMerge trong Order (Xóa các bàn đã chọn ra khỏi mảng)
        for (uint i = 0; i < tablesToRemove.length; i++) {
            _removeFromMergedArray(sessionId, tablesToRemove[i]);
        }

        emit SeparateTableFromStaff(tablesToRemove, sessionId, block.timestamp);
    }

    // Helper để xóa một phần tử cụ thể trong mảng động
    function _removeFromMergedArray(bytes32 sessionId, uint256 tableNum) internal {
        uint256[] storage tables = mSessionToTableMerge[sessionId];
        for (uint i = 0; i < tables.length; i++) {
            if (tables[i] == tableNum) {
                tables[i] = tables[tables.length - 1]; // Đổi chỗ với phần tử cuối
                tables.pop(); // Xóa phần tử cuối
                break;
            }
        }
    }

    function checkStatusTable(uint256 _tableNumber) external view returns(TABLE_STATUS) {
        Table memory table = MANAGEMENT.GetTable(_tableNumber);
        require(table.number > 0, "Table not found");
        return table.status;
    }

    function CreateSessionForTable(
        uint256 _tableNumber,
        uint256 _numPeople,
        bytes32 _reservationId
    ) external returns(bytes32 sessionId, bool isMerge)
     { 
        
        Table memory table = MANAGEMENT.GetTable(_tableNumber);
        require(table.number > 0, "Table not found");

        if(table.status == TABLE_STATUS.RESERVED || 
        table.status == TABLE_STATUS.MERGED_PARENT || 
        table.status == TABLE_STATUS.MERGED) 
        {
            sessionId = _getSessionIdFromtableMerge(_tableNumber);
            isMerge = true;
        } 
        else {
            sessionId = _createSession(_tableNumber, _numPeople, _reservationId);
            isMerge = false;
        }

        return (sessionId, isMerge);
    }
    
   function checkSessionTable(uint256 _tableNumber, bytes32 _sessionId) external view returns(bool) {
        Table memory table = MANAGEMENT.GetTable(_tableNumber);
        
        require(table.number > 0, "Table not found");

        bool hasSession = false;
        for (uint256 i = 0; i < table.sessionIds.length; i++) {
            if (table.sessionIds[i] == _sessionId) {
                hasSession = true;
                break;
            }
        }

        return hasSession;
    }


    function getSessionPayment(bytes32 sessionId, bytes32 paymentId) external view returns (Payment memory) {
        Payment[] storage payments = mSessionToPayment[sessionId];
        
        for (uint256 i = 0; i < payments.length; i++) {
            if (payments[i].id == paymentId) {
                return payments[i];
            }
        }
        revert("Payment not found");
    }

    function getSessionPaymentInfo(bytes32 sessionId, bytes32 paymentId) external view returns (PaymentInformation memory) {
        PaymentInformation[] storage payments = mSessionToPaymentInformation[sessionId];
        
        for (uint256 i = 0; i < payments.length; i++) {
            if (payments[i].id == paymentId) {
                return payments[i];
            }
        }
        revert("PaymentInfo not found");
    }

    function getPaymentByOrder(bytes32 orderId) external view returns (Payment memory) {
        bytes32 pId = mOrderIdToPaymentId[orderId];
        require(pId != bytes32(0), "Order not linked to any payment");
        return mIdToPayment[pId];
    }

    function getPaymentInfoByOrder(bytes32 orderId) external view returns (PaymentInformation memory) {
        bytes32 pId = mOrderIdToPaymentId[orderId];
        require(pId != bytes32(0), "Order not linked to any payment");
        return mIdToPaymentInformation[pId];
    }

    function getTableBySession(bytes32 sessionId) external view returns (uint256) {
        return mIdToSession[sessionId].tableId;
    }
}