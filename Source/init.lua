local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Signal)

local DEFAULT_LOGGING_SCHEMA = "[%s][%s] :: %s"
local MAXIMUM_CACHED_LOGS = 500
local PRETTY_TABLE_TAB = string.rep("\t", (RunService:IsStudio() and 1) or 5)

local Logger = { }

Logger.LogLevel = 1
Logger.Schema = DEFAULT_LOGGING_SCHEMA

Logger.Functions = { }
Logger.Interface = { }
Logger.Reporters = { }
Logger.Class = { }

Logger.Interface.onMessageOut = Signal.new()
Logger.Interface.LogLevel = {
	["Debug"] = 1,
	["Log"] = 2,
	["Warn"] = 3,
	["Error"] = 4,
	["Critical"] = 5,
}

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

function Logger.Class:assert(statement, ...)
	if not statement then
		self:error(...)
	end
end

function Logger.Class:critical(...)
	local outputMessage = Logger.Functions:formatMessageSchema(self.schema or Logger.Schema, self.id, "critical", Logger.Functions:formatVaradicArguments(...))

	table.insert(self.logs, 1, { "critical", outputMessage, self.id })
	if #self.logs > MAXIMUM_CACHED_LOGS then
		table.remove(self.logs, MAXIMUM_CACHED_LOGS)
	end

	if self.level > Logger.Interface.LogLevel.Critical or Logger.LogLevel > Logger.Interface.LogLevel.Critical then
		return
	end

	Logger.Interface.onMessageOut:Fire(self.id or "<unknown>", outputMessage)

	error(outputMessage)
end

function Logger.Class:error(...)
	local outputMessage = Logger.Functions:formatMessageSchema(self.schema or Logger.Schema, self.id, "error", Logger.Functions:formatVaradicArguments(...))

	table.insert(self.logs, 1, { "error", outputMessage, self.id })
	if #self.logs > MAXIMUM_CACHED_LOGS then
		table.remove(self.logs, MAXIMUM_CACHED_LOGS)
	end

	if self.level > Logger.Interface.LogLevel.Error or Logger.LogLevel > Logger.Interface.LogLevel.Error then
		return
	end

	Logger.Interface.onMessageOut:Fire(self.id or "<unknown>", outputMessage)

	error(outputMessage)
end

function Logger.Class:warn(...)
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

function Logger.Class:log(...)
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

function Logger.Class:debug(...)
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

function Logger.Class:setLogLevel(logLevel: number)
	self.level = logLevel
end

function Logger.Class:setEnabled(state: boolean)
	self.enabled = state
end

function Logger.Class:fetchLogs(count: number)
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

function Logger.Interface.setGlobalLogLevel(logLevel: number)
	Logger.LogLevel = logLevel
end

function Logger.Interface.setGlobalSchema(schema: string)
	Logger.Schema = schema
end

function Logger.Interface.get(logId: string)
	return Logger.Reporters[logId]
end

function Logger.Interface.new(logId: string?, schema: string?)
	local self = setmetatable({
		id = logId,
		level = Logger.Interface.LogLevel.Debug,
		schema = schema,
		enabled = true,
		logs = { },
	}, { __index = Logger.Class })

	if logId then
		Logger.Reporters[self.id] = self
	end

	return self
end

return Logger.Interface
