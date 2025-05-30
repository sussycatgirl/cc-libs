--[[
    Basic library to interact with PushGateway.
    https://github.com/prometheus/pushgateway

    Features:
    - Partial API coverage (Why does CC only do GET and POST)
    - unstable label support
    - It kinda works
    - Supports basicauth (haven't tested it without)
]]--

local PushGW = {
    ["name"] = "PushGW",
    ["author"] = "sussycatgirl",
    ["_debug"] = false
}

function PushGW.setDebug(enable_debug)
  PushGW._debug = enable_debug
end

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
    local labels = ""
    
    if v.labels ~= nil then
      for lk, lv in pairs(v.labels) do
        if string.len(labels) > 0 then
          labels = labels..","
        end
        
        -- this is supposed to foolproof things a bit
        -- but you probably cant rely on it to be fully
        -- safe. be careful if youre passing user input
        -- to labels
        local safe_value = string.gsub(lv, "\\", "\\\\")
        safe_value = string.gsub(safe_value, "\"", "\\\"")
        
        labels = labels
          ..lk.."=\""..safe_value.."\""
      end
    end
    
    metricout = metricout
      .."#TYPE "..k.." "..v.type.."\n"
      ..k.."{"..labels.."} "..v.value.."\n"
  end

  return metricout
end

function PushGW._setMetric(k, v, type, labels)
    PushGW._metrics[k] = {
        ["type"] = type,
        ["value"] = v,
        ["labels"] = labels
    }
end

function PushGW.counter(key, startValue)
    if key == nil then error("Missing key") end

    local value = startValue
    if value == nil then value = 0 end
    PushGW._setMetric(key, value, "counter")
    
    local labels = {}

    return {
        ["inc"] = function (amount)
            if amount == nil then amount = 1 end
            if amount < 0 then error("Cannot decrement counter") end
            value = amount + value
            PushGW._setMetric(key, value, "counter", labels)
        end,
        ["set"] = function (amount)
            if amount < value and amount ~= 0 then error("Cannot decrement counter") end
            value = amount
            PushGW._setMetric(key, value, "counter", labels)
        end,
        ["reset"] = function ()
            value = 0
            PushGW._setMetric(key, value, "counter", labels)
        end,
        ["getValue"] = function ()
            return value
        end,
        ["label"] = function (name, value)
            labels[name] = value
        end
    }
end

function PushGW.gauge(key, startValue)
    if key == nil then error("Missing key") end

    local value = startValue
    if value == nil then value = 0 end
    PushGW._setMetric(key, value, "gauge")
    
    local labels = {}

    return {
        ["inc"] = function (amount)
            if amount == nil then amount = 1 end
            value = amount + value
            PushGW._setMetric(key, value, "gauge", labels)
        end,
        ["set"] = function (amount)
            value = amount
            PushGW._setMetric(key, value, "gauge", labels)
        end,
        ["getValue"] = function ()
            return value
        end,
        ["label"] = function (name, value)
            labels[name] = value
        end
    }
end

-- Push metrics
function PushGW.push()
    if PushGW.url == nil then
        error("PushGW: push() called without"
            .." calling configure() first")
    end
    
    local metrics = PushGW._toMetrics(PushGW._metrics)
    
    if PushGW._debug then
      print("[>] "..metrics)
    end

    local res, err, errRes = http.post(
        PushGW.url.."/job/"..PushGW.job,
        metrics,
        PushGW.auth
    )
    
    if err ~= nil then
      error(err)
    end
end

return PushGW
