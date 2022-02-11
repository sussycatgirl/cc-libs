--[[
    Basic library to interact with PushGateway.
    https://github.com/prometheus/pushgateway

    Features:
    - Unreliable
    - Partial API coverage (Why does CC only do GET and POST) (I'm also lazy) (+ dont care + ratio)
    - It kinda works
    - Supports basicauth (haven't tested it without)
]]--

local PushGW = {
    ["name"] = "PushGW",
    ["author"] = "Jan"
}

local internet = require("internet")

-- https://stackoverflow.com/questions/34618946/lua-base64-encode
local function b64enc(data)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return chars:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- Set the remote URL and job name.
-- Do not pass a trailing slash, like this:
-- http://pushgateway:6969/metrics
function PushGW.configure(url, job)
    if url == nil or job == nil then
        error("PushGW: No 'url' or 'job' param passed to configure()")
    end

    PushGW.url = url
    PushGW.job = job
    PushGW._metrics = {}
end

-- Use BasicAuth
function PushGW.useAuthentication(user, pass)
    PushGW.auth = {
        ["Authorization"] = "Basic "..b64enc(user..":"..pass)
    }
end

function PushGW._toMetrics(metrics)
    local metricout = ""
    for k,v in pairs(metrics) do
        metricout = metricout
            .."#TYPE "..k.." "..v.type.."\n"
            ..k.."{} "..v.value.."\n"
    end

    return metricout
end

function PushGW._setMetric(k, v, type, tags)
    PushGW._metrics[k] = {
        ["type"] = type,
        ["value"] = v,
        ["tags"] = tags
    }
end

function PushGW.counter(key, startValue)
    if key == nil then error("Missing key") end

    local value = startValue
    if value == nil then value = 0 end
    PushGW._setMetric(key, value, "counter")

    return {
        ["inc"] = function (amount)
            if amount == nil then amount = 1 end
            if amount < 0 then error("Cannot decrement counter") end
            value = amount + value
            PushGW._setMetric(key, value, "counter")
        end,
        ["set"] = function (amount)
            if amount < value and amount ~= 0 then error("Cannot decrement counter") end
            value = amount
            PushGW._setMetric(key, value, "counter")
        end,
        ["reset"] = function ()
            value = 0
            PushGW._setMetric(key, value, "counter")
        end
    }
end

function PushGW.gauge(key, startValue)
    if key == nil then error("Missing key") end

    local value = startValue
    if value == nil then value = 0 end
    PushGW._setMetric(key, value, "gauge")

    return {
        ["inc"] = function (amount)
            if amount == nil then amount = 1 end
            value = amount + value
            PushGW._setMetric(key, value, "gauge")
        end,
        ["set"] = function (amount)
            value = amount
            PushGW._setMetric(key, value, "gauge")
        end
    }
end

-- Push metrics
function PushGW.push()
    if PushGW.url == nil then
        error("PushGW: push() called without"
            .." calling configure() first")
    end

    internet.request(
        PushGW.url.."/job/"..PushGW.job,
        PushGW._toMetrics(PushGW._metrics),
        PushGW.auth
    )
end

return PushGW
