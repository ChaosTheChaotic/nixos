-- Wrapper around ProFi 

local profiler = {}

local _profi = nil
local _enabled = false
local _initialized = false
local _session_active = false

function profiler.init(enabled)
    if _initialized then return end
    _initialized = true
    _enabled = enabled or false

    if _enabled then
        -- Try to load ProFi
        local ok, profi = pcall(require, "strontium.lib.ProFi")
        if ok and profi then
            _profi = profi
            _profi:setGetTimeMethod(love.timer.getTime or os.clock)
            print("[Strontium Profiler] ProFi loaded successfully.")
        else
            print("[Strontium Profiler] Failed to load ProFi: " .. tostring(profi))
            _enabled = false
        end
    end
end

function profiler.is_enabled()
    return _enabled and _profi ~= nil
end

function profiler.set_enabled(enabled)
    if not _initialized then
        profiler.init(enabled)
    end
    
    if not enabled and _session_active then
        profiler.stop()
        profiler.writeReport()
    end
    
    _enabled = enabled
    
    if enabled and _profi and not _session_active then
        profiler.start()
    end
end

function profiler.start()
    if not _enabled or not _profi then return end
    if _session_active then return end
    
    _profi:reset()
    _profi:start()
    _session_active = true
    print("[Strontium Profiler] Session started.")
end

function profiler.stop()
    if not _profi then return end
    if not _session_active then return end
    
    _profi:stop()
    _session_active = false
    print("[Strontium Profiler] Session stopped.")
end

function profiler.writeReport(filename)
    if not _profi then return end
    
    filename = filename or "strontium_profile.txt"
    _profi:writeReport(filename)
end

function profiler.is_session_active()
    return _session_active
end

function profiler.toggle()
    if _session_active then
        profiler.stop()
        profiler.writeReport()
    else
        profiler.start()
    end
end

return profiler
