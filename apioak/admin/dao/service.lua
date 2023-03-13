local pdk    = require("apioak.pdk")
local uuid   = require("resty.jit-uuid")
local common = require("apioak.admin.dao.common")
local router = require("apioak.admin.dao.router")

local _M = {}

_M.PROTOCOLS_HTTP = "http"
_M.PROTOCOLS_HTTPS = "https"

function _M.created(params)

    local service_id = uuid.generate_v4()

    local service_body = {
        id        = service_id,
        name      = params.name,
        protocols = params.protocols or { _M.PROTOCOLS_HTTP },
        hosts     = params.hosts,
        plugins   = params.plugins or {},
        enabled   = params.enabled
    }

    local payload = {
        {
            KV = {
                Verb  = "set",
                Key   = common.SYSTEM_PREFIX_MAP.services .. service_id,
                Value = params.name,
            }
        },
        {
            KV = {
                Verb  = "set",
                Key   = common.PREFIX_MAP.services .. params.name,
                Value = pdk.json.encode(service_body),
            }
        },
    }

    local res, err = common.txn(payload)

    if err or not res then
        return nil, "create service FAIL [".. err .."]"
    end

    local _, update_hash_err = common.update_sync_data_hash()

    if update_hash_err then
        pdk.log.error("dao-service-create update_sync_data_hash err: [" .. update_hash_err .. "]")
    end

    return { id = service_id }, nil
end

function _M.updated(params, detail)

    local old_name = detail.name

    if params.name then
        detail.name = params.name
    end
    if params.protocols then
        detail.protocols = params.protocols
    end
    if params.hosts then
        detail.hosts = params.hosts
    end
    if params.plugins then
        detail.plugins = params.plugins
    end
    if params.enabled then
        detail.enabled = true
    else
        detail.enabled = false
    end

    local payload = {
        {
            KV = {
                Verb  = "delete",
                Key   = common.PREFIX_MAP.services .. old_name,
                Value = nil,
            }
        },
        {
            KV = {
                Verb  = "set",
                Key   = common.SYSTEM_PREFIX_MAP.services .. detail.id,
                Value = detail.name,
            }
        },
        {
            KV = {
                Verb  = "set",
                Key   = common.PREFIX_MAP.services .. detail.name,
                Value = pdk.json.encode(detail),
            }
        },
    }

    local res, err = common.txn(payload)

    if err or not res then
        return nil, "update service FAIL, err[".. tostring(err) .."]"
    end

    local update_service_name_err = router.update_associate_service_name(detail)

    if update_service_name_err then
        pdk.log.error("dao-service-update update_associate_service_name err: [" .. update_service_name_err .. "]")
    end

    local _, update_hash_err = common.update_sync_data_hash()

    if update_hash_err then
        pdk.log.error("dao-service-update update_sync_data_hash err: [" .. update_hash_err .. "]")
    end

    return { id = detail.id }, nil
end

function _M.lists()

    local res, err = common.list_keys(common.PREFIX_MAP.services)

    if err then
        return nil, "get service list FAIL [".. err .."]"
    end

    return res, nil
end

function _M.detail(key)

    if uuid.is_valid(key) then
        local tmp, err = common.get_key(common.SYSTEM_PREFIX_MAP.services .. key)

        if err then
            return nil, "service detail:[".. key .. "] does not exists"
        end

        if not tmp then
            return nil, nil
        end

        key = tmp
    end

    local res, err = common.get_key(common.PREFIX_MAP.services .. key)

    if err then
        return nil, "service detail:[".. key .. "] does not exists"
    end

    if not res then
        return nil, nil
    end

    return pdk.json.decode(res), nil
end

function _M.deleted(detail)

    local payload = {
        {
            KV = {
                Verb  = "delete",
                Key   = common.SYSTEM_PREFIX_MAP.services .. detail.id,
                Value = nil,
            }
        },
        {
            KV = {
                Verb  = "delete",
                Key   = common.PREFIX_MAP.services .. detail.name,
                Value = nil,
            }
        }
    }

    local res, err = common.txn(payload)

    if err or not res then
        return nil, "delete service FAIL, err[".. tostring(err) .."]"
    end

    local _, update_hash_err = common.update_sync_data_hash()

    if update_hash_err then
        pdk.log.error("dao-service-delete update_sync_data_hash err: [" .. update_hash_err .. "]")
    end

    return {}, nil
end

function _M.exist_host(hosts, filter_id)

    if #hosts == 0 then
        return {}, nil
    end

    local hosts_map = {}
    for i = 1, #hosts do
        hosts_map[hosts[i]] = 0
    end

    local list, err = common.list_keys(common.PREFIX_MAP.services)

    if err then
        return nil, "get services list FAIL [".. err .."]"
    end

    local exist_hosts = {}

    for i = 1, #list['list'] do

        repeat

            if list['list'][i]['id'] == filter_id then
                break
            end

            if #list['list'][i]['hosts'] > 0 then
                for j = 1, #list['list'][i]['hosts'] do
                    if hosts_map[list['list'][i]['hosts'][j]] then
                        table.insert(exist_hosts, list['list'][i]['hosts'][j])
                    end
                end
            end

        until true
    end

    if #exist_hosts == 0 then
        return nil, nil
    end

    return exist_hosts, nil
end

function _M.service_list_by_plugin(detail)

    if not detail.id and not detail.name then
        return nil, nil
    end

    local list, err = common.list_keys(common.PREFIX_MAP.services)

    if err then
        return nil, "get service list FAIL [".. err .."]"
    end

    local service_list = {}

    for i = 1, #list['list'] do

        local service_info = list['list'][i]

        repeat

            if not service_info['plugins'] then
                break
            end

            local service_plugins = service_info['plugins']

            for j = 1, #service_plugins do

                if service_plugins[j].id and (service_plugins[j].id == detail.id) then
                    table.insert(service_list, service_info)
                    break
                end

                if service_plugins[j].name and (service_plugins[j].name == detail.name) then
                    table.insert(service_list, service_info)
                    break
                end
            end

        until true
    end

    return service_list
end

function _M.update_associate_plugin_name (plugin)

    if not plugin.id  then
        return nil
    end

    local list, err = common.list_keys(common.PREFIX_MAP.services)

    if err then
        return "update_associate_plugin_name: get service list FAIL [".. err .."]"
    end

    for i = 1, #list['list'] do

        local service_info = list['list'][i]

        repeat

            if not service_info['plugins'] or (next(service_info['plugins']) == nil) then
                break
            end

            local associate_plugins = service_info['plugins']

            local new_plugins = {
                plugins = {}
            }

            local update = false
            for j = 1, #associate_plugins do

                if associate_plugins[j].id and (associate_plugins[j].id == plugin.id) then
                    update = true
                    table.insert(new_plugins.plugins, { id = plugin.id, name = plugin.name })
                else
                    table.insert(new_plugins.plugins, associate_plugins[j])
                end
            end

            if update then
                local _, update_err = _M.updated(new_plugins, service_info)

                if update_err then
                    return "update_associate_plugin_name: update plugin name FAIL [".. update_err .."]"
                end
            end

        until true
    end

    return nil
end

return _M