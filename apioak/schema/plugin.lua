local _M = {}

_M.created = {
    type = "object",
    properties = {
        name = {
            type = "string",
            minLength = 1,
            maxLength = 50
        },
        protocols = {
            type = "array",
            minItems = 1,
            uniqueItems = true,
            items = {
                type = "string",
                enum = { "http", "https" }
            },
        },
        host = {
            type = "array",
            minItems = 1,
            uniqueItems = true,
            items = {
                type = "string",
                pattern = "^\\*?[0-9a-zA-Z-.]+$"
            },
        },
        port = {
            type = "array",
            minItems = 1,
            uniqueItems = true,
            items = {
                type = "number",
                pattern = "^\\*?[0-9]+$"
            },
            default = {80}
        },
        plugins = {
            type = "array",
            uniqueItems = true,
            items = {
                type = "object",
                properties = {
                    id = {
                        type = "string",
                        pattern = "^\\*?[0-9a-zA-Z-.]+$"
                    },
                    name = {
                        type = "string",
                        pattern = "^\\*?[0-9a-zA-Z-.]+$"
                    }
                }
            },
        },
        enabled = {
            type = "boolean",
            default = false
        },
        prefix = {
            type = "string",
            minLength = 0,
            maxLength = 50
        }
    },
    required = { "name", "protocols", "hosts" }
}

_M.updated = {
    type = "object",
    properties = {
        id = {
            type = "string",
            minLength = 1,
            maxLength = 50
        },
        name = {
            type = "string",
            minLength = 1,
            maxLength = 50
        },
        protocols = {
            type = "array",
            minItems = 1,
            uniqueItems = true,
            items = {
                type = "string",
                enum = { "http", "https" }
            },
        },
        host = {
            type = "array",
            minItems = 1,
            uniqueItems = true,
            items = {
                type = "string",
                pattern = "^\\*?[0-9a-zA-Z-.]+$"
            },
        },
        port = {
            type = "array",
            minItems = 1,
            uniqueItems = true,
            items = {
                type = "number",
                pattern = "^\\*?[0-9]+$"
            },
            default = {80}
        },
        plugins = {
            type = "array",
            uniqueItems = true,
            items = {
                type = "object",
                properties = {
                    id = {
                        type = "string",
                        pattern = "^\\*?[0-9a-zA-Z-.]+$"
                    },
                    name = {
                        type = "string",
                        pattern = "^\\*?[0-9a-zA-Z-.]+$"
                    }
                }
            },
        },
        enabled = {
            type = "boolean",
            default = false
        },
        prefix = {
            type = "string",
            minLength = 0,
            maxLength = 50
        }
    },
    required = { "id", "name", "protocols", "hosts" }
}

_M.lists = {
    type = "object",
    properties = {
        prefix = {
            type = "string",
            minLength = 0,
            maxLength = 50
        }
    }
}

_M.detail = {
    type = "object",
    properties = {
        service_id = {
            type = "string",
            minLength = 1,
            maxLength = 50
        },
        prefix = {
            type = "string",
            minLength = 0,
            maxLength = 50
        }
    },
    required = { "service_id"}
}

_M.deleted = {
    type = "object",
    properties = {
        service_id = {
            type = "string",
            minLength = 1,
            maxLength = 50
        },
        prefix = {
            type = "string",
            minLength = 0,
            maxLength = 50
        }
    },
    required = { "service_id"}
}

return _M
