// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import "./DateTimeLibrary.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
    #####################################################
    #   @dev WRAPUP FUNC FOR DateTime Lib With TimeZone #
    #####################################################
 */
library DateTimeTZ {
    uint constant DAY_IN_WEEK = DateTimeLibrary.DAY_IN_WEEK;

    uint constant DOW_MON = DateTimeLibrary.DOW_MON;
    uint constant DOW_TUE = DateTimeLibrary.DOW_TUE;
    uint constant DOW_WED = DateTimeLibrary.DOW_WED;
    uint constant DOW_THU = DateTimeLibrary.DOW_THU;
    uint constant DOW_FRI = DateTimeLibrary.DOW_FRI;
    uint constant DOW_SAT = DateTimeLibrary.DOW_SAT;
    uint constant DOW_SUN = DateTimeLibrary.DOW_SUN;
    function addTimezone(uint timestamp, int tz) internal pure returns (uint) {
        int newTimestamp = int(timestamp) + int(DateTimeLibrary.SECONDS_PER_HOUR) * tz;
        require(newTimestamp > 0);
        return uint(newTimestamp);
    }

    function timestampToDateTime(uint timestamp, int tz) internal pure returns (uint year, uint month, uint day, uint hour, uint minute, uint second) {
        // Convert GTM+0 to TZ
        timestamp = addTimezone(timestamp, tz);
        return DateTimeLibrary.timestampToDateTime(timestamp);
    }

    function timestampToDate(uint timestamp, int tz) internal pure returns (uint year, uint month, uint day) {
        // Convert GTM+0 to TZ
        timestamp = addTimezone(timestamp, tz);
        return DateTimeLibrary.timestampToDate(timestamp);
    }

    function getYMD(uint timestamp, int tz)  internal pure returns (uint) {
        (uint y, uint m, uint d) = timestampToDate(timestamp, tz);
        return y * 10000 + m * 100 + d;
    }

    function getYM(uint timestamp, int tz)  internal pure returns (uint) {
        (uint y, uint m, ) = timestampToDate(timestamp, tz);
        return y * 100 + m;
    }

    function timestampFromDate(uint year, uint month, uint day, int tz) internal pure returns (uint timestamp) {
        timestamp = DateTimeLibrary.timestampFromDate(year, month, day);
        
        // Convert TZ to GTM+0
        timestamp = addTimezone(timestamp, -tz);
    }

    function timestampFromDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second, int tz) internal pure returns (uint timestamp) {
        timestamp = DateTimeLibrary.timestampFromDateTime(year, month, day, hour, minute, second);
        // Convert TZ to GTM+0
        timestamp = addTimezone(timestamp, -tz);
    }

    function getStartOfDate(uint timestamp, int tz) internal pure returns (uint startOfDate) {
        (uint year, uint month, uint day) = timestampToDate(timestamp, tz);
        startOfDate = timestampFromDate(year, month, day, tz);
    }

    function getEndOfDate(uint timestamp, int tz) internal pure returns (uint endOfDate) {
        endOfDate = getStartOfDate(timestamp, tz) + DateTimeLibrary.SECONDS_PER_DAY - 1;
    }

    function addDays(uint timestamp, uint _days) internal pure returns (uint newTimestamp) {
        newTimestamp = DateTimeLibrary.addDays(timestamp, _days);
        require(newTimestamp >= timestamp);
    }

    function subDays(uint timestamp, uint _days) internal pure returns (uint newTimestamp) {
        newTimestamp = DateTimeLibrary.subDays(timestamp, _days);
        require(newTimestamp <= timestamp);
    }

    function extractYMD(uint _ymd) internal pure returns (uint year, uint month, uint day) {
        year = _ymd / 10000;
        month = (_ymd / 100) % 100;
        day = _ymd % 100;
    }

    function timestampFromYMD(uint _ymd, int tz) internal pure returns (uint timestamp) {
        (uint year, uint month, uint day) = extractYMD(_ymd);
        return timestampFromDate(year, month, day, tz);
    }
    function timestampFromYMD(uint year, uint month, uint day, int tz) internal pure returns (uint timestamp) {
        return timestampFromDate(year, month, day, tz);
    }

    function getDaysInMonth(uint year, uint month) internal pure returns (uint daysInMonth) {
        daysInMonth = DateTimeLibrary.getDaysInMonth(year, month);
    }

    function getDayOfWeekFromYMD(uint _ymd, int tz) internal pure returns (uint dayOfWeek) {
        uint timestamp = timestampFromYMD(_ymd, tz);
        timestamp = addTimezone(timestamp, tz);
        return DateTimeLibrary.getDayOfWeek(timestamp);
    }

    function getYYYYMMDDAndTime(uint timestamp, int tz) internal pure returns (uint ymd, uint time) {
        ymd = getYMD(timestamp, tz);
        time = timestamp - getStartOfDate(timestamp, tz);
    }

    function timestampToString(uint timestamp, int tz) internal pure returns (string memory) {
        (uint year, uint month, uint day) = timestampToDate(timestamp, tz);
        return string.concat(Strings.toString(day), "/", Strings.toString(month), "/", Strings.toString(year));
    }

    function ymdToString(uint ymd) internal pure returns (string memory) {
        (uint year, uint month, uint day) = extractYMD(ymd);
        return string.concat(Strings.toString(day), "/", Strings.toString(month), "/", Strings.toString(year));
    }

    function timestampToDetailString(uint timestamp, int tz) internal pure returns (string memory) {
        (uint year, uint month, uint day, uint hour, uint minute,) = timestampToDateTime(timestamp, tz);
        string memory date = string.concat(Strings.toString(day), "/", Strings.toString(month), "/", Strings.toString(year));
        string memory time = string.concat(Strings.toString(hour), ":", Strings.toString(minute));

        return string.concat(time, " ", date);
    }

    function timestampToDateAndTimeString(uint timestamp, int tz) internal pure returns (string memory date, string memory time) {
        (uint year, uint month, uint day, uint hour, uint minute,) = timestampToDateTime(timestamp, tz);
        date = string.concat(Strings.toString(day), "/", Strings.toString(month), "/", Strings.toString(year));

        if (hour > 12) {
            time = string.concat(Strings.toString(hour - 12), ":", Strings.toString(minute), " PM");
        } else {
            time = string.concat(Strings.toString(hour), ":", Strings.toString(minute), " AM");
        }

        return (date, time);
    }
}