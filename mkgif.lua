-- This script uses the lavfi cropdetect filter to automatically
-- insert a crop filter with appropriate parameters for the currently
-- playing video.
--
-- It registers the key-binding "C" (shift+c), which when pressed,
-- inserts the filter vf=lavfi=cropdetect. After 1 second, it then
-- inserts the filter vf=crop=w:h:x:y, where w,h,x,y are determined
-- from the vf-metadata gathered by cropdetect. The cropdetect filter
-- is removed immediately after the crop filter is inserted as it is
-- no longer needed.
--
-- If the "C" key is pressed again, the crop filter is removed
-- restoring playback to its original state.
--
-- Since the crop parameters are determined from the 1 second of video
-- between inserting the cropdetect and crop filters, the "C" key
-- should be pressed at a position in the video where the crop region
-- is unambiguous (i.e., not a black frame, black background title
-- card, or dark scene).
--
-- The default delay between insertion of the cropdetect and
-- crop filters may be overridden by adding
--
-- --script-opts=autocrop.detect_seconds=<number of seconds>
--
-- to mpv's arguments. This may be desirable to allow cropdetect more
-- time to collect data.
local msg = require 'mp.msg'

start_time = -1
end_time = -1
crop_str = ""

function make_gif_with_subtitles()
  make_gif_internal(true)
end

function make_gif()
  make_gif_internal(false)
end

function make_gif_internal(burn_subtitles)
  local end_time_l = end_time
  local duration = end_time - start_time

  if start_time == -1 or end_time == -1 or duration <= 0 then
    mp.osd_message("Invalid start/end time.")
    return
  end

  mp.osd_message("Creating APNG.")

  -- shell escape
  function esc(s)
    return string.gsub(s, '"', '"\\""')
  end

  local pathname = mp.get_property("path", "")

  stream_path = mp.get_property("path", "")
  local working_path = get_containing_path(stream_path)
  local filename = mp.get_property("filename/no-ext")
  local file_path = working_path .. filename

    -- find a filename that works
  for i=0,9999 do
    local fn = string.format('%s_%03d.png', file_path, i)
    if not file_exists(fn) then
      imgname = fn
      break
    end
  end
  if not imgname then
    mp.osd_message('No available filenames!')
    return
  end

  args = string.format(
    'mkgif.sh %s %s %s %s %s%s-M',
    esc(pathname), esc(imgname),
    start_time, duration,
    crop_str,
    (burn_subtitles and '-s ' or '')
  )
  os.execute(args)

  msg.info("APNG created.")
  mp.osd_message("APNG created.")
end

function set_start()
  start_time = mp.get_property_number("time-pos", -1)
  mp.osd_message("APNG Start: " .. start_time)
end

function set_end()
  end_time = mp.get_property_number("time-pos", -1)
  mp.osd_message("APNG End: " .. end_time)
end

function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then
    io.close(f)
    return true
  else
    return false
  end
end

function get_containing_path(str,sep)
  sep=sep or package.config:sub(1,1)
  return str:match("(.*"..sep..")")
end

mp.add_key_binding("g", "set_gif_start", set_gif_start)
mp.add_key_binding("G", "set_gif_end", set_gif_end)
mp.add_key_binding("Ctrl+g", "make_gif_with_subtitles", make_gif_with_subtitles)
mp.add_key_binding("Ctrl+G", "make_gif", make_gif)
