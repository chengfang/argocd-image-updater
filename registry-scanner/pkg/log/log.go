package log

// Wrapper package around logrus whose main purpose is to support having
// different output streams for error and non-error messages.
//
// Does not wrap every method of logrus package. If you need direct access,
// use log.Log() to get the actual logrus logger object.
//
// It might seem redundant, but we really want the different output streams.

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"

	"github.com/sirupsen/logrus"
)

// Internal Logger object
var logger *logrus.Logger

// LogContext contains a structured context for logging
type LogContext struct {
	fields    logrus.Fields
	normalOut io.Writer
	errorOut  io.Writer
	mutex     sync.RWMutex
}

// NewContext returns a LogContext with default settings
func NewContext() *LogContext {
	var logctx LogContext
	logctx.fields = make(logrus.Fields)
	logctx.normalOut = os.Stdout
	logctx.errorOut = os.Stderr
	return &logctx
}

// SetLogLevel sets the log level to use for the logger
func SetLogLevel(logLevel string) error {
	var level logrus.Level
	switch strings.ToLower(logLevel) {
	case "trace":
		level = logrus.TraceLevel
	case "debug":
		level = logrus.DebugLevel
	case "info":
		level = logrus.InfoLevel
	case "warn":
		level = logrus.WarnLevel
	case "error":
		level = logrus.ErrorLevel
	default:
		return fmt.Errorf("invalid loglevel: %s", logLevel)
	}
	logger.SetLevel(level)
	logrus.SetLevel(level) // set loglevel for the default logrus.logger
	return nil
}

// WithContext is an alias for NewContext
func WithContext() *LogContext {
	return NewContext()
}

// AddField adds a structured field to logctx
func (logctx *LogContext) AddField(key string, value interface{}) *LogContext {
	logctx.mutex.Lock()
	logctx.fields[key] = value
	logctx.mutex.Unlock()
	return logctx
}

// Log retrieves the native logger interface. Use with care.
func Log() *logrus.Logger {
	return logger
}

// Tracef logs a debug message for logctx to stdout
func (logctx *LogContext) Tracef(format string, args ...interface{}) {
	logger.SetOutput(logctx.normalOut)
	if len(logctx.fields) > 0 {
		logger.WithFields(logctx.fields).Tracef(format, args...)
	} else {
		logger.Tracef(format, args...)
	}
}

// Debugf logs a debug message for logctx to stdout
func (logctx *LogContext) Debugf(format string, args ...interface{}) {
	logger.SetOutput(logctx.normalOut)
	if len(logctx.fields) > 0 {
		logger.WithFields(logctx.fields).Debugf(format, args...)
	} else {
		logger.Debugf(format, args...)
	}
}

// Infof logs an informational message for logctx to stdout
func (logctx *LogContext) Infof(format string, args ...interface{}) {
	logger.SetOutput(logctx.normalOut)
	if len(logctx.fields) > 0 {
		logger.WithFields(logctx.fields).Infof(format, args...)
	} else {
		logger.Infof(format, args...)
	}
}

// Warnf logs a warning message for logctx to stdout
func (logctx *LogContext) Warnf(format string, args ...interface{}) {
	logger.SetOutput(logctx.normalOut)
	if len(logctx.fields) > 0 {
		logger.WithFields(logctx.fields).Warnf(format, args...)
	} else {
		logger.Warnf(format, args...)
	}
}

// Errorf logs a non-fatal error message for logctx to stdout
func (logctx *LogContext) Errorf(format string, args ...interface{}) {
	logger.SetOutput(logctx.errorOut)
	if len(logctx.fields) > 0 {
		logger.WithFields(logctx.fields).Errorf(format, args...)
	} else {
		logger.Errorf(format, args...)
	}
}

// Fatalf logs a fatal error message for logctx to stdout
func (logctx *LogContext) Fatalf(format string, args ...interface{}) {
	logger.SetOutput(logctx.errorOut)
	if len(logctx.fields) > 0 {
		logger.WithFields(logctx.fields).Fatalf(format, args...)
	} else {
		logger.Fatalf(format, args...)
	}
}

// Tracef logs a warning message without context to stdout
func Tracef(format string, args ...interface{}) {
	logCtx := NewContext()
	logCtx.Tracef(format, args...)
}

// Debugf logs a warning message without context to stdout
func Debugf(format string, args ...interface{}) {
	logCtx := NewContext()
	logCtx.Debugf(format, args...)
}

// Infof logs a warning message without context to stdout
func Infof(format string, args ...interface{}) {
	logCtx := NewContext()
	logCtx.Infof(format, args...)
}

// Warnf logs a warning message without context to stdout
func Warnf(format string, args ...interface{}) {
	logCtx := NewContext()
	logCtx.Warnf(format, args...)
}

// Errorf logs an error message without context to stderr
func Errorf(format string, args ...interface{}) {
	logCtx := NewContext()
	logCtx.Errorf(format, args...)
}

// Fatalf logs a non-recoverable error message without context to stderr
func Fatalf(format string, args ...interface{}) {
	logCtx := NewContext()
	logCtx.Fatalf(format, args...)
}

func disableLogColors() bool {
	return strings.ToLower(os.Getenv("ENABLE_LOG_COLORS")) == "false"
}

// A private key type is used to prevent collisions with context keys from other packages.
type loggerKey struct{}

// ContextWithLogger returns a new context.Context that carries the provided logrus Entry.
// Use this to pass a contextual logger down through a call stack.
func ContextWithLogger(ctx context.Context, logger *logrus.Entry) context.Context {
	return context.WithValue(ctx, loggerKey{}, logger)
}

// LoggerFromContext retrieves the logrus Entry from the context.
// If no logger is found in the context, it returns the global logger, ensuring
// that a valid logger is always returned.
func LoggerFromContext(ctx context.Context) *logrus.Entry {
	if logger, ok := ctx.Value(loggerKey{}).(*logrus.Entry); ok {
		return logger
	}
	// Fallback to the global logger if none is found in the context.
	return logrus.NewEntry(Log())
}

// Initializes the logging subsystem with default values
func init() {
	logger = logrus.New()
	logger.SetFormatter(&logrus.TextFormatter{DisableColors: disableLogColors()})
	logger.SetLevel(logrus.DebugLevel)
}
