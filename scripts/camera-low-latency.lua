local obs = obslua
local source_name = "iMac Camera Video"
local source_input = "tcp://192.168.50.2:5000"
local previous_unbuffered = nil

local function camera_source()
    local source = obs.obs_get_source_by_name(source_name)
    if source == nil then return nil end
    local settings = obs.obs_source_get_settings(source)
    local matches = obs.obs_source_get_unversioned_id(source) == "ffmpeg_source"
        and not obs.obs_data_get_bool(settings, "is_local_file")
        and obs.obs_data_get_string(settings, "input") == source_input
    obs.obs_data_release(settings)
    if matches then return source end
    obs.obs_source_release(source)
    return nil
end

local function apply_once()
    local source = camera_source()
    if source == nil then return end
    previous_unbuffered = obs.obs_source_async_unbuffered(source)
    obs.obs_source_set_async_unbuffered(source, true)
    obs.obs_source_release(source)
    obs.timer_remove(apply_once)
    obs.script_log(obs.LOG_INFO, "Camera source: async_unbuffered enabled")
end

function script_load(settings)
    assert(type(obs.obs_source_set_async_unbuffered) == "function", "Missing OBS async-unbuffered setter")
    assert(type(obs.obs_source_async_unbuffered) == "function", "Missing OBS async-unbuffered getter")
    obs.timer_add(apply_once, 250)
end

function script_unload()
    obs.timer_remove(apply_once)
    if previous_unbuffered == nil then return end
    local source = camera_source()
    if source == nil then return end
    obs.obs_source_set_async_unbuffered(source, previous_unbuffered)
    obs.obs_source_release(source)
    previous_unbuffered = nil
end
