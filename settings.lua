if mods["ModuleInserterEx"] then
    data:extend({
        {
            type = "bool-setting",
            name = "oil-outpost-planner-interface-with-module-inserter-ex",
            setting_type = "runtime-per-user",
            default_value = true,
        }
    })
end

data:extend({
    {
        type = "int-setting",
        name = "oil-outpost-planner-num-columns",
        setting_type = "runtime-per-user",
        minimum_value = 1,
        default_value = 10,
    }
})
