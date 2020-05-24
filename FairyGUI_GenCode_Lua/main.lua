local projectCustomPropertiesDic;

local customPropKeys = {
    key_gen_lua = {name = "key_gen_lua",default_value = "true"},
    key_lua_file_extension_name = {name = "key_lua_file_extension_name",default_value = "lua"},
    key_lua_class_prefix = {name = "key_lua_class_prefix",default_value = ""},
}

local function get_project_custom_property_value(key_name)
    if(projectCustomPropertiesDic and projectCustomPropertiesDic:ContainsKey(key_name)) then
        return projectCustomPropertiesDic:get_Item(key_name);
    else
        return customPropKeys[key_name].default_value;
    end
end

function onPublish(handler)
    if not handler.genCode then return end

    projectCustomPropertiesDic = App.project:GetSettings("CustomProperties").elements;

    local gen_lua = get_project_custom_property_value(customPropKeys.key_gen_lua.name);
    if(gen_lua == "true") then
        handler.genCode = false --prevent default output
        App.consoleView:Clear();
        fprint("Handling gen lua code in plugin.")
        genCode2lua(handler)
    end
end

-- this is copied from Editor-Install-Path/Resources/Data/StreamingAssets/Scripts
function genCode(handler)
    local settings = handler.project:GetSettings("Publish").codeGeneration
    local codePkgName = handler:ToFilename(handler.pkg.name); --convert chinese to pinyin, remove special chars etc.
    local exportCodePath = handler.exportCodePath..'/'..codePkgName
    local namespaceName = codePkgName
    local ns = 'fgui'

    if settings.packageName~=nil and settings.packageName~='' then
        namespaceName = settings.packageName..'.'..namespaceName;
    end

    --CollectClasses(stripeMemeber, stripeClass, fguiNamespace)
    local classes = handler:CollectClasses(settings.ignoreNoname, settings.ignoreNoname, ns)
    handler:SetupCodeFolder(exportCodePath, "ts") --check if target folder exists, and delete old files

    local getMemberByName = settings.getMemberByName

    local classCnt = classes.Count
    local writer = CodeWriter.new({ blockFromNewLine=false, usingTabs = true  })
    for i=0,classCnt-1 do
        local classInfo = classes[i]
        local members = classInfo.members
        local references = classInfo.references
        writer:reset()

        local refCount = references.Count
        if refCount>0 then
            for j=0,refCount-1 do
                local ref = references[j]
                writer:writeln('import %s from "./%s";', ref, ref)
            end
            writer:writeln()
        end

        writer:writeln('export default class %s extends %s', classInfo.className, classInfo.superClassName)
        writer:startBlock()

        local memberCnt = members.Count
        for j=0,memberCnt-1 do
            local memberInfo = members[j]
            writer:writeln('public %s:%s;', memberInfo.varName, memberInfo.type)
        end
        writer:writeln('public static URL:string = "ui://%s%s";', handler.pkg.id, classInfo.classId)
        writer:writeln()

        writer:writeln('public static createInstance():%s', classInfo.className)
        writer:startBlock()
        writer:writeln('return <%s><any>%s.UIPackage.createObject("%s", "%s");', classInfo.className, ns, handler.pkg.name, classInfo.resName)
        writer:endBlock()
        writer:writeln()

        writer:writeln('protected onConstruct():void')
        writer:startBlock()
        for j=0,memberCnt-1 do
            local memberInfo = members[j]
            if memberInfo.group==0 then
                if getMemberByName then
                    writer:writeln('this.%s = <%s><any>this.getChild("%s");', memberInfo.varName, memberInfo.type, memberInfo.name)
                else
                    writer:writeln('this.%s = <%s><any>this.getChildAt(%s);', memberInfo.varName, memberInfo.type, memberInfo.index)
                end
            elseif memberInfo.group==1 then
                if getMemberByName then
                    writer:writeln('this.%s = this.getController("%s");', memberInfo.varName, memberInfo.name)
                else
                    writer:writeln('this.%s = this.getControllerAt(%s);', memberInfo.varName, memberInfo.index)
                end
            else
                if getMemberByName then
                    writer:writeln('this.%s = this.getTransition("%s");', memberInfo.varName, memberInfo.name)
                else
                    writer:writeln('this.%s = this.getTransitionAt(%s);', memberInfo.varName, memberInfo.index)
                end
            end
        end
        writer:endBlock()

        writer:endBlock() --class

        writer:save(exportCodePath..'/'..classInfo.className..'.ts')
    end

    writer:reset()

    local binderName = codePkgName..'Binder'

    for i=0,classCnt-1 do
        local classInfo = classes[i]
        writer:writeln('import %s from "./%s";', classInfo.className, classInfo.className)
    end

    writer:writeln()
    writer:writeln('export default class %s', binderName)
    writer:startBlock()

    writer:writeln('public static bindAll():void')
    writer:startBlock()
    for i=0,classCnt-1 do
        local classInfo = classes[i]
        writer:writeln('%s.UIObjectFactory.setExtension(%s.URL, %s);', ns, classInfo.className, classInfo.className)
    end
    writer:endBlock() --bindall

    writer:endBlock() --class

    writer:save(exportCodePath..'/'..binderName..'.ts')
end

function genCode2lua(handler)
    local settings = handler.project:GetSettings("Publish").codeGeneration
    local codePkgName = handler:ToFilename(handler.pkg.name); --convert chinese to pinyin, remove special chars etc.
    local exportCodePath = handler.exportCodePath..'/'..codePkgName
    local lua_class_prefix = get_project_custom_property_value(customPropKeys.key_lua_class_prefix.name);
    local lua_file_extension_name = get_project_custom_property_value(customPropKeys.key_lua_file_extension_name.name);

    local namespaceName = codePkgName
    local ns = 'fgui'

    if settings.packageName~=nil and settings.packageName~='' then
        namespaceName = settings.packageName..'.'..namespaceName;
    end

    --CollectClasses(stripeMemeber, stripeClass, fguiNamespace)
    local classes = handler:CollectClasses(settings.ignoreNoname, settings.ignoreNoname, ns)
    handler:SetupCodeFolder(exportCodePath, lua_file_extension_name) --check if target folder exists, and delete old files

    local getMemberByName = settings.getMemberByName

    local classCnt = classes.Count
    local writer = CodeWriter.new({ blockFromNewLine=false, usingTabs = true  })
    for i=0,classCnt-1 do
        local classInfo = classes[i]
        local members = classInfo.members
        local references = classInfo.references
        writer:reset()

        local refCount = references.Count
        if refCount>0 then
            for j=0,refCount-1 do
                local ref = references[j]
                writer:writeln('import %s from "./%s";', ref, ref)
            end
            writer:writeln()
        end

        writer:writeln('export default class %s extends %s', classInfo.className, classInfo.superClassName)
        writer:startBlock()

        local memberCnt = members.Count
        for j=0,memberCnt-1 do
            local memberInfo = members[j]
            writer:writeln('public %s:%s;', memberInfo.varName, memberInfo.type)
        end
        writer:writeln('public static URL:string = "ui://%s%s";', handler.pkg.id, classInfo.classId)
        writer:writeln()

        writer:writeln('public static createInstance():%s', classInfo.className)
        writer:startBlock()
        writer:writeln('return <%s><any>%s.UIPackage.createObject("%s", "%s");', classInfo.className, ns, handler.pkg.name, classInfo.resName)
        writer:endBlock()
        writer:writeln()

        writer:writeln('protected onConstruct():void')
        writer:startBlock()
        for j=0,memberCnt-1 do
            local memberInfo = members[j]
            if memberInfo.group==0 then
                if getMemberByName then
                    writer:writeln('this.%s = <%s><any>this.getChild("%s");', memberInfo.varName, memberInfo.type, memberInfo.name)
                else
                    writer:writeln('this.%s = <%s><any>this.getChildAt(%s);', memberInfo.varName, memberInfo.type, memberInfo.index)
                end
            elseif memberInfo.group==1 then
                if getMemberByName then
                    writer:writeln('this.%s = this.getController("%s");', memberInfo.varName, memberInfo.name)
                else
                    writer:writeln('this.%s = this.getControllerAt(%s);', memberInfo.varName, memberInfo.index)
                end
            else
                if getMemberByName then
                    writer:writeln('this.%s = this.getTransition("%s");', memberInfo.varName, memberInfo.name)
                else
                    writer:writeln('this.%s = this.getTransitionAt(%s);', memberInfo.varName, memberInfo.index)
                end
            end
        end
        writer:endBlock()

        writer:endBlock() --class

        writer:save(exportCodePath..'/'..classInfo.className..'.'..lua_file_extension_name)
    end

    writer:reset()

    local binderName = codePkgName..'Binder'

    for i=0,classCnt-1 do
        local classInfo = classes[i]
        writer:writeln('import %s from "./%s";', classInfo.className, classInfo.className)
    end

    writer:writeln()
    writer:writeln('export default class %s', binderName)
    writer:startBlock()

    writer:writeln('public static bindAll():void')
    writer:startBlock()
    for i=0,classCnt-1 do
        local classInfo = classes[i]
        writer:writeln('%s.UIObjectFactory.setExtension(%s.URL, %s);', ns, classInfo.className, classInfo.className)
    end
    writer:endBlock() --bindall

    writer:endBlock() --class

    writer:save(exportCodePath..'/'..binderName..'.'..lua_file_extension_name)

end
