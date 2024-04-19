
HorseWinner = {
    "BlackShadow",
    "Chitu",
    "Dilu"
 }

 StakingPool = {
    ["Dilu"] = {
        ["fvrYP8P9qSTr--myi8icGV59FpSKOvmnPSEKKT93yhM"] = 6000
    },
    ["Chitu"] = {
        ["cVVsTGjJPSf7eckrJaT97M9UhUOHrarzkC5UjIZg2Zg"] = 12000,
        ["fvrYP8P9qSTr--myi8icGV59FpSKOvmnPSEKKT93yhM"] = 10000
    },
    ["BlackShadow"] = {
        ["cVVsTGjJPSf7eckrJaT97M9UhUOHrarzkC5UjIZg2Zg"] = 6000
    }
 }

print(HorseWinner)
for _, horseId in ipairs(HorseWinner) do
    for pid, amount in pairs(StakingPool[horseId]) do
        print(pid)
        print(amount)
        -- winnerPlayerStakingAmount = winnerPlayerStakingAmount + tonumber(amount)
        -- if not winnerPlayerStaking[pid] then
        --     winnerPlayerStaking[pid] = 0
        -- end
        -- winnerPlayerStaking[pid] = winnerPlayerStaking[pid] + amount
    end
end