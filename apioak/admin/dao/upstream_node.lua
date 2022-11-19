local pdk    = require("apioak.pdk")
local uuid   = require("resty.jit-uuid")
local common = require("apioak.admin.dao.common")

local _M = {}

_M.DEFAULT_PORT = 80
_M.DEFAULT_WEIGHT = 1
_M.DEFAULT_TIMEOUT = 1
_M.DEFAULT_INTERVAL = 5
_M.DEFAULT_ENABLED_FALSE = false
_M.DEFAULT_HEALTH = "HEALTH"
_M.DEFAULT_UNHEALTH = "UNHEALTH"

function _M.created(params)
    local id = uuid.generate_v4()

    local data = {
        id      = id,
        name    = params.name,
        address = params.address or "",
        port    = params.port or _M.DEFAULT_PORT,
        health  = params.health or _M.DEFAULT_HEALTH,
        weight  = params.weight or _M.DEFAULT_WEIGHT,
        check   = {
            enabled  = params.check.enabled or _M.DEFAULT_ENABLED_FALSE,
            tcp      = params.check.tcp or "",
            method   = params.check.method or "",
            http     = params.check.http or "",
            timeout  = params.check.timeout or _M.DEFAULT_TIMEOUT,
            interval = params.check.interval or _M.DEFAULT_INTERVAL,
        }
    }

    local payload = {
        {
            KV = {
                Verb  = "set",
                Key   = common.SYSTEM_PREFIX_MAP.upstream_nodes .. id,
                Value = params.name,
            }
        },
        {
            KV = {
                Verb  = "set",
                Key   = common.PREFIX_MAP.upstream_nodes .. params.name,
                Value = pdk.json.encode(data),
            }
        },
    }

    local res, err = common.txn(payload)

    if err or not res then
        return nil, "create upstream_node FAIL [".. err .."]"
    end

    return { id = id }, nil
end

function _M.lists()
    local res, err = common.list_keys(common.PREFIX_MAP.upstream_nodes)

    if err then
        return nil, "get upstream_node list FAIL [".. err .."]"
    end

    return res, nil
end

function _M.updated(params, detail)

    local old_name = detail.name

    if params.name then
        detail.name = params.name
    end
    if params.address then
        detail.address = params.address
    end
    if params.port then
        detail.port = params.port
    end
    if params.weight then
        detail.weight = params.weight
    end
    if params.health then
        detail.health = params.health
    end
    if params.check.enabled then
        detail.check.enabled = params.check.enabled
    end
    if params.check.tcp then
        detail.check.tcp = params.check.tcp
    end
    if params.check.method then
        detail.check.method = params.check.method
    end
    if params.check.http then
        detail.check.http = params.check.http
    end
    if params.check.interval then
        detail.check.interval = params.check.interval
    end
    if params.check.timeout then
        detail.check.timeout = params.check.timeout
    end

    local payload = {
        {
            KV = {
                Verb  = "delete",
                Key   = common.PREFIX_MAP.upstream_nodes .. old_name,
                Value = nil,
            }
        },
        {
            KV = {
                Verb  = "set",
                Key   = common.SYSTEM_PREFIX_MAP.upstream_nodes .. detail.id,
                Value = detail.name,
            }
        },
        {
            KV = {
                Verb  = "set",
                Key   = common.PREFIX_MAP.upstream_nodes .. detail.name,
                Value = pdk.json.encode(detail),
            }
        },
    }

    local res, err = common.txn(payload)

    if err or not res then
        return nil, "update upstream_node FAIL, err[".. tostring(err) .."]"
    end

    return { id = detail.id }, nil
end

function _M.detail(key)

    if uuid.is_valid(key) then

        local name, err = common.get_key(common.SYSTEM_PREFIX_MAP.upstream_nodes .. key)

        if err or not name then
            return nil, "upstream_node key:[".. key .. "] does not exist"
        end

        key = name
    end

    local detail, err = common.get_key(common.PREFIX_MAP.upstream_nodes .. key)

    if err or not detail then
        return nil, "upstream_node detail:[".. key .."] does not exist"
    end

    return  pdk.json.decode(detail), nil
end

local upstream_relation = function(detail)

    local list, err = common.list_keys(common.PREFIX_MAP.upstreams)

    if err then
        return nil, err
    end

    list = list['list']

    local relation_upstream = {}
    for i = 1, #list do
        local nodes = list[i].nodes

        if #nodes > 0 then
            for j = 1, #nodes do
                if nodes[j].id ~= nil and nodes[j].id == detail.id then
                    table.insert(relation_upstream, list[i])
                    break
                end

                if nodes[j].name ~= nil and nodes[j].name == detail.name then
                    table.insert(relation_upstream, list[i])
                    break
                end
            end
        end
    end

    if #relation_upstream == 0 then
        relation_upstream = nil
    end

    return relation_upstream, nil
end

function _M.deleted(detail)

    local relation_upstream, err = upstream_relation(detail)
    if err then
        return nil, "upstream_relation FAIL [".. err .."]"
    end

    if relation_upstream then
        return nil, "the upstream_node is being used by upstream"
    end

    local payload = {
        {
            KV = {
                Verb  = "delete",
                Key   = common.SYSTEM_PREFIX_MAP.upstream_nodes .. detail.id,
                Value = nil,
            }
        },
        {
            KV = {
                Verb  = "delete",
                Key   = common.PREFIX_MAP.upstream_nodes .. detail.name,
                Value = nil,
            }
        }
    }

    local res, err = common.txn(payload)

    if err or not res then
        return nil, "delete upstream_node FAIL, err[".. tostring(err) .."]"
    end

    return {}, nil
end

return _M