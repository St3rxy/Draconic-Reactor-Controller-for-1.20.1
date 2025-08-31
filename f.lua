-- peripheral identification
function periphSearch(type)
   local names = peripheral.getNames()
   for _, name in pairs(names) do
      if peripheral.getType(name) == type then
         return peripheral.wrap(name)
      end
   end
   return nil
end

-- number formatting
function format_int(number)
  if number == nil then number = 0 end
  local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
  int = int:reverse():gsub("(%d%d%d)", "%1,")
  return minus .. int:reverse():gsub("^,", "") .. fraction
end

-- ===== Monitor Drawing Helpers =====

-- clears an entire line at y
local function clear_line(mon, y, bg_color)
  mon.monitor.setBackgroundColor(bg_color)
  mon.monitor.setCursorPos(1, y)
  mon.monitor.write(string.rep(" ", mon.X))
end

-- display text at position
function draw_text(mon, x, y, text, text_color, bg_color)
  clear_line(mon, y, bg_color)
  mon.monitor.setTextColor(text_color)
  mon.monitor.setCursorPos(x, y)
  mon.monitor.write(tostring(text))
end

-- display right-aligned text with offset
function draw_text_right(mon, offset, y, text, text_color, bg_color)
  clear_line(mon, y, bg_color)
  mon.monitor.setTextColor(text_color)
  mon.monitor.setCursorPos(mon.X - string.len(tostring(text)) - offset, y)
  mon.monitor.write(tostring(text))
end

-- display left & right text on same line
function draw_text_lr(mon, x, y, offset, text1, text2, text1_color, text2_color, bg_color)
  clear_line(mon, y, bg_color)
  -- left side
  mon.monitor.setTextColor(text1_color)
  mon.monitor.setCursorPos(x, y)
  mon.monitor.write(tostring(text1))
  -- right side
  mon.monitor.setTextColor(text2_color)
  mon.monitor.setCursorPos(mon.X - string.len(tostring(text2)) - offset, y)
  mon.monitor.write(tostring(text2))
end

-- draw line (progress bar background, etc.)
function draw_line(mon, x, y, length, color)
  if length < 0 then length = 0 end
  mon.monitor.setBackgroundColor(color)
  mon.monitor.setCursorPos(x, y)
  mon.monitor.write(string.rep(" ", length))
end

-- progress bar (minVal/maxVal percentage)
function progress_bar(mon, x, y, length, minVal, maxVal, bar_color, bg_color)
  draw_line(mon, x, y, length, bg_color) -- background
  local barSize = math.floor((minVal / maxVal) * length)
  draw_line(mon, x, y, barSize, bar_color) -- progress
end

-- clear entire monitor
function clear(mon)
  term.clear()
  term.setCursorPos(1, 1)
  mon.monitor.setBackgroundColor(colors.black)
  mon.monitor.clear()
  mon.monitor.setCursorPos(1, 1)
end
