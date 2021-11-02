## [0.2.0] - 2021-11-02

* Change `filename_or_process` to just `name`
* Allow user to set a logger which allows new methods:
  * `log_batch_line` (uses the logger to log the batch line; no-op if no 
    logger)
  * `log_final_line` (as above)
  * `increment_and_report`, equivalent to `wp.incr; wp.on_batch {log.info
    (wp.bach_line)}`
* Added `Waypoint::Structured` which provides hashes instead of strings 
  for `batch_line` and `final_line` and aliases them to `batch_data` and 
  `final_data`
  * Presumes you're using something like `semantic_logger`, or at least 
    `logger.formatter`

## [0.1.2] - 2021-10-28

* Extract from other code and more liberal use of ppnum
* Allow setting of filename/process name for use in default output lines

## [0.1.0] - 2021-10-28

- Initial release
