# Console
A Roblox resource to simplify &amp; enhance the Roblox Console/Output

## Examples
Brief documentation to go through the functionality:

```lua
-- A schema is the format we're going to use when creating messages in the output.. 

-- 1: Source - The Reporter Name OR The path to the script which created a message
-- 2: Type - The type of message, warn, print, error etc..
-- 3: Message - The message
Console.setGlobalSchema("[%s][%s] -> %s")

-- The Reporter is how we are going to warn, print & log to the output, the Reporter is a class built to report things. 

-- 1: Name - The name of the reporter, if there is no name provided, the calling scripts name will be used
-- 2: Schema - A custom schema in the case we want to avoid using the global schema
local Reporter = Console.new("Reporter Name")

-- Warning/Printing messages to the output.
Reporter:Log("Hello, World!")
Reporter:Warn("Hello, World!")
```

Brief overview on how this integrates well with Knit:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Console = require(ReplicatedStorage.Packages.console)

local Controller = Knit.CreateController({
	Name = script.Name,
	reporter = Console.new(),
})

function Controller:KnitInit()
	self.reporter:Log("Hello, from " .. script.Name)
end

return Controller
```
