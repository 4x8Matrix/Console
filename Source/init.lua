-- // Services
local RunService = game:GetService("RunService")

-- // Dependencies
local Signal = require(script.Parent.Signal)

-- // Constants
local DEFAULT_LOGGING_SCHEMA = "[%s][%s] :: %s"
local MAXIMUM_CACHED_LOGS = 500
local PRETTY_TABLE_TAB = string.rep("\t", (RunService:IsStudio() and 1) or 5)

-- // Module
local Logger = { }

Logger.LogLevel = 1
Logger.Schema = DEFAULT_LOGGING_SCHEMA

Logger.Functions = { }
Logger.Interface = { }
Logger.Reporters = { }
Logger.Prototype = { }

Logger.Interface.onMessageOut = Signal.new()
Logger.Interface.LogLevel = {
	["Debug"] = 1,
	["Log"] = 2,
	["Warn"] = 3,
	["Error"] = 4,
	["Critical"] = 5,
}

-- // Module Types
export type Reporter = {
	fetchLogs: (Reporter, count: number) -> { [number]: { logType: string, message: string, logId: string } },

	setState: (Reporter, state: boolean) -> (),
	setLogLevel: (Reporter, logLevel: number) -> (),

	debug: (Reporter, ...any) -> (),
	log: (Reporter, ...any) -> (),
	warn: (Reporter, ...any) -> (),
	error: (Reporter, ...any) -> (),
	critical: (Reporter, ...any) -> (),

	assert: (Reporter, condition: boolean, ...any) -> ()
}

export type Logger = {
	new: (logId: string?, schema: string?) -> Reporter,
	get: (logId: string) -> Reporter | nil,

	setGlobalSchema: (schema: string) -> (),
	setGlobalLogLevel: (logLevel: number) -> (),

	onMessageOut: RBXScriptSignal,

	LogLevel: {
		Debug: number,
		Log: number,
		Warn: number,
		Error: number,
		Critical: number
	}
}

-- // QoL functions
function Logger.Functions:addScopeToString(string)
	local stringSplit = string.split(string, "\n")

	for index, value in stringSplit do
		if index == 1 then
			continue
		end

		stringSplit[index] = string.format("%s%s", PRETTY_TABLE_TAB, value)
	end

	return table.concat(stringSplit, "\n")
end

function Logger.Functions:toPrettyString(...)
	local stringifiedObjects = { }

	for _, object in { ... } do
		local objectType = typeof(object)

		if objectType == "table" then
			local tableSchema = "{\n"
			local tableEntries = 0

			for key, value in object do
				tableEntries += 1

				key = self:toPrettyString(key)

				if typeof(value) == "table" then
					value = self:addScopeToString(self:toPrettyString(value))
				else
					value = self:toPrettyString(value)
				end

				tableSchema ..= string.format("%s[%s] = %s,\n", PRETTY_TABLE_TAB, key, value)
			end

			table.insert(stringifiedObjects, tableEntries == 0 and "{ }" or tableSchema .. "}")
		elseif objectType == "string" then
			table.insert(stringifiedObjects, string.format('"%s"', object))
		else
			table.insert(stringifiedObjects, tostring(object))
		end
	end

	return table.concat(stringifiedObjects, " ")
end

function Logger.Functions:formatVaradicArguments(...)
	local args = { ... }

	local message = string.rep("%s ", #args)
	local messageType = typeof(args[1])

	if messageType == "string" then
		message = table.remove(args, 1)
	end

	for index, value in args do
		args[index] = self:toPrettyString(value)
	end

	return string.format(
		message,
		table.unpack(args)
	)
end

function Logger.Functions:formatMessageSchema(schema: string, source: string, ...)
	source = source or debug.info(2, "s")

	return string.format(
		schema, source, ...
	)
end

-- // Prototype functions
--[[
	Assertions, however written through our reporter, if the condition isn't met, the reporter will call :error on itself with the given message.

	### Parameters
	- **condition**: *the condition we are going to validate*
	- **...**: *anything, Logger is equipped to parse & display all types.*

	---
	Example:

	```lua
		local Reporter = Logger.new("Reporter")

		Reporter:assert(1 == 1, "Hello, World!") -- > will output: nothing
		Reporter:assert(1 == 2, "Hello, World!") -- > will output: [Reporter][error]: "Hello, World!" <stack attached>
	```
]]
function Logger.Prototype:assert(condition, ...): ()
	if not condition then
		self:error(...)
	end
end

--[[
	Create a new log for 'critical', critical being deployed in a situation where something has gone terribly wrong.

	### Parameters
	- **...**: *anything, Logger is equipped to parse & display all types.*

	---
	Example:

	```lua
		local Reporter = Logger.new("Reporter")

		Reporter:critical("Hello, World!") -- > will output: [Reporter][critical]: "Hello, World!" <stack attached>
	```
]]
function Logger.Prototype:critical(...): ()
	local outputMessage = Logger.Functions:formatMessageSchema(self.schema or Logger.Schema, self.id, "critical", Logger.Functions:formatVaradicArguments(...))

	table.insert(self.logs, 1, { "critical", outputMessage, self.id })
	if #self.logs > MAXIMUM_CACHED_LOGS then
		table.remove(self.logs, MAXIMUM_CACHED_LOGS)
	end

	if self.level > Logger.Interface.LogLevel.Critical or Logger.LogLevel > Logger.Interface.LogLevel.Critical then
		task.cancel(coroutine.running())

		return
	end

	Logger.Interface.onMessageOut:Fire(self.id or "<unknown>", outputMessage)

	error(outputMessage, 2)
end

--[[
	Create a new log for 'error', this is for errors raised through a developers code on purpose.

	### Parameters
	- **...**: *anything, Logger is equipped to parse & display all types.*

	---
	Example:

	```lua
		local Reporter = Logger.new("Reporter")

		Reporter:error("Hello, World!") -- > will output: [Reporter][error]: "Hello, World!" <stack attached>
	```
]]
function Logger.Prototype:error(...): ()
	local outputMessage = Logger.Functions:formatMessageSchema(self.schema or Logger.Schema, self.id, "error", Logger.Functions:formatVaradicArguments(...))

	table.insert(self.logs, 1, { "error", outputMessage, self.id })
	if #self.logs > MAXIMUM_CACHED_LOGS then
		table.remove(self.logs, MAXIMUM_CACHED_LOGS)
	end

	if self.level > Logger.Interface.LogLevel.Error or Logger.LogLevel > Logger.Interface.LogLevel.Error then
		task.cancel(coroutine.running())

		return
	end

	Logger.Interface.onMessageOut:Fire(self.id or "<unknown>", outputMessage)

	error(outputMessage, 2)
end

--[[
	Create a new log for 'warn', this is for informing developers about something which takes precedence over a log

	### Parameters
	- **...**: *anything, Logger is equipped to parse & display all types.*

	---
	Example:

	```lua
		local Reporter = Logger.new("Reporter")

		Reporter:warn("Hello, World!") -- > will output: [Reporter][warn]: "Hello, World!"
	```
]]
function Logger.Prototype:warn(...): ()
	local outputMessage = Logger.Functions:formatMessageSchema(self.schema or Logger.Schema, self.id, "warn", Logger.Functions:formatVaradicArguments(...))

	table.insert(self.logs, 1, { "warn", outputMessage, self.id })
	if #self.logs > MAXIMUM_CACHED_LOGS then
		table.remove(self.logs, MAXIMUM_CACHED_LOGS)
	end

	if self.level > Logger.Interface.LogLevel.Warn or Logger.LogLevel > Logger.Interface.LogLevel.Warn then
		return
	end

	Logger.Interface.onMessageOut:Fire(self.id or "<unknown>", outputMessage)

	warn(outputMessage)
end

--[[
	Create a new log for 'log', this is for general logging - ideally what we would use in-place of print.

	### Parameters
	- **...**: *anything, Logger is equipped to parse & display all types.*

	---
	Example:

	```lua
		local Reporter = Logger.new("Reporter")

		Reporter:log("Hello, World!") -- > will output: [Reporter][log]: "Hello, World!"
	```
]]
function Logger.Prototype:log(...): ()
	local outputMessage = Logger.Functions:formatMessageSchema(self.schema or Logger.Schema, self.id, "log", Logger.Functions:formatVaradicArguments(...))

	table.insert(self.logs, 1, { "log", outputMessage, self.id })
	if #self.logs > MAXIMUM_CACHED_LOGS then
		table.remove(self.logs, MAXIMUM_CACHED_LOGS)
	end

	if self.level > Logger.Interface.LogLevel.Log or Logger.LogLevel > Logger.Interface.LogLevel.Log then
		return
	end

	Logger.Interface.onMessageOut:Fire(self.id or "<unknown>", outputMessage)

	print(outputMessage)
end

--[[
	Create a new log for 'debug', typically we should only use 'debug' when debugging code or leaving hints for developers.

	### Parameters
	- **...**: *anything, Logger is equipped to parse & display all types.*

	---
	Example:

	```lua
		local Reporter = Logger.new("Reporter")

		Reporter:debug("Hello, World!") -- > will output: [Reporter][debug]: "Hello, World!"
	```
]]
function Logger.Prototype:debug(...): ()
	local outputMessage = Logger.Functions:formatMessageSchema(self.schema or Logger.Schema, self.id, "debug", Logger.Functions:formatVaradicArguments(...))

	table.insert(self.logs, 1, { "debug", outputMessage, self.id })
	if #self.logs > MAXIMUM_CACHED_LOGS then
		table.remove(self.logs, MAXIMUM_CACHED_LOGS)
	end

	if self.level > Logger.Interface.LogLevel.Debug or Logger.LogLevel > Logger.Interface.LogLevel.Debug then
		return
	end

	Logger.Interface.onMessageOut:Fire(self.id or "<unknown>", outputMessage)

	print(outputMessage)
end

--[[
	Set an log level for this reporter, log levels assigned per reporter override the global log level.

	### Parameters
	- **logLevel**: *The logLevel priority you only want to show in output*
		* *Log Levels are exposed through `Logger.LogLevel`*

	### Returns
	- **Array**: *The array of logs created from this reporter*

	---
	Example:

	```lua
		local Reporter = Logger.new("Reporter")
		
		Logger.setGlobalLogLevel(Logger.LogLevel.Warn)

		Reporter:log("Hello, World!") -- this will NOT output anything
		Reporter:warn("Hello, World!") -- this will output something

		Reporter:setLogLevel(Logger.LogLevel.Log)

		Reporter:log("Hello, World!") -- this will output something
		Reporter:warn("Hello, World!") -- this will output something
	```
]]
function Logger.Prototype:setLogLevel(logLevel: number): ()
	self.level = logLevel
end

--[[
	Sets the state of the reporter, state depicts if the reporter can log messages into the output.

	### Parameters
	- **state**: *A bool to indicate weather this reporter is enabled or not.*

	---
	Example:

	```lua
		local Reporter = Logger.new("Reporter")

		Reporter:log("Hello, World!") -- > will output: [Reporter][log]: "Hello, World!"
		Reporter:setState(false)
		Reporter:log("Hello, World!") -- > will output: nothing
	```
]]
function Logger.Prototype:setState(state: boolean): ()
	self.enabled = state
end

--[[
	Fetch an array of logs generated through this reporter

	### Parameters
	- **count**: *The amount of logs you're trying to retrieve*

	### Returns
	- **Array**: *The array of logs created from this reporter*

	---
	Example:

	```lua
		local Reporter = Logger.new("Reporter")

		Reporter:log("Hello, World!") -- > [Reporter][log]: "Hello, World!"
		Reporter:fetchLogs() -- > table
	```
]]
function Logger.Prototype:fetchLogs(count: number): { [number]: { logType: string, message: string, logId: string } }
	local fetchedLogs = {}

	if not count then
		return self.logs
	end

	for index = 1, count do
		if not self.logs[index] then
			return fetchedLogs
		end

		table.insert(fetchedLogs, self.logs[index])
	end

	return fetchedLogs
end

-- // Module functions
--[[
	Set the global log level for all loggers, a log level is the priority of a log, priorities are represented by a number.

	### Parameters
	- **logLevel**: *The logLevel priority you only want to show in output*
		* *Log Levels are exposed through `Logger.LogLevel`*

	---
	Example:

	```lua
		Logger.setGlobalLogLevel(Logger.LogLevel.Warn)

		Reporter:log("Hello, World!") -- this will NOT output anything
		Reporter:warn("Hello, World!") -- this will output something
	```
]]
function Logger.Interface.setGlobalLogLevel(logLevel: number): ()
	Logger.LogLevel = logLevel
end

--[[
	Set the global schema for all loggers, a schema is how we display the output of a log.

	### Parameters
	- **schema**: *The schema you want all loggers to follow*
		* **schema format**: *loggerName / logType / logMessage*
		* **example schema**: *[%s][%s]: %s*

	---
	Example:

	```lua
		Logger.setGlobalSchema("[%s][%s]: %s")

		Reporter:log("Hello, World!") -- > [<ReporterName>][log]: Hello, World!
	```
]]
function Logger.Interface.setGlobalSchema(schema: string): ()
	Logger.Schema = schema
end

--[[
	Fetch a `Reporter` object through it's given `logId`

	### Parameters
	- **logId?**: *The name of the `Reporter` object you want to fetch*

	### Returns
	- **Reporter**: *The constructed `Reporter` prototype*
	- **nil**: *Unable to find the `Reporter`*

	---
	Example:

	```lua
		Logger.get("Reporter"):log("Hello, World!") -- > [Reporter][log]: "Hello, World!"
	```
]]
function Logger.Interface.get(logId: string): Reporter | nil
	return Logger.Reporters[logId]
end

--[[
	Constructor to generate a `Reporter` prototype

	### Parameters
	- **logId?**: *The name of the `Reporter`, this will default to the calling script name.*
	- **schema?**: *The schema this paticular `Reporter` will follow*

	### Returns
	- **Reporter**: The constructed `Reporter` prototype

	---
	Example:

	```lua
		Logger.new("Example"):log("Hello, World!") -- > [Example][log]: "Hello, World!"
	```
]]
function Logger.Interface.new(logId: string?, schema: string?): Reporter
	local self = setmetatable({
		id = logId,
		level = Logger.Interface.LogLevel.Debug,
		schema = schema,
		enabled = true,
		logs = { },
	}, { __index = Logger.Prototype })

	if logId then
		Logger.Reporters[self.id] = self
	end

	return self
end

return Logger :: Logger