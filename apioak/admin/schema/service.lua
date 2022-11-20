local service = require "apioak.admin.dao.service"
local common  = require "apioak.admin.schema.common"

local _M = {}

local hosts = {
    type = "array",
    minItems = 1,
    uniqueItems = true,
    items = {
        type = "string",
        minLength = 3,
        pattern = "^(?=^.{3,255}$)[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+$"
    }
}

_M.created = {
    type = "object",
    properties = {
        name = common.name,
        protocols = {
            type = "array",
            minItems = 1,
            uniqueItems = true,
            items = {
                type = "string",
                enum = { service.PROTOCOLS_HTTP, service.PROTOCOLS_HTTPS }
            },
            default = { service.PROTOCOLS_HTTP }
        },
        hosts = hosts,
        plugins = common.items_array_id_or_name,
        enabled = {
            type = "boolean",
            default = true
        }
    },
    required = { "name", "hosts" }
}

_M.updated = {
    type = "object",
    properties = {
        service_key = common.param_key,
        name = common.name,
        protocols = {
            type = "array",
            minItems = 1,
            uniqueItems = true,
            items = {
                type = "string",
                enum = { service.PROTOCOLS_HTTP, service.PROTOCOLS_HTTPS }
            },
        },
        hosts = hosts,
        plugins = common.items_array_id_or_name,
        enabled = {
            type = "boolean"
        }
    },
    required = { "service_key"}
}

_M.detail = {
    type = "object",
    properties = {
        service_key = common.param_key
    },
    required = { "service_key"}
}

_M.deleted = {
    type = "object",
    properties = {
        service_key = common.param_key
    },
    required = { "service_key"}
}

return _M
