using System.Collections;
using System.Text.Json;
using DaemonPlatform.Contracts.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace DaemonPlatform.Core.Logging;

public sealed class FileJsonLoggerProvider : ILoggerProvider, ISupportExternalScope
{
    private readonly FileJsonLogSink sink;
    private IExternalScopeProvider scopeProvider = new LoggerExternalScopeProvider();

    public FileJsonLoggerProvider(IOptions<FileLoggingOptions> options)
    {
        sink = new FileJsonLogSink(options.Value);
    }

    public ILogger CreateLogger(string categoryName) => new FileJsonLogger(categoryName, sink, () => scopeProvider);

    public void Dispose() => sink.Dispose();

    public void SetScopeProvider(IExternalScopeProvider scopeProvider)
    {
        this.scopeProvider = scopeProvider;
    }

    private sealed class FileJsonLogger(
        string categoryName,
        FileJsonLogSink sink,
        Func<IExternalScopeProvider> scopeProviderAccessor) : ILogger
    {
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => scopeProviderAccessor().Push(state);

        public bool IsEnabled(LogLevel logLevel) => logLevel != LogLevel.None;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            if (!IsEnabled(logLevel))
            {
                return;
            }

            var payload = new Dictionary<string, object?>
            {
                ["timestampUtc"] = DateTimeOffset.UtcNow,
                ["level"] = logLevel.ToString(),
                ["category"] = categoryName,
                ["eventId"] = eventId.Id,
                ["message"] = formatter(state, exception),
                ["exception"] = exception?.ToString()
            };

            var stateValues = ExtractState(state);
            if (stateValues.Count > 0)
            {
                payload["state"] = stateValues;
            }

            var scopes = new List<object?>();
            scopeProviderAccessor().ForEachScope((scope, list) => list.Add(scope), scopes);
            if (scopes.Count > 0)
            {
                payload["scopes"] = scopes;
            }

            sink.Write(payload);
        }

        private static Dictionary<string, object?> ExtractState<TState>(TState state)
        {
            if (state is IEnumerable<KeyValuePair<string, object?>> structured)
            {
                return structured
                    .Where(item => !string.Equals(item.Key, "{OriginalFormat}", StringComparison.Ordinal))
                    .ToDictionary(item => item.Key, item => NormalizeValue(item.Value), StringComparer.OrdinalIgnoreCase);
            }

            return new Dictionary<string, object?>();
        }

        private static object? NormalizeValue(object? value)
        {
            return value switch
            {
                null => null,
                string => value,
                IEnumerable enumerable when value is not IDictionary => enumerable.Cast<object?>().ToArray(),
                _ => value
            };
        }
    }

    private sealed class FileJsonLogSink : IDisposable
    {
        private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web);
        private readonly object gate = new();
        private readonly string path;

        public FileJsonLogSink(FileLoggingOptions options)
        {
            path = Path.GetFullPath(options.Path);
            var directory = Path.GetDirectoryName(path);
            if (!string.IsNullOrWhiteSpace(directory))
            {
                Directory.CreateDirectory(directory);
            }
        }

        public void Write(Dictionary<string, object?> payload)
        {
            var line = JsonSerializer.Serialize(payload, SerializerOptions);
            lock (gate)
            {
                File.AppendAllText(path, line + Environment.NewLine);
            }
        }

        public void Dispose()
        {
        }
    }
}
