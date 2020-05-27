# FairyGUI_GenCode_Lua

#### 介绍
FairyGUI.v2020 编辑器插件，用于生成 Lua UI绑定代码。

#### 安装教程

克隆本项目到 FairyGUI 工程的 plugins 目录中，刷新 FairyGUI 编辑器插件窗口或重启编辑器。

#### 使用说明

1.  本项目理论上适用使用 Lua 作为UI逻辑的游戏引擎，但只在 Unity 引擎下进行了测试。
2.  使用本插件前，需要先熟悉编辑器发布代码的功能，并开启发布代码。
3.  使用 编辑器—项目设置—自定义属性 为插件功能赋值。
```
local customPropKeys = {
    key_gen_lua = { name = "key_gen_lua", default_value = "true" },
    key_lua_file_extension_name = { name = "key_lua_file_extension_name", default_value = "lua" },
    key_lua_path_root = { name = "key_lua_path_root", default_value = "UIGenCode/" },
    key_wrapper_namespace = { name = "key_wrapper_namespace", default_value = "" },
}
```
* key_gen_lua 是否生成Lua代码，默认为值 true
* key_lua_file_extension_name Lua文件的扩展名，默认值为 lua
* key_lua_path_root 生成文件相对于Lua执行根路径的相对路径，默认值为 UIGenCode/
* key_wrapper_namespace 框架层 FairyGUI 导出代码的命名空间，默认值为 CS.FairyGUI

4.  生成文件是根据模板文件 __component_template.txt__ 和 __binder_template.txt__ 生成，以 __$XXX__ 作为占位符，可以在此基础上继续自定义扩展。
5. 	使用生成文件示例:
```
	require("UIGenCode.init");
	UI_DemoComponent:CreateInstance();
    GRoot.inst:AddChild(UI_DemoComponent.__ui);
	UI_DemoComponent.m_btn_login.onClick:Add(function()
        print("btn clicked");
    end);
```
* 绑定类是自动调用绑定方法的，只需要引入一次 init.lua 文件即可。
* 为了使用方便，生成的组件类都是全局名称，这一点需要注意。如果不需要生成全局名称，则修改插件源码。
* 组件实例默认赋值为 __ui 对象，为了防止被组件子级覆盖，使用了双下划线命名。
* 不要手动修改生成文件，以免被下一次生成覆盖，更好的办法是修改插件源码和模板文件。
6.  本项目参考了官方的 [GenCode](https://github.com/fairygui/FairyGUI-Editor) 插件，作为补充，提供Lua生成作为一个选项。
