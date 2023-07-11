// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract CalendarDailyTelos is AccessControl {
    bytes32 public constant MEMBER_ROLE = keccak256("MEMBER_ROLE");
    bytes32 public constant GUEST_ROLE = keccak256("GUEST_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint public adminCount;
    uint public memberCount; 
    uint public guestCount; 

    struct CalendarEvent {
        uint eventId; 
        string title; 
        address organizer; 
        uint startTime; // start time ie. 1687393537 Thu Jun 22 2023 00:25:37
        uint endTime; // end time ie. 1687739137 Mon Jun 26 2023 00:25:37
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

    mapping(address => Invitation) public userInvitations;
    string public contractName = "Daily Telos Calendar V0.2";
    mapping(address => Guest) public guests;
    mapping(address => Member) public members;
    mapping(address => Admin) public admin;
    mapping(uint => CalendarEvent) public eventsById;
    mapping(address => CalendarEvent[]) public userEvents;
    mapping(address => CalendarEvent[]) public guestEvents;
    mapping(address => CalendarEvent[]) public adminEvents;
    mapping(address => CalendarEvent[]) public memberEvents; 
    address[] public users; 
    address[] public eventCreators;
    mapping(address => uint) public eventCount; 
    mapping(uint => address[]) public eventInvitations; 
    uint public totalEvents; 

    event EventUpdated(uint indexed eventID, string title, address indexed organizer, uint startTime, uint endTime, string metadataURI, uint timestamp);
    event UserInvited(uint indexed eventID, string title, address invitedUser);
    event InvitationAccepted(uint indexed eventID, address indexed attendee);
    event AccountRoleGranted(bytes32 role, address indexed account, address indexed sender);
    event NewEventCreated(uint indexed eventID, string title, address indexed organizer, uint startTime, uint endTime, string metadataURI, uint timestamp, bytes32 role);
    event EventDeleted(uint indexed eventID, address indexed organizer);

    constructor() {
        _setupRole(ADMIN_ROLE, msg.sender); 
        _setupRole(MEMBER_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, address(this));
        memberCount = 1;
        guestCount = 0;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlyMember() {
        require(hasRole(MEMBER_ROLE, msg.sender), "Caller is not a member");
        _;
    } 

    function revokeRole(bytes32 role, address account) public override {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        super.revokeRole(role, account);
        if (!hasRole(ADMIN_ROLE, account) && hasRole(MEMBER_ROLE, account)) {
            revokeRole(MEMBER_ROLE, account);
            delete members[account];
            memberCount--;
        }
    }

    function grantRole(bytes32 role, address account) public override {
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
        CalendarEvent[] memory memberEvents = getAllMemberEvents();
        CalendarEvent[] memory guestEvents = getAllGuestEvents();
        CalendarEvent[] memory adminEvents = getAllAdminEvents();
        uint totalEvents = memberEvents.length + guestEvents.length + adminEvents.length;
        CalendarEvent[] memory allEvents = new CalendarEvent[](totalEvents);
        uint currentIndex = 0;
        for (uint i = 0; i < memberEvents.length; i++) {
                allEvents[currentIndex] = memberEvents[i];
                currentIndex++;
        }
        for (uint i = 0; i < guestEvents.length; i++) {
                allEvents[currentIndex] = guestEvents[i];
                currentIndex++;
        }
        for (uint i = 0; i < adminEvents.length; i++) {
            allEvents[currentIndex] = adminEvents[i];
            currentIndex++;
        }
        return allEvents;
    }

    function getAllMemberEvents() public view returns (CalendarEvent[] memory) {
        uint totalMemberEvents = 0;
        address[] memory memberAddresses = new address[](users.length);
        uint memberCount = 0;
        for (uint i = 0; i < users.length; i++) {
            if (hasRole(MEMBER_ROLE, users[i])) {
                memberAddresses[memberCount] = users[i];
                memberCount++;
                totalMemberEvents += memberEvents[users[i]].length;
            }
        }
        CalendarEvent[] memory allMemberEvents = new CalendarEvent[](totalMemberEvents);
        uint currentIndex = 0;
            for (uint i = 0; i < memberCount; i++) {
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
        uint guestCount = 0;
        for (uint i = 0; i < users.length; i++) {
        if (hasRole(GUEST_ROLE, users[i])) {
            guestAddresses[guestCount] = users[i];
            guestCount++;
            totalGuestEvents += guestEvents[users[i]].length;
                }
            }
        CalendarEvent[] memory allGuestEvents = new CalendarEvent[](totalGuestEvents);
        uint currentIndex = 0;
        for (uint i = 0; i < guestCount; i++) {
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
        uint adminCount = 0;
        for (uint i = 0; i < users.length; i++) {
            if (hasRole(ADMIN_ROLE, users[i])) {
                adminAddresses[adminCount] = users[i];
                adminCount++;
                totalAdminEvents += adminEvents[users[i]].length;
            }
          }
        CalendarEvent[] memory allAdminEvents = new CalendarEvent[](totalAdminEvents);
         uint currentIndex = 0;
            for (uint i = 0; i < adminCount; i++) {
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
  
// Helper function to check if an address exists in an array
function includes(address[] memory array, address element) internal pure returns (bool) {
    for (uint i = 0; i < array.length; i++) {
        if (array[i] == element) {
            return true;
        }
    }
    return false;
}


    function acceptInvitation(uint eventID) public {
    // Check if the user is a member or admin
    require(hasRole(MEMBER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Only members or admins can accept invitations");

    // Make sure the event ID is valid and that the user was invited to this event
    uint[] memory invitedEvents = getInvitations(msg.sender);
    bool isInvited = false;
    for (uint i = 0; i < invitedEvents.length; i++) {
        if (invitedEvents[i] == eventID) {
            isInvited = true;
            break;
        }
    }
    require(isInvited, "You are not invited to this event");

    // Confirm the attendance
    CalendarEvent storage calendarEvent = eventsById[eventID];
    calendarEvent.confirmedAttendees.push(msg.sender);
    emit InvitationAccepted(eventID, msg.sender);
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
        emit EventUpdated(eventID, title, msg.sender, startTime, endTime, metadataURI, block.timestamp);
    }

    function getAllAddresses() public view returns (address[] memory, address[] memory, address[] memory) {
        uint adminCount = 0;
        uint memberCount = 0;
        uint guestCount = 0;
            for (uint i = 0; i < users.length; i++) {
                if (hasRole(ADMIN_ROLE, users[i])) adminCount++;
                if (hasRole(MEMBER_ROLE, users[i])) memberCount++;
                if (hasRole(GUEST_ROLE, users[i])) guestCount++;
           }
        address[] memory adminAddresses = new address[](adminCount);
        address[] memory memberAddresses = new address[](memberCount);
        address[] memory guestAddresses = new address[](guestCount);
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
         uint guestCount = 0;
        for (uint i = 0; i < users.length; i++) {
            if (hasRole(GUEST_ROLE, users[i])) {
                guestCount++;
                }
            }
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

    // Add the event creator's address to eventCreators
    eventCreators.push(msg.sender);

    for (uint i = 0; i < invitees.length; i++) {
        address invitee = invitees[i];
        eventInvitations[eventID].push(invitee);
        addInvitation(invitee, eventID);
        emit UserInvited(eventID, title, invitee);
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
        require(hasRole(MEMBER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Caller is not a member or admin");
        if (hasRole(MEMBER_ROLE, msg.sender)) {
            require(eventID < memberEvents[msg.sender].length, "Invalid event ID");
            CalendarEvent[] storage events = memberEvents[msg.sender];
            emit EventDeleted(events[eventID].eventId, events[eventID].organizer);
            delete events[eventID];
        } else if (hasRole(ADMIN_ROLE, msg.sender)) {
            require(eventID < adminEvents[msg.sender].length, "Invalid event ID");
            CalendarEvent[] storage events = adminEvents[msg.sender];
            emit EventDeleted(events[eventID].eventId, events[eventID].organizer);
            delete events[eventID];
        }
    }
}
