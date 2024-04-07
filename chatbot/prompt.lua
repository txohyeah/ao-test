function Prompt()
  return ao.env.Process.TagArray[2].value .. "[" .. #Inbox .. "]($" .. CRED.balance .. ") > "
end

Handlers.add(
  "Announcement",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function(msg)
    print(msg.Data)
  end
)



-- Handlers.add(
--     "Broadcast",
--     Handlers.utils.hasMatchingTag("Action", "Broadcast"),
--     function(m)
--         if Balances[m.From] == undefined or tonumber(Balances[m.From]) < 1 then
--             print("UNAUTH REQ: " .. m.From)
--             return
--         end
--         local type = m.Type or "Normal"
--         print("Broadcasting message from " .. m.From .. ". Content: " .. m.Data)
--         for i = 1, #Members, 1 do
--             ao.send({
--                 Target = Members[i],
--                 Action = "Broadcasted",
--                 Broadcaster = m.From,
--                 Data = m.Data
--             })
--         end
--     end
-- )