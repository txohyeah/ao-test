local bint = require('.bint')(256)

local utils = {
    add = function (a,b) 
      return tostring(bint(a) + bint(b))
    end,
    subtract = function (a,b)
      return tostring(bint(a) - bint(b))
    end,
    toBalanceValue = function (a)
      return tostring(bint(a))
    end,
    toNumber = function (a)
      return tonumber(a)
    end
}

--[Not-Started] -> Waiting -> Playing -> [Game end] -> Waiting...
--游戏被手动开启或者停止
GameMode = GameMode or "Not-Started"
StateChangeTime = StateChangeTime or nil

-- run round
Round = Round or 0

-- Wuzhu Token 的unit
UNIT = 1000

WaitTimeAfterReady = WaitTimeAfterReady or 5 * 60 * 1000 -- 5 minutes
Now = Now or nil -- Current time, updated on every message.

-- 所有玩家
Listeners = Listeners or {}

-- 马匹
Horses = Horses or {
    "Dilu",
    "BlackShadow",
    "Chitu",
    "YellowLighting"
}

-- 到终点的马
HorseWinner = HorseWinner or {}

--[[赌注 
Staking: {
    "StakingTotalAmount": 1000000,
    "StakingPool": {
        "Dilu": {
            "pid1": "staking amount1",
            "pid2": "staking amount2",
            ...
        },
        "BlackShadow": {
            "pid3": "staking amount3"
        }
        ...
    },
    "StakingRatioHorse": {
        "Dilu": ratioDilu,
        ...
    },
    "StakingRatioHorsePlayer": {
        "Dilu": {
            "pid1": ratio1,
            "pid2": ratio2
            ...
        },
        ...
    }
  }
]]
Staking = Staking or {}

StakingPool = StakingPool or nil

StakingRatio = StakingRatio or {
    ["Dilu"] = 0,
    ["BlackShadow"] = 0,
    ["Chitu"] = 0,
    ["YellowLighting"] = 0
}

-- 赛马的状态。 ultimateSkill 大招，distance 已经跑了多远
HorseStatus = HorseStatus or {
    ["Dilu"] = {
        ["ultimateSkill"] = true,
        ["distance"] = 0
    },
    ["BlackShadow"] = {
        ["ultimateSkill"] = true,
        ["distance"] = 0
    },
    ["Chitu"] = {
        ["ultimateSkill"] = true,
        ["distance"] = 0
    },
    ["YellowLighting"] = {
        ["ultimateSkill"] = true,
        ["distance"] = 0
    }
}

------- function -------



-- Sends a state change announcement to all registered listeners.
-- @param event: The event type or name.
-- @param description: Description of the event.
local function announce(event, description)
    for ix, address in pairs(Listeners) do
        ao.send({
            Target = address,
            Action = "Announcement",
            Event = event,
            Data = description
        })
    end
    return print(Colors.gray .. "Announcement: " .. Colors.red .. event .. " " .. Colors.blue .. description .. Colors.reset)
end

-- Sends a reward to a player.
-- @param recipient: The player receiving the reward.
-- @param qty: The quantity of the reward.
-- @param reason: The reason for the reward.
local function sendReward(recipient, qty, reason)
    if type(qty) ~= number then
      qty = tonumber(qty)
    end
    ao.send({
        Target = ao.id,
        Action = "Transfer",
        Quantity = tostring(qty),
        Recipient = recipient,
        Reason = reason
    })
    return print(Colors.gray .. "Sent Reward: " ..  
      Colors.blue .. tostring(qty) .. 
      Colors.gray .. ' tokens to ' ..  
      Colors.green .. recipient .. " " ..
      Colors.blue .. reason .. Colors.reset
    )
end

-- 一个玩家参与以后，会等待5分钟开始赛马。
local function startWaitingPeriod(player)
    GameMode = "Waiting"
    StateChangeTime = Now + WaitTimeAfterReady
    if player then
        announce("Started-Waiting-Period", player .. "is staking in the game. Waiting time is refresh.")
    else
        announce("Started-Waiting-Period", "Lack of staking. Waiting time is refresh.")
    end
end

-- 开始游戏
local function startRacingPeriod()
    GameMode = "Playing"
    initStaking()
    ao.send({Target = ao.id, Action = "HorseTicker"})
end


-- 是否满足开始游戏的条件(StakingPool为nil，即没有一个人质押)，如果不满足则进入下一个等待期。
local function startRacingFlag()
    if StakingPool then
        return true
    else
        return false
    end
end

-- 参加游戏后，加入到Listeners列表中
local function attendGame(player)
    table.insert(Listeners, player)
end

-- Removes a listener from the listeners' list.
-- @param listener: The listener to be removed.
local function removeListener(listener)
    local idx = 0
    for i, v in ipairs(Listeners) do
        if v == listener then
            idx = i
            break
        end
    end
    if idx > 0 then
        table.remove(Listeners, idx)
    end 
end

-- 退出比赛，从Listeners和PlayerAttended中删除
local function retire(player)
    if GameMode == "Playing" then
        ao.send({
            Target = player, 
            Action = "Fail-Retired", 
            Data = "You can not retire during playing period."
        })
    else
        ao.send({
            Target = player, 
            Action = "Retired", 
            Data = "Retired"
        })
        removeListener(player)
    end
end




--[[
    从赌注池，初始化赌注信息
    1. 一共多少赌注
    2. 每匹马的赌注比例
]]
function initStaking()
    HorseWinner = {}
    if StakingPool == nil then
        print(Colors.red .. "StakingPool is nil. initStaking failed." .. Colors.reset)
        return
    end

    local stakingTotalAmount = 0
    for _, staking in pairs(StakingPool) do
        for _, amount in pairs(staking) do
            stakingTotalAmount = stakingTotalAmount + tonumber(amount)
        end
    end

    Staking.StakingTotalAmount = stakingTotalAmount
    Staking.StakingPool = StakingPool

    if stakingTotalAmount == 0 then
        print(Colors.red .. "No tokens in the staking pool." .. Colors.reset)
        return
    end

    Staking["StakingRatioHorse"] = {}
    for horseId, staking in pairs(StakingPool) do
        local horseAmount = 0
        for _, amount in pairs(staking) do
            horseAmount = horseAmount + tonumber(amount)
        end

        if not Staking["StakingRatioHorse"][horseId] then
            Staking["StakingRatioHorse"][horseId] = 0
        end
        Staking["StakingRatioHorse"][horseId] = horseAmount / stakingTotalAmount
    end
end

-- 游戏结束时，重新设置游戏状态
local function reset()
    HorseWinner = {}
    Staking = {}
    StakingPool = nil
    StakingRatio = {
        ["Dilu"] = 0,
        ["BlackShadow"] = 0,
        ["Chitu"] = 0,
        ["YellowLighting"] = 0
    }
    HorseStatus = {
        ["Dilu"] = {
            ["ultimateSkill"] = true,
            ["distance"] = 0
        },
        ["BlackShadow"] = {
            ["ultimateSkill"] = true,
            ["distance"] = 0
        },
        ["Chitu"] = {
            ["ultimateSkill"] = true,
            ["distance"] = 0
        },
        ["YellowLighting"] = {
            ["ultimateSkill"] = true,
            ["distance"] = 0
        }
    }
end

-- 统计所有马赛跑时需要的质押比例(占比不超过70%，不小于10%)
local function calStakingRatioForRunning(ratio)
    if ratio == nil then
        return 0
    end

    if ratio > 0.7 then
        return 0.7
    end

    if ratio < 0.1 then
        return 0.1
    end

    return ratio
end

-- 判断p是不是存在的horse
local function isHorse(p)
    for _, horse in ipairs(Horses) do
        if p == horse then
            return true
        end
    end
    return false
end

-- 判断马匹p 是否释放大招。 没有释放过，则有20%的概率释放
local function ultimateSkill(state)
    if not state["ultimateSkill"] then
        return false
    end

    if math.random() > 0.8 then
        state["ultimateSkill"] = false
        return true
    end

    return false
end

--[[ 
玩家质押赌注
1. 玩家选择马匹进行质押
2. 如果没有选择马匹，或者输入名称有误，则随机选择一个马匹
3. 质押范围：0.1 - 10 token（参数表示为 10 ~ 10000）
]]
function staking(player, horse, amount)
    if not isHorse(horse) then
        horse = Horses[math.random(1, #Horses)]
    end

    if StakingPool == nil then
        StakingPool = {}
    end

    if StakingPool[horse] == nil then
        StakingPool[horse] = {}
    end

    if not StakingPool[horse][player] then
        StakingPool[horse][player] = 0
    end

    StakingPool[horse][player] = StakingPool[horse][player] + amount
    announce("Staking", "Player: " .. player .. " staked " .. tostring(StakingPool[horse][player]) .. " token on horse " .. horse)
end

--[[
    计算一回合的赛马
1. 判断是否要释放大招。
2. 计算每一批马的distance结果。
3. 判断有没有马匹赢了。如果没有到达终点的马匹，则进行下一个Ticker
return: false - 没有结束; true - 比赛结束；
]]
function horsesRun()
    if #HorseWinner ~= 0 then
        print("The winner has emerged! Pass this ticker.")
        return true
    end

    for horseId, state in pairs(HorseStatus) do
        local ratio = calStakingRatioForRunning(Staking["StakingRatioHorse"][horseId])

        if ultimateSkill(state) then
            state["distance"] = state["distance"] + 5 * math.ceil(math.random() * 3 * ratio)
        else
            state["distance"] = state["distance"] + math.ceil(math.random() * 3 * ratio)
        end

        if state["distance"] > 20 then
            table.insert(HorseWinner, horseId)
        end
    end
    
    if #HorseWinner == 0 then
        local json = require("json")
        local HorseStatusJson = json.encode({HorseStatus})
        announce("HorseStatus", HorseStatusJson)
        ao.send({Target = ao.id, Action = "HorseTicker"})
    else
        local winnerStr = ""
        for _, winner in ipairs(HorseWinner) do
            winnerStr = winnerStr .. winner .. " "
        end
        announce("Game Over", "The winners is :" .. winnerStr)
        return true
    end
    return false
end


-- 赛马结束. 
-- send reward to players who choose the correct horse. set game mode to waiting.
local function endGame()
    print("Game Over")

    -- 胜利马匹的总质押数量
    local winnerPlayerStakingAmount = 0
    -- 胜利马匹的质押列表
    --[[
        winnerPlayerStaking: {
            pid: amount
            ...
        }
    ]]
    local winnerPlayerStaking = {}

    -- 胜利玛丽的质押者所获得的奖励列表
    --[[
        winnerPlayerReward: {
            pid: amount
            ...
        }
    ]]
    local winnerPlayerReward = {}
    
    -- 计算到达终点的马匹对应的押注人，所质押的列表。
    -- 如果一个人质押了多匹到达终点的马，会在列表中合并。
    for _, horseId in ipairs(HorseWinner) do
        for pid, amount in pairs(StakingPool[horseId]) do
            winnerPlayerStakingAmount = winnerPlayerStakingAmount + tonumber(amount)
            if not winnerPlayerStaking[pid] then
                winnerPlayerStaking[pid] = 0
            end
            winnerPlayerStaking[pid] = winnerPlayerStaking[pid] + amount
        end
    end

    -- 计算每个玩家分到的钱（除不尽剩余的部分会留在游戏的Process中）
    for pid, amount in pairs(winnerPlayerStaking) do
        local ratio = amount / winnerPlayerStakingAmount
        winnerPlayerReward[pid] = math.floor(Staking.StakingTotalAmount * ratio)
    end

    -- 给每个赢家发送奖励 
    for pid, amount in pairs(winnerPlayerReward) do
        print(pid .. " receiving " .. amount .. " coins")
        sendReward(pid, amount, "Win")
    end

    reset()

    startWaitingPeriod()
end


-------------------- handlers --------------------

-- Handlers
-- 参加赛马
Handlers.add(
    "AttendHorseRacingGame",
    Handlers.utils.hasMatchingTag("Action", "JumpInto"),
    function (Msg)
        if GameMode == "Not-Started" then
            ao.send({
                Target = Msg.From, 
                Action="Off-Season-Notice", 
                Data="You can call the host to start the game."
            })
        elseif GameMode == "Waiting" then
            attendGame(Msg.From)
            announce("Welcome", "Welcome to 3 kingdoms arena. Enjoy your horse racing game.")
            print(Colors.gray .. Msg.From .. " is attending the game." .. Colors.reset)
        end
    end
)


-- 通过RequestWuzhu获取三国五铢钱
Handlers.add(
    "RequestWuzhu",
    Handlers.utils.hasMatchingTag("Action", "RequestWuzhu"),
    function (Msg)
        print("Transfering Tokens: " .. tostring(math.floor(10000 * UNIT)))
        ao.send({
            Target = ao.id,
            Action = "Transfer",
            Quantity = tostring(math.floor(10000 * UNIT)),
            Recipient = Msg.From
        })
    end
)

-- Handler for cron messages, manages game state transitions.
Handlers.add(
    "Game-State-Timers",
    function(Msg)
        print("Game-State-Timers From:" .. Msg.From)
        return Msg.Action == "HorseTicker" and "continue"
    end,
    function(Msg)
        Now = Msg.Timestamp
        if GameMode == "Waiting" then
            if Now >= StateChangeTime then
                -- 满足条件，则启动比赛;不满足，则刷新等待时间
                if startRacingFlag() then
                    startRacingPeriod()
                else
                    startWaitingPeriod()
                end
            end
        end
    end
)

-- 开启游戏
Handlers.add(
    "StartGame",
    function (Msg)
        return Msg.Action == "Launched" and Msg.From == ao.id
    end,
    function (Msg)
        Now = Msg.Timestamp
        print("Three kingdoms Horse racing is launched.")
        startWaitingPeriod()
    end
)

-- 关闭游戏
Handlers.add(
    "HandleShutDown",
    function (Msg)
        return Msg.Action == "ShutDown" and Msg.From == ao.id
    end,
    function (Msg)
        if GameMode == "Waiting" then
            print("Three kingdoms Horse racing is shutting down.")
            GameMode = "Not-Started"
            StateChangeTime = 0
            Listeners = {}
            announce("ShutDown", "Game is shutting down.")
        else
            print("Three kingdoms Horse racing is playing. Please try again during Waiting period.")
        end  
    end
)

-- 玩家退休
Handlers.add(
    "HandleRetire",
    Handlers.utils.hasMatchingTag("Action", "Retire"),
    function (Msg)
        retire(Msg.From)
    end
)

--[[ 
只能在 GameMode = Waiting 时进行赌注的质押
staking完成以后，刷新等待时间
]]
Handlers.add(
    "HandleStaking",
    function (msg)
        return msg.Action == "StakingHorse" --and msg.Target == PaymentTokenAddr
    end,
    function(msg)
        if GameMode == "Playing" then
            ao.send({
                Target = msg.From, 
                Action = "Fail-Staking", 
                Data = "Game is playing. Please staking during the waiting period."
            })
            return
        end

        assert(type(msg.Recipient) == 'string', 'Recipient is required!')
        assert(type(msg.Quantity) == 'string', 'Quantity is required!')
        assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')

        if not Balances[msg.From] then Balances[msg.From] = "0" end
        if not Balances[msg.Recipient] then Balances[msg.Recipient] = "0" end

        if bint(msg.Quantity) <= bint(Balances[msg.From]) then
            Balances[msg.From] = utils.subtract(Balances[msg.From], msg.Quantity)
            Balances[msg.Recipient] = utils.add(Balances[msg.Recipient], msg.Quantity)
            
            if not msg.Cast then
                -- Debit-Notice message template, that is sent to the Sender of the transfer
                local debitNotice = {
                  Target = msg.From,
                  Action = 'Debit-Notice',
                  Recipient = msg.Recipient,
                  Quantity = msg.Quantity,
                  Data = Colors.gray ..
                      "You transferred " ..
                      Colors.blue .. msg.Quantity .. Colors.gray .. " to " .. Colors.green .. msg.Recipient .. Colors.reset
                }
                -- Credit-Notice message template, that is sent to the Recipient of the transfer
                local creditNotice = {
                  Target = msg.Recipient,
                  Action = 'Credit-Notice',
                  Sender = msg.From,
                  Quantity = msg.Quantity,
                  Data = Colors.gray ..
                      "You received " ..
                      Colors.blue .. msg.Quantity .. Colors.gray .. " from " .. Colors.green .. msg.From .. Colors.reset
                }
          
                -- Add forwarded tags to the credit and debit notice messages
                for tagName, tagValue in pairs(msg) do
                  -- Tags beginning with "X-" are forwarded
                  if string.sub(tagName, 1, 2) == "X-" then
                    debitNotice[tagName] = tagValue
                    creditNotice[tagName] = tagValue
                  end
                end
          
                -- Send Debit-Notice and Credit-Notice
                ao.send(debitNotice)
                ao.send(creditNotice)
            end
        else
            ao.send({
              Target = msg.From,
              Action = 'Transfer-Error',
              ['Message-Id'] = msg.Id,
              Error = 'Insufficient Balance!'
            })
        end

        local player = msg.From
        local horse = msg.Horse
        local amount = tonumber(msg.Quantity)
        print(msg.From)
        print(msg.Horse)
        print(msg.Quantity)
        staking(player, horse, amount)
        startWaitingPeriod(msg.From)
    end
)

--[[
    每个回合，公告游戏状态
]]
Handlers.add(
    "HandleTicker",
    function (msg)
        return msg.Action == "HorseTicker" and "continue"
    end,
    function (msg)
        if GameMode ~= "Playing" then
            print("HandleTicker, Game is not playing. Ticker From " .. msg.From)
            return
        end

        if horsesRun() then
            endGame()
        end
    end
)