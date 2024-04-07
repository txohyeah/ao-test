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
