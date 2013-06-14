def radiate duration, threaded=false
  warn "----- radiate  #{duration} ----------"
  duration = duration.to_f

   execute_command ":interpolate1||/animata/osc-for-artists/layer/waves/alpha||1.0||0.0||#{duration/2}"
    sleep duration
    execute_command ":interpolate1||/animata/osc-for-artists/layer/waves/alpha||0.0||1.0||#{duration/2}"
    sleep duration
end
