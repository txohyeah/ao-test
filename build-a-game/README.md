English | [简体中文](README.zh-CN.md)

# Notice
The game creation is exclusively for AO test Quest 4 and is not to be used for any commercial purposes, especially for horse racing games. 

Therefore, in-game tokens can be acquired directly via requests, and when there is a shortage, process owner can mint more tokens.

If anyone modify this code to develop commercial games, it shall be entirely unrelated to the author, and they shall bear all legal and other consequences themselves!

# Three Kingdoms Horse Racing Game
This game's inspiration comes from a horse racing scene within a casual game set in the Three Kingdoms backdrop, as depicted in the following image.
![alt text](image.png)

There are four elite steeds in total: Dilu, BlackShadow, Chitu, and YellowLighting (transliterated from Chinese names: 的卢, 绝影, 赤兔, 抓黄飞电).

Initially, one can acquire Three Kingdoms' Wu Zhu coins through a RequestWuzhu function call.

```
ThreeKingdoms = "cVVsTGjJPSf7eckrJaT97M9UhUOHrarzkC5UjIZg2Zg"
Send({ Target = ThreeKingdoms, Action = "RequestWuzhu"})
```

## Rules
Firstly, Welcome to Three Kingdoms Horse Racing Game!
```
Send({Target = ThreeKingdoms, Action = "JumpInto"})
```

### Waiting period
Upon the last player entering and staking, a 5-minute waiting period will be refreshed.

1.Players have the option to choose a horse and place a bet on their favored steed.
```
Send({Target = ThreeKingdoms, Action = "StakingHorse", Recipient = ThreeKingdoms, Quantity = "1000", Horse = "Dilu"})
```

If the input a horse that does not exist, a random horse will be chosen.

Once the waiting period concludes, any player can initiate the game using a HorseTicker message.

Player can use a Retire message to exit the game.
```
Send({Target = ThreeKingdoms, Action = "Retire"})
```

If Wuzhu coins have already been staked, players are not allowed to withdraw from the race until the current round concludes.

### Playing period
2.The finish line consists of 20 squares. The horse that reaches it first wins. The calculation rules for the distance advanced each turn are as follows:
```
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

local ratio = calStakingRatioForRunning(Staking["StakingRatioHorse"][horseId])

math.ceil(math.random() * 3 * ratio)
```

3.Each horse has one opportunity to use a skill, which enables them to move at a distance five times their regular pace. It is also possible that the game ends before a horse has the chance to use its skill. The function to trigger the skill is as follows:
```
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
```

4.The game ends when a horse reaches the finish line. In the event that multiple horses reach the finish line simultaneously, they are declared joint winners.

5.The player who staked on the winning horse will receive all the Wu Zhu coins according to their staking proportion.