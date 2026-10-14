class_name LoggerService
extends Node

## -----------------------------------------------------------------------------
## Constants & Configuration
## -----------------------------------------------------------------------------
enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3
}

const LOG_FILE_PATH: String = "res://logs/app.log"
const LOG_LEVEL_NAMES: Array[String] = ["DEBUG", "INFO", "WARN", "ERROR"]
const DEFAULT_LOG_TAG: String = "Engine"
const LOG_TIMESTAMP_FORMAT: String = "%04d-%02d-%02d %02d:%02d:%02d"

## -----------------------------------------------------------------------------
## State Variables
## -----------------------------------------------------------------------------
var current_min_level: LogLevel = LogLevel.DEBUG
var log_file: FileAccess = null

func _ready() -> void:
	_open_log_file()
	info("Logger service initialized. Runtime logging directed to " + LOG_FILE_PATH, "Logger")

func _exit_tree() -> void:
	if log_file != null:
		log_file.flush()
		log_file.close()
		log_file = null

func _open_log_file() -> void:
	log_file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	if log_file == null:
		push_warning("Failed to open runtime log file at: " + LOG_FILE_PATH)

func log_message(level: LogLevel, message: String, tag: String = DEFAULT_LOG_TAG) -> void:
	if level < current_min_level:
		return

	var time_dict: Dictionary = Time.get_datetime_dict_from_system()
	var timestamp_str: String = LOG_TIMESTAMP_FORMAT % [
		time_dict["year"],
		time_dict["month"],
		time_dict["day"],
		time_dict["hour"],
		time_dict["minute"],
		time_dict["second"]
	]
	var level_str: String = LOG_LEVEL_NAMES[level]
	var formatted_line: String = "[%s] [%s] [%s] %s" % [timestamp_str, level_str, tag, message]

	# Console output
	match level:
		LogLevel.ERROR:
			printerr(formatted_line)
		LogLevel.WARN:
			push_warning(formatted_line)
		_:
			print(formatted_line)

	# File output
	if log_file != null:
		log_file.store_line(formatted_line)
		log_file.flush()

func debug(message: String, tag: String = DEFAULT_LOG_TAG) -> void:
	log_message(LogLevel.DEBUG, message, tag)

func info(message: String, tag: String = DEFAULT_LOG_TAG) -> void:
	log_message(LogLevel.INFO, message, tag)

func warn(message: String, tag: String = DEFAULT_LOG_TAG) -> void:
	log_message(LogLevel.WARN, message, tag)

func error(message: String, tag: String = DEFAULT_LOG_TAG) -> void:
	log_message(LogLevel.ERROR, message, tag)
