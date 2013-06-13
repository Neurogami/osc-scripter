def fade_out_and_back duration
  warn "----- fade_out_and_back  #{duration} ----------"
  duration = duration.to_f
    execute_command ":interpolate1||/animata/sprite_left/layer/main_head/alpha||1.0||0.0||#{duration/2}"
    sleep duration/2.0+2.0
    execute_command ":interpolate1||/animata/sprite_left/layer/main_head/alpha||0.0||1.0||#{duration/2}"
    sleep duration/2.0+2.0
end
