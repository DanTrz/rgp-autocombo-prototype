using Godot;
using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Diagnostics.CodeAnalysis;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

public static class Log
{
    /// <summary>
    /// Defines additional debug log info components to be displayed
    /// </summary>
    private static readonly bool _showTimeStamp = true;
    private static readonly bool _showDeclaringClass = true;
    private static readonly bool _showCallingMethod = true;

    /// <summary>
    /// Individually select active types of debug messages
    /// </summary>
    private static readonly bool _debugMessages = true;
    private static readonly bool _infoMessages = true;
    private static readonly bool _warningMessages = true;
    private const bool _errorMessages = true;

    /// <summary>
    /// Overrides the individual selection of debug messages
    /// </summary>
    private static readonly bool _enableAllMessages = true;
    private static readonly bool _disableAllMessages = false;
    private static readonly bool _isVisualStudioDebugger = false;

    //SUMMARY OF THE LOGGINS SYSTEM
    //1.. _logQueue: A thread-safe blocking collection to hold log entries.
    //2.. Producers (Log.Debug, Info, etc.) add entries to this queue.
    //3.. The consumer (ProcessLogQueueAsync) reads entries from this queue.
    //4.. The BlockingCollection handles the waiting and signaling mechanisms for the producer/consumer pattern.
    //5.. Any new Producer Entry signals the BlockingCollection, and the blocked foreach loop in ProcessLogQueueAsync wakes up, retrieves the enqueued LogEntry, and processes it in await AddInternalAsync().

    /// <summary>
    /// Built-in thread-safe blocking collection and handles queue management and wake-up.
    /// </summary>
    private static readonly BlockingCollection<LogEntry> _logQueue = [];
    /// <summary>
    /// Background task responsible for processing log entries.
    /// </summary>
    private static Task _processingTask;
    private static readonly Lock _processingLock = new();

    /// <summary>
    /// Record to represent the log entry
    /// </summary>
    /// <param name="CallerNode"></param>
    /// <param name="Level"></param>
    /// <param name="DeclaringClass"></param>
    /// <param name="CallingMethod"></param>
    /// <param name="Message"></param>
    private record LogEntry(
        Node CallerNode,
        LogLevel Level,
        string DeclaringClass,
        string CallingMethod,
        params object[] Message
    );

    public enum LogLevel
    {
        ERROR,
        WARNING,
        DEBUG,
        INFO
    }

    static Log()
    {
        if (OS.IsDebugBuild())
        {
            _isVisualStudioDebugger = IsRunningInVisualStudio();
            // Start the background task to process log messages.
            StartProcessingQueue();
        }
        else
        {
            _disableAllMessages = true;
        }
    }

    /// <summary>
    /// Starts the background task that processes log messages from the queue.
    /// </summary>
    private static void StartProcessingQueue()
    {
        lock (_processingLock)
        {
            if (_processingTask?.IsCompleted != false)
            {
                // Start a new background task to execute the ProcessLogQueueAsync method.
                _processingTask = Task.Run(ProcessLogQueueAsync);
            }
        }
    }

    /// <summary>
    /// This method runs in the background to process log messages.
    /// </summary>
    /// <returns></returns>
    private static async Task ProcessLogQueueAsync()
    {
        // It stops when the collection is empty and yields/retrieves items as they become available.
        // This works as we are using BlockingCollection for the _logQueue that handles the waiting and signaling mechanisms for the producer/consumer pattern.
        foreach (LogEntry entry in _logQueue.GetConsumingEnumerable())
        {
            await AddLogMessage(entry.Level, entry.DeclaringClass, entry.CallingMethod, entry.Message);
        }
    }

    private static Task AddLogMessage(LogLevel level, string declaringNodeOrClass, string callingMethod, params object[] message)
    {
        if (_disableAllMessages)
        {
            return Task.CompletedTask;
        }

        string timeStamp = _showTimeStamp ? $"[{DateTime.Now:yy-MM-dd HH:mm:ss}]" : "";
        string logMessage = $"{timeStamp}[{level}]{declaringNodeOrClass}{callingMethod} ";
        string color = level switch
        {
            LogLevel.DEBUG => "WHITE",
            LogLevel.INFO => "CYAN",
            LogLevel.WARNING => "YELLOW",
            LogLevel.ERROR => "RED",
            _ => "CYAN"
        };

        if (!_isVisualStudioDebugger)
        {
            GD.PrintRich([$"[color={color}]{logMessage}[/color]", .. message]);
        }
        else
        {
            Debugger.Log((int)level, "Messages", logMessage + AppendPrintParams(message) + "\r\n");
        }

        return Task.CompletedTask;
    }

    /// <summary>
    /// Captures the caller information at the time the log is created
    /// </summary>
    /// <param name="callerNode"></param>
    /// <param name="level"></param>
    /// <param name="message"></param>
    /// <returns></returns>
    [RequiresUnreferencedCode("Calls System.Diagnostics.StackFrame.GetMethod()")]
    private static LogEntry CreateLogEntry(Node callerNode, LogLevel level, params object[] message)
    {
        string declaringClass = null;
        string callingMethod = null;

        if (_showDeclaringClass || _showCallingMethod)
        {
            StackTrace trace = new StackTrace(false); //false argument disables expensive file info
            foreach (StackFrame frame in trace.GetFrames())
            {
                System.Reflection.MethodBase method = frame.GetMethod();
                Type declaringType = method?.DeclaringType;
                if (declaringType == null)
                {
                    continue;
                }

                if (declaringType == typeof(Log))
                {
                    continue; // skip Log class
                }

                string nodeInfo = null;

                if (callerNode != null)
                {
                    //If node.GetType().Name is the same as callerNode.Name, avoid adding the same thing twice
                    nodeInfo = callerNode.GetType().Name == callerNode.Name
                        ? callerNode.GetType().Name
                        : $"{callerNode.GetType().Name}/{callerNode.Name}";
                }

                // If nodeInfo not null then use nodeInfo, else use declaringType, if both are null then use "unknown"
                declaringClass = nodeInfo != null ? $"[{nodeInfo}]" : $"[{declaringType?.Name ?? "unknown"}]";
                callingMethod = $"[{method.Name}]";
                break;
            }
        }

        return new LogEntry(
            callerNode,
            level,
            declaringClass,
            callingMethod,
            message
        );
    }

    public static void Debug(params object[] message)
    {
        if (_debugMessages || _enableAllMessages)
        {
            _logQueue.Add(CreateLogEntry(null, LogLevel.DEBUG, message));
        }
    }

    public static void Debug(Node callerNode, params object[] message)
    {
        if (_debugMessages || _enableAllMessages)
        {
            _logQueue.Add(CreateLogEntry(callerNode, LogLevel.DEBUG, message));
        }
    }

    public static void Info(params object[] message)
    {
        if (_infoMessages || _enableAllMessages)
        {
            _logQueue.Add(CreateLogEntry(null, LogLevel.INFO, message));
        }
    }

    public static void Info(Node callerNode, params object[] message)
    {
        if (_infoMessages || _enableAllMessages)
        {
            _logQueue.Add(CreateLogEntry(callerNode, LogLevel.INFO, message));
        }
    }

    public static void Warning(params object[] message)
    {
        if (_warningMessages || _enableAllMessages)
        {
            _logQueue.Add(CreateLogEntry(null, LogLevel.WARNING, message));
        }
    }

    public static void Warning(Node callerNode, params object[] message)
    {
        if (_warningMessages || _enableAllMessages)
        {
            _logQueue.Add(CreateLogEntry(callerNode, LogLevel.WARNING, message));
        }
    }

    public static void Error(params object[] message)
    {
        if (_errorMessages || _enableAllMessages)
        {
            _logQueue.Add(CreateLogEntry(null, LogLevel.ERROR, message));
        }
    }

    public static void Error(Node callerNode, params object[] message)
    {
        if (_errorMessages || _enableAllMessages)
        {
            _logQueue.Add(CreateLogEntry(callerNode, LogLevel.ERROR, message));
        }
    }

    private static string AppendPrintParams(object[] parameters)
    {
        if (parameters == null || parameters.Length == 0)
        {
            return "null";
        }
        //return string.Join(string.Empty, parameters.Select(p => p?.ToString() ?? "null"));
        return string.Join(" ", parameters.Select(static p => p?.ToString() ?? "null"));
    }

    private static bool IsRunningInVisualStudio()
    {
        string vsVersion = System.Environment.GetEnvironmentVariable("VisualStudioVersion");
        return !string.IsNullOrEmpty(vsVersion) && vsVersion.StartsWith("17.0", StringComparison.OrdinalIgnoreCase);
    }

    public static void Shutdown()
    {
        if (!_logQueue.IsAddingCompleted)
        {
            _logQueue.CompleteAdding();
            try
            {
                _processingTask?.Wait();
            }
            catch (Exception ex)
            {
                GD.PrintErr("Error while shutting down Log processing task:", ex.Message);
            }
        }
    }
}