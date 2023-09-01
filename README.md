# Dev Log

## Solidity Contract Events

- **NewEventCreated**: This event is emitted when a new event is created. It includes the new event Id, title, organizer address, start time, end time, metadata URI, the timestamp of when the event was created, and the role of the creator.

*Note:* The `indexed` keyword is used for parameters in these events to allow for more efficient filtering when these events are searched for in the transaction log history.


## Constructor
- Set `calendarOwner - msg.sender`
- Set `ADMIN_ROLE`
- Set `MEMBER_ROLE`
- Set `GUEST_ROLE`

## Create Calendar Event

**createEvent**
- Title: test event
- Start: 1688449051
- End: 1688449051
- Metadata: [Link](https://gateway.pinata.cloud/ipfs/QmWnDhTrUkddy4njjRBUKE4EA3uds2qkdGWPB3yBfjPJSQ)
- Invitees: ["0x8406A51A0E1B5F52Ff61226773e6328e5Da5d964","0xBbE028eFf077cE1C2a8E635a38946aA80994eB87"]

Event created successfully. Event emitted event successfully.

**NewEventCreated**
- eventID (uint256): 0
- title (string): Am I still here?
- organizer (address): 0x8406A51A0E1B5F52Ff61226773e6328e5Da5d964
- startTime (uint256): 1688449051
- endTime (uint256): 1688449051
- metadataURI (string): [Link](https://gateway.pinata.cloud/ipfs/QmWnDhTrUkddy4njjRBUKE4EA3uds2qkdGWPB3yBfjPJSQ)
- timestamp (uint256): 1688433871
- role (bytes32): 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775 (admin)

## Add Member
Admin can add member address, the member count counter adds +1 and the member role is set to `MEMBER_ROLE`

## Grant Guest Role
Admin can add guest user role

## Non-Role User Can Create Event Without Role
`GUEST_ROLE` is assigned to non-role assigned user. Guest can create event.

**hasRole**
- Input role address i.e. `MEMBER_ROLE = 0x829b824e2329e205435d941c9f13baf578548505283d29261236d8e6596d4636`
- Input address of member
- Returns boolean true/false

**getAllMemberAddresses**
- Returns array of organizer addresses

**getAllMemberEvents**
- Returns tuple: tuple(uint256,string,address,uint256,uint256,uint256,string,address[],address[])[]: 0, title Demo Member test, 0xBbE028eFf077cE1C2a8E635a38946aA80994eB87, 1688701043, 1688787443, 1688525744, [Link](https://gateway.pinata.cloud/ipfs/QmWnDhTrUkddy4njjRBUKE4EA3uds2qkdGWPB3yBfjPJSQ), 0x8406A51A0E1B5F52Ff61226773e6328e5Da5d964, 0xBbE028eFf077cE1C2a8E635a38946aA80994eB87
