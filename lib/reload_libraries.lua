reload_libraries = {}

function reload_libraries.with_arg_list(...)
    for i, v in ipairs(args) do
        package.loaded[v] = nil
    end
end

function reload_libraries.with_table(libs)
    for k, v in pairs(libs) do
        package.loaded[v] = nil
    end
end

return reload_libraries
