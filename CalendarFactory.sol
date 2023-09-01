// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./CalendarDailyTelos.sol";

contract CalendarFactory {
    address[] public calAddressArray;
    address public factoryOwner;
    mapping(address => Calendar) public calendar;


    struct Calendar {
        address calendarOwner;
        address calendarAddress;
        string calendarName;
        
    }

    constructor() {
        factoryOwner = msg.sender;
    }

    modifier onlyfactoryOwner() {
        require(msg.sender == factoryOwner, 'Only the contract factoryOwner may call this function');
        _;
    }


         function createTelosCalendar(string memory _calendarName) public {
        CalendarDailyTelos tc = new CalendarDailyTelos(_calendarName);
        calAddressArray.push(address(tc));
        calendar[address(tc)] = Calendar(msg.sender, address(tc), _calendarName);
        
    }

    function getCalendarAddresses() public view returns(address[] memory) {
        return calAddressArray;
    }

    function getCalendar(address calendarAddress) public view returns (address, address, string memory) {
        Calendar memory calendarOwner = calendar[calendarAddress];
        return (calendarOwner.calendarOwner, calendarOwner.calendarAddress, calendarOwner.calendarName);
    }
}
