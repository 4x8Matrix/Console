local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Console = require(ReplicatedStorage.Packages.Console)

local Logger = Console.new("👋 Logger")

Logger:Log("Hello, World!")
Logger:Warn("Hello, World!")