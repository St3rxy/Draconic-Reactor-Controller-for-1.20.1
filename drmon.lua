-- drmon.lua

-- modifiable variables
local reactorSide = "back"
local fluxgateSide = "right"

local targetStrength = 50
local maxTemperature = 8000
local safeTemperature = 3000
local lowestFieldPercent = 15

local activateOnCharged = 1

-- please leave things untouched from here on
os.loadAPI("lib/f")

local version = "0.25"
local autoInputGate = 1
local curInputGate = 222000

-- monitor
local mon, monitor, monX, monY

-- peripherals
local reactor
local fluxgate
local inputfluxgate

-- reactor information
local ri

-- last performed action
local action = "None since reboot"
local emergencyCharge = false
local emergencyTemp = false

monitor = f.periphSearch("monitor")
inputfluxgate = f.periphSearch("flow_gate")
fluxgate = peripheral.wrap(fluxgateSide)
reactor = peripheral.wrap(reactorSide)

if monitor == nil then
	error("No valid monitor was found")
end

if fluxgate == nil then
	error("No valid fluxgate was found")
end

if reactor == nil then
	error("No valid reactor was found")
end

if inputfluxgate == nil then
	error("No valid flux gate was found")
end

monX, monY = monitor.getSize()
mon = {}
mon.monitor,mon.X, mon.Y = monitor, monX, monY

--write settings to config file
function save_config()
  sw = fs.open("config.txt", "w")
  sw.writeLine(version)
  sw.writeLine(autoInputGate)
  sw.writeLine(curInputGate)
  sw.close()
end

--read settings from file
function load_config()
  sr = fs.open("config.txt", "r")
  version = sr.readLine()
  autoInputGate = tonumber(sr.readLine())
  curInputGate = tonumber(sr.readLine())
  sr.close()
end

-- 1st time? save our settings, if not, load our settings
if fs.exists("config.txt") == false then
  save_config()
else
  load_config()
end

-- ======================================================
-- BUTTONS
-- ======================================================

-- Button definitions
local outputButtons = {
  {x1=2,  x2=4,  change=-1000,  label=" < "},
  {x1=6,  x2=9,  change=-10000, label=" <<"},
  {x1=10, x2=12, change=-100000,label="<<<"},
  {x1=17, x2=19, change=100000, label=">>>"},
  {x1=21, x2=23, change=10000,  label=">> "},
  {x1=25, x2=27, change=1000,   label=" > "}
}

local inputButtons = {
  {x1=2,  x2=4,  change=-1000,  label=" < "},
  {x1=6,  x2=9,  change=-10000, label=" <<"},
  {x1=10, x2=12, change=-100000,label="<<<"},
  {x1=17, x2=19, change=100000, label=">>>"},
  {x1=21, x2=23, change=10000,  label=">> "},
  {x1=25, x2=27, change=1000,   label=" > "}
}

-- Draw a row of buttons at position y
local function drawButtons(buttons, y)
  for _, b in ipairs(buttons) do
    f.draw_text(mon, b.x1, y, b.label, colors.white, colors.gray)
  end
end

-- Button handler
function buttons()
  while true do
    local event, side, xPos, yPos = os.pullEvent("monitor_touch")

    -- Output gate buttons (row 8)
    if yPos == 8 then
      local cFlow = fluxgate.getSignalLowFlow()
      for _, b in ipairs(outputButtons) do
        if xPos >= b.x1 and xPos <= b.x2 then
          cFlow = cFlow + b.change
        end
      end
      fluxgate.setSignalLowFlow(cFlow)
    end

    -- Input gate buttons (row 10)
    if yPos == 10 and autoInputGate == 0 and (xPos ~= 14 and xPos ~= 15) then
      for _, b in ipairs(inputButtons) do
        if xPos >= b.x1 and xPos <= b.x2 then
          curInputGate = curInputGate + b.change
        end
      end
      inputfluxgate.setSignalLowFlow(curInputGate)
      save_config()
    end

    -- Input gate toggle (AU/MA)
    if yPos == 10 and (xPos == 14 or xPos == 15) then
      autoInputGate = 1 - autoInputGate -- toggle between 1 and 0
      save_config()
    end
  end
end

-- ======================================================
-- MAIN UPDATE LOOP
-- ======================================================

-- create buffered window for monitor output
local win = window.create(monitor, 1, 1, monX, monY, false)
win.setBackgroundColor(colors.black)
win.clear()
term.redirect(win)

function update()
  while true do
    win.setBackgroundColor(colors.black)
    win.clear()
    win.setCursorPos(1,1)

    ri = reactor.getReactorInfo()
    if ri == nil then
      error("reactor has an invalid setup")
    end

    -- Debug output
    for k, v in pairs (ri) do
      print(k.. ": ".. tostring(v))
    end
    print("Output Gate: ", fluxgate.getSignalLowFlow())
    print("Input Gate: ", inputfluxgate.getSignalLowFlow())

    -- === Monitor output ===
    local statusColor = colors.red
    if ri.status == "online" or ri.status == "charged" then
      statusColor = colors.green
    elseif ri.status == "offline" then
      statusColor = colors.gray
    elseif ri.status == "charging" then
      statusColor = colors.orange
    end

    f.draw_text_lr(mon, 2, 2, 1, "Reactor Status", string.upper(ri.status), colors.white, statusColor, colors.black)
    f.draw_text_lr(mon, 2, 4, 1, "Generation", f.format_int(ri.generationRate) .. " rf/t", colors.white, colors.lime, colors.black)

    local tempColor = colors.red
    if ri.temperature <= 5000 then tempColor = colors.green end
    if ri.temperature >= 5000 and ri.temperature <= 6500 then tempColor = colors.orange end
    f.draw_text_lr(mon, 2, 6, 1, "Temperature", f.format_int(ri.temperature) .. "C", colors.white, tempColor, colors.black)

    f.draw_text_lr(mon, 2, 7, 1, "Output Gate", f.format_int(fluxgate.getSignalLowFlow()) .. " rf/t", colors.white, colors.blue, colors.black)

    -- Output buttons
    drawButtons(outputButtons, 8)

    f.draw_text_lr(mon, 2, 9, 1, "Input Gate", f.format_int(inputfluxgate.getSignalLowFlow()) .. " rf/t", colors.white, colors.blue, colors.black)

    if autoInputGate == 1 then
      f.draw_text(mon, 14, 10, "AU", colors.white, colors.gray)
    else
      f.draw_text(mon, 14, 10, "MA", colors.white, colors.gray)
      drawButtons(inputButtons, 10)
    end

    local satPercent = math.ceil(ri.energySaturation / ri.maxEnergySaturation * 10000)*.01
    f.draw_text_lr(mon, 2, 11, 1, "Energy Saturation", satPercent .. "%", colors.white, colors.white, colors.black)
    f.progress_bar(mon, 2, 12, mon.X-2, satPercent, 100, colors.blue, colors.gray)

    local fieldPercent = math.ceil(ri.fieldStrength / ri.maxFieldStrength * 10000)*.01
    local fieldColor = colors.red
    if fieldPercent >= 50 then fieldColor = colors.green end
    if fieldPercent < 50 and fieldPercent > 30 then fieldColor = colors.orange end

    if autoInputGate == 1 then
      f.draw_text_lr(mon, 2, 14, 1, "Field Strength T:" .. targetStrength, fieldPercent .. "%", colors.white, fieldColor, colors.black)
    else
      f.draw_text_lr(mon, 2, 14, 1, "Field Strength", fieldPercent .. "%", colors.white, fieldColor, colors.black)
    end
    f.progress_bar(mon, 2, 15, mon.X-2, fieldPercent, 100, fieldColor, colors.gray)

    local fuelPercent = 100 - math.ceil(ri.fuelConversion / ri.maxFuelConversion * 10000)*.01
    local fuelColor = colors.red
    if fuelPercent >= 70 then fuelColor = colors.green end
    if fuelPercent < 70 and fuelPercent > 30 then fuelColor = colors.orange end

    f.draw_text_lr(mon, 2, 17, 1, "Fuel ", fuelPercent .. "%", colors.white, fuelColor, colors.black)
    f.progress_bar(mon, 2, 18, mon.X-2, fuelPercent, 100, fuelColor, colors.gray)

    f.draw_text_lr(mon, 2, 19, 1, "Action ", action, colors.gray, colors.gray, colors.black)

    -- === Reactor management logic ===
    if emergencyCharge == true then
      reactor.chargeReactor()
    end

    if ri.status == "charging" then
      inputfluxgate.setSignalLowFlow(900000)
      emergencyCharge = false
    end

    if emergencyTemp == true and ri.status == "stopping" and ri.temperature < safeTemperature then
      reactor.activateReactor()
      emergencyTemp = false
    end

    if ri.status == "charged" and activateOnCharged == 1 then
      reactor.activateReactor()
    end

    if ri.status == "running" then
      if autoInputGate == 1 then
        local fluxval = ri.fieldDrainRate / (1 - (targetStrength/100) )
        print("Target Gate: ".. fluxval)
        inputfluxgate.setSignalLowFlow(fluxval)
      else
        inputfluxgate.setSignalLowFlow(curInputGate)
      end
    end

    if fuelPercent <= 10 then
      reactor.stopReactor()
      action = "Fuel below 10%, refuel"
    end

    if fieldPercent <= lowestFieldPercent and ri.status == "online" then
      action = "Field Str < " ..lowestFieldPercent.."%"
      reactor.stopReactor()
      reactor.chargeReactor()
      emergencyCharge = true
    end

    if ri.temperature > maxTemperature then
      reactor.stopReactor()
      action = "Temp > " .. maxTemperature
      emergencyTemp = true
    end

    -- === Flush buffer to monitor ===
    win.redraw()

    sleep(0.2) -- slower refresh = less flicker
  end
end

parallel.waitForAny(buttons, update)
