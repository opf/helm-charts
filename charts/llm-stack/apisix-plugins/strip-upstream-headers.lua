--
-- strip-upstream-headers
--
-- Removes a configured list of request headers before APISIX proxies the
-- request to the upstream.
--
-- Unlike proxy-rewrite's headers.remove, the header values stay readable via
-- $http_<name> for the rest of the request. This means, for example, the prometheus plugin's
-- extra_labels still get the value in the
-- log phase, even though the upstream never sees the header.
--
-- Route / consumer / global rule config example:
--   "strip-upstream-headers": { "headers": ["X-Tenant-Id"] }
--

local core = require("apisix.core")

local ngx         = ngx
local ipairs      = ipairs
local str_lower   = string.lower
local re_gsub     = ngx.re.gsub
local clear_header = ngx.req.clear_header

local plugin_name = "strip-upstream-headers"

local schema = {
    type = "object",
    properties = {
        headers = {
            description = "request headers to remove before proxying upstream",
            type = "array",
            minItems = 1,
            uniqueItems = true,
            items = {
                type = "string",
                minLength = 1,
                -- valid HTTP header name characters
                pattern = "^[!#$%&'*+.^_`|~0-9A-Za-z-]+$",
            },
        },
    },
    required = { "headers" },
}

local _M = {
    version  = 0.1,
    -- low priority: runs late in the access phase, after most other plugins
    -- have had a chance to read the headers. Change if it collides.
    priority = 10,
    name     = plugin_name,
    schema   = schema,
}


function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end


local function var_name(header)
    -- "X-Tenant-Id" -> "http_x_tenant_id"
    local name = re_gsub(str_lower(header), "-", "_", "jo")
    return "http_" .. name
end


-- The access phase runs after all rewrite phases, including plugins merged
-- in from a consumer (e.g. a consumer-level proxy-rewrite that *sets* the
-- header). So the value cached below is the final one.
function _M.access(conf, ctx)
    for _, header in ipairs(conf.headers) do
        -- Reading through ctx.var caches the value for the rest of the
        -- request, so later lookups of $http_<name> (prometheus extra_labels,
        -- loggers) still return it after the header is cleared.
        local _ = ctx.var[var_name(header)]

        -- Removes the header from the request APISIX sends upstream.
        clear_header(header)
    end
end


return _M