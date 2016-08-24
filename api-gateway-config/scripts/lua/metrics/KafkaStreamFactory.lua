-- Copyright (c) 2015 Adobe Systems Incorporated. All rights reserved.
--
--   Permission is hereby granted, free of charge, to any person obtaining a
--   copy of this software and associated documentation files (the "Software"),
--   to deal in the Software without restriction, including without limitation
--   the rights to use, copy, modify, merge, publish, distribute, sublicense,
--   and/or sell copies of the Software, and to permit persons to whom the
--   Software is furnished to do so, subject to the following conditions:
--
--   The above copyright notice and this permission notice shall be included in
--   all copies or substantial portions of the Software.
--
--   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
--   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
--   DEALINGS IN THE SOFTWARE.

--
-- A factory to initialize a kafka or kinesis logger
-- User: doronrk
--

local logger_factory = require "api-gateway.logger.factory"
local MetricsCls = require "metrics.MetricsBuffer"
local metrics = MetricsCls:new()

local function get_logger_configuration()
    local logger_module = "api-gateway.logger.BufferedAsyncLogger"
    local logger_opts = {
        flush_length = 500,          -- http://docs.aws.amazon.com/kinesis/latest/APIReference/API_PutRecords.html - 500 is max
        flush_interval = 5,          -- interval in seconds to flush regardless if the buffer is full or not
        flush_concurrency = 16,      -- max parallel threads used for sending logs
        flush_throughput = 10000,     -- max logs / SECOND that can be sent to the Kinesis backend
        sharedDict = "stats_kafka", -- dict for caching the logs
        backend = "api-gateway.logger.backend.KafkaLogger",
        backend_opts = {
	    	key = "value"
        },
        callback = function(status)
            local client_failed_logs = 0
            if (tonumber(status.backend_response_code) == nil) then
                client_failed_logs = status.logs_sent
            end
            metrics:count("kinesis-logger.records_sent.count", tonumber(status.logs_sent))
            metrics:count("kinesis-logger.records_failed.count", tonumber(status.logs_failed))
            metrics:count("kinesis-logger.records_failed_client.count", tonumber(client_failed_logs))
            metrics:count("kinesis-logger.response." .. tostring(status.backend_response_code) .. ".count", 1)
            metrics:count("kinesis-logger.threads.running", tonumber(status.threads_running))
            metrics:count("kinesis-logger.threads.pending", tonumber(status.threads_pending))
            metrics:count("kinesis-logger.buffer.count", tonumber(status.buffer_length))
        end
    }
    return logger_module, logger_opts
end

local function get_logger(name)
    -- try to reuse an existing logger instance for each worker process
    if (logger_factory:hasLogger(name)) then
        return logger_factory:getLogger(name)
    end

    -- create a new logger instance
    local logger_module , logger_opts
    if (name == "kafka-logger") then
        logger_module , logger_opts = get_logger_configuration()
    end

    return logger_factory:getLogger(name, logger_module, logger_opts)
end


local MetricsCollector = require "metrics.KinesisMetricsCollector"
local collector = MetricsCollector:new()

local function _captureUsageData()
	ngx.log(ngx.ERR, "in KafkaStreamFactory, _captureUsageData")
	local kinesisSwitch = ngx.var.kinesisSwitch
    if (kinesisSwitch == "off") then
        return
    end
    local kafkaLogger = get_logger("kafka-logger")
    return collector:logCurrentRequest(kafkaLogger)
end

return {
    captureUsageData = _captureUsageData,
    getLogger = get_logger
}