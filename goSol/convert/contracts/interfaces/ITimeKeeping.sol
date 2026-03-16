// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
enum AttendanceStatus {
    PRESENT,    // Có mặt
    ABSENT      // Vắng mặt
}

enum ABSENT_TYPE {
    VACATION,       // Nghỉ phép
    UNAUTHORIZED    // Nghỉ không phép
}

struct WorkPlaceAttendance {
    uint WorkPlaceId;
    string LatLon;
}

struct WorkPlace {
    uint WorkPlaceId;
    string LocationName;
    string LocationAddress;
    string LatLon;
}

struct SettingAddress {
    WorkPlace[] WorkPlaces;
    uint LastUpdate;
}

struct NotInPositionRecord {
    uint256 startTime;      // Thời gian rời khỏi vị trí quy định
    uint256 endTime;        // Thời gian trở lại vị trí quy định
    uint256 duration;       // Thời gian tính từ khi rời khỏi vị trí quy định đến khi trở lại (phút)
}

// Updated AttendanceRecord struct
struct AttendanceRecord {
    address staffWallet;
    string staffCode;
    string staffName;
    uint256 date; // YYYYMMDD format
    uint256 checkInTime;    // Thời gian checkin
    uint256 checkOutTime;   // Thời gian checkout
    uint256 lateMinutes;    // Thời gian trễ (phút)
    bool isLate;            // Có đi trễ không
    bool isHalfDay;         // Có làm nửa ngày không
    NotInPositionRecord[] notInPositionRecords; // Danh sách các lần rời khỏi vị trí
    uint256 totalNotInPositionTime; // Tổng thời gian rời khỏi vị trí (phút)
    uint256 totalNotInPositionCount; // Tổng số lần rời khỏi vị trí
    uint256 totalWorkingHours; // Tổng giờ làm việc (phút)
    AttendanceStatus status;
    ABSENT_TYPE absentType; // Loại vắng mặt (chỉ dùng khi status = ABSENT)
    string notes;
    bool isApproved;
    address approvedBy;
    uint256 approvedAt;
    WorkPlaceAttendance WorkPlaceAttendance;
    uint256 ShiftId;
}

// Updated struct cho báo cáo ngày của từng nhân viên
struct StaffDailyReport {
    address staffWallet;
    string staffCode;
    string staffName;
    uint256 date;
    uint256 checkInTime;                    // Thời gian checkin
    uint256 checkOutTime;                   // Thời gian checkout
    uint256 lateMinutes;                    // Thời gian trễ (phút)
    bool isLate;                           // Có đi trễ không
    bool isHalfDay;                        // Có làm nửa ngày không
    uint256 totalWorkingHours;              // Tổng giờ làm việc
    uint256 totalNotInPositionTime;         // Tổng thời gian rời khỏi vị trí quy định
    uint256 totalNotInPositionCount;        // Số lần rời khỏi vị trí quy định
    NotInPositionRecord[] notInPositionRecords; // Chi tiết các lần rời khỏi vị trí
    AttendanceStatus status;
    ABSENT_TYPE absentType;
    string notes;
}

// Updated struct cho báo cáo tháng của từng nhân viên
struct StaffMonthlyReport {
    address staffWallet;
    string staffCode;
    string staffName;
    uint256 month; // YYYYMM format
    
    // Danh sách các ngày cụ thể
    uint256[] workingDayArr;        // Danh sách các ngày nhân viên đi làm
    uint256[] absentVacationDayArr; // Danh sách các ngày nhân viên nghỉ phép
    uint256[] absentUnauthorizedDayArr; // Danh sách các ngày nhân viên nghỉ không phép
    uint256[] halfDayArr;           // Danh sách các ngày nhân viên đi làm nửa ngày
    uint256[] lateDayArr;           // Danh sách các ngày nhân viên đi làm muộn
    
    // Thống kê tổng hợp
    uint256 presentDays;
    uint256 lateDays;
    uint256 vacationDays;
    uint256 unauthorizedDays;
    uint256 halfDays;
    uint256 totalWorkingHours;
    uint256 totalNotInPositionCount; // Tổng số lần rời khỏi vị trí trong tháng
    uint256 totalNotInPositionTime;  // Tổng thời gian rời khỏi vị trí trong tháng
    uint256 attendanceRate; // percentage
    uint256 punctualityRate; // percentage
}

// Updated struct cho danh sách nhân viên trong báo cáo ngày
struct DailyStaffSummary {
    address staffWallet;
    string staffCode;
    string staffName;
    uint256 workingHours;   // Số giờ làm việc trong ngày (phút)
    uint256 lateCount;      // Số lần đi trễ (0 hoặc 1)
    bool isHalfDay;         // Có làm nửa ngày không
    uint256 checkInTime;    // Thời gian check in
    uint256 checkOutTime;   // Thời gian check out
    AttendanceStatus status;
    ABSENT_TYPE absentType; // Chỉ dùng khi status = ABSENT
    uint256 lateMinutes;
}

struct DailyReportHR {
    uint256 date;
    uint256 totalStaff;
    uint256 presentStaff;
    uint256 absentStaff;
    uint256 lateStaff;
    uint256 vacationStaff;
    uint256 unauthorizedStaff;
    uint256 halfDayStaff;
    uint256 totalWorkingHours;
    uint256 totalNotInPositionCount;
    uint256 averageWorkingHours;
    uint256 totalLateMinutes;       // Tổng thời gian trễ của tất cả nhân viên
    uint256 totalTakeawayOrders;    // Tổng số món takeaway
    uint256 totalDineInOrders;      // Tổng số món dine-in
    uint256 takeawayPercentage;     // Phần trăm takeaway
    uint256 dineInPercentage;       // Phần trăm dine-in
    DailyStaffSummary[] staffList;  // Danh sách tất cả nhân viên với thông tin cơ bản
    uint256 unrecordedStaff;
}

struct StaffDayDetail {
    uint256 date;
    AttendanceStatus status;
    ABSENT_TYPE absentType;
    bool isLate;
    bool isHalfDay;
    uint256 checkInTime;            // Thời gian checkin
    uint256 checkOutTime;           // Thời gian checkout
    uint256 totalWorkingHours;      // Tổng giờ làm việc
    uint256 notInPositionCount;     // Số lần rời khỏi vị trí
    uint256 totalNotInPositionTime; // Tổng thời gian rời khỏi vị trí
    uint256 lateMinutes;            // Số phút trễ
    string notes;
}

struct MonthlyReportHR {
    uint256 month; // YYYYMM format
    uint256 totalWorkingDays;
    uint256 totalStaffDays;
    uint256 presentDays;
    uint256 lateDays;
    uint256 totalWorkingHours;
    uint256 totalNotInPositionCount;
    uint256 averageAttendanceRate;
    mapping(address => StaffMonthlyStats) staffStats;
    address[] staffList;
    uint256 lastUpdated;
}

struct StaffMonthlyStats {
    address staffWallet;
    string staffCode;
    string staffName;
    uint256 presentDays;
    uint256 lateDays;
    uint256 vacationDays;
    uint256 unauthorizedDays;
    uint256 halfDays;
    uint256 totalWorkingHours;
    uint256 totalNotInPositionCount; // Tổng số lần notInPosition trong tháng
    uint256 totalNotInPositionTime;
    uint256 attendanceRate; // percentage
    uint256 punctualityRate; // percentage
    
    // Detailed day lists - Danh sách các ngày cụ thể
    uint256[] workingDayArr;        // Danh sách các ngày nhân viên đi làm
    uint256[] absentVacationDayArr; // Danh sách các ngày nhân viên nghỉ phép
    uint256[] absentUnauthorizedDayArr; // Danh sách các ngày nhân viên nghỉ không phép
    uint256[] halfDayArr;           // Danh sách các ngày nhân viên đi làm nửa ngày
    uint256[] lateDayArr;           // Danh sách các ngày nhân viên đi làm muộn
}

// Struct cho báo cáo tháng với danh sách nhân viên đơn giản
struct MonthlyStaffSummary {
    address staffWallet;
    string staffCode;
    string staffName;
    uint256 workingDays;    // Số ngày công
    uint256 lateCount;      // Số lần đi trễ trong tháng
}

// Struct cho báo cáo ngày của toàn công ty
struct CompanyDailySummary {
    string staffName;
    string staffCode;
    string position;        // Chức vụ
    uint256 workingHours;   // Số giờ làm việc trong ngày (phút)
    uint256 lateCount;      // Số lần đi trễ (0 hoặc 1)
}

// Struct cho báo cáo tháng của toàn công ty
struct CompanyMonthlySummary {
    string staffName;
    string staffCode;
    string position;        // Chức vụ
    uint256 workingDays;    // Số ngày công trong tháng tính đến thời điểm gọi
}
interface ITimeKeeping {
    function getWorkPlaceById(uint _workPlaceId) external view returns (WorkPlace memory) ;
}