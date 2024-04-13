import Cocoa

internal let log = Logger(name: "MainLog", level: .info, toFile: true)

// MARK: Helpers
private func commandLineDebugEnabled() -> Bool {
#if DEBUG
    return Preferences.shared.envKeyPresent(key: "DCCmdLineDebug")
#else
    return false
#endif
}

private func isRunningFromCommandLine(args: [String]) -> Bool {
    // We have few ways of checking it, first is checking if our STDOUT is bound to some terminal
    // and second is checking for presence of env variable set in dev-cleaner.sh script. It helps
    // in cases where we want to run the script from headless environments where there's no TTY.
    //
    // Maybe there're better & more sure ways of handling/checking that, but I could't really found them.
    //
    
    let isTTY = isatty(STDIN_FILENO)
    let haveProperEnvValue = Preferences.shared.envKeyPresent(key: "DEV_CLEANER_FROM_COMMAND_LINE")
    
    let runningFromCommandLine = isTTY == 1 || haveProperEnvValue
    
#if DEBUG
    let runningFromXcode = args.contains("-NSDocumentRevisionsDebugMode")
#else
    let runningFromXcode = false
#endif
    
    return commandLineDebugEnabled() || (runningFromCommandLine && !runningFromXcode)
}

private func cleanedCommandLineArguments(args: [String]) -> [String] {
    var resultArgs = args
    
    // we have to remove some Xcode stuff here
    if commandLineDebugEnabled() {
        if let index = resultArgs.firstIndex(of: "-NSDocumentRevisionsDebugMode") {
            resultArgs.remove(at: index)
            resultArgs.remove(at: index) // twice as there's "YES" afterwards
        }
    }
    
    return resultArgs
}

// MARK: App Start

// save app path to defaults
Preferences.shared.appFolder = Bundle.main.bundleURL

let cleanedArgs = cleanedCommandLineArguments(args: CommandLine.arguments)

if isRunningFromCommandLine(args: cleanedArgs) {
    log.consoleLogging = false // disable console logging to not interfere with console output, file log will still be available
    CmdLine.shared.start(args: cleanedArgs)
} else {
    let _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
