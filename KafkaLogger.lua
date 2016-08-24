--[[
  Copyright (c) 2016. Adobe Systems Incorporated. All rights reserved.
    This file is licensed to you under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
      http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under the License is
    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR RESPRESENTATIONS OF ANY KIND,
    either express or implied.  See the License for the specific language governing permissions and
    limitations under the License.
  ]]

---
-- A Kafka logging class that takes a list of key,value pairs and sends them to Kafka
--

local _M = {}

function _M:new(o)
    o = o or {}

    if (not o.___super) then
        self:constructor(o)
    end

    setmetatable(o, self)
    self.__index = self
    return o
end

function _M:constructor(o)
    ngx.log(ngx.DEBUG, "constructor")

    assert(o.key ~= nil, "Please provide a valid key in the init object.")
end

function _M:sendLogs(logs_table)
    ngx.log(ngx.ERR, "in KafkaLogger, sendLogs called")
end

return _M