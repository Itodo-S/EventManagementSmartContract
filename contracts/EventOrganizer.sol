// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EventOrganizer is Ownable {
    address nftCollectionAddress;
    uint256 public totalEventsCreated;

    constructor() Ownable(msg.sender) {}

    struct AttendanceRecord {
        address attendee;
        uint256 checkInTimestamp;
    }

    struct OrganizedEvent {
        uint256 eventId;
        string eventName;
        string location;
        string details;
        address organizer;
        uint256 startTime;
        uint256 endTime;
        uint256 creationTimestamp;
        uint256 maxParticipants;
        bool isRegistrationClosed;
        bool isEventCancelled;
        address nftRequired;
        address[] participants;
        AttendanceRecord[] attendanceRecords;
    }

    mapping(uint256 => OrganizedEvent) public eventRegistry;
    mapping(address => mapping(uint256 => bool)) public userRegistrations;

    // Events
    event EventCreated(uint256 indexed eventId, address organizer);
    event UserRegistered(uint256 indexed eventId, address user);
    event UserCheckedIn(uint256 indexed eventId, address user);
    event EventCancelled(uint256 indexed eventId);

    // Modifiers
    modifier eventExists(uint256 eventId) {
        require(eventRegistry[eventId].eventId > 0, "Event does not exist");
        _;
    }

    modifier onlyOrganizer(uint256 eventId) {
        require(isEventOrganizer(eventId), "Not the event organizer");
        _;
    }

    // Create a new event
    function createEvent(
        address _nftRequired,
        string memory _eventName,
        string memory _location,
        string memory _details,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxParticipants
    ) external returns (uint256) {
        require(msg.sender != address(0), "InvalidAddress");
        require(_nftRequired != address(0), "InvalidNFTAddress");
        require(!_isEmpty(_eventName), "EventNameRequired");
        require(!_isEmpty(_location), "LocationRequired");
        require(!_isEmpty(_details), "DetailsRequired");
        require(_startTime < _endTime, "InvalidStartTime");
        require(_maxParticipants > 0, "MaxParticipantsRequired");

        uint256 eventId = ++totalEventsCreated;
        OrganizedEvent storage newEvent = eventRegistry[eventId];
        newEvent.eventId = eventId;
        newEvent.eventName = _eventName;
        newEvent.location = _location;
        newEvent.details = _details;
        newEvent.organizer = msg.sender;
        newEvent.startTime = _startTime;
        newEvent.endTime = _endTime;
        newEvent.creationTimestamp = block.timestamp;
        newEvent.nftRequired = _nftRequired;
        newEvent.maxParticipants = _maxParticipants;

        emit EventCreated(eventId, msg.sender);
        return eventId;
    }

    // Retrieve event participants
    function getEventParticipants(
        uint eventId
    ) external view returns (address[] memory) {
        require(isEventOrganizer(eventId), "NotOrganizer");
        require(eventRegistry[eventId].eventId >= 1, "InvalidEventId");

        return eventRegistry[eventId].participants;
    }

    // Sign up for an event
    function registerForEvent(uint256 eventId) external eventExists(eventId) {
        require(eventRegistry[eventId].eventId >= 1, "InvalidEventId");
        require(!userRegistrations[msg.sender][eventId], "AlreadyRegistered");
        require(
            !eventRegistry[eventId].isRegistrationClosed,
            "RegistrationClosed"
        );
        require(!eventRegistry[eventId].isEventCancelled, "EventCancelled");

        address nftRequired = eventRegistry[eventId].nftRequired;
        require(
            hasRequiredNFT(nftRequired, msg.sender) >= 1,
            "NFTRequiredForEvent"
        );

        eventRegistry[eventId].participants.push(msg.sender);
        userRegistrations[msg.sender][eventId] = true;
        
        emit UserRegistered(eventId, msg.sender);
    }

    // Record attendance for an event
    function checkInForEvent(
        uint eventId,
        address participant
    ) external eventExists(eventId) onlyOrganizer(eventId) returns (bool) {
        require(userRegistrations[participant][eventId], "User not registered");
        
        for (uint i = 0; i < eventRegistry[eventId].attendanceRecords.length; i++) {
            if (eventRegistry[eventId].attendanceRecords[i].attendee == participant) {
                return false; // User already checked in
            }
        }

        eventRegistry[eventId].attendanceRecords.push(AttendanceRecord({
            attendee: participant,
            checkInTimestamp: block.timestamp
        }));

        emit UserCheckedIn(eventId, participant);
        return true;
    }

    // Terminate an event
    function cancelEvent(uint256 eventId) external eventExists(eventId) onlyOrganizer(eventId) {
        require(!eventRegistry[eventId].isEventCancelled, "Event already cancelled");
        eventRegistry[eventId].isEventCancelled = true;
        emit EventCancelled(eventId);
    }

    // Verify if a string is empty
    function _isEmpty(string memory str) internal pure returns (bool) {
        return bytes(str).length == 0;
    }

    // Verify NFT ownership for event participation
    function hasRequiredNFT(
        address _nftCollection,
        address user
    ) public view returns (uint) {
        return IERC721(_nftCollection).balanceOf(user);
    }

    // Confirm if the sender is the event organizer
    function isEventOrganizer(uint256 eventId) internal view returns (bool) {
        return eventRegistry[eventId].organizer == msg.sender;
    }
}
