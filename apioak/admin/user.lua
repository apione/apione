local db         = require("apioak.db")
local pdk        = require("apioak.pdk")
local schema     = require("apioak.schema")
local controller = require("apioak.admin.controller")

local user_controller = controller.new("user")

function user_controller.register()

    local body = user_controller.get_body()

    user_controller.check_schema(schema.user.register, body)

    local res, err = db.user.all()
    if err then
        pdk.response.exit(500, { err_message = err })
    end

    if #res == 0 then
        body.is_owner = 1
        body.is_enable = 1
    end

    if body.password ~= body.valid_password then
        pdk.response.exit(401, { err_message = "inconsistent password entry" })
    end

    res, err = db.user.create(body)
    if err then
        pdk.response.exit(500, { err_message = err })
    end

    if body.is_owner == 1 then
        local user_id = res.insert_id
        res, err = db.group.create({
            name = "Default Group",
            description = "default project group",
            user_id    = user_id
        })
        if err then
            pdk.response.exit(500, { err_message = err })
        end

        local group_id = res.insert_id
        res, err = db.role.create(group_id, user_id, true)
        if err then
            pdk.response.exit(500, { err_message = err })
        end
    end

    pdk.response.exit(200, { err_message = "OK" })
end

function user_controller.login()

    local body = user_controller.get_body()

    user_controller.check_schema(schema.user.login, body)

    local res, err = db.user.query_by_email(body.email)
    if err then
        pdk.response.exit(401, { err_message = err })
    end

    if #res == 0 then
        pdk.response.exit(401, { err_message = pdk.string.format(
                "request login user \"%s\" not exists", body.email) })
    end

    local user = res[1]
    if pdk.string.md5(body.password) ~= user.password then
        pdk.response.exit(401, { err_message = pdk.string.format(
                "request login user \"%s\" password error", body.email) })
    end

    if user.is_enable == 0 then
        pdk.response.exit(401, { err_message =
                                 "user account is not enabled, please contact the administrator" })
    end

    res, err = db.token.query_by_uid(user.id)
    if err then
        pdk.response.exit(401, { err_message = err })
    end

    if #res == 0 then
        res, err = db.token.create_by_uid(user.id)
    else
        res, err = db.token.update_by_uid(user.id)
    end

    if err then
        pdk.response.exit(401, { err_message = err })
    end
    user.token = res.token

    if user.is_owner then
        res, err = db.group.all(true)
    else
        res, err = db.group.query_by_uid(user.id)
    end

    if err then
        pdk.response.exit(401, { err_message = err })
    end

    pdk.response.exit(200, { err_message = "OK" , user = {
        id       = user.id,
        name     = user.name,
        token    = user.token,
        is_owner = user.is_owner,
        groups   = res
    }})
end

function user_controller.logout()

    user_controller.user_authenticate()

    local _, err = db.token.expire_by_token(user_controller.token)

    if err then
        pdk.response.exit(500, { err_message = err })
    end
    pdk.response.exit(200, { err_message = "OK" })
end

function user_controller.list()

    user_controller.user_authenticate()

    local res, err = db.user.all()

    if err then
        pdk.response.exit(500, { err_message = err })
    end
    pdk.response.exit(200, { err_message = "OK", users = res })
end

function user_controller.created()

    user_controller.user_authenticate()

    local body = user_controller.get_body()

    user_controller.check_schema(schema.user.created, body)

    if body.password ~= body.valid_password then
        pdk.response.exit(401, { err_message = "inconsistent password entry" })
    end

    if not user_controller.is_owner then
        pdk.response.exit(401, { err_message = "no permission to create user" })
    end

    local _, err = db.user.create(body)

    if err then
        pdk.response.exit(500, { err_message = err })
    end
    pdk.response.exit(200, { err_message = "OK" })
end


function user_controller.updated_password(params)

    user_controller.user_authenticate()

    local body   = user_controller.get_body()
    body.user_id = params.user_id

    user_controller.check_schema(schema.user.updated_password, body)

    if not user_controller.is_owner and params.user_id ~= user_controller.uid then
        pdk.response.exit(401, { err_message = "no permission to create user" })
    end

    if body.password ~= body.valid_password then
        pdk.response.exit(401, { err_message = "inconsistent password entry" })
    end

    local _, err = db.user.update_password(params.user_id, body.password)

    if err then
        pdk.response.exit(500, { err_message = err })
    end
    pdk.response.exit(200, { err_message = "OK" })
end

function user_controller.updated_status(params)

    user_controller.user_authenticate()

    local body   = user_controller.get_body()
    body.user_id = params.user_id

    user_controller.check_schema(schema.user.updated_status, body)

    if not user_controller.is_owner then
        pdk.response.exit(401, { err_message = "no permission to create user" })
    end

    local _, err = db.user.update_status(params.user_id, body.is_enable)

    if err then
        pdk.response.exit(500, { err_message = err })
    end
    pdk.response.exit(200, { err_message = "OK" })
end

function user_controller.deleted(params)

    user_controller.user_authenticate()

    if not user_controller.is_owner then
        pdk.response.exit(401, { err_message = "no permission to delete user" })
    end

    if params.user_id == user_controller.uid then
        pdk.response.exit(401, { err_message = "no permission to delete user" })
    end

    user_controller.check_schema(schema.user.updated, params)

    local res, err = db.role.delete_by_uid(params.user_id)
    if err then
        pdk.response.exit(500, { err_message = err })
    end

    res, err = db.user.create(params.user_id)
    if err then
        pdk.response.exit(500, { err_message = err })
    end
    pdk.response.exit(200, { err_message = "OK" })
end

return user_controller