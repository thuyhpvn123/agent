// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IRestaurant.sol";
import "./interfaces/IManagement.sol";
import "./interfaces/ITimeKeeping.sol";
import "./lib/DateTimeTZ.sol";
// import "forge-std/console.sol";
contract AttendanceSystem is 
    Initializable,
    OwnableUpgradeable, 
    // UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // Constants
    uint256 private constant SECONDS_PER_MINUTE = 60;
    uint256 private constant SECONDS_PER_HOUR = 3600;
    uint256 private constant HOURS_PER_DAY = 24;
    IManagement public managementContract;
  
    // Storage
    mapping(address => mapping(uint256 =>AttendanceRecord[])) public staffDailyAttendance; // staff => date => record
    mapping(uint256 => DailyReportHR) public dailyReports; // date => report
    mapping(uint256 => MonthlyReportHR) public monthlyReports; // month => report
    mapping(address => bool) public isStaffExists;
    mapping(address => mapping(uint256 => bool)) public isAttendanceRecorded;
    mapping(address => mapping(uint => uint)) public mLatestCheckinShift;
    mapping(address => mapping(uint => uint)) public mLatestCheckoutShift;

    // Tracking arrays
    uint256[] public reportedDates;
    uint256[] public reportedMonths;
    address[] public allStaffAddresses;
    int256 public TIMEZONE;
    // Counters
    uint256 public totalAttendanceRecords;    
    // Settings
    uint256 public standardWorkingHours; // in minutes (e.g., 480 for 8 hours)
    uint256 public lateThreshold; // in minutes (e.g., 15 minutes)
    uint256 public halfDayThreshold; // in minutes (e.g., 240 for 4 hours)
    address public BE;
    // bytes32 public ROLE_ADMIN;
    SettingAddress public settingAddress;
    uint256 public nextWorkPlaceId ;
    mapping(address =>ReportCheckinAccident[]) public mStaffToDateToIncidents;
    mapping( bytes32 => ReportCheckinAccident )public mIdToIncident;

    // Events 
    event CheckInRecorded(address indexed staff, uint256 date, uint256 time);
    event CheckOutRecorded(address indexed staff, uint256 date, uint256 time);
    event NotInPositionStartRecorded(address indexed staff, uint256 date, uint256 time);
    event NotInPositionEndRecorded(address indexed staff, uint256 date, uint256 time);
    event AttendanceStatusUpdated(address indexed staff, uint256 date, AttendanceStatus status, bool isLate, bool isHalfDay);
    event AttendanceDataSet(address indexed staff, uint256 date, AttendanceStatus status, ABSENT_TYPE absentType);
    event DailyReportUpdated(uint256 date);
    event MonthlyReportGenerated(uint256 month);
    
    // Reserve storage for upgradeability
    uint256[50] private __gap;
    
    // constructor() {
    //     _disableInitializers();
    // }
    
    function initialize(address _managementContract) public initializer {
        __Ownable_init(msg.sender);
        // __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        managementContract = IManagement(_managementContract);
        
        // Default settings
        standardWorkingHours = 480; // 8 hours
        lateThreshold = 15; // 15 minutes
        halfDayThreshold = 240; // 4 hours
        BE = msg.sender;
        TIMEZONE = 7; // VN
        nextWorkPlaceId = 1;
    }
    
    function setTimeZone(int _tz) public returns (int) {
        TIMEZONE = _tz;
        return TIMEZONE;
    }
    
    function getTimeZone() public view returns (int) {
        return TIMEZONE;
    }

    // function _authorizeUpgrade(address newImplementation) internal override  {}
    
    // Modifiers
    modifier onlyBE() {
        require(msg.sender == BE, "only BE can call");
        _;
    }
    modifier onlyBEOrRole(address user){
        require(msg.sender == BE || user == msg.sender, "only BE or staff can call");
        _;
    }
    modifier onlyManagerOrHR() {
        require(
            managementContract.checkRole(STAFF_ROLE.STAFF_MANAGE, msg.sender),
            "Insufficient permissions"
        );
        _;
    }

    function setManagement(address _managementContract) external onlyOwner {
        managementContract = IManagement(_managementContract);
    }

    function setBE(address _BE) external onlyOwner {
        BE = _BE;
    }

    // Setting - Address
    function getSettingAddress() external view returns (SettingAddress memory) {
        return settingAddress;
    }

    function createSettingAddress(
        WorkPlace[] memory _workPlaces
    ) external onlyManagerOrHR returns (uint[] memory ids) {
        settingAddress.LastUpdate = block.timestamp;
        // delete settingAddress.WorkPlaces;
        ids = new uint[](_workPlaces.length);
        for (uint256 i = 0; i < _workPlaces.length; i++) {
            _workPlaces[i].WorkPlaceId = nextWorkPlaceId;
            settingAddress.WorkPlaces.push(_workPlaces[i]);
            ids[i]=_workPlaces[i].WorkPlaceId;
            nextWorkPlaceId++;
        }
        return ids;
    }
    function getWorkPlaceById(uint _workPlaceId) external view returns (WorkPlace memory) {
        for (uint256 i = 0; i < settingAddress.WorkPlaces.length; i++) {
            if (settingAddress.WorkPlaces[i].WorkPlaceId == _workPlaceId) {
                return settingAddress.WorkPlaces[i];
            }
        }
        revert("Workplace not found by id");
    }
    function updateWorkPlace(
        uint _workPlaceId,
        string memory _name,
        string memory _location,
        string memory _latLon
    ) external onlyManagerOrHR returns (bool) {
        for (uint256 i = 0; i < settingAddress.WorkPlaces.length; i++) {
            WorkPlace storage workplace = settingAddress.WorkPlaces[i];
            if (workplace.WorkPlaceId == _workPlaceId) {
                if(bytes(_name).length >0){
                    workplace.LocationName = _name;
                }
                if(bytes(_location).length >0){
                    workplace.LocationAddress = _location;
                }
                if(bytes(_latLon).length >0){
                    workplace.LatLon = _latLon;
                }
                settingAddress.LastUpdate = block.timestamp;
                return true;
            }
        }
        revert("Workplace not found by id");
    }

    function _workPlaceExistsRequire(
        WorkPlaceAttendance memory _workPlaceAttendance
    ) internal view {
        bool isExist = false;
        for (uint256 i = 0; i < settingAddress.WorkPlaces.length; i++) {
            if (
                settingAddress.WorkPlaces[i].WorkPlaceId ==
                _workPlaceAttendance.WorkPlaceId &&
                Strings.equal(
                    settingAddress.WorkPlaces[i].LatLon,
                    _workPlaceAttendance.LatLon
                )
            ) {
                isExist = true;
                break;
            }
        }
        require(
            isExist,
            '{"from": "Timekeeping.sol","msg": "Workplace not found by id and latlon"}'
        );
    }

    function _getShiftBasedOnCheckInTime(
        WorkingShift[] memory _shifts,
        uint _time //số s tính từ 0h 0m ngày hôm đó
    ) internal pure returns (WorkingShift memory shift) {
        for (uint i = 0; i < _shifts.length; i++) {
            if (_time >= _shifts[i].from && _time < _shifts[i].to) {
                return _shifts[i];
            }
        }
    }
    function approveIncident(
        bytes32 id,
        bool isApproved
    )external onlyManagerOrHR{
        ReportCheckinAccident storage incident  = mIdToIncident[id];
        require(incident.staff != address(0),"Incident not found");
        require(incident.approvedAt == 0,"Incident is already approved or denied");
        incident.approved = isApproved;
        incident.approvedAt = block.timestamp;
        ReportCheckinAccident[] storage arr = mStaffToDateToIncidents[incident.staff];
        for(uint i; i<arr.length; i++ ){
            if(arr[i].id == id){
                arr[i].approved = isApproved;
                arr[i].approvedAt = block.timestamp;
                break;
            }
        }
        if(incident.approved == true){
            _checkInOnBehalf(incident.staff,incident.workPlace,incident.createdAt);
        }else{
            (uint256 _yyyymmdd, ) = DateTimeTZ.getYYYYMMDDAndTime(
                incident.createdAt,
                TIMEZONE
            );
            AttendanceDataInput memory input = AttendanceDataInput({
                _staff : incident.staff,
                _date: _yyyymmdd,
                _status: AttendanceStatus.ABSENT,
                _absentType: ABSENT_TYPE.UNAUTHORIZED,
                _notes:"",
                approver:msg.sender
            });
            setAttendanceData(input);
        }
    }

    function ReportCheckin(
        address _staff,
        WorkPlaceAttendance memory _workPlace
    )external{
        _workPlaceExistsRequire(_workPlace);
        bytes32 id = keccak256(abi.encodePacked(_staff,block.timestamp));
        ReportCheckinAccident memory incident = ReportCheckinAccident({
                id: id,
                staff: _staff,
                workPlace: _workPlace,
                createdAt: block.timestamp,
                approved: false,
                approvedAt:0
            });
        mStaffToDateToIncidents[_staff].push(incident);
        mIdToIncident[id] = incident;
    }
    function getIncidentByStaffAndTime(
        address staff,
        uint from,
        uint to
    ) external view returns(ReportCheckinAccident[] memory) {
        ReportCheckinAccident[] storage allIncidents = mStaffToDateToIncidents[staff];
        
        // Đếm số lượng incidents trong khoảng thời gian
        uint count = 0;
        for(uint i = 0; i < allIncidents.length; i++) {
            if(allIncidents[i].createdAt >= from && allIncidents[i].createdAt <= to) {
                count++;
            }
        }
        
        // Tạo mảng kết quả với đúng kích thước
        ReportCheckinAccident[] memory result = new ReportCheckinAccident[](count);
        
        // Lọc và thêm vào mảng kết quả
        uint index = 0;
        for(uint i = 0; i < allIncidents.length; i++) {
            if(allIncidents[i].createdAt >= from && allIncidents[i].createdAt <= to) {
                result[index] = allIncidents[i];
                index++;
            }
        }
        
        return result;
    }    
    function checkIn(
        address _staff,
        WorkPlaceAttendance memory _workPlace
    ) external onlyBEOrRole(_staff) nonReentrant {
        _checkIn(_staff,_workPlace, block.timestamp);
    }
    function _checkInOnBehalf(
        address _staff,
        WorkPlaceAttendance memory _workPlace,
        uint createdAt
    ) internal  {
        _checkIn(_staff,_workPlace, createdAt);
    }
   
    // Updated Core Attendance Functions
    function _checkIn(
        address _staff,
        WorkPlaceAttendance memory _workPlace,
        uint createdAt
    ) internal  {
        _workPlaceExistsRequire(_workPlace);
        (uint _yyyymmdd, uint _time) = DateTimeTZ.getYYYYMMDDAndTime(
            createdAt,
            TIMEZONE
        );
        uint256 currentTime = createdAt;
        WorkingShift[] memory shifts = managementContract.getWorkingShifts();
        WorkingShift memory shift = _getShiftBasedOnCheckInTime(shifts, _time);
        
        require(
            shift.shiftId != 0,
            '{"from": "Timekeeping.sol","msg": "Shift not found for the current time"}'
        );

        require(
            mLatestCheckinShift[_staff][_yyyymmdd] < shift.shiftId,
            '{"from": "Timekeeping.sol","msg": "Shift already checkin. Please double-check your current time"}'
        );

        require(
            mLatestCheckoutShift[_staff][_yyyymmdd] == 0 ||
                mLatestCheckoutShift[_staff][_yyyymmdd] + 1 <= shift.shiftId,
            '{"from": "Timekeeping.sol","msg": "Please complete the previous shift before checking in"}'
        );
        
        Staff memory staff = managementContract.GetStaffInfo(_staff);
        AttendanceRecord memory record;
        
        record.staffWallet = _staff;
        record.staffCode = staff.code;
        record.staffName = staff.name;
        record.date = _yyyymmdd;
        record.checkInTime = _time;
        record.status = AttendanceStatus.PRESENT;
        record.WorkPlaceAttendance = _workPlace;
        record.ShiftId = shift.shiftId;
        
        // Check if late
        if (_isLate(_time, shift)) {
            record.isLate = true;
            record.lateMinutes = _calculateLateMinutes(_time, shift);
        } else {
            record.isLate = false;
            record.lateMinutes = 0;
        }
        
        totalAttendanceRecords++;
        mLatestCheckinShift[_staff][_yyyymmdd] = shift.shiftId;
        staffDailyAttendance[_staff][_yyyymmdd].push(record);

        // Add staff to tracking if not already added
        _addStaffToTrackingInternal(_staff);
        isAttendanceRecorded[_staff][_yyyymmdd] = true;
        emit CheckInRecorded(_staff, _yyyymmdd, currentTime);
        emit AttendanceStatusUpdated(_staff, _yyyymmdd, record.status, record.isLate, record.isHalfDay);
        
        // Auto-update daily report
         _updateDailyReportOptimizedWithMonthly(_yyyymmdd, _staff);
    }
    
    function checkOut(
        address _staff,
        WorkPlaceAttendance memory _workPlace
    ) external onlyBEOrRole(_staff) nonReentrant {
        _workPlaceExistsRequire(_workPlace);
        uint256 currentTime = block.timestamp;
        (uint _yyyymmdd, uint _time) = DateTimeTZ.getYYYYMMDDAndTime(
            block.timestamp,
            TIMEZONE
        );
        WorkingShift[] memory shifts = managementContract.getWorkingShifts();
        WorkingShift memory shift = _getShiftBasedOnCheckInTime(shifts, _time);
        require(
            shift.shiftId != 0,
            '{"from": "Timekeeping.sol","msg": "Shift not found for the current checkout time"}'
        );

        require(
            mLatestCheckoutShift[_staff][_yyyymmdd] < shift.shiftId,
            '{"from": "Timekeeping.sol","msg": "Shift already checkout. Please double-check your current time"}'
        );

        require(
            mLatestCheckinShift[_staff][_yyyymmdd] > 0,
            '{"from": "Timekeeping.sol","msg": "No check-in record found for today. Please check in before checking out."}'
        );
        require(
            mLatestCheckinShift[_staff][_yyyymmdd] <= shift.shiftId,
            '{"from": "Timekeeping.sol","msg": "Invalid checkout. Please check in before checking out."}'
        );

        uint length = staffDailyAttendance[_staff][_yyyymmdd].length;
        AttendanceRecord storage record = staffDailyAttendance[_staff][_yyyymmdd][length-1];
        
        // Validate workplace consistency
        require(
            record.WorkPlaceAttendance.WorkPlaceId == _workPlace.WorkPlaceId,
            '{"from": "Timekeeping.sol","msg": "Checkout workplace must match checkin workplace"}'
        );
        
        record.checkOutTime = _time;
        uint256 totalMinutes;
        // Calculate working hours 
        if(record.checkOutTime > record.checkInTime){
            // Ca bình thường (không qua 00:00)
            totalMinutes = (record.checkOutTime - record.checkInTime) / SECONDS_PER_MINUTE;
        }else{
            // Ca qua đêm (checkOut < checkIn)
            uint256 midnightTime = (record.checkInTime / (HOURS_PER_DAY * SECONDS_PER_HOUR)) * 
                                  (HOURS_PER_DAY * SECONDS_PER_HOUR) + 
                                  (HOURS_PER_DAY * SECONDS_PER_HOUR);
            totalMinutes = (midnightTime - record.checkInTime + record.checkOutTime) / SECONDS_PER_MINUTE;
        }
        totalMinutes -= record.totalNotInPositionTime; // Subtract not in position time
        
        record.totalWorkingHours = totalMinutes / SECONDS_PER_MINUTE;
        
        // Determine if half day based on working hours
        if (totalMinutes <= halfDayThreshold) {
            record.isHalfDay = true;
        } else {
            record.isHalfDay = false;
        }
              
        mLatestCheckoutShift[_staff][_yyyymmdd] = record.ShiftId;
        isAttendanceRecorded[_staff][_yyyymmdd] = true;
        emit CheckOutRecorded(_staff, _yyyymmdd, currentTime);
        emit AttendanceStatusUpdated(_staff, _yyyymmdd, record.status, record.isLate, record.isHalfDay);

        // Auto-update daily report
        // _updateDailyReport(_yyyymmdd);
         _updateDailyReportOptimizedWithMonthly(_yyyymmdd, _staff);
    }
    
    function startNotInPosition(address staff) external onlyManagerOrHR {
        (uint256 _yyyymmdd, ) = DateTimeTZ.getYYYYMMDDAndTime(
            block.timestamp,
            TIMEZONE
        );
        uint256 currentTime = block.timestamp;
        
        uint length = staffDailyAttendance[staff][_yyyymmdd].length;
        AttendanceRecord storage record = staffDailyAttendance[staff][_yyyymmdd][length-1];
        require(record.checkInTime > 0, "Must check in first");
        
        // Add new not in position record
        record.notInPositionRecords.push(NotInPositionRecord({
            startTime: currentTime,
            endTime: 0,
            duration: 0
        }));
        
        emit NotInPositionStartRecorded(staff, _yyyymmdd, currentTime);
    }
    
    function endNotInPosition(address staff) external onlyManagerOrHR {
        (uint256 _yyyymmdd, ) = DateTimeTZ.getYYYYMMDDAndTime(
            block.timestamp,
            TIMEZONE
        );
        uint256 currentTime = block.timestamp;
        
        uint length = staffDailyAttendance[staff][_yyyymmdd].length;
        AttendanceRecord storage record = staffDailyAttendance[staff][_yyyymmdd][length-1];
        require(record.notInPositionRecords.length > 0, "No not in position record found");
        
        // Find the latest unclosed not in position record
        uint256 lastIndex = record.notInPositionRecords.length - 1;
        NotInPositionRecord storage lastRecord = record.notInPositionRecords[lastIndex];
        require(lastRecord.endTime == 0, "Latest not in position already ended");
        
        lastRecord.endTime = currentTime;
        lastRecord.duration = (currentTime - lastRecord.startTime) / SECONDS_PER_MINUTE; // in minutes
        
        // Update totals
        record.totalNotInPositionTime += lastRecord.duration;
        record.totalNotInPositionCount = record.notInPositionRecords.length;
        isAttendanceRecorded[staff][_yyyymmdd] = true;
        emit NotInPositionEndRecorded(staff, _yyyymmdd, currentTime);
        
        // Auto-update daily report
        // _updateDailyReport(_yyyymmdd);
         _updateDailyReportOptimizedWithMonthly(_yyyymmdd, staff);
    }
    // Updated BE Data Input Functions for ABSENT status
    function setAttendanceData(
        // address _staff,
        // uint256 _date,
        // AttendanceStatus _status,
        // ABSENT_TYPE _absentType,
        // string memory _notes,    
        // address approver
        AttendanceDataInput memory input
    ) internal {
        require(input._staff != address(0), "Invalid staff address");
        require(input._date > 0, "Invalid date");
        
        if (input._status == AttendanceStatus.ABSENT) {
            require(input._absentType == ABSENT_TYPE.VACATION || input._absentType == ABSENT_TYPE.UNAUTHORIZED, "Invalid absent type");
        }
        
        Staff memory staff = managementContract.GetStaffInfo(input._staff);
        AttendanceRecord memory record ;
        
        record.staffWallet = input._staff;
        record.staffCode = staff.code;
        record.staffName = staff.name;
        record.date = input._date;
        record.checkInTime = 0;
        record.checkOutTime = 0;
        record.status = input._status;
        record.absentType = input._absentType;
        record.notes = input._notes;
        record.isApproved = true;
        record.approvedBy = input.approver;
        record.approvedAt = block.timestamp;
        record.isLate = false; // Default for manual entries
        record.isHalfDay = false; // Default for manual entries
        staffDailyAttendance[input._staff][input._date].push(record);

        // // Add staff to tracking if not already added
        // _addStaffToTrackingInternal(input._staff);
        
        emit AttendanceDataSet(input._staff, input._date, input._status, input._absentType);
        isAttendanceRecorded[input._staff][input._date] = true;
        // Auto-update daily report
        // _updateDailyReport(input._date);
         _updateDailyReportOptimizedWithMonthly(input._date, input._staff);
    }
    // Hàm để rebuild daily report nếu cần (cho admin)
    function rebuildDailyReport(uint256 _date) external onlyManagerOrHR {
        delete dailyReports[_date];
        
        // Clear tracking
        // for (uint256 i = 0; i < allStaffAddresses.length; i++) {
        //     staffHasRecordOnDate[_date][allStaffAddresses[i]] = false;
        // }
        
        // Rebuild từ đầu
        for (uint256 i = 0; i < allStaffAddresses.length; i++) {
            address staff = allStaffAddresses[i];
            if (staffDailyAttendance[staff][_date][0].date > 0 || 
                staffDailyAttendance[staff][_date][0].staffWallet != address(0)) {
                _updateDailyReportOptimizedWithMonthly(_date, staff);
            }
        }
    }
    function setBulkAttendanceData(
        address[] memory _staffs,
        uint256[] memory _dates,
        AttendanceStatus[] memory _statuses,
        ABSENT_TYPE[] memory _absentTypes,
        string memory _notes,
        address approver
    ) external onlyManagerOrHR {
        require(_staffs.length == _dates.length && _dates.length == _statuses.length, "Array length mismatch");
        require(_statuses.length == _absentTypes.length, "Status and absent type array length mismatch");
        
        for (uint256 i = 0; i < _staffs.length; i++) {
            AttendanceDataInput memory input = AttendanceDataInput({
                _staff : _staffs[i],
                _date: _dates[i],
                _status: _statuses[i],
                _absentType:_absentTypes[i],
                _notes:_notes,
                approver:approver
            });

            setAttendanceData(input);
        }
    }
        
    // Updated View Functions - Individual Staff Daily Report
    function getStaffDailyReport(address _staff, uint256 _date) external view returns (AttendanceRecord[] memory records) {
       records = staffDailyAttendance[_staff][_date];
        
        // return StaffDailyReport({
        //     staffWallet: _staff,
        //     staffCode: record.staffCode,
        //     staffName: record.staffName,
        //     date: _date,
        //     checkInTime: record.checkInTime,
        //     checkOutTime: record.checkOutTime,
        //     lateMinutes: record.lateMinutes,
        //     isLate: record.isLate,
        //     isHalfDay: record.isHalfDay,
        //     totalWorkingHours: record.totalWorkingHours,
        //     totalNotInPositionTime: record.totalNotInPositionTime,
        //     totalNotInPositionCount: record.totalNotInPositionCount,
        //     notInPositionRecords: record.notInPositionRecords,
        //     status: record.status,
        //     absentType: record.absentType,
        //     notes: record.notes
        // });
    }
    
    function getAttendanceRecord(address _staff, uint256 _date) external view returns (AttendanceRecord[] memory) {
        return staffDailyAttendance[_staff][_date];
    }
    
    function getDailyReport(uint256 _date) external view returns (DailyReportHR memory) {
        return dailyReports[_date];
    }
    
    function getStaffMonthlyStats(uint256 _month, address _staff) external view returns (StaffMonthlyStats memory) {
        return monthlyReports[_month].staffStats[_staff];
    }
    
    function getStaffWorkingDays(uint256 _month, address _staff) external view returns (uint256[] memory) {
        return monthlyReports[_month].staffStats[_staff].workingDayArr;
    }
    
    function getStaffVacationDays(uint256 _month, address _staff) external view returns (uint256[] memory) {
        return monthlyReports[_month].staffStats[_staff].absentVacationDayArr;
    }
    
    function getStaffUnauthorizedDays(uint256 _month, address _staff) external view returns (uint256[] memory) {
        return monthlyReports[_month].staffStats[_staff].absentUnauthorizedDayArr;
    }
    
    function getStaffHalfDays(uint256 _month, address _staff) external view returns (uint256[] memory) {
        return monthlyReports[_month].staffStats[_staff].halfDayArr;
    }
    
    function getStaffLateDays(uint256 _month, address _staff) external view returns (uint256[] memory) {
        return monthlyReports[_month].staffStats[_staff].lateDayArr;
    }
    
    // function getNotInPositionRecords(address _staff, uint256 _date) external view returns (NotInPositionRecord[] memory) {
    //     return staffDailyAttendance[_staff][_date].notInPositionRecords;
    // }
    
    function getMonthlyReportStaffList(uint256 _month) external view returns (address[] memory) {
        return monthlyReports[_month].staffList;
    }
    
    function getStaffDayDetailsAMonth(address _staff, uint256 _month) external view returns (StaffDayDetail[][] memory) {
        uint256 year = _month / 100;
        uint256 monthNum = _month % 100;
        uint256 daysInMonth = _getDaysInMonth(year, monthNum);
        
        StaffDayDetail[][] memory details = new StaffDayDetail[][](daysInMonth);
        
        for (uint256 day = 1; day <= daysInMonth; day++) {
            uint256 date = _month * 100 + day;
            AttendanceRecord[] memory record = staffDailyAttendance[_staff][date];
            for(uint i; i<record.length; i++){
                StaffDayDetail[] memory detailInADay = new StaffDayDetail[](record.length);
                detailInADay[i] = StaffDayDetail({
                    date: date,
                    status: record[i].status,
                    absentType: record[i].absentType,
                    isLate: record[i].isLate,
                    isHalfDay: record[i].isHalfDay,
                    checkInTime: record[i].checkInTime,
                    checkOutTime: record[i].checkOutTime,
                    totalWorkingHours: record[i].totalWorkingHours,
                    notInPositionCount: record[i].totalNotInPositionCount,
                    totalNotInPositionTime: record[i].totalNotInPositionTime,
                    notes: record[i].notes,
                    lateMinutes: record[i].lateMinutes
                });
                details[day - 1][i]= detailInADay[i];
            }
            
        }
        
        return details;
    }
    
    // Helper function to format time as HH:MM
    function formatTime(uint256 timestamp) external pure returns (string memory) {
        if (timestamp == 0) return "00:00";
        
        uint256 _hours = (timestamp / 3600) % 24;
        uint256 _minutes = (timestamp % 3600) / 60;
        
        return string(abi.encodePacked(
            _hours < 10 ? "0" : "",
            Strings.toString(_hours),
            ":",
            _minutes < 10 ? "0" : "",
            Strings.toString(_minutes)
        ));
    }
    
    // // Updated Company Report Functions
    // /**
    //  * @dev Lấy danh sách báo cáo ngày của toàn công ty
    //  * @param _date Ngày cần lấy báo cáo (format YYYYMMDD)
    //  * @return Mảng CompanyDailySummary chứa thông tin của tất cả nhân viên
    //  */
    // function getCompanyDailyReport(uint256 _date) external view returns (CompanyDailySummary[] memory) {
    //     address[] memory allStaffs = allStaffAddresses;
        
    //     CompanyDailySummary[] memory companySummary = new CompanyDailySummary[](allStaffs.length);
        
    //     for (uint256 i = 0; i < allStaffs.length; i++) {
    //         Staff memory staff = managementContract.GetStaffInfo(allStaffs[i]);
    //         address staffWallet = staff.wallet;
    //         AttendanceRecord memory record = staffDailyAttendance[staffWallet][_date];
            
    //         companySummary[i] = CompanyDailySummary({
    //             staffName: staff.name,
    //             staffCode: staff.code,
    //             position: staff.position,
    //             workingHours: record.totalWorkingHours,
    //             lateCount: record.isLate ? 1 : 0
    //         });
    //     }
        
    //     return companySummary;
    // }

    // /**
    //  * @dev Lấy danh sách báo cáo tháng của toàn công ty
    //  * @param _month Tháng cần lấy báo cáo (format YYYYMM)
    //  * @return Mảng CompanyMonthlySummary chứa thông tin của tất cả nhân viên
    //  */
    // function getCompanyMonthlyReport(uint256 _month) external view returns (CompanyMonthlySummary[] memory) {
    //     Staff[] memory allStaffs = managementContract.GetAllStaffs();
    //     CompanyMonthlySummary[] memory companySummary = new CompanyMonthlySummary[](allStaffs.length);
        
    //     // Tính toán số ngày trong tháng và ngày hiện tại
    //     uint256 year = _month / 100;
    //     uint256 monthNum = _month % 100;
    //     uint256 daysInMonth = _getDaysInMonth(year, monthNum);
        
    //     // Lấy ngày hiện tại để xác định số ngày đã qua trong tháng
    //     uint256 currentDate = _getCurrentDate();
    //     uint256 currentYear = currentDate / 10000;
    //     uint256 currentMonth = (currentDate / 100) % 100;
    //     uint256 currentDay = currentDate % 100;
        
    //     // Xác định số ngày cần tính (đến ngày hiện tại hoặc hết tháng)
    //     uint256 daysToCount = daysInMonth;
    //     if (year == currentYear && monthNum == currentMonth) {
    //         daysToCount = currentDay;
    //     }
        
    //     for (uint256 i = 0; i < allStaffs.length; i++) {
    //         address staffWallet = allStaffs[i].wallet;
    //         uint256 workingDays = 0;
            
    //         // Đếm số ngày công từ đầu tháng đến ngày hiện tại
    //         for (uint256 day = 1; day <= daysToCount; day++) {
    //             uint256 date = _month * 100 + day;
    //             AttendanceRecord memory record = staffDailyAttendance[staffWallet][date];
                
    //             // Chỉ tính các ngày có status PRESENT
    //             if (record.date > 0 && record.status == AttendanceStatus.PRESENT) {
    //                 workingDays++;
    //             }
    //         }
            
    //         companySummary[i] = CompanyMonthlySummary({
    //             staffName: allStaffs[i].name,
    //             staffCode: allStaffs[i].code,
    //             position: allStaffs[i].position,
    //             workingDays: workingDays
    //         });
    //     }
        
    //     return companySummary;
    // }

    // /**
    //  * @dev Lấy danh sách báo cáo tháng với filter theo chức vụ
    //  * @param _month Tháng cần lấy báo cáo (format YYYYMM)
    //  * @param _position Chức vụ cần filter (để trống nếu muốn lấy tất cả)
    //  * @return Mảng CompanyMonthlySummary chứa thông tin của nhân viên theo chức vụ
    //  */
    // function getCompanyMonthlyReportByPosition(
    //     uint256 _month, 
    //     string memory _position
    // ) external view returns (CompanyMonthlySummary[] memory) {
    //     address[] memory allStaffs = allStaffAddresses;
        
    //     // Đếm số nhân viên phù hợp với filter
    //     uint256 matchingCount = 0;
    //     for (uint256 i = 0; i < allStaffs.length; i++) {
    //         Staff memory staff = managementContract.GetStaffInfo(allStaffs[i]);
    //         if (bytes(_position).length == 0 ||              
    //             Strings.equal(staff.position, _position)) {
    //             matchingCount++;
    //         }
    //     }
        
    //     CompanyMonthlySummary[] memory companySummary = new CompanyMonthlySummary[](matchingCount);
        
    //     // Tính toán số ngày trong tháng và ngày hiện tại
    //     uint256 year = _month / 100;
    //     uint256 monthNum = _month % 100;
    //     uint256 daysInMonth = _getDaysInMonth(year, monthNum);
        
    //     uint256 currentDate = _getCurrentDate();
    //     uint256 currentYear = currentDate / 10000;
    //     uint256 currentMonth = (currentDate / 100) % 100;
    //     uint256 currentDay = currentDate % 100;
        
    //     uint256 daysToCount = daysInMonth;
    //     if (year == currentYear && monthNum == currentMonth) {
    //         daysToCount = currentDay;
    //     }
        
    //     uint256 summaryIndex = 0;
    //     for (uint256 i = 0; i < allStaffs.length; i++) {
    //         Staff memory staff = managementContract.GetStaffInfo(allStaffs[i]);
    //         // Filter theo chức vụ
    //         if (bytes(_position).length > 0 && 
    //             !Strings.equal(staff.position, _position)) {
    //             continue;
    //         }
            
    //         address staffWallet = staff.wallet;
    //         uint256 workingDays = 0;
            
    //         // Đếm số ngày công
    //         for (uint256 day = 1; day <= daysToCount; day++) {
    //             uint256 date = _month * 100 + day;
    //             AttendanceRecord memory record = staffDailyAttendance[staffWallet][date];
                
    //             // Chỉ tính các ngày có status PRESENT
    //             if (record.date > 0 && record.status == AttendanceStatus.PRESENT) {
    //                 workingDays++;
    //             }
    //         }
            
    //         companySummary[summaryIndex] = CompanyMonthlySummary({
    //             staffName: staff.name,
    //             staffCode: staff.code,
    //             position: staff.position,
    //             workingDays: workingDays
    //         });
            
    //         summaryIndex++;
    //     }
        
    //     return companySummary;
    // }
    
    // Admin Functions
    function _addStaffToTrackingInternal(address _staffWallet) internal {
        // Add staff to tracking if not already added
        if (!isStaffExists[_staffWallet]) {
            allStaffAddresses.push(_staffWallet);
            isStaffExists[_staffWallet] = true;
        }
    }
    
    function updateSettings(
        uint256 _standardWorkingHours,
        uint256 _lateThreshold,
        uint256 _halfDayThreshold
    ) external onlyManagerOrHR {
        standardWorkingHours = _standardWorkingHours;
        lateThreshold = _lateThreshold;
        halfDayThreshold = _halfDayThreshold;
    }
    
    function updateManagementContract(address _newContract) external onlyManagerOrHR {
        managementContract = IManagement(_newContract);
    }
    
    // Internal Helper Functions
    function _getCurrentDate() internal view returns (uint256) {
        // Convert timestamp to YYYYMMDD format
        (uint256 yyyymmdd, ) = DateTimeTZ.getYYYYMMDDAndTime(block.timestamp, TIMEZONE);
        return yyyymmdd;
    }
    
    function _isLate(uint256 _checkInTime, WorkingShift memory _shift) internal view returns (bool) {
        uint256 shiftStartTime = _shift.from;
        return _checkInTime > (shiftStartTime + lateThreshold * SECONDS_PER_MINUTE);
    }
    
    function _calculateLateMinutes(uint256 _checkInTime, WorkingShift memory _shift) internal pure returns (uint256) {
        uint256 shiftStartTime = _shift.from;
        if (_checkInTime > shiftStartTime) {
            return (_checkInTime - shiftStartTime) / SECONDS_PER_MINUTE;
        }
        return 0;
    }
    
    function _getShiftById(WorkingShift[] memory _shifts, uint256 _shiftId) internal pure returns (WorkingShift memory) {
        for (uint256 i = 0; i < _shifts.length; i++) {
            if (_shifts[i].shiftId == _shiftId) {
                return _shifts[i];
            }
        }
        revert("Shift not found");
    }
    
    // Tối ưu hóa _updateDailyReport - chỉ tính toán lại staff có thay đổi
    function _updateDailyReportOptimized(uint256 _date, address _staff) internal {
        DailyReportHR storage report = dailyReports[_date];
        
        // Initialize report if new
        if (report.date == 0) {
            report.date = _date;
            reportedDates.push(_date);
            // Initialize counters
            report.totalStaff = 0;
            report.presentStaff = 0;
            report.absentStaff = 0;
            report.lateStaff = 0;
            report.vacationStaff = 0;
            report.unauthorizedStaff = 0;
            report.halfDayStaff = 0;
            report.totalWorkingHours = 0;
            report.totalNotInPositionCount = 0;
            report.totalLateMinutes = 0;
        }
            
        // Cập nhật thông tin cho staff cụ thể
        _updateStaffInDailyReport(_date, _staff, report);
        
        // Tính toán lại averages
        report.averageWorkingHours = report.totalStaff > 0 ? report.totalWorkingHours / report.totalStaff : 0;
        
        emit DailyReportUpdated(_date);
    }

    function _updateStaffInDailyReport(uint256 _date, address _staff, DailyReportHR storage report) internal {
        if (!isAttendanceRecorded[_staff][_date]) {
            // Staff chưa có record -> đếm riêng
            report.unrecordedStaff++;
            return;
        }
        AttendanceRecord[] memory records = staffDailyAttendance[_staff][_date];
        Staff memory staff = managementContract.GetStaffInfo(_staff);
        for(uint i; i<records.length;i++){
            AttendanceRecord memory record = records[i];
            bool found = false;
            for (uint256 i = 0; i < report.staffList.length; i++) {
                if (report.staffList[i].staffWallet == _staff) {
                    found = true;
                    // Trừ đi số liệu cũ trước khi cập nhật
                    if (report.staffList[i].status == AttendanceStatus.PRESENT) {
                        report.presentStaff--;
                        report.totalWorkingHours -= report.staffList[i].workingHours;
                        if (report.staffList[i].lateCount > 0) {
                            report.lateStaff--;
                            report.totalLateMinutes -= report.staffList[i].lateMinutes;
                        }
                        if (report.staffList[i].isHalfDay) {
                            report.halfDayStaff--;
                        }
                    } else if (report.staffList[i].status == AttendanceStatus.ABSENT) {
                        report.absentStaff--;
                        if (report.staffList[i].absentType == ABSENT_TYPE.VACATION) {
                            report.vacationStaff--;
                        } else if (report.staffList[i].absentType == ABSENT_TYPE.UNAUTHORIZED) {
                            report.unauthorizedStaff--;
                        }
                    }

                    // 👉 Cập nhật lại staffList[i] với dữ liệu mới
                    report.staffList[i] = DailyStaffSummary({
                        staffWallet: _staff,
                        staffCode: staff.code,
                        staffName: staff.name,
                        workingHours: record.totalWorkingHours,
                        lateCount: record.isLate ? 1 : 0,
                        lateMinutes: record.lateMinutes,
                        isHalfDay: record.isHalfDay,
                        checkInTime: record.checkInTime,
                        checkOutTime: record.checkOutTime,
                        status: record.status,
                        absentType: record.absentType
                    });

                    break;
                }
            }
        
            // Cập nhật staff list nếu chưa có
            if (!found) {
                report.staffList.push(DailyStaffSummary({
                    staffWallet: _staff,
                    staffCode: staff.code,
                    staffName: staff.name,
                    workingHours: record.totalWorkingHours,
                    lateCount: record.isLate ? 1 : 0,
                    isHalfDay: record.isHalfDay,
                    checkInTime: record.checkInTime,
                    checkOutTime: record.checkOutTime,
                    status: record.status,
                    absentType: record.absentType,
                    lateMinutes: record.lateMinutes
                }));
                report.totalStaff++;
            }
            // Nếu staff chưa có record => absent unauthorized
            if (record.status == AttendanceStatus.PRESENT) {
                report.presentStaff++;
                if (record.isLate) {
                    report.lateStaff++;
                    report.totalLateMinutes += record.lateMinutes;
                }
                if (record.isHalfDay) {
                    report.halfDayStaff++;
                }
                report.totalWorkingHours += record.totalWorkingHours;
                report.totalNotInPositionCount += record.totalNotInPositionCount;
            } 
            else if (record.status == AttendanceStatus.ABSENT) {
                report.absentStaff++;
                if (record.absentType == ABSENT_TYPE.VACATION) {
                    report.vacationStaff++;
                } else {
                    report.unauthorizedStaff++;
                }
            }

        }
    }
        
    // Hàm getStaffMonthlyReport thực tế (không cần generateMonthlyReport trước)
    function getStaffMonthlyReportRealtime(address _staff, uint256 _month) external view returns (StaffMonthlyReport memory) {
        require(_staff != address(0), "Invalid staff address");
        require(_month >= 202401 && _month <= 205012, "Invalid month format");
        Staff memory staffInfo = managementContract.GetStaffInfo(_staff);
        
        uint256 year = _month / 100;
        uint256 monthNum = _month % 100;
        require(monthNum >= 1 && monthNum <= 12, "Invalid month number");
        uint256 daysInMonth = _getDaysInMonth(year, monthNum);
        
        // Xác định số ngày cần tính (đến ngày hiện tại hoặc hết tháng)
        uint256 currentDate = _getCurrentDate();
        uint256 currentYear = currentDate / 10000;
        uint256 currentMonth = (currentDate / 100) % 100;
        uint256 currentDay = currentDate % 100;
        
        uint256 daysToCount = daysInMonth;
        if (year == currentYear && monthNum == currentMonth && currentDay > 1) {
            daysToCount = currentDay - 1 ; // Đến hết ngày hôm qua
        }
        
        // Dynamic arrays để lưu các ngày
        uint256[] memory tempWorkingDays = new uint256[](daysToCount);
        uint256[] memory tempVacationDays = new uint256[](daysToCount);
        uint256[] memory tempUnauthorizedDays = new uint256[](daysToCount);
        uint256[] memory tempHalfDays = new uint256[](daysToCount);
        uint256[] memory tempLateDays = new uint256[](daysToCount);
        
        uint256 workingCount = 0;
        uint256 vacationCount = 0;
        uint256 unauthorizedCount = 0;
        uint256 halfDayCount = 0;
        uint256 lateDayCount = 0;
        
        uint256 presentDays = 0;
        uint256 lateDays = 0;
        uint256 vacationDays = 0;
        uint256 unauthorizedDays = 0;
        uint256 halfDays = 0;
        uint256 totalWorkingHours = 0;
        uint256 totalNotInPositionCount = 0;
        uint256 totalNotInPositionTime = 0;
        
        // Duyệt qua các ngày để tính toán
        for (uint256 day = 1; day <= daysToCount; day++) {
            uint256 date = _month * 100 + day;
            // console.log("date:",date);
            AttendanceRecord[] memory records = staffDailyAttendance[_staff][date];
            // console.log("records.length:",records.length);
            for(uint i; i<records.length;i++){
                
                AttendanceRecord memory record = records[i];
                bool hasRecord = (record.date > 0 || record.staffWallet != address(0));
                if (!hasRecord) {
                    // Staff chưa có record -> đếm riêng
                    if((_isWorkingDay(date))){
                        // Không có record = vắng không phép
                        tempUnauthorizedDays[unauthorizedCount] = date;
                        unauthorizedCount++;
                        unauthorizedDays++;
                    }
                } else {
                    if (record.status == AttendanceStatus.PRESENT) {
                        tempWorkingDays[workingCount] = date;
                        workingCount++;
                        presentDays++;
                        
                        if (record.isLate) {
                            tempLateDays[lateDayCount] = date;
                            lateDayCount++;
                            lateDays++;
                        }
                        
                        if (record.isHalfDay) {
                            tempHalfDays[halfDayCount] = date;
                            halfDayCount++;
                            halfDays++;
                        }
                        
                        totalWorkingHours += record.totalWorkingHours;
                        totalNotInPositionCount += record.totalNotInPositionCount;
                        totalNotInPositionTime += record.totalNotInPositionTime;
                        
                    } else if (record.status == AttendanceStatus.ABSENT) {
                        if (record.absentType == ABSENT_TYPE.VACATION) {
                            tempVacationDays[vacationCount] = date;
                            vacationCount++;
                            vacationDays++;
                        } else if (record.absentType == ABSENT_TYPE.UNAUTHORIZED) {
                            tempUnauthorizedDays[unauthorizedCount] = date;
                            unauthorizedCount++;
                            unauthorizedDays++;
                        }
                    }
                }
            }
        }
        
        // Tạo arrays với kích thước chính xác
        uint256[] memory workingDayArr = new uint256[](workingCount);
        uint256[] memory vacationDayArr = new uint256[](vacationCount);
        uint256[] memory unauthorizedDayArr = new uint256[](unauthorizedCount);
        uint256[] memory halfDayArr = new uint256[](halfDayCount);
        uint256[] memory lateDayArr = new uint256[](lateDayCount);
        
        // Copy dữ liệu
        for (uint256 i = 0; i < workingCount; i++) {
            workingDayArr[i] = tempWorkingDays[i];
        }
        for (uint256 i = 0; i < vacationCount; i++) {
            vacationDayArr[i] = tempVacationDays[i];
        }
        for (uint256 i = 0; i < unauthorizedCount; i++) {
            unauthorizedDayArr[i] = tempUnauthorizedDays[i];
        }
        for (uint256 i = 0; i < halfDayCount; i++) {
            halfDayArr[i] = tempHalfDays[i];
        }
        for (uint256 i = 0; i < lateDayCount; i++) {
            lateDayArr[i] = tempLateDays[i];
        }
            
        // FIX: Calculate rates chỉ với working days
        uint256 totalWorkingDays = _countWorkingDaysInMonth(_month, daysToCount);
        uint256 attendanceRate = 0;
        uint256 punctualityRate = 0;
        
        if (totalWorkingDays > 0) {
            // Attendance rate = present days / total working days * 100
            attendanceRate = (presentDays * 100) / totalWorkingDays;
        }
        
        if (presentDays > 0) {
            punctualityRate = ((presentDays - lateDays) * 100) / presentDays;
        }        
        return StaffMonthlyReport({
            staffWallet: _staff,
            staffCode: staffInfo.code,
            staffName: staffInfo.name,
            month: _month,
            workingDayArr: workingDayArr,
            absentVacationDayArr: vacationDayArr,
            absentUnauthorizedDayArr: unauthorizedDayArr,
            halfDayArr: halfDayArr,
            lateDayArr: lateDayArr,
            presentDays: presentDays,
            lateDays: lateDays,
            vacationDays: vacationDays,
            unauthorizedDays: unauthorizedDays,
            halfDays: halfDays,
            totalWorkingHours: totalWorkingHours,
            totalNotInPositionCount: totalNotInPositionCount,
            totalNotInPositionTime: totalNotInPositionTime,
            attendanceRate: attendanceRate,
            punctualityRate: punctualityRate
        });
    }
    // Helper function để determine if a date is a working day
    function _isWorkingDay(uint256 _date) internal pure returns (bool) {
        // Get day of week (0 = Sunday, 6 = Saturday)
        uint256 dayOfWeek = _getDayOfWeek(_date);
        
        // Check if it's weekend (assuming Sunday = 0, Saturday = 6)
        if (dayOfWeek == 0 || dayOfWeek == 6) {
            return false; // Weekend
        }
        
        // Check if it's a company holiday
        if (_isCompanyHoliday(_date)) {
            return false;
        }
        
        return true; // Regular working day
    }
    // Helper function để get day of week from date
    function _getDayOfWeek(uint256 _date) internal pure returns (uint256) {
        uint256 year = _date / 10000;
        uint256 month = (_date / 100) % 100;
        uint256 day = _date % 100;
        
        // Zeller's congruence algorithm để tính day of week
        if (month < 3) {
            month += 12;
            year--;
        }
        
        uint256 k = year % 100;
        uint256 j = year / 100;
        
        uint256 h = (day + ((13 * (month + 1)) / 5) + k + (k / 4) + (j / 4) - 2 * j) % 7;
        
        // Convert to standard format (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
        return (h + 5) % 7;
    }

    // Helper function để check company holidays
    function _isCompanyHoliday(uint256 _date) internal pure returns (bool) {
        uint256 month = (_date / 100) % 100;
        uint256 day = _date % 100;
        
        // Vietnam public holidays
        if (month == 1 && day == 1) return true;  // New Year's Day
        if (month == 4 && day == 30) return true; // Reunification Day
        if (month == 5 && day == 1) return true;  // Labour Day
        if (month == 9 && day == 2) return true;  // Independence Day
        
        // Có thể thêm các ngày lễ khác hoặc sử dụng storage mapping
        return false;
    }

    // Alternative: Flexible holiday management với storage
    mapping(uint256 => bool) public companyHolidays; // date => isHoliday

    function setCompanyHolidays(uint256[] memory _dates, bool[] memory _isHoliday) external onlyManagerOrHR {
        require(_dates.length == _isHoliday.length, "Array length mismatch");
        
        for (uint256 i = 0; i < _dates.length; i++) {
            companyHolidays[_dates[i]] = _isHoliday[i];
        }
    }
    // Helper function để count working days in month
    function _countWorkingDaysInMonth(uint256 _month, uint256 daysToCount) internal pure returns (uint256) {
        uint256 workingDays = 0;
        
        for (uint256 day = 1; day <= daysToCount; day++) {
            uint256 date = _month * 100 + day;
            if (_isWorkingDay(date)) {
                workingDays++;
            }
        }
        
        return workingDays;
    }

    function _getDaysInMonth(uint256 _year, uint256 _month) internal pure returns (uint256) {
        if (_month == 2) {
            // Kiểm tra năm nhuận
            if (_year % 4 == 0 && (_year % 100 != 0 || _year % 400 == 0)) return 29;
            return 28;
        } else if (_month == 4 || _month == 6 || _month == 9 || _month == 11) {
            return 30;
        }
        return 31;
    }

    // Add this function to automatically update monthly reports
    function _updateMonthlyReportOptimized(uint256 _date, address _staff) internal {
        uint256 month = _date / 100; // Extract YYYYMM from YYYYMMDD
        
        MonthlyReportHR storage monthlyReport = monthlyReports[month];
        
        // Initialize monthly report if new
        if (monthlyReport.month == 0) {
            monthlyReport.month = month;
            monthlyReport.lastUpdated = block.timestamp;
            reportedMonths.push(month);
        }
        
        // Check if staff is already in monthly report
        bool staffExists = false;
        for (uint256 i = 0; i < monthlyReport.staffList.length; i++) {
            if (monthlyReport.staffList[i] == _staff) {
                staffExists = true;
                break;
            }
        }
        
        // Add staff to monthly report if not exists
        if (!staffExists) {
            monthlyReport.staffList.push(_staff);
        }
        
        // Recalculate monthly stats for this staff
        _recalculateStaffMonthlyStats(month, _staff);
        
        monthlyReport.lastUpdated = block.timestamp;
        emit MonthlyReportGenerated(month);
    }

    // Helper function to recalculate monthly stats for a specific staff
    function _recalculateStaffMonthlyStats(uint256 _month, address _staff) internal {
        MonthlyReportHR storage monthlyReport = monthlyReports[_month];
        StaffMonthlyStats storage stats = monthlyReport.staffStats[_staff];
        
        // Get staff info
        Staff memory staffInfo = managementContract.GetStaffInfo(_staff);
        
        // Reset all arrays and counters
        delete stats.workingDayArr;
        delete stats.absentVacationDayArr;
        delete stats.absentUnauthorizedDayArr;
        delete stats.halfDayArr;
        delete stats.lateDayArr;
        
        stats.staffWallet = _staff;
        stats.staffCode = staffInfo.code;
        stats.staffName = staffInfo.name;
        // stats.month = _month;
        
        // Reset counters
        stats.presentDays = 0;
        stats.lateDays = 0;
        stats.vacationDays = 0;
        stats.unauthorizedDays = 0;
        stats.halfDays = 0;
        stats.totalWorkingHours = 0;
        stats.totalNotInPositionCount = 0;
        stats.totalNotInPositionTime = 0;
        
        // Calculate days in month
        uint256 year = _month / 100;
        uint256 monthNum = _month % 100;
        uint256 daysInMonth = _getDaysInMonth(year, monthNum);
        
        // Get current date to determine days to count
        uint256 currentDate = _getCurrentDate();
        uint256 currentYear = currentDate / 10000;
        uint256 currentMonth = (currentDate / 100) % 100;
        uint256 currentDay = currentDate % 100;
        
        uint256 daysToCount = daysInMonth;
        if (year == currentYear && monthNum == currentMonth && currentDay > 1) {
            daysToCount = currentDay - 1; // Count until yesterday
        }
        
        // Loop through all days in month
        for (uint256 day = 1; day <= daysToCount; day++) {
            uint256 date = _month * 100 + day;
            AttendanceRecord[] memory records = staffDailyAttendance[_staff][date];
            for(uint i; i<records.length;i++){
                AttendanceRecord memory record = records[i];
                bool hasRecord = (record.date > 0 || record.staffWallet != address(0));
            
                if (!hasRecord) {
                    // No record = unauthorized absence if it's a working day
                    if (_isWorkingDay(date)) {
                        stats.absentUnauthorizedDayArr.push(date);
                        stats.unauthorizedDays++;
                    }
                } else {
                    if (record.status == AttendanceStatus.PRESENT) {
                        stats.workingDayArr.push(date);
                        stats.presentDays++;
                        
                        if (record.isLate) {
                            stats.lateDayArr.push(date);
                            stats.lateDays++;
                        }
                        
                        if (record.isHalfDay) {
                            stats.halfDayArr.push(date);
                            stats.halfDays++;
                        }
                        
                        stats.totalWorkingHours += record.totalWorkingHours;
                        stats.totalNotInPositionCount += record.totalNotInPositionCount;
                        stats.totalNotInPositionTime += record.totalNotInPositionTime;
                        
                    } else if (record.status == AttendanceStatus.ABSENT) {
                        if (record.absentType == ABSENT_TYPE.VACATION) {
                            stats.absentVacationDayArr.push(date);
                            stats.vacationDays++;
                        } else if (record.absentType == ABSENT_TYPE.UNAUTHORIZED) {
                            stats.absentUnauthorizedDayArr.push(date);
                            stats.unauthorizedDays++;
                        }
                    }
                }
            }
        }
        
        // Calculate rates
        uint256 totalWorkingDays = _countWorkingDaysInMonth(_month, daysToCount);
        if (totalWorkingDays > 0) {
            stats.attendanceRate = (stats.presentDays * 100) / totalWorkingDays;
        }
        
        if (stats.presentDays > 0) {
            stats.punctualityRate = ((stats.presentDays - stats.lateDays) * 100) / stats.presentDays;
        }
    }


    // Update the existing _updateDailyReportOptimized function to also update monthly reports
    function _updateDailyReportOptimizedWithMonthly(uint256 _date, address _staff) internal {
        // Update daily report (existing logic)
        _updateDailyReportOptimized(_date, _staff);
        
        // Update monthly report
        _updateMonthlyReportOptimized(_date, _staff);
    }
}