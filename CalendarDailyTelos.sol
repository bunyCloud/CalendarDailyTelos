// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract CalendarDailyTelos is AccessControl {
    
    bytes32 public constant MEMBER_ROLE = keccak256("MEMBER_ROLE");
    bytes32 public constant GUEST_ROLE = keccak256("GUEST_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint public memberCount; 
    uint public guestCount; 
    uint public adminCount; 

    struct CalendarEvent {
        uint eventId; // ID of the event
        string title; // title of the event
        address organizer; // event organizer's address
        uint startTime; // start time ie. 1687393537 Thu Jun 22 2023 00:25:37
        uint endTime; // end time ie. 1687739137 Mon Jun 26 2023 00:25:37
        uint created; // event created date time
        string metadataURI; // IPFS metadata or JSON file URL
        address[] invitedAttendees; // array of invited addresses
        address[] confirmedAttendees; // array of confirmed addresses
    }

    struct Member {
        address addr;
        uint[] eventIds;
    }

    struct Guest {
        address addr;
        uint[] eventIds;
    }

    struct MemberEvents {
        address user;
        CalendarEvent[] events;
    }

    struct GuestEvents {
        address user;
        CalendarEvent[] events;
    }

    string public contractName = "Daily Telos Calendar V0.2";
    mapping(address => Guest) public guests;
    mapping(address => Member) public members;
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
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender); 
        _setupRole(MEMBER_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, address(this));
        memberCount = 1;
        guestCount = 0;
        adminCount = 1; 
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
        adminCount--;
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
        } else if (role == ADMIN_ROLE) {
            adminCount++;
        }
    }

function addMember(address memberAddress) public onlyAdmin {
    _setupRole(MEMBER_ROLE, memberAddress);
    members[memberAddress] = Member({
        addr: memberAddress,
        eventIds: new uint[](0)
    });
    memberCount++;
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


    function removeMember(address memberAddress) public onlyAdmin {
        revokeRole(MEMBER_ROLE, memberAddress);
        delete members[memberAddress];
        memberCount--;
    }

    function getMemberEvents(address memberAddress) public view onlyMember returns (CalendarEvent[] memory) {
        return memberEvents[memberAddress];
    }

    function getAllMemberEvents(bytes32 role) public view returns (CalendarEvent[] memory) {
        require(role == MEMBER_ROLE || role == ADMIN_ROLE || role == GUEST_ROLE, "Invalid role");

        uint totalMemberEvents = 0;
        address[] memory memberAddresses = new address[](users.length);
        uint memberCount = 0;

        for (uint i = 0; i < users.length; i++) {
            if (hasRole(role, users[i])) {
                memberAddresses[memberCount] = users[i];
                memberCount++;

                if (role == MEMBER_ROLE) {
                    totalMemberEvents += memberEvents[users[i]].length;
                } else if (role == ADMIN_ROLE) {
                    totalMemberEvents += adminEvents[users[i]].length;
                } else if (role == GUEST_ROLE) {
                    totalMemberEvents += guestEvents[users[i]].length;
                }
            }
        }

        CalendarEvent[] memory allMemberEvents = new CalendarEvent[](totalMemberEvents);
        uint currentIndex = 0;

        if (role == GUEST_ROLE) {
            for (uint i = 0; i < memberCount; i++) {
                for (uint j = 0; j < guestEvents[memberAddresses[i]].length; j++) {
                    allMemberEvents[currentIndex] = guestEvents[memberAddresses[i]][j];
                    currentIndex++;
                }
            }
        } else {
            for (uint i = 0; i < memberCount; i++) {
                if (role == MEMBER_ROLE) {
                    for (uint j = 0; j < memberEvents[memberAddresses[i]].length; j++) {
                        allMemberEvents[currentIndex] = memberEvents[memberAddresses[i]][j];
                        currentIndex++;
                    }
                } else if (role == ADMIN_ROLE) {
                    for (uint j = 0; j < adminEvents[memberAddresses[i]].length; j++) {
                        allMemberEvents[currentIndex] = adminEvents[memberAddresses[i]][j];
                        currentIndex++;
                    }
                }
            }
        }

        return allMemberEvents;
    }

    function acceptInvitation(uint eventID) public {
        require(eventID < eventCreators.length, "Invalid event ID");
        address eventCreator = eventCreators[eventID];
        CalendarEvent[] storage events = userEvents[eventCreator];
        require(eventID < events.length, "Invalid event ID for this user");
        bool isInvited = false;
        for (uint i = 0; i < events[eventID].invitedAttendees.length; i++) {
            if (events[eventID].invitedAttendees[i] == msg.sender) {
                isInvited = true;
                break;
            }
        }
        require(isInvited, "You are not invited to this event");
        events[eventID].confirmedAttendees.push(msg.sender);
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

    function createEvent(string memory title, uint startTime, uint endTime, string memory metadataURI, address[] memory invitees) public {
        if (!hasRole(MEMBER_ROLE, msg.sender) && !hasRole(ADMIN_ROLE, msg.sender)) {
            _setupRole(GUEST_ROLE, msg.sender);
            guestCount++;
        }
        
        CalendarEvent memory newEvent;
        newEvent.eventId = userEvents[msg.sender].length;
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
            guests[msg.sender].eventIds.push(newEvent.eventId);
        }

        uint eventID = newEvent.eventId;
        totalEvents++;

        for (uint i = 0; i < invitees.length; i++) {
            eventInvitations[eventID].push(invitees[i]);
            emit UserInvited(eventID, title, invitees[i]);
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
