# PushGW
Stupid library for pushing data to Prometheus via [PushGateway](https://github.com/prometheus/pushgateway). Supports BasicAuth.

### Usage
Grab the library from `pushgw/cc/pushgw.lua` or `pushgw/oc/pushgw.lua`, depending on if you use ComputerCraft or OpenComputers, and download it using `wget`, `oppm` or similar.

```lua
local pushgw = require("pushgw")

-- Set the PushGateway URL and job name
pushgw.configure("http://pushgateway:6969/metrics", "example_job_name")

-- Optional: Configure Authentication
pushgw.useAuthentication("username", "P@ssw0rd!")

local my_cool_counter = pushgw.counter("example_counter")
local my_epic_gauge = pushgw.gauge("example_gauge")

my_cool_counter.set(5)
my_epic_gauge.set(2)

-- Push your new or updated metrics
pushgw.push()

-- Increment counters and gauges
my_cool_counter.inc()
my_epic_gauge.inc(3)

-- This will not work as counters can't be decremented
my_cool_counter.inc(-2)
my_cool_counter.set(1) -- 1 is lower than the current value

-- Use counter.reset() to reset a counter to 0
my_cool_counter.reset()
```

### Limitations / Drawbacks
- If a web request fails, it will fail silently in the background instead of erroring - This is due to me being a lazy fuck. Might change in the future.
- This library only supports counters and gauges due to, as mentioned above, me being a lazy fuck.
