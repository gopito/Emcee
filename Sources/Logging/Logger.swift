import Foundation

public final class Logger {
    private init() {}
    
    public static func verboseDebug(
        _ message: String,
        _ subprocessInfo: SubprocessInfo? = nil,
        file: StaticString = #file,
        line: UInt = #line)
    {
        log(.verboseDebug, message, subprocessInfo, file: file, line: line)
    }
    
    public static func debug(
        _ message: String,
        _ subprocessInfo: SubprocessInfo? = nil,
        file: StaticString = #file,
        line: UInt = #line)
    {
        log(.debug, message, subprocessInfo, file: file, line: line)
    }
    
    public static func info(
        _ message: String,
        _ subprocessInfo: SubprocessInfo? = nil,
        file: StaticString = #file,
        line: UInt = #line)
    {
        log(.info, message, subprocessInfo, file: file, line: line)
    }
    
    public static func warning(
        _ message: String,
        _ subprocessInfo: SubprocessInfo? = nil,
        file: StaticString = #file,
        line: UInt = #line)
    {
        log(.warning, message, subprocessInfo, file: file, line: line)
    }
    
    public static func error(
        _ message: String,
        _ subprocessInfo: SubprocessInfo? = nil,
        file: StaticString = #file,
        line: UInt = #line)
    {
        log(.error, message, subprocessInfo, file: file, line: line)
    }
    
    public static func fatal(
        _ message: String,
        _ subprocessInfo: SubprocessInfo? = nil,
        file: StaticString = #file,
        line: UInt = #line) -> Never
    {
        log(.fatal, message, subprocessInfo, file: file, line: line)
        fatalError(message)
    }
    
    public static func always(
        _ message: String,
        _ subprocessInfo: SubprocessInfo? = nil,
        file: StaticString = #file,
        line: UInt = #line) 
    {
        log(.always, message, subprocessInfo, file: file, line: line)
    }
    
    public static func log(
        _ verbosity: Verbosity,
        _ message: String,
        _ subprocessInfo: SubprocessInfo? = nil,
        file: StaticString = #file,
        line: UInt = #line)
    {
        let logEntry = LogEntry(
            file: file,
            line: line,
            message: message,
            subprocessInfo: subprocessInfo,
            timestamp: Date(),
            verbosity: verbosity
        )
        log(logEntry)
    }
    
    public static func log(_ logEntry: LogEntry) {
        GlobalLoggerConfig.loggerHandler.handle(logEntry: logEntry)
    }
}
