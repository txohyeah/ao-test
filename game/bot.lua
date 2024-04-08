-- 策略：
-- 寻找到可以一击必杀的敌人 player.heath < me.energy * 2/3。
-- 移动到敌人附近，并攻击敌人。
-- 如果没有击杀，在没有能量的时候，随机移动。


-- 初始化全局变量来存储最新的游戏状态和游戏主机进程。
LatestGameState = LatestGameState or nil
InAction = InAction or false -- 防止代理同时采取多个操作。

-- 目标敌人的process id，为nil则为暂时没有目标
LockingTarget = nil
-- 因此测试的ao-effect中，没人主动战斗，因此如果超过5个轮次没有人战斗，那么我们主动求战
Times = 0

DirectionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}

Colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

-- 自己是否在游戏中
function isInGame()
  for pid, player in pairs(LatestGameState.Players) do
    if pid == ao.id then
      return true
    end
  end
  return false
end

-- 检查两个点是否在给定范围内。
-- @param x1, y1: 第一个点的坐标
-- @param x2, y2: 第二个点的坐标
-- @param range: 点之间允许的最大距离
-- @return: Boolean 指示点是否在指定范围内
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- 根据玩家和目标状态判断是否进入战斗状态。
function isFight(me, player)
  return player.health < me.energy * 2/3
end

-- 根据玩家和目标状态判断是否逃跑。
function isEscape(me, player)
  return player.energy * 2/3 > me.health
end

-- 锁定最弱的敌人（首先，血量最小并且血量小于66；其次，能量最小；）
function findWeakPlayer()
  local heathValue = 66
  local energyValue = 100
  local weakPlayer = nil
  for pid, player in pairs(LatestGameState.Players) do
    if pid ~= ao.id and player.health < heathValue then
      heathValue = player.health
      energyValue = player.energy
      weakPlayer = pid
    elseif player.health == heathValue and player.energy < energyValue then
      weakPlayer = pid
    end
  end
  
  LockingTarget = weakPlayer
end

-- 如果两个玩家在不同半场，则按照反向计算方向
function adjustPosition(n1, n2)
  if n1 < 20 and n2 >= 20 then
    n2 = n2 - 40
  end

  if n1 >= 20 and n2 < 20 then
    n1 = n1 - 40
  end

  return n1, n2
end

-- 找到 player 1 接近 player 2 的方向
local function getDirections(x1, y1, x2, y2)
  x1, x2 = adjustPosition(x1, x2)
  y1, y2 = adjustPosition(y1, y2)

  local dx, dy = x2 - x1, y2 - y1
  local dirX, dirY = "", ""
  if dx > 0 then dirX = "Right" else dirX = "Left" end
  if dy > 0 then dirY = "Down" else dirY = "Up" end
  print(dirY .. dirX)
  return dirY .. dirX
end

-- 向目标移动，在攻击范围，则进行攻击
function moveToTarget(me, player)
  if inRange(me.x, me.y, player.x, player.y, 1) then
    ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(me.energy)})
    print(Colors.red .. "Target in range, Attacking!" .. Colors.reset)
  end

  -- 攻击以后，要尽量移动，避免被反击
  local moveDir = getDirections(me.x, me.y, player.x, player.y)
  print(Colors.red .. "Move " .. moveDir .. Colors.reset)
  ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = moveDir})
end

-- 随机移动
function randomMove()
  print("Moving randomly.")
  local randomIndex = math.random(#DirectionMap)
  ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = DirectionMap[randomIndex]})
end

-- TestCode: 随机选取一个目标玩家
function chooseRandomTarget()
  for pid, _ in pairs(LatestGameState.Players) do
    if pid ~= ao.id then
        LockingTarget = pid
        break
    end
  end
end

--#region 决策
-- 1. 存在目标，判断是否可以与之一战。是，则接近目标，并发起攻击
-- 2. 在1为否的情况下，四周是否存在有威胁的敌人。是，则逃离敌人
-- 3. 在2为否的情况下，随机移动
--#endregion
function decideNextAction()

  --#region test
  -- Times = Times + 1
  
  -- print("Round: " .. Times)
  -- if LockingTarget == nil and Times < 3 then
  --   print("No target. Move randomly. Waiting for " .. Times)
  --   randomMove()
  --   return
  -- else
  --   chooseRandomTarget()
  --   local me = LatestGameState.Players[ao.id]
  --   local player = LatestGameState.Players[LockingTarget]
    
  --   if isFight(me, player) or Times >= 3 then
  --     print("Fight with " .. LockingTarget .. "Position:" .. "(" .. player.x .. "," .. player.y .. ")")
  --     print("Player state: (health:" .. player.health .. ", energy:" .. player.energy .. ")")
  --     moveToTarget(me, player)
  --   else
  --     print("You energy is " .. me.energy .. ". Can't fight with " .. LockingTarget .. "move randomly.")
  --     randomMove()
  --   end
  -- end
  --#endregion

  local me = LatestGameState.Players[ao.id]
  local player = LatestGameState.Players[LockingTarget]
  
  if isFight(me, player) then
    print("Fight with " .. LockingTarget .. "Position:" .. "(" .. player.x .. "," .. player.y .. ")")
    print("Player state: (health:" .. player.health .. ", energy:" .. player.energy .. ")")
    moveToTarget(me, player)
  else
    -- todo：如果改成 runaway 似乎更好
    print("You energy is " .. me.energy .. ". Can't fight with " .. LockingTarget .. "move randomly.")
    randomMove()
  end
end

-- 打印游戏公告并触发游戏状态更新的handler。
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    print(msg.Event)
    if msg.Event == "Started-Waiting-Period" then
      ao.send({Target = ao.id, Action = "AutoPay"})
    elseif msg.Event == "PlayerMoved" then
      print(msg.Data)
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
      InAction = true --  InAction 逻辑添加
      ao.send({Target = Game, Action = "GetGameState"})
    elseif InAction then --  InAction 逻辑添加
      print("Previous action still in progress. Skipping.")
    end
    print(Colors.green .. msg.Event .. ": " .. msg.Data .. Colors.reset)
  end
)

-- 触发游戏状态更新的handler。
Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
    if not InAction then -- InAction 逻辑添加
      InAction = true -- InAction 逻辑添加
      print(Colors.gray .. "Getting game state..." .. Colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)


-- handlers
-- 等待期开始时自动付款确认的handler。
Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "AutoPay"),
  function (msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})
  end
)

-- 接收游戏状态信息后更新游戏状态的handler。
Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    print("Game state updated. Print \'LatestGameState\' for detailed view.")
  end
)

-- 决策下一个最佳操作的handler。
Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    if LatestGameState.GameMode ~= "Playing" then
      InAction = false -- InAction 逻辑添加
      print("Not playing state.")
      return
    end
    if isInGame() then
      print("Deciding next action.")
      decideNextAction()
      InAction = false -- InAction 逻辑添加
    else
      print("You are not in game.")
    end

    ao.send({Target = ao.id, Action = "Tick"})
  end
)

-- 被其他玩家击中时自动攻击的handler。
Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    if not InAction then --  InAction 逻辑添加
      InAction = true --  InAction 逻辑添加
      local playerEnergy = LatestGameState.Players[ao.id].energy
      if playerEnergy == undefined then
        print(Colors.red .. "Unable to read energy." .. Colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy."})
      elseif playerEnergy == 0 then
        print(Colors.red .. "Player has insufficient energy." .. Colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
      else
        print(Colors.red .. "Returning attack." .. Colors.reset)
        ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy)})
      end
      InAction = false --  InAction 逻辑添加
      ao.send({Target = ao.id, Action = "Tick"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)