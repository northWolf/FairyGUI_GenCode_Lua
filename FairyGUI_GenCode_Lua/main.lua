--region LuaCodeWriter
local LuaCodeWriter = fclass()

function LuaCodeWriter:ctor(config)
    config = config or {}
    self.blockStart = config.blockStart or '{'
    self.blockEnd = config.blockEnd or '}'
    self.blockFromNewLine = config.blockFromNewLine
    if self.blockFromNewLine == nil then
        self.blockFromNewLine = true
    end
    if config.usingTabs then
        self.indentStr = '\t'
    else
        self.indentStr = '    '
    end
    self.usingTabs = config.usingTabs
    self.endOfLine = config.endOfLine or '\n'
    self.lines = {}
    self.indent = 0

    self:writeMark()
end

function LuaCodeWriter:writeMark()
    table.insert(self.lines, '--- This is an automatically generated class by FairyGUI. Please do not modify it. ---')
    table.insert(self.lines, '')
end

function LuaCodeWriter:writeln(format, ...)
    if not format then
        table.insert(self.lines, '')
        return
    end

    local str = ''
    for i = 0, self.indent - 1 do
        str = str .. self.indentStr
    end
    str = str .. string.format(format, ...)
    table.insert(self.lines, str)

    return self
end

function LuaCodeWriter:startBlock()
    if self.blockFromNewLine or #self.lines == 0 then
        self:writeln(self.blockStart)
    else
        local str = self.lines[#self.lines]
        self.lines[#self.lines] = str .. ' ' .. self.blockStart
    end
    self.indent = self.indent + 1

    return self
end

function LuaCodeWriter:endBlock()
    self.indent = self.indent - 1
    self:writeln(self.blockEnd)

    return self
end

function LuaCodeWriter:incIndent()
    self.indent = self.indent + 1

    return self
end

function LuaCodeWriter:decIndent()
    self.indent = self.indent - 1

    return self
end

function LuaCodeWriter:reset()
    if #self.lines > 0 then
        self.lines = {}
    end
    self.indent = 0

    self:writeMark()
end

function LuaCodeWriter:tostring()
    return table.concat(self.lines, self.endOfLine)
end

function LuaCodeWriter:save(filePath)
    local str = table.concat(self.lines, self.endOfLine)

    CS.System.IO.File.WriteAllText(filePath, str)
end

--endregion

local projectCustomPropertiesDic;

local customPropKeys = {
    key_gen_lua = { name = "key_gen_lua", default_value = "true" },
    key_lua_file_extension_name = { name = "key_lua_file_extension_name", default_value = "lua" },
    key_lua_path_root = { name = "key_lua_path_root", default_value = "UIGenCode/" },
    key_wrapper_namespace = { name = "key_wrapper_namespace", default_value = "CS.FairyGUI" },
}

local function get_project_custom_property_value(key_name)
    if (projectCustomPropertiesDic and projectCustomPropertiesDic:ContainsKey(key_name)) then
        return projectCustomPropertiesDic:get_Item(key_name);
    else
        return customPropKeys[key_name].default_value;
    end
end

function onPublish(handler)
    if not handler.genCode then
        return
    end

    projectCustomPropertiesDic = App.project:GetSettings("CustomProperties").elements;

    local gen_lua = get_project_custom_property_value(customPropKeys.key_gen_lua.name);
    if (gen_lua == "true") then
        handler.genCode = false --prevent default output
        App.consoleView:Clear();
        fprint("Handling gen lua code in plugin.")
        genCode(handler)
    end
end

function genCode(handler)
    local settings = handler.project:GetSettings("Publish").codeGeneration
    local codePkgName = handler:ToFilename(handler.pkg.name); --convert chinese to pinyin, remove special chars etc.
    fprint("codePkgName = " .. codePkgName);
    local exportCodePath = handler.exportCodePath .. '/' .. codePkgName
    fprint("exportCodePath = " .. exportCodePath);
    local lua_file_extension_name = get_project_custom_property_value(customPropKeys.key_lua_file_extension_name.name);

    local namespaceName = codePkgName
    local key_wrapper_namespace = get_project_custom_property_value(customPropKeys.key_wrapper_namespace.name);

    if settings.packageName ~= nil and settings.packageName ~= '' then
        namespaceName = settings.packageName .. '.' .. namespaceName;
    end

    --CollectClasses(stripeMemeber, stripeClass, fguiNamespace)
    local classes = handler:CollectClasses(settings.ignoreNoname, settings.ignoreNoname, key_wrapper_namespace)
    handler:SetupCodeFolder(exportCodePath, lua_file_extension_name) --check if target folder exists, and delete old files

    local getMemberByName = settings.getMemberByName
    local classTemplateTxt = CS.System.IO.File.ReadAllText(PluginPath .. "/class_template.txt");

    local classCnt = classes.Count
    local writer = LuaCodeWriter.new({ blockFromNewLine = false, usingTabs = true })
    for i = 0, classCnt - 1 do
        local _classTemplateTxt = classTemplateTxt;
        local classInfo = classes[i]
        local members = classInfo.members
        local references = classInfo.references
        writer:reset()

        local refCount = references.Count
        if refCount > 0 then
            for j = 0, refCount - 1 do
                local ref = references[j]
                writer:writeln('local %s = require("%s/%s");', ref, exportCodePath, ref)
            end
            writer:writeln()
        end

        _classTemplateTxt = string.gsub(_classTemplateTxt, "$className", classInfo.className);
        _classTemplateTxt = string.gsub(_classTemplateTxt, "$superClassName", classInfo.superClassName);
        if (key_wrapper_namespace ~= "") then
            _classTemplateTxt = string.gsub(_classTemplateTxt, "$namespace", key_wrapper_namespace .. ".");
        else
            _classTemplateTxt = string.gsub(_classTemplateTxt, "$namespace", "");
        end
        local _classMemberAnnotation = "";
        local memberCnt = members.Count
        for j = 0, memberCnt - 1 do
            if (j > 0) then
                _classMemberAnnotation = _classMemberAnnotation .. "\n";
            end
            local memberInfo = members[j]
            _classMemberAnnotation = _classMemberAnnotation .. string.format('---@field public %s %s', memberInfo.varName, memberInfo.type);
        end
        _classTemplateTxt = string.gsub(_classTemplateTxt, "$classMemberAnnotation", _classMemberAnnotation);

        local _urlValue = string.format('"ui://%s%s"', handler.pkg.id, classInfo.classId)
        _classTemplateTxt = string.gsub(_classTemplateTxt, "$urlValue", _urlValue);

        _classTemplateTxt = string.gsub(_classTemplateTxt, "$uiPackageName", handler.pkg.name);
        _classTemplateTxt = string.gsub(_classTemplateTxt, "$uiResName", classInfo.resName);

        local _classMemberInstatiation = "";
        for j = 0, memberCnt - 1 do
            local memberInfo = members[j]
            if j > 0 then
                _classMemberInstatiation = _classMemberInstatiation .. "\n";
            end
            _classMemberInstatiation = _classMemberInstatiation .. "\t";
            if memberInfo.group == 0 then
                if getMemberByName then
                    _classMemberInstatiation = _classMemberInstatiation .. string.format('self.%s = self:GetChild("%s");', memberInfo.varName, memberInfo.name);
                else
                    _classMemberInstatiation = _classMemberInstatiation .. string.format('self.%s = self:GetChildAt("%s");', memberInfo.varName, memberInfo.index);
                end
            elseif memberInfo.group == 1 then
                if getMemberByName then
                    _classMemberInstatiation = _classMemberInstatiation .. string.format('self.%s = self:GetController("%s");', memberInfo.varName, memberInfo.name);
                else
                    _classMemberInstatiation = _classMemberInstatiation .. string.format('self.%s = self:GetControllerAt("%s");', memberInfo.varName, memberInfo.index);
                end
            else
                if getMemberByName then
                    _classMemberInstatiation = _classMemberInstatiation .. string.format('self.%s = self:GetTransition("%s");', memberInfo.varName, memberInfo.name);
                else
                    _classMemberInstatiation = _classMemberInstatiation .. string.format('self.%s = self:GetTransitionAt("%s");', memberInfo.varName, memberInfo.index);
                end
            end
        end
        _classTemplateTxt = string.gsub(_classTemplateTxt, "$classMemberInstantiation", _classMemberInstatiation);
        writer:writeln('%s', _classTemplateTxt);

        writer:save(exportCodePath .. '/' .. classInfo.className .. '.' .. lua_file_extension_name)
    end

    writer:reset()

    local binderTemplateTxt = CS.System.IO.File.ReadAllText(PluginPath .. "/binder_template.txt");

    local binderName = codePkgName .. 'Binder'

    local _requireStatement = "";
    local lua_path_root = get_project_custom_property_value(customPropKeys.key_lua_path_root.name);
    lua_path_root = string.gsub(lua_path_root, "/", ".");
    lua_path_root = string.gsub(lua_path_root, "\\", ".");
    for i = 0, classCnt - 1 do
        if (i > 0) then
            _requireStatement = _requireStatement .. "\n";
        end
        local classInfo = classes[i]
        _requireStatement = _requireStatement .. string.format('local %s = require("%s%s.%s");', classInfo.className, lua_path_root,codePkgName, classInfo.className);
    end

    binderTemplateTxt = string.gsub(binderTemplateTxt, "$requireStatement", _requireStatement);
    binderTemplateTxt = string.gsub(binderTemplateTxt, "$binderClassName", binderName);

    local _bindStatement = "";
    for i = 0, classCnt - 1 do
        if (i > 0) then
            _bindStatement = _bindStatement .. "\n";
        end
        local classInfo = classes[i]
        _bindStatement = _bindStatement .. "\t";

        if (key_wrapper_namespace ~= "") then
            _bindStatement = _bindStatement .. string.format('%sUIObjectFactory.SetExtension(%s.URL, %s);', key_wrapper_namespace .. ".", classInfo.className, classInfo.className);
        else
            _bindStatement = _bindStatement .. string.format('UIObjectFactory.SetExtension(%s.URL, %s);', classInfo.className, classInfo.className);
        end


    end
    binderTemplateTxt = string.gsub(binderTemplateTxt, "$bindStatement", _bindStatement);
    writer:writeln('%s', binderTemplateTxt);

    writer:save(exportCodePath .. '/' .. binderName .. '.' .. lua_file_extension_name)

end


