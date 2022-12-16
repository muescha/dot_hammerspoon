--- === HotKeySheet ===
---
--- HotKey Bindings cheatsheet for current application
---
--- Download: https://github.com/muescha/dot_hammerspoon/tree/master/Spoons/HotKeySheet.spoon

local obj={}
obj.__index = obj

-- Metadata
obj.name = "HotKeySheet"
obj.version = "1.0"
obj.author = "muescha, ashfinal <ashfinal@gmail.com>"
obj.homepage = "https://github.com/muescha/dot_hammerspoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Workaround for "Dictation" menuitem
hs.application.menuGlyphs[148]="fn fn"

obj.commandEnum = {
    alt = '⌥',
    ctrl = '⌃',
    cmd = '⌘',
    shift = '⇧',
}

obj.commandEnumOrder = {
    'ctrl',
    'alt',
    'cmd',
    'shift',
}

--- HotKeySheet:init()
--- Method
--- Initialize the spoon
function obj:init()
    self.sheetView = hs.webview.new({x=0, y=0, w=0, h=0})
    self.sheetView:windowTitle("CheatSheets")
    self.sheetView:windowStyle("utility")
    self.sheetView:allowGestures(true)
    self.sheetView:allowNewWindows(false)
    self.sheetView:level(hs.drawing.windowLevels.tornOffMenu)
    local cscreen = hs.screen.mainScreen()
    local cres = cscreen:fullFrame()
    self.sheetView:frame({
        x = cres.x+cres.w*0.15/2,
        y = cres.y+cres.h*0.25/2,
        w = cres.w*0.85,
        h = cres.h*0.75
    })
end


function split_on_first_colon(str)
    local colon_pos = str:find(": ")
    if colon_pos then
        return str:sub(1, colon_pos-1), str:sub(colon_pos+2)
    else
        return str, ""
    end
end

local function groupedHotKeys()
    local result = {};

    local activeHotkeys = hs.hotkey.getHotkeys()

    for key, value in ipairs(activeHotkeys) do

        local index, fullDescription = split_on_first_colon(value.msg)
        local scriptName, description = split_on_first_colon(fullDescription)

        if description == "" then
            description = scriptName
            scriptName = "Others"
        end

        if not result[scriptName] then
            result[scriptName] = {};
        end

        local newValue = {
            script = scriptName,
            hotkey = index:gsub('RETURN','↩'),
            description = description
        }
        if description ~= "~~~~~hide~~~~~" then
            table.insert(result[scriptName], newValue);
        end
    end

    return result;
end

local function processHotKeys()
    local groupedKeys = groupedHotKeys()

    local menu = ""
    local col = 1

    local tableOrder = {}
    for scriptName, _ in pairs(groupedKeys) do
        table.insert(tableOrder, scriptName)
    end
    table.sort(tableOrder, function(a,b) return a < b end)


    for pos,scriptName in pairs(tableOrder) do

        local keysPerScript = groupedKeys[scriptName]
        menu = menu .. "<ul class='col col" .. pos .. "'>"
        menu = menu .. "<li class='title'><strong>" .. scriptName .. "</strong></li>"

        for pos, value in ipairs(keysPerScript) do
            menu = menu .. "<li><div class='cmdModifiers'>"
                    .. value.hotkey .. "</div><div class='cmdtext'>" .. " "
                    .. value.description .. "</div></li>"
        end
        --menu = menu .. processMenuItems(val.AXChildren[1])
        menu = menu .. "</ul>"

    end

    return menu

end

local function generateHtml()
    local app_title = "Hammerspoon"
    local hotkeys = processHotKeys()
    local fontSize = '16'

    local html = [[
        <!DOCTYPE html>
        <html>
        <head>
        <style type="text/css">
            *{margin:0; padding:0;}
            html, body{
              background-color:#eee;
              font-family: "Verdana", arial;
              font-size: ]]..fontSize..[[px;
            }
            a{
              text-decoration:none;
              color:#000;
              font-size:]]..fontSize..[[px;
            }
            li.title{ text-align:left;}
            ul, li{list-style: inside none; padding: 0 0 5px;}
            footer{
              position: fixed;
              left: 0;
              right: 0;
              height: 48px;
              background-color:#eee;
            }
            header{
              position: fixed;
              top: 0;
              left: 0;
              right: 0;
              height:48px;
              background-color:#eee;
              z-index:99;
            }
            footer{ bottom: 0; }
            header hr,
            footer hr {
              border: 0;
              height: 0;
              border-top: 1px solid rgba(0, 0, 0, 0.1);
              border-bottom: 1px solid rgba(255, 255, 255, 0.3);
            }
            .title{
                padding: 15px;
            }
            li.title{padding: 0  10px 15px}
            .content{
              padding: 0 0 15px;
              font-size:]]..fontSize..[[px;
              overflow:hidden;
            }
            .content.maincontent{
            position: relative;
              height: 577px;
              margin-top: 46px;
            }
            .content > .col{
              width: 31%;
              padding:20px 0 20px 20px;
            }

            li:after{
              visibility: hidden;
              display: block;
              font-size: 0;
              content: " ";
              clear: both;
              height: 0;
            }
            .cmdModifiers{
              width: 50px;
              padding-right: 15px;
              text-align: left;
              float: left;
              font-family: monospace;
            }
            .cmdtext{
              float: left;
              overflow: hidden;
              font-family: "Verdana";
            }
            footer > .content{
              width: 100% !important;
            }
        </style>
        </head>
          <body>
            <header>
              <div class="title"><strong>]] .. app_title .. [[</strong></div>
              <hr />
            </header>
            <div class="content maincontent">]] .. hotkeys .. [[</div>
            <br>

          <footer>
            <hr />
              <div class="content" >
                <div class="colx">
                  HotKeySheet by <a href="https://github.com/muescha" target="_parent">muescha</a>
                  (based on original by <a href="https://github.com/dharmapoudel" target="_parent">dharma poudel</a>)
                </div>
              </div>
          </footer>
          <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery.isotope/2.2.2/isotope.pkgd.min.js"></script>
            <script type="text/javascript">
              var elem = document.querySelector('.content');
              var iso = new Isotope( elem, {
                // options
                itemSelector: '.col',
                layoutMode: 'masonry'
                //layoutMode: 'fitRows'
              });
            </script>
          </body>
        </html>
        ]]

    return html
end

--- HotKeySheet:show()
--- Method
--- Show current application's keybindings in a view.
function obj:show()
    local webcontent = generateHtml()
    self.sheetView:html(webcontent)
    self.sheetView:show()
end

--- HotKeySheet:hide()
--- Method
--- Hide the cheatsheet view.
function obj:hide()
    self.sheetView:hide()
end

--- HotKeySheet:toggle()
--- Method
--- Alternatively show/hide the cheatsheet view.
function obj:toggle()
  if self.sheetView and self.sheetView:hswindow() and self.sheetView:hswindow():isVisible() then
    self:hide()
  else
    self:show()
  end
end

--- HotKeySheet:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for HotKeySheet
---
--- Parameters:
---  * mapping - A table containing hotkey modifier/key details for the following items:
---   * show - Show the keybinding view
---   * hide - Hide the keybinding view
---   * toggle - Show if hidden, hide if shown
function obj:bindHotkeys(mapping)
  local actions = {
    toggle = hs.fnutils.partial(self.toggle, self),
    show = hs.fnutils.partial(self.show, self),
    hide = hs.fnutils.partial(self.hide, self)
  }
  hs.spoons.bindHotkeysToSpec(actions, mapping)
end

return obj
