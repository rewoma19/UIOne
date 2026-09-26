-- Run in Studio's edit-mode Command Bar after syncing this project with Rojo.
-- Tests construct detached UI and destroy it; the live HUD and audio are untouched.
local settingsModule = game:GetService("ReplicatedStorage").UI.SettingsUI
local realVide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local realRequire = require
local videModule = game:GetService("ReplicatedStorage").Packages.Vide
-- Capture the same Activated callbacks connected to the real Roblox buttons.
local buttonActions = {}
local Vide = setmetatable({}, {__index = realVide})
Vide.create = function(class)
 local constructor = realVide.create(class)
 return function(properties)
  local instance = constructor(properties)
  if properties.Activated then buttonActions[instance] = properties.Activated end
  return instance
 end
end
-- Load current production source with an instrumented Vide dependency.
-- This avoids changing or reusing the game's cached component modules.
local definitions = {}
local cache = {}
local tokens = {settings={}, panel={}, slider={}}
tokens.settings.SettingsPanel = tokens.panel
tokens.settings.VolumeSlider = tokens.slider
tokens.panel.Parent = tokens.settings
tokens.slider.Parent = tokens.settings
definitions[tokens.settings] = settingsModule.Source
definitions[tokens.panel] = settingsModule.SettingsPanel.Source
definitions[tokens.slider] = settingsModule.VolumeSlider.Source
local function loadModule(token)
 if token == videModule then return Vide end
 if cache[token] then return cache[token] end
 local source = definitions[token]
 if not source then return realRequire(token) end
 local chunk, problem = loadstring(source)
 assert(chunk, problem)
 setfenv(chunk, setmetatable({script=token, require=loadModule}, {__index=getfenv()}))
 local exported = chunk()
 cache[token] = exported
 return exported
end
local SettingsUI = loadModule(tokens.settings)
local root, effects, background
local changes = 0
local destroy = realVide.mount(function()
 effects = Vide.source(0.25)
 background = Vide.source(0.75)
 root = SettingsUI({
  effectsVolume = effects,
  backgroundVolume = background,
  onEffectsChanged = function(value) changes += 1; effects(math.clamp(value,0,1)) end,
  onBackgroundChanged = function(value) changes += 1; background(math.clamp(value,0,1)) end
 })
 Vide.cleanup(root)
 return root
end)
local checks = {}
-- Each assertion names an externally observable behavior of the settings UI.
local function check(ok, name)
 assert(ok, name)
 table.insert(checks,name)
end
local didDestroy = false
local ok, problem = xpcall(function()
 local panel = root:FindFirstChild("SettingsMenu")
 local gear = root:FindFirstChild("SettingsButton")
 local effectsRow = root:FindFirstChild("EffectsVolumeSlider",true)
 local backgroundRow = root:FindFirstChild("BackgroundVolumeSlider",true)
 local track = effectsRow.SliderFrame
 local handle = track.Handle
 check(not panel.Visible, "Menu starts closed")
 check(handle.Position.X.Scale == 0.25 and track.InnerFill.Size.X.Scale == 0.25, "Initial slider value renders")
 check(backgroundRow.SliderFrame.Handle.Position.X.Scale == 0.75, "Independent background initial value")
 buttonActions[gear]()
 check(panel.Visible, "Gear opens menu")
 buttonActions[panel.CloseButton]()
 check(not panel.Visible, "Close button hides menu")
 buttonActions[gear]()
 check(panel.Visible and effects()==0.25, "Reopening preserves volume")
 handle.Position = UDim2.fromScale(0.6,0.5)
 task.wait()
 check(math.abs(effects()-0.6)<0.00001, "Handle movement updates source")
 check(math.abs(track.InnerFill.Size.X.Scale-0.6)<0.00001, "Handle movement updates fill")
 check(background()==0.75, "Effects movement leaves background unchanged")
 effects(1)
 task.wait()
 check(handle.Position.X.Scale==1 and track.InnerFill.Size.X.Scale==1,"External source reaches full endpoint")
 effects(0)
 task.wait()
 check(handle.Position.X.Scale==0 and track.InnerFill.Size.X.Scale==0,"External source reaches mute endpoint")
 effects(-1)
 task.wait()
 check(handle.Position.X.Scale==0 and track.InnerFill.Size.X.Scale==0,"Display clamps negative input")
 effects(2)
 task.wait()
 check(handle.Position.X.Scale==1 and track.InnerFill.Size.X.Scale==1,"Display clamps excessive input")
 local detector=handle:FindFirstChildWhichIsA("UIDragDetector")
 check(detector~=nil and detector.DragSpace==Enum.UIDragDetectorDragSpace.Parent,"Native drag detector configured")
 local destroyed=false
 root.Destroying:Once(function() destroyed=true end)
 destroy()
 didDestroy = true
 task.wait()
 check(destroyed,"Unmount destroys root")
 local before=changes
 handle.Position=UDim2.fromScale(0.3,0.5)
 task.wait()
 check(changes==before,"Unmount disconnects position listener")
end, debug.traceback)
-- Always release the temporary scope, including when an assertion fails.
if not didDestroy then destroy() end
assert(ok,problem)
return game:GetService("HttpService"):JSONEncode({runtimeChecks=checks, note="Detached instances only; no live game UI or audio changed. Native pointer dragging and layout not simulated."})
