local MESSAGE = "Your use of this software is unauthorized, for more info, contact Gelodix."

local function show(screen)
    local previous = term.redirect(screen)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    term.clear()
    term.setCursorPos(1, 1)
    print(MESSAGE)
    term.setTextColor(colors.white)
    term.redirect(previous)
end

local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(0.5)
    show(monitor)
end

show(term.current())