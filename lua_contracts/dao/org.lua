local bint = require('.bint')(256)
local ao = require('ao')
local json = require('json')

-- Initialize state
if not Balances then Balances = { [ao.id] = tostring(bint(10 * 1e12)) } end -- 10 tokens for the process
if not Members then Members = { ao.id } end -- Process is the initial member

if Name ~= 'DAO Token' then Name = 'DAO Token' end
if Ticker ~= 'DAO' then Ticker = 'DAO' end
if Denomination ~= 12 then Denomination = 12 end

-- Helper function to check if an address is a member
local function isMember(address)
    return Balances[address] and tonumber(Balances[address]) > 0
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

-- Handler for getting member list
Handlers.add('getMembers', Handlers.utils.hasMatchingTag('Action', 'GetMembers'), function(msg)
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
        Action = 'MemberList',
        Data = json.encode(Members)
    })
end)

-- Handler for adding a new member
Handlers.add('addMember', Handlers.utils.hasMatchingTag('Action', 'AddMember'), function(msg)
    if not isMember(msg.From) then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'Unauthorized: Only members can add new members'
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

    -- Transfer 1 token to the new member
    local senderBalance = bint(Balances[msg.From] or "0")
    if bint.__lt(senderBalance, bint(1 * 1e12)) then
        ao.send({
            Target = msg.From,
            Action = 'Error',
            Error = 'Insufficient balance to add a new member'
        })
        return
    end

    Balances[msg.From] = tostring(bint.__sub(senderBalance, bint(1 * 1e12)))
    --when a new member is added a single token is essentailly minted, allows the dao to grow
    Balances[newMember] = tostring(bint(2 * 1e12))
    table.insert(Members, newMember)

    ao.send({
        Target = msg.From,
        Action = 'MemberAdded',
        NewMember = newMember,
        Data = "New member added successfully"
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