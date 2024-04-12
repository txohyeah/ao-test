
-- 初始化全局变量来存储最新的游戏状态和游戏主机进程。
LatestGameState = LatestGameState or nil
InAction = InAction or false -- 防止代理同时采取多个操作。

-- 目标敌人的process id，为nil则为暂时没有目标
LockingTarget = LockingTarget or nil
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
  local rangeX, rangeY = 0, 0
  if math.abs(x1 - x2) > 20 then
    rangeX = 41 - math.abs(x1 - x2)
  else
    rangeX = math.abs(x1 - x2)
  end

  if math.abs(y1 - y2) > 20 then
    rangeY = 41 - math.abs(y1 - y2)
  else
    rangeY = math.abs(y1 - y2)
  end
  return rangeX <= range and rangeY <= range
end

-- 根据玩家和目标状态判断是否进入战斗状态。
function isFight(me, player)
  return player.health < me.energy * 2/3
end

-- 锁定最弱的敌人（首先，血量最小并且血量小于66；其次，能量最小；）
function findWeakPlayer()
  local heathValue = 100
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
-- isAway == true 远离; isAway == false 接近;
local function getDirections(x1, y1, x2, y2, isAway)
  if isAway == nil then
    isAway = false
  end

  x1, x2 = adjustPosition(x1, x2)
  y1, y2 = adjustPosition(y1, y2)

  local dx, dy = x2 - x1, y2 - y1
  local dirX, dirY = "", ""

  if isAway then
    if dx > 0 then dirX = "Left" else dirX = "Right" end
    if dy > 0 then dirY = "Up" else dirY = "Down" end
  else
    if dx > 0 then dirX = "Right" else dirX = "Left" end
    if dy > 0 then dirY = "Down" else dirY = "Up" end
  end
  
  print(dirY .. dirX)
  return dirY .. dirX
end

-- 向目标移动，在攻击范围，则进行攻击
function moveToTarget(me, player)
  if inRange(me.x, me.y, player.x, player.y, 1) then
    attack()
    print(Colors.red .. "Target in range, Attacking!" .. Colors.reset)
  end

  -- 攻击以后，要尽量移动，避免被反击
  local moveDir = getDirections(me.x, me.y, player.x, player.y, false)
  print(Colors.red .. "Approaching the enemy. Move " .. moveDir .. Colors.reset)
  ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = moveDir})
end

-- 从目标玩家那里逃跑
function runaway(me, player)
  local moveDir = getDirections(me.x, me.y, player.x, player.y, true)
  print(Colors.red .. "Runaway, Move " .. moveDir .. Colors.reset)
  ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = moveDir})
end

-- 攻击
function attack() 
  local playerEnergy = LatestGameState.Players[ao.id].energy
  if playerEnergy == undefined then
    print(Colors.red .. "Attack-Failed. Unable to read energy." .. Colors.reset)
  elseif playerEnergy == 0 then
    print(Colors.red .. "Attack-Failed. Player has insufficient energy." .. Colors.reset)
  else
    ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy)})
    print(Colors.red .. "Attacked." .. Colors.reset)
  end
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
-- 策略：
-- 寻找到可以一击必杀的敌人 player.heath < me.energy * 2/3。
-- 移动到敌人附近，并攻击敌人。
-- 如果没有击杀，在没有能量的时候，随机移动。
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
    
  --   if isFight(me, player) or me.energy == 100 then
  --     print("Fight with " .. LockingTarget .. "Position:" .. "(" .. player.x .. "," .. player.y .. ")")
  --     print("Player state: (health:" .. player.health .. ", energy:" .. player.energy .. ")")
  --     moveToTarget(me, player)
  --   else
  --     print("You energy is " .. me.energy .. ". Can't fight with " .. LockingTarget .. ".")
  --     if inRange(me.x, me.y, player.x, player.y, 3) then
  --       runaway(me, player)
  --       print("Runaway.")
  --     else
  --       print(Colors.red .. "No enongh energy. But you are safe now. random move." .. Colors.red)
  --       randomMove()
  --     end
  --   end
  -- end
  --#endregion

  if LockingTarget == nil then
    findWeakPlayer()
  end

  local me = LatestGameState.Players[ao.id]
  local player = LatestGameState.Players[LockingTarget]

  if me.health < 50 then
    ao.send({Target = Game, Action = "Withdraw" })
  end

  -- 没有目标，或者目标生命值大于66的情况下，每次都重新找敌人
  if player == nil or player == undefined or player.health > 66 then
    findWeakPlayer()
    player = LatestGameState.Players[LockingTarget]
  end
  
  if isFight(me, player) then
    print("Fight with " .. LockingTarget .. "Position:" .. "(" .. player.x .. "," .. player.y .. ")")
    moveToTarget(me, player)
  else
    print("You energy is " .. me.energy .. ". Can't fight with " .. LockingTarget .. ".")
    if inRange(me.x, me.y, player.x, player.y, 3) then
      runaway(me, player)
      print("Runaway.")
    else
      print(Colors.red .. "No enongh energy. But you are safe now. random move." .. Colors.red)
      randomMove()
    end
  end
  print("Player state: (health:" .. player.health .. ", energy:" .. player.energy .. ")")
  print("You state: (health:" .. me.health .. ", energy:" .. me.energy .. ")")
  print("You Position: (x:" .. me.x .. ", y:" .. me.y .. ")")
end

-- 打印游戏公告并触发游戏状态更新的handler。
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    print(msg.Event)
    if msg.Event == "Started-Waiting-Period" then
      print("Auto-paying confirmation fees.")
      ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})
    elseif msg.Event == "PlayerMoved" then
      print(msg.Data)
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
      InAction = true
      ao.send({Target = Game, Action = "GetGameState"})
    elseif InAction then
      print("Previous action still in progress. Skipping.")
    end
    print(Colors.green .. msg.Event .. ": " .. msg.Data .. Colors.reset)
  end
)

Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "Removed from the Game"),
  function ()
    print("Auto-paying confirmation fees.")
    ao.send({Target = CRED, Action = "Transfer", Quantity = "1000", Recipient = Game})
  end
)

Handlers.add(
  "AutoStart",
  Handlers.utils.hasMatchingTag("Action", "Payment-Received"),
  function ()
    print("Auto start game.")
    ao.send({Target = Game, Action = "GetGameState"})
    InAction = false
  end
)


-- 接收游戏状态信息后更新游戏状态的handler。
Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    print("Game state updated. Print \'LatestGameState\' for detailed view.")

    if LatestGameState.GameMode ~= "Playing" then
      InAction = false
      print("Not playing state.")
      return
    end

    if isInGame() then
      print("Deciding next action.")
      decideNextAction()
      InAction = false
    else
      print("You are not in game.")
      InAction = false
    end

    if not InAction then
      InAction = true
      print(Colors.gray .. "Getting game state..." .. Colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)

-- 被其他玩家击中时自动攻击的handler。
Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    if not InAction then
      InAction = true
      attack()
      print(Colors.red .. "Be hitted, Attacking!" .. Colors.reset)
      InAction = false
      ao.send({Target = ao.id, Action = "Tick"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)


