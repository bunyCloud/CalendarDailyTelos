// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import './CalendarFactory.sol';


contract CalendarDailyTelos is AccessControl {
    
    string public calendarName;
    address public calendarAdmin;
    
    CalendarFactory private _factory;
    
    bytes32 public constant MEMBER_ROLE = keccak256("MEMBER_ROLE");
    bytes32 public constant GUEST_ROLE = keccak256("GUEST_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    address[] public users; 
    address[] public eventCreators;
    
    uint public totalEvents; 
    uint public adminCount;
    uint public memberCount; 
    uint public guestCount;
    
    mapping(address => uint) public eventCount; 
    mapping(address => Invitation) public userInvitations;
    mapping(address => Guest) public guests;
    mapping(address => Member) public members;
    mapping(address => Admin) public admins;
    mapping(uint => CalendarEvent) public eventsById;
    mapping(address => CalendarEvent[]) public userEvents;
    mapping(address => CalendarEvent[]) public guestEvents;
    mapping(address => CalendarEvent[]) public adminEvents;
    mapping(address => CalendarEvent[]) public memberEvents; 
    mapping(uint => address[]) public eventInvitations; 
    
    event NewEventCreated(uint indexed eventID, string title, address indexed organizer, uint startTime, uint endTime, string metadataURI, uint timestamp, bytes32 role);
    
    struct CalendarEvent {
        uint eventId; 
        string title; 
        address organizer; 
        uint startTime;
        uint endTime;
        uint created; 
        string metadataURI; 
        address[] invitedAttendees; 
        address[] confirmedAttendees; 
    }

    struct Admin {
        address addr;
        uint[] eventIds;
    }
   
    struct Member {
        address addr;
        uint[] eventIds;
    }

    struct Guest {
        address addr;
        uint[] eventIds;
    }

    struct Invitation {
          address userAddress;
          uint[] eventIDs;
    }

    
   constructor(string memory _calendarName) {
        require(bytes(_calendarName).length > 0, "Calendar name must not be empty");
        calendarName = _calendarName;
        _factory = CalendarFactory(msg.sender);
        calendarAdmin = msg.sender;
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlyMember() {
        require(hasRole(MEMBER_ROLE, msg.sender), "Caller is not a member");
        _;
    } 

    function revokeRole(bytes32 role, address account) public override onlyAdmin {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        super.revokeRole(role, account);
        if (!hasRole(ADMIN_ROLE, account) && hasRole(MEMBER_ROLE, account)) {
            revokeRole(MEMBER_ROLE, account);
            delete members[account];
            memberCount--;
        }
    }

    function grantRole(bytes32 role, address account) public override onlyAdmin {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        super.grantRole(role, account);
        if (role == MEMBER_ROLE) {
            members[account] = Member({
                addr: account,
                eventIds: new uint[](0)
            });
            memberCount++;
        } else if (role == GUEST_ROLE) {
            guestCount++;
        } 
    }

    function addMember(address memberAddress) public onlyAdmin {
        _setupRole(MEMBER_ROLE, memberAddress);
        members[memberAddress] = Member({
            addr: memberAddress,
            eventIds: new uint[](0)
        });
        memberCount++;
        if (!hasRole(GUEST_ROLE, memberAddress)) {
            _setupRole(GUEST_ROLE, memberAddress);
            guests[memberAddress] = Guest({
                addr: memberAddress,
                eventIds: new uint[](0)
            });
            guestCount++;
        }
        bool userExists = false;
        for (uint i = 0; i < users.length; i++) {
            if (users[i] == memberAddress) {
                userExists = true;
                break;
            }
        }
        if (!userExists) {
            users.push(memberAddress);
        }
    }

    function addMembers(address[] memory memberAddresses) public onlyAdmin {
    for (uint i = 0; i < memberAddresses.length; i++) {
        address memberAddress = memberAddresses[i];
        _setupRole(MEMBER_ROLE, memberAddress);
        members[memberAddress] = Member({
            addr: memberAddress,
            eventIds: new uint[](0)
        });
        memberCount++;

        if (!hasRole(GUEST_ROLE, memberAddress)) {
            _setupRole(GUEST_ROLE, memberAddress);
            guests[memberAddress] = Guest({
                addr: memberAddress,
                eventIds: new uint[](0)
            });
            guestCount++;
        }

        bool userExists = false;
        for (uint j = 0; j < users.length; j++) {
            if (users[j] == memberAddress) {
                userExists = true;
                break;
            }
        }
        if (!userExists) {
            users.push(memberAddress);
        }
    }
}


 function addAdmins(address[] memory adminAddresses) public onlyAdmin {
    for (uint i = 0; i < adminAddresses.length; i++) {
        address adminAddress = adminAddresses[i];
        _setupRole(ADMIN_ROLE, adminAddress);
        admins[adminAddress] = Admin({
            addr: adminAddress,
            eventIds: new uint[](0)
        });
        adminCount++;

        if (!hasRole(MEMBER_ROLE, adminAddress)) {
            _setupRole(MEMBER_ROLE, adminAddress);
            members[adminAddress] = Member({
                addr: adminAddress,
                eventIds: new uint[](0)
            });
            memberCount++;
        }

        bool userExists = false;
        for (uint j = 0; j < users.length; j++) {
            if (users[j] == adminAddress) {
                userExists = true;
                break;
            }
        }
        if (!userExists) {
            users.push(adminAddress);
        }
    }
}


    function addGuest(address guestAddress) public {
        _setupRole(GUEST_ROLE, guestAddress);
        guests[guestAddress] = Guest({
            addr: guestAddress,
            eventIds: new uint[](0)
        });
        guestCount++;
        bool userExists = false;
        for (uint i = 0; i < users.length; i++) {
            if (users[i] == guestAddress) {
                userExists = true;
                break;
            }
        }
        if (!userExists) {
            users.push(guestAddress);
        }
    }

    function removeMember(address memberAddress) public onlyAdmin {
        revokeRole(MEMBER_ROLE, memberAddress);
        delete members[memberAddress];
        memberCount--;
    }

   function getEventById(uint eventId) public view returns (CalendarEvent memory) {
    for (uint i = 0; i < eventCreators.length; i++) {
        CalendarEvent[] storage events;
        if (hasRole(MEMBER_ROLE, eventCreators[i])) {
            events = memberEvents[eventCreators[i]];
        } else if (hasRole(GUEST_ROLE, eventCreators[i])) {
            events = guestEvents[eventCreators[i]];
        } else if (hasRole(ADMIN_ROLE, eventCreators[i])) {
            events = adminEvents[eventCreators[i]];
        } else {
            continue;
        }
        for (uint j = 0; j < events.length; j++) {
            if (events[j].eventId == eventId) {
                return events[j];
            }
        }
    }
    revert("Event not found");
}

    function getAdminEvents(address adminAddress) public view onlyAdmin returns (CalendarEvent[] memory) {
        return adminEvents[adminAddress];
    }

    function getMemberEvents(address memberAddress) public view onlyMember returns (CalendarEvent[] memory) {
        return memberEvents[memberAddress];
    }

    function getGuestEvents(address guestAddress) public view returns (CalendarEvent[] memory) {
        require(hasRole(GUEST_ROLE, guestAddress), "Caller is not a guest");
        return guestEvents[guestAddress];
    }

    function getAllEvents() public view returns (CalendarEvent[] memory) {
        CalendarEvent[] memory memberEventsData = getAllMemberEvents();
        CalendarEvent[] memory guestEventsData = getAllGuestEvents();
        CalendarEvent[] memory adminEventsData = getAllAdminEvents();
        uint combinedTotalEvents = memberEventsData.length + guestEventsData.length + adminEventsData.length;
        CalendarEvent[] memory allEvents = new CalendarEvent[](combinedTotalEvents);
        uint currentIndex = 0;
        for (uint i = 0; i < memberEventsData.length; i++) {
            allEvents[currentIndex] = memberEventsData[i];
            currentIndex++;
        }
        for (uint i = 0; i < guestEventsData.length; i++) {
            allEvents[currentIndex] = guestEventsData[i];
            currentIndex++;
        }
        for (uint i = 0; i < adminEventsData.length; i++) {
            allEvents[currentIndex] = adminEventsData[i];
            currentIndex++;
        }
        return allEvents;
    }

     function getAllMemberEvents() public view returns (CalendarEvent[] memory) {
        address[] memory memberAddresses = new address[](users.length);
        uint memberCountLocal = 0; 
        uint totalMemberEvents = 0; 
        for (uint i = 0; i < users.length; i++) {
            if (hasRole(MEMBER_ROLE, users[i])) {
                memberAddresses[memberCountLocal] = users[i];
                memberCountLocal++;
            totalMemberEvents += memberEvents[users[i]].length;
        }
    }

    CalendarEvent[] memory allMemberEvents = new CalendarEvent[](totalMemberEvents);
    uint currentIndex = 0;
    for (uint i = 0; i < memberCountLocal; i++) {
        for (uint j = 0; j < memberEvents[memberAddresses[i]].length; j++) {
            allMemberEvents[currentIndex] = memberEvents[memberAddresses[i]][j];
            currentIndex++;
        }
    }

    return allMemberEvents;
}



   function getAllGuestEvents() public view returns (CalendarEvent[] memory) {
    uint totalGuestEvents = 0;
    address[] memory guestAddresses = new address[](users.length);
    uint guestCountLocal = 0; 
        for (uint i = 0; i < users.length; i++) {
            if (hasRole(GUEST_ROLE, users[i])) {
                guestAddresses[guestCountLocal] = users[i];
                guestCountLocal++;
                totalGuestEvents += guestEvents[users[i]].length;
            }
        }
        CalendarEvent[] memory allGuestEvents = new CalendarEvent[](totalGuestEvents);
        uint currentIndex = 0;
        for (uint i = 0; i < guestCountLocal; i++) {
        for (uint j = 0; j < guestEvents[guestAddresses[i]].length; j++) {
            allGuestEvents[currentIndex] = guestEvents[guestAddresses[i]][j];
            currentIndex++;
            }
        }
        return allGuestEvents;
    }

   function getAllAdminEvents() public view returns (CalendarEvent[] memory) {
        uint totalAdminEvents = 0;
        address[] memory adminAddresses = new address[](users.length);
        uint adminCountLocal = 0; 
        for (uint i = 0; i < users.length; i++) {
            if (hasRole(ADMIN_ROLE, users[i])) {
                adminAddresses[adminCountLocal] = users[i];
                adminCountLocal++;
                totalAdminEvents += adminEvents[users[i]].length;
            }
        }
        CalendarEvent[] memory allAdminEvents = new CalendarEvent[](totalAdminEvents);
        uint currentIndex = 0;
        for (uint i = 0; i < adminCountLocal; i++) {
        for (uint j = 0; j < adminEvents[adminAddresses[i]].length; j++) {
            allAdminEvents[currentIndex] = adminEvents[adminAddresses[i]][j];
            currentIndex++;
            }
        }
        return allAdminEvents;
    }


    function addInvitation(address userAddress, uint eventID) internal {
        Invitation storage invitation = userInvitations[userAddress];
        invitation.userAddress = userAddress;
        invitation.eventIDs.push(eventID);
    }

    function getInvitations(address userAddress) public view returns (uint[] memory) {
        Invitation storage invitation = userInvitations[userAddress];
        return invitation.eventIDs;
    }
    
    function includes(address[] memory array, address element) internal pure returns (bool) {
        for (uint i = 0; i < array.length; i++) {
        if (array[i] == element) {
            return true;
            }
        }
        return false;
    }


    function acceptInvitation(uint eventID) public {
    require(hasRole(MEMBER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only members or admins can accept invitations");
    uint[] memory invitedEvents = getInvitations(msg.sender);
    bool isInvited = false;
    for (uint i = 0; i < invitedEvents.length; i++) {
        if (invitedEvents[i] == eventID) {
            isInvited = true;
            break;
        }
    }
    require(isInvited, "You are not invited to this event");
    CalendarEvent storage calendarEvent = eventsById[eventID];
    calendarEvent.confirmedAttendees.push(msg.sender);
    }

    function updateEvent(uint eventID, string memory title, uint startTime, uint endTime, string memory metadataURI) public {
        require(hasRole(GUEST_ROLE, msg.sender) || hasRole(MEMBER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Caller is not a user, member or admin");
        if (hasRole(GUEST_ROLE, msg.sender)) {
            require(eventID < userEvents[msg.sender].length, "Invalid event ID");
            CalendarEvent storage eventToUpdate = userEvents[msg.sender][eventID];
            eventToUpdate.title = title;
            eventToUpdate.startTime = startTime;
            eventToUpdate.endTime = endTime;
            eventToUpdate.metadataURI = metadataURI;
        } else if (hasRole(MEMBER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender)) {
            require(eventID < memberEvents[msg.sender].length, "Invalid event ID");
            CalendarEvent storage eventToUpdate = memberEvents[msg.sender][eventID];
            eventToUpdate.title = title;
            eventToUpdate.startTime = startTime;
            eventToUpdate.endTime = endTime;
            eventToUpdate.metadataURI = metadataURI;
        }
        
    }

    function getAllAddresses() public view returns (address[] memory, address[] memory, address[] memory) {
        uint adminCountLocal = 0;
        uint memberCountLocal = 0;
        uint guestCountLocal = 0;
    for (uint i = 0; i < users.length; i++) {
        if (hasRole(ADMIN_ROLE, users[i])) adminCountLocal++;
        if (hasRole(MEMBER_ROLE, users[i])) memberCountLocal++;
        if (hasRole(GUEST_ROLE, users[i])) guestCountLocal++;
        }
        address[] memory adminAddresses = new address[](adminCountLocal);
        address[] memory memberAddresses = new address[](memberCountLocal);
        address[] memory guestAddresses = new address[](guestCountLocal);
        uint adminIndex = 0;
        uint memberIndex = 0;
        uint guestIndex = 0;
        for (uint i = 0; i < users.length; i++) {
            if (hasRole(ADMIN_ROLE, users[i])) {
                adminAddresses[adminIndex] = users[i];
                adminIndex++;
        }
            if (hasRole(MEMBER_ROLE, users[i])) {
                memberAddresses[memberIndex] = users[i];
                memberIndex++;
            }
            if (hasRole(GUEST_ROLE, users[i])) {
                guestAddresses[guestIndex] = users[i];
                guestIndex++;
           }
        }
        return (adminAddresses, memberAddresses, guestAddresses);
    }

    function getAllMemberAddresses() public view returns (address[] memory) {
        address[] memory memberAddresses = new address[](memberCount);
        uint currentIndex = 0;
        for (uint i = 0; i < users.length; i++) {
            if (hasRole(MEMBER_ROLE, users[i])) {
                memberAddresses[currentIndex] = users[i];
                currentIndex++;
            }
        }
        return memberAddresses;
    }

    function getAllGuestAddresses() public view returns (address[] memory) {
        address[] memory guestAddresses = new address[](guestCount);
        uint currentIndex = 0;
            for (uint i = 0; i < users.length; i++) {
            if (hasRole(GUEST_ROLE, users[i])) {
                guestAddresses[currentIndex] = users[i];
                currentIndex++;
                }
            }
            return guestAddresses;
    }

    function createEvent(string memory title, uint startTime, uint endTime, string memory metadataURI, address[] memory invitees) public {
    require(bytes(title).length > 0, "Event title must not be empty");
    require(startTime < endTime, "Invalid event times");
        if (!hasRole(MEMBER_ROLE, msg.sender) && !hasRole(ADMIN_ROLE, msg.sender) && !hasRole(GUEST_ROLE, msg.sender)) {
            addGuest(msg.sender);
            guestCount++;
        }
        CalendarEvent memory newEvent;
        newEvent.eventId = totalEvents + 1;
        newEvent.title = title;
        newEvent.startTime = startTime;
        newEvent.endTime = endTime;
        newEvent.organizer = msg.sender;
        newEvent.created = block.timestamp;
        newEvent.metadataURI = metadataURI;
        newEvent.invitedAttendees = invitees;
        newEvent.confirmedAttendees = new address[](0);
        if (hasRole(MEMBER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender)) {
            memberEvents[msg.sender].push(newEvent);
            members[msg.sender].eventIds.push(newEvent.eventId);
        } else {
            userEvents[msg.sender].push(newEvent);
            guestEvents[msg.sender].push(newEvent);
            guests[msg.sender].eventIds.push(newEvent.eventId);
        }
        uint eventID = newEvent.eventId;
        totalEvents++;
        eventCreators.push(msg.sender);
        for (uint i = 0; i < invitees.length; i++) {
        address invitee = invitees[i];
        eventInvitations[eventID].push(invitee);
        addInvitation(invitee, eventID);
        }
        bytes32 userRole = MEMBER_ROLE;
        if (hasRole(ADMIN_ROLE, msg.sender)) {
        userRole = ADMIN_ROLE;
        } else if (hasRole(GUEST_ROLE, msg.sender)) {
        userRole = GUEST_ROLE;
        }
        emit NewEventCreated(eventID, title, msg.sender, startTime, endTime, metadataURI, block.timestamp, userRole);
    }   

    function deleteEvent(uint eventID) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not a admin");
        if (hasRole(ADMIN_ROLE, msg.sender)) {
            require(eventID < memberEvents[msg.sender].length, "Invalid event ID");
            CalendarEvent[] storage events = memberEvents[msg.sender];
                        delete events[eventID];
        } 
    }
}
