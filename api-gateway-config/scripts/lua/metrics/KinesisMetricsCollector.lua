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

-- Records the metrics for the current request.
--
-- # Sample StatsD messages
-- # pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.device_links.POST.200.count
-- # pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.device_links.POST.200.responseTime
-- # pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.device_links.POST.200.upstreamResponseTime
-- # pub.publisher_name.consumer.consumer_name.app.application_name.service.service_name.prod.region.useast.request.validate_request.GET.200.responseTime
--
-- NOTE: by default it logs the root-path of the request. If the root path is used for versioning ( i.e. v1.0 ) there is the property $metric_path that
-- can be set on the location block in order to override the root-path
--
-- Created by IntelliJ IDEA.
-- User: nramaswa
-- Date: 3/14/14
-- Time: 12:45 AM
-- To change this template use File | Settings | File Templates.
--
local cjson = require "cjson"

local ngx_var = ngx.var

local M = {}

function M:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

local function get_http_resource()
    local user_defined_path = nil
    if ( ngx_var.metrics_path ~= nil and ngx_var.metrics_path ~= "" ) then
        user_defined_path = ngx_var.metrics_path
    end

    local request_uri = user_defined_path or ngx_var.uri or "/".. serviceName
    local pattern = "(?:\\/?\\/?)([^\\/:]+)" -- To get the first part of the request uri excluding content after :
    local requestPathFromURI, err = ngx.re.match(request_uri, pattern)
    local requestPath = serviceName -- default value

    if err then
        ngx.log(ngx.WARN, "Assigned requestPath as serviceName due to error in extracting requestPathFromURI: ", err)
    end

    if requestPathFromURI then
        if requestPathFromURI[1] then
            requestPath = requestPathFromURI[1]
            requestPath = requestPath:gsub("%.", "_")
            --ngx.log(ngx.INFO, "\n the extracted requestPath::"..requestPath)
        end
    end
    return requestPath
end

function M:logCurrentRequest(kinesisLogger)

    local publisherName = ngx_var.publisher_org_name or "undefined"
    local consumerName = ngx_var.consumer_org_name or "undefined"
    local appName = ngx_var.app_name or "undefined"
    local serviceName = ngx_var.service_name or "undefined"
    local realm = ngx_var.service_env or ngx_var.realm or "sandbox" -- NOT USED FOR NOW
    local requestMethod = ngx_var.request_method or "undefined"
    local status = ngx_var.status or "0"
    local validateRequestStatus = ngx_var.validate_request_status or "0"
    local requestTime = tonumber(ngx_var.request_time) or -1
    local upstreamResponseTime = tonumber(ngx_var.upstream_response_time) or -1
    local validateTime = tonumber(ngx_var.validate_request_response_time) or -1
    local rgnName = ngx_var.aws_region or "undefined"
    local bytesSent = tonumber(ngx_var.bytes_sent) or -1
    local bytesReceived = tonumber(ngx_var.request_length) or -1
    local delayedTime = tonumber(ngx.var.request_delayed) or 0

    local http_resource = get_http_resource()

    -- FUTURE TO DO: guid of the applicatiton owner, send this data after figuring it out.
    local applnOwnerGuid = ngx_var.appln_owner_guid or "0"

    local userGuid = ngx_var.oauth_token_user_id or "0"
    local useripAddress = ngx_var.http_x_forwarded_for or "127.0.0.1"
    local userCountryCode = ngx_var.user_country_code or "undefined"


    local utc = ngx.utctime()
    local timeStamp = string.sub(utc, 1, 10) .. "T" .. string.sub(utc, 12) .. "-00"

    local randomSeed = ngx.now() * 1000
    local key_timestamp = ngx.utctime() .."-".. math.random(randomSeed)

    local key = ngx_var.requestId

    if(key == nil or #key < 2) then
        key = userGuid..".".. key_timestamp ..".".. http_resource
    end


    if ( kinesisLogger ~= nil) then

        local partition_key = ngx.utctime() .."-".. math.random(ngx.now() * 1000)
        local kinesis_data = {}

        -- Metrics to send to kinesis
        kinesis_data["gwid"] = "dc"

        kinesis_data["timestamp"] = timeStamp
        kinesis_data["reqid"] = ngx_var.requestId or "N/A"
        kinesis_data["publisher"] = publisherName
        kinesis_data["consumer"] = consumerName
        kinesis_data["app"] = appName
        kinesis_data["service"] = serviceName
        kinesis_data["region"] = rgnName

        kinesis_data["http_referer"] = ngx_var.http_referer
        kinesis_data["user_agent"] = ngx_var.http_user_agent

        kinesis_data["hostname"] = ngx_var.hostname
        kinesis_data["http_host"] = ngx_var.host
        kinesis_data["http_method"] = requestMethod
        kinesis_data["http_status"] = status
        kinesis_data["http_xfwdf"] = ngx_var.http_x_forwarded_for
        kinesis_data["http_protocol"] = ngx_var.http_x_forwarded_proto

        kinesis_data["uri"] = ngx_var.request_uri           -- the complete URI
        kinesis_data["scheme"] = ngx_var.scheme
        kinesis_data["http_resource"] = http_resource -- a name of the resource behind the URI

        kinesis_data["request_time"] = requestTime
        kinesis_data["backend_request_time"] = upstreamResponseTime
        kinesis_data["backend_request_status"] = ngx_var.upstream_status
        kinesis_data["backend_address"] = ngx_var.upstream_addr

        kinesis_data["user_ip"] = useripAddress
        kinesis_data["user_uid"] = userGuid
        kinesis_data["user_country_code"] = userCountryCode

        kinesis_data["bytes_sent"] = bytesSent
        kinesis_data["bytes_received"] = bytesReceived

        kinesis_data["gw_validation_time"] = validateTime
        kinesis_data["gw_validation_status"] = validateRequestStatus

        kinesis_data["delayed"] = delayedTime

        -- Send logs to kinesis
        kinesisLogger:logMetrics(partition_key, cjson.encode(kinesis_data))

    else
        ngx.log(ngx.WARN, "Metrics are not sent to Kinesis")
    end

end

return M