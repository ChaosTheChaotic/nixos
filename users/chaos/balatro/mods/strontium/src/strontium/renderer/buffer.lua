--- ByteData + FFI float buffers for fast bulk uploads.

local buffer = {}

local _has_ffi, _ffi = pcall(require, "ffi")
local HAS_FFI = _has_ffi and _ffi and _ffi.cast ~= nil

function buffer.available()
    return HAS_FFI and love and love.data and love.data.newByteData
end

function buffer.new_float()
    return {
        data = nil,
        ptr = nil,
        capacity = 0,
        stride = 0,
    }
end

function buffer.ensure_float(buf, capacity, stride)
    if not (buf and buffer.available()) then return false end
    if not capacity or capacity <= 0 then return false end
    if not stride or stride <= 0 then return false end

    if buf.data and buf.capacity >= capacity and buf.stride == stride then
        return true
    end

    local byte_len = capacity * stride * 4
    local ok, data = pcall(love.data.newByteData, byte_len)
    if not ok then return false end

    buf.data = data
    buf.ptr = _ffi.cast("float*", data:getPointer())
    buf.capacity = capacity
    buf.stride = stride
    return true
end

return buffer
