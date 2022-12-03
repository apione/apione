local pdk        = require("apioak.pdk")
local dao        = require("apioak.dao")
local schema     = require("apioak.schema")
local oakrouting = require("resty.oakrouting")
local ngx_ssl    = require("ngx.ssl")

local ssl_objects

local oakrouting_ssl_prefix = "oakrouting_ssl_prefix"
local oakrouting_ssl_method = "OPTIONS"

local _M = {}

_M.events_source_ssl   = "events_source_ssl"
_M.events_type_put_ssl = "events_type_put_ssl"

local function generate_ssl_data(ssl_data)

    if not ssl_data or type(ssl_data) ~= "table" then
        return nil, "generate_ssl_data: the data is empty or the data format is wrong["
                .. pdk.json.encode(ssl_data, true) .. "]"
    end

    if not ssl_data.sni or not ssl_data.cert or not ssl_data.key then
        return nil, "generate_ssl_data: Missing data required fields["
                .. pdk.json.encode(ssl_data, true) .. "]"
    end

    return {
        path    = oakrouting_ssl_prefix .. ":" .. ssl_data.sni,
        method  = oakrouting_ssl_method,
        handler = function(params, oak_ctx)

            oak_ctx.params = params

            oak_ctx.config = {}
            oak_ctx.config.cert_key = {
                sni  = ssl_data.sni,
                cert = ssl_data.cert,
                key  = ssl_data.key,
            }
        end
    }, nil
end

_M.ssl_handler = function (data, event, source)

    if source ~= _M.events_source_ssl then
        return
    end

    if event ~= _M.events_type_put_ssl then
        return
    end

    if (type(data) ~= "table") or not next(data) then
        return
    end

    local oak_ssl_data = {}

    for i = 1, #data do

        repeat

            local ssl_data, ssl_data_err = generate_ssl_data(data[i])

            if ssl_data_err then
                pdk.log.error("ssl_handler: generate ssl data err: [" .. tostring(ssl_data_err) .. "]")
                break
            end

            table.insert(oak_ssl_data, ssl_data)

        until true
    end

    ssl_objects = oakrouting.new(oak_ssl_data)
end

function _M.sync_update_ssl_data()

    local ssl_list, ssl_list_err = dao.certificate.lists()

    if ssl_list_err then
        return nil, ssl_list_err
    end

    if not ssl_list.list then
        return nil, nil
    end

    local ssl_data = {}
    for i = 1, #ssl_list.list do

        repeat

            local _, err = pdk.schema.check(schema.certificate.sync_data_certificate, ssl_list.list[i])

            if err then
                pdk.log.error("sync_update_ssl_data: schema check err:[" .. err .. "]["
                                      .. pdk.json.encode(ssl_list.list[i], true) .. "]")
                break
            end

            for j = 1, #ssl_list.list[i].snis do
                table.insert(ssl_data, {
                    sni = ssl_list.list[i].snis[j],
                    key = ssl_list.list[i].key,
                    cert = ssl_list.list[i].cert,
                })
            end

        until true
    end

    if not next(ssl_data) then
        return nil, nil
    end

    return ssl_data, nil
end

function _M.ssl_match(oak_ctx)

    if not oak_ctx.matched or not oak_ctx.matched.host then
        pdk.log.error("ssl_match: oak_ctx data format err: [" .. pdk.json.encode(oak_ctx, true) .. "]")
        return false
    end

    local match_sni = oakrouting_ssl_prefix .. ":" .. oak_ctx.matched.host

    if not ssl_objects then
        return false
    end

    local match, err = ssl_objects:dispatch(match_sni, oakrouting_ssl_method, oak_ctx)

    if err then
        pdk.log.error("ssl_match: ssl_objects dispatch err: [" .. tostring(err) .. "]")
        return false
    end

    if not match then
        return false
    end

    ngx_ssl.clear_certs()

    -- TODO Store cdata to lrucache
    local parsed_cert, err = ngx_ssl.parse_pem_cert(oak_ctx.config.cert_key.cert)

    if err ~= nil then
        pdk.log.error("failed to parse pem cert" ,err)
        return false
    end

    local ok, err = ngx_ssl.set_cert(parsed_cert)

    if err ~= nil or not ok then
        pdk.log.error("failed to set pem cert" ,err)
        return false
    end

    -- TODO Store cdata to lrucache
    local parsed_priv_key, err = ngx_ssl.parse_pem_priv_key(oak_ctx.config.cert_key.key)

    if err ~= nil then
        pdk.log.error("failed to parse pem priv key" ,err)
        return false
    end

    local ok, err = ngx_ssl.set_priv_key(parsed_priv_key)

    if err ~= nil or not ok then
        pdk.log.error("failed to set pem priv key" ,err)
        return false
    end

    return true
end

return _M