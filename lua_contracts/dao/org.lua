--[[
Voting Mechanism for DAO Token

This script implements a decentralized voting mechanism for adding new members to a DAO (Decentralized Autonomous Organization). The process is managed using a token system where members hold tokens and can vote on proposals to add new members.

Key Components:
1. Balances: A table that tracks the token balances of each member. Each member must have a positive balance to participate in the voting process.
2. AddRequests: A table that stores the details of all pending requests to add new members. Each request includes information about the new member to be added, the requester, the votes received, the voters, and the voting threshold.
3. Voting Threshold: A dynamic threshold calculated as 51% of the total token supply. A request to add a new member is approved if the total votes exceed this threshold.

Workflow:
1. Requesting to Add a New Member:
   - Only members with a positive balance can request to add a new member.
   - The requester must specify the address of the new member.
   - The request is identified using a unique message ID.
   - If the requester has previously made a request, the previous request is removed, and the requester is notified.
   - All members are notified of the new member request.

2. Voting on a Request:
   - Members with a positive balance can vote on pending requests.
   - Each member can vote only once on a particular request.
   - The vote value is proportional to the voter's token balance.
   - If the total votes exceed the voting threshold, the new member is added, and the requester's balance is deducted by 1 token.
   - If the requester's balance is insufficient after the vote, the request is canceled.

3. Viewing Balances and Requests:
   - Members can view their own token balance.
   - Members can retrieve the list of all current balances (only available to members).
   - Members can view the list of all pending add member requests.

Handlers:
- 'info': Provides DAO token information.
- 'balance': Returns the balance of the requesting member.
- 'getBalances': Returns the list of all balances (members only).
- 'requestAddMember': Handles requests to add new members.
- 'voteOnRequest': Handles voting on member addition requests.
- 'getAddRequests': Returns the list of all pending add member requests (members only).

This script ensures a fair and transparent voting process for managing membership in the DAO, leveraging token balances to determine voting power and thresholds.
]]

local bint = require('.bint')(256)
local ao = require('ao')
local json = require('json')

-- Initialize state
if not Balances then Balances = { [ao.id] = tostring(bint(10 * 1e12)) } end -- 10 tokens for the process
if not AddRequests then AddRequests = {} end -- Ledger for add requests

if Name ~= 'DAO Token' then Name = 'DAO Token' end
if Ticker ~= 'DAO' then Ticker = 'DAO' end
if Denomination ~= 12 then Denomination = 12 end

-- Helper function to check if an address is a member
local function isMember(address)
    return Balances[address] and tonumber(Balances[address]) > 0
end

-- Helper function to calculate total token supply
local function getTotalSupply()
    local total = bint(0)
    for _, balance in pairs(Balances) do
        total = bint.__add(total, bint(balance))
    end
    return total
end

-- Helper function to calculate voting threshold
local function getVotingThreshold()
    local totalSupply = getTotalSupply()
    return bint.__mul(totalSupply, bint(51)) / bint(100) -- 51% of total supply
end

-- Handler for getting DAO information
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    ao.send({
        Target = msg.From,
        Name = Name,
        Ticker = Ticker,
        Denomination = tostring(Denomination)
    })
end)

-- Handler for checking balance
Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
    local balance = Balances[msg.From] or "0"
    ao.send({
        Target = msg.From,
        Action = 'BalanceResult',
        Balance = balance,
        Data = "Your balance is " .. balance .. " " .. Ticker
    })
end)

-- Handler for getting list of Balances
Handlers.add('getBalances', Handlers.utils.hasMatchingTag('Action', 'GetBalances'), function(msg)
    if not isMember(msg.From) then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'Unauthorized: Only members can view the member list'
        })
        return
    end

    ao.send({
        Target = msg.From,
        Action = 'Balances',
        Data = json.encode(Balances)
    })
end)

-- Handler for requesting to add a new member
Handlers.add('requestAddMember', Handlers.utils.hasMatchingTag('Action', 'RequestAddMember'), function(msg)
    if not isMember(msg.From) then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'Unauthorized: Only members can request to add new members'
        })
        return
    end

    local newMember = msg.Tags.Member_To_Add
    if not newMember then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'Member_To_Add tag is required'
        })
        return
    end

    if isMember(newMember) then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'Address is already a member'
        })
        return
    end

    local requesterBalance = bint(Balances[msg.From] or "0")
    if bint.__lt(requesterBalance, bint(1 * 1e12)) then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'Insufficient balance to request adding a new member'
        })
        return
    end

    -- Check if the requester has already made a request and, if so, remove that request
    for id, request in pairs(AddRequests) do
        if request.requester == msg.From then
            AddRequests[id] = nil

            ao.send({
                Target = msg.From,
                Action = 'Notification',
                RequestId = id,
                Data = "Your previous request to add a new member has been removed."
            })
            break
        end
    end

    -- Use the message id as identifier
    AddRequests[msg.Id] = {
        newMember = newMember,
        requester = msg.From,
        votes = bint(0),
        voters = {},
        threshold = getVotingThreshold()
    }

    -- Notify all members about the new request
    for member, _ in pairs(Balances) do
        if tonumber(Balances[member]) > 0 then
            ao.send({
                Target = member,
                Action = 'NewMemberRequest',
                RequestId = msg.Id,
                NewMember = newMember,
                Requester = msg.From
            })
        end
    end

    ao.send({
        Target = msg.From,
        Action = 'RequestSubmitted',
        RequestId = msg.Id,
        NewMember = newMember,
        Data = "Request to add new member submitted successfully"
    })
end)

-- Handler for voting on a new member request
Handlers.add('voteOnRequest', Handlers.utils.hasMatchingTag('Action', 'VoteOnRequest'), function(msg)
    local requestId = msg.Tags.RequestId
    local vote = msg.Tags.Vote

    if not requestId or not vote then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'RequestId and Vote tags are required'
        })
        return
    end

    local request = AddRequests[requestId]
    if not request then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'Invalid request ID'
        })
        return
    end

    if request.voters[msg.From] then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'You have already voted on this request'
        })
        return
    end

    local voterBalance = bint(Balances[msg.From] or "0")
    if bint.__eq(voterBalance, bint(0)) then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'You must have a positive balance to vote'
        })
        return
    end

    if vote == "yes" then
        request.votes = bint.__add(request.votes, voterBalance)
    end
    request.voters[msg.From] = true

    if bint.__lt(request.threshold, request.votes) then
        -- Request approved, add new member
        Balances[request.newMember] = tostring(bint(2 * 1e12)) -- Equivalent to minting 1 token for the new member
        -- check if balance of requester is greater than 1
        local requesterBalance = bint(Balances[request.requester] or "0")
        if bint.__lt(requesterBalance, bint(1 * 1e12)) then
            ao.send({
                Target = msg.From,
                Action = 'Error',
                Error = 'Votes threshold passed, but the requester no longer has a satisfactory balance'
            })
            AddRequests[requestId] = nil
            return
        end

        Balances[request.requester] = tostring(bint.__sub(bint(Balances[request.requester]), bint(1 * 1e12))) -- Deduct 1 token from requester

        ao.send({
            Target = request.requester,
            Action = 'MemberAdded',
            NewMember = request.newMember,
            Data = "New member added successfully"
        })

        -- Remove the request
        AddRequests[requestId] = nil
    else
        ao.send({
            Target = msg.From,
            Action = 'VoteRecorded',
            RequestId = requestId,
            Data = "Your vote has been recorded"
        })
    end
end)

-- Handler for getting current add requests
Handlers.add('getAddRequests', Handlers.utils.hasMatchingTag('Action', 'GetAddRequests'), function(msg)
    if not isMember(msg.From) then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'Unauthorized: Only members can view add requests'
        })
        return
    end

    local requestsInfo = {}
    for id, request in pairs(AddRequests) do
        requestsInfo[id] = {
            newMember = request.newMember,
            requester = request.requester,
            votes = tostring(request.votes),
            threshold = tostring(request.threshold)
        }
    end

    ao.send({
        Target = msg.From,
        Action = 'AddRequestsList',
        Data = json.encode(requestsInfo)
    })
end)