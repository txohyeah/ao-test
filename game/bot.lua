
-- 初始化全局变量来存储最新的游戏状态和游戏主机进程。
LatestGameState = LatestGameState or nil
InAction = InAction or false -- 防止代理同时采取多个操作。
Paying = Paying or false
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
--  print("x1: " .. x1 .. " y1:" .. y1 .. " x2: " .. x2 .. " y2: " .. y2)

  local dx, dy = x2 - x1, y2 - y1
  local dirX, dirY = "", ""
--  print("dx:" .. dx .. " dy:" .. dy)

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
  else
    local moveDir = getDirections(me.x, me.y, player.x, player.y, false)
    print(Colors.red .. "Approaching the enemy. Move " .. moveDir .. Colors.reset)
    ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = moveDir})
  end
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
    moveToTarget(me, player)
  else
    print("You energy is " .. me.energy)
    if inRange(me.x, me.y, player.x, player.y, 3) then
      runaway(me, player)
      print("Runaway.")
    else
      print(Colors.red .. "No enongh energy. But you are safe now. random move." .. Colors.reset)
      randomMove()
    end
  end

  InAction = false
  print("LockingTarget:" .. LockingTarget)
  print("Player state: (health:" .. player.health .. ", energy:" .. player.energy .. ")")
  print("Player Position: (x:" .. player.x .. ", y:" .. player.y .. ")")
  print("You state: (health:" .. me.health .. ", energy:" .. me.energy .. ")")
  print("You Position: (x:" .. me.x .. ", y:" .. me.y .. ")")
end

-- 打印游戏公告并触发游戏状态更新的handler。
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    if (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
      InAction = true
      print(Colors.gray .. "Getting game state...From Announcement" .. Colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
    elseif msg.Event == "Attack" then
      print(Colors.red .. msg.Data .. Colors.reset)
      InAction = false
    elseif InAction then
      print(Colors.gray .. "Previous action still in progress. Skipping." .. Colors.reset)
    end
    print(Colors.green .. msg.Event .. ": " .. msg.Data .. Colors.reset)
  end
)

Handlers.add(
  "HandlerPlaying",
  function (msg)
    if msg.Action == "Player-Moved" or msg.Action == "Successful-Hit" or msg.Action == "" then
      return true
    else 
      return false
    end
  end,
  function (msg)
    print(msg.Data)
    print(Colors.gray .. "Getting game state...after Player-Action" .. Colors.reset)
    InAction = true
    ao.send({Target = Game, Action = "GetGameState"})
  end
)

-- Withdraw 以后自动支付，参加比赛
Handlers.add(
  "AutoPay",
  function (msg)
    if msg.Action == "Removed from the Game" then
      return true
    else
      return false
    end
  end,
  Handlers.utils.hasMatchingTag("Action", "Removed from the Game"),
  function (msg)
    if Paying then
      print("You have paid just now.")
    else
      print(Colors.red .. "Withdraw CRED. Removed from the Game." .. Colors.reset)
      print("Auto-paying confirmation fees.")
      ao.send({Target = CRED, Action = "Transfer", Quantity = "1000", Recipient = Game})
      Paying = true
    end
  end
)

-- 确认支付，以后设置为 Paying 为false，即可以再次支付
Handlers.add(
  "HandlePaying",
  Handlers.utils.hasMatchingTag("Action", "Debit-Notice"),
  function (msg)
    print("Paying success.")
    Paying = false
  end
)

-- 被淘汰 以后自动支付，参加比赛
Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "Eliminated"),
  function ()
    print("After Eliminated. Auto-paying confirmation fees.")
    ao.send({Target = CRED, Action = "Transfer", Quantity = "1000", Recipient = Game})
  end
)


-- 防止inbox里面存在太多的内容
Handlers.add(
  "AutoStart",
  Handlers.utils.hasMatchingTag("Action", "Payment-Received"),
  function (msg)
    print(Colors.gray .. "Auto start game...GetGameState... From AutoStart" .. Colors.reset)
    ao.send({Target = Game, Action = "GetGameState"})
    InAction = true
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
      print(Colors.gray .. "Deciding next action." .. Colors.reset)
      decideNextAction()
    else
      print(Colors.red .. "You are not in game." ..Colors.reset)
    end

    -- Game进程总是卡住，在收到Action进行消息发送的同时，也在每次执行完decision以后发送一次！
    if not InAction then
      InAction = true
      print(Colors.gray .. "Getting game state...From UpdateGameState" .. Colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
    else
      print(Colors.gray .. "Previous action still in progress. Skipping." .. Colors.reset)
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
      ao.send({Target = Game, Action = "GetGameState"})
      print(Colors.red .. "Be hitted!" .. Colors.reset)
      print(Colors.gray .. "GetGameState..From ReturnAttack" .. Colors.reset)
    else
      print(Colors.gray .. "Previous action still in progress. Skipping." .. Colors.reset)
    end
  end
)


Handlers.add(
  "Return2Cred",
  Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
  function (msg)
    print(msg.Data)
    print(Colors.blue .. "Credit Received. Auto Withdraw." .. Colors.reset)
    ao.send({Target = Game, Action = "Withdraw" })
  end
)
