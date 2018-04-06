pragma solidity ^0.4.16;

interface Owned {
    function getOwner() constant external returns (address contractOwner);
}

contract Citizens {
    
    // Contract Variables and events
    mapping (address => uint) public memberId;
    uint public numCitizens;
    Member[] public members;
    Owned public sharesOwnedAddress;

    event MembershipChanged(address member, bool isMember);
   
    struct Member {
        address member;
        string name;
        uint memberSince;
    }
    
    function getCitizen(address _citizen) constant public returns(uint citizenId){
        uint id = memberId[_citizen];
        return id;
    }

    /**
     * Constructor function
     */
    function Citizens (Owned ownedAddress)  public {
        sharesOwnedAddress = Owned(ownedAddress);
        // It’s necessary to add an empty first member
        addMember(0, "");
        numCitizens = 0;
        // and let's add the founder, to save a step later
        addMember(sharesOwnedAddress.getOwner(), 'Founder');
    }

    /**
     * Add member
     *
     * Make `targetMember` a member named `memberName`
     *
     * @param targetMember ethereum address to be added
     * @param memberName public name for that member
     */
    function addMember(address targetMember, string memberName) public {
        require(memberId[targetMember] == 0);
        if (targetMember != 0){
            require(msg.sender == targetMember);
        }
        uint id = memberId[targetMember];
        memberId[targetMember] = members.length;
        id = members.length++;
        Member storage m = members[id];
        m.member = targetMember;
        m.memberSince = now;
        m.name = memberName;
        MembershipChanged(targetMember, true);
        numCitizens += 1;
    }

    function editMember(address targetMember, string newName) public {
        require(memberId[targetMember] != 0
            && msg.sender == targetMember);
        uint id = memberId[targetMember];
        Member storage m = members[id];
        m.name = newName;
        MembershipChanged(targetMember, true);
    }
    /**
     * Remove member
     *
     * @notice Remove membership from `targetMember`
     *
     * @param targetMember ethereum address to be removed
     */
    function removeMember(address targetMember) public {
        require(memberId[targetMember] != 0
            && msg.sender == targetMember);
        uint id = memberId[targetMember];
        delete members[id];
        delete memberId[targetMember];
    }

}