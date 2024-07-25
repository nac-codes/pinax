local json = require('json')

-- Initialize the Members table with initial members, including the current process
Members = Members or {
    ao.id
}

-- Function to check if an address is a member
local function isMember(address)
    for _, member in ipairs(Members) do
        if member == address then
            return true
        end
    end
    return false
end

-- Handler for adding new members
Handlers.add(
    "AddMember",
    Handlers.utils.hasMatchingTag("Action", "AddMember"),
    function(msg)
        if not isMember(msg.From) then
            ao.send({
                Target = msg.From,
                Data = "Request rejected: Not authorized",
                Action = "AddMemberResponse"
            })
            return
        end

        local newMemberAddress = msg.Tags.Member_To_Add
        if not newMemberAddress then
            ao.send({
                Target = msg.From,
                Data = "Please provide a valid address in the Member_To_Add tag",
                Action = "AddMemberResponse"
            })
            return
        end

        if isMember(newMemberAddress) then
            ao.send({
                Target = msg.From,
                Data = "Address is already a member",
                Action = "AddMemberResponse"
            })
            return
        end

        table.insert(Members, newMemberAddress)
        print("Member added: " .. newMemberAddress)
        ao.send({
            Target = msg.From,
            Data = "Member added: " .. newMemberAddress,
            Action = "AddMemberResponse"
        })
    end
)

Handlers.add(
    "GetMembers",
    Handlers.utils.hasMatchingTag("Action", "GetMembers"),
    function(msg)
        local memberList = {
            status = "success",
            message = "Current members list",
            members = Members
        }
        local encodedMemberList = json.encode(memberList)
        ao.send({
            Target = msg.From,
            Data = encodedMemberList,
            Action = "MemberListResponse"
        })
    end
)

-- Handler to remove a member (only executable by existing members)
Handlers.add(
    "RemoveMember",
    Handlers.utils.hasMatchingTag("Action", "RemoveMember"),
    function(msg)
        if not isMember(msg.From) then
            ao.send({
                Target = msg.From,
                Data = "Request rejected: Not authorized",
                Action = "RemoveMemberResponse"
            })
            return
        end

        local memberToRemove = msg.Tags.Member_To_Remove
        if not memberToRemove then
            ao.send({
                Target = msg.From,
                Data = "Please provide a valid address in the Member_To_Remove tag",
                Action = "RemoveMemberResponse"
            })
            return
        end

        if not isMember(memberToRemove) then
            ao.send({
                Target = msg.From,
                Data = "Address is not a current member",
                Action = "RemoveMemberResponse"
            })
            return
        end

        for i, member in ipairs(Members) do
            if member == memberToRemove then
                table.remove(Members, i)
                break
            end
        end

        print("Member removed: " .. memberToRemove)
        ao.send({
            Target = msg.From,
            Data = "Member removed: " .. memberToRemove,
            Action = "RemoveMemberResponse"
        })
    end
)

-- Handler to check if user is authorized, sends a message back true if authorized, false if not
Handlers.add(
    "CheckAuthorization",
    Handlers.utils.hasMatchingTag("Action", "CheckAuthorization"),
    function(msg)
        local authorized = isMember(msg.From)
        ao.send({
            Target = msg.From,
            Data = tostring(authorized),
            Action = "CheckAuthorizationResponse"
        })
    end
)