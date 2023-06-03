export type Logger = {
	FetchLogs: (self: Logger, count: number) -> { [number]: { logType: string, message: string, logId: string } },

	SetState: (self: Logger, state: boolean) -> (),
	SetLogLevel: (self: Logger, logLevel: number) -> (),

	Debug: (self: Logger, ...any) -> (),
	Log: (self: Logger, ...any) -> (),
	Warn: (self: Logger, ...any) -> (),
	Error: (self: Logger, ...any) -> (),
	Critical: (self: Logger, ...any) -> (),

	Assert: (self: Logger, condition: boolean, ...any) -> ()
}

export type LoggerModule = {
	new: (logId: string?, schema: string?) -> Logger,
	get: (logId: string) -> Logger | nil,

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

return {}