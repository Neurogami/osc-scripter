require "test/unit"
$:.unshift File.dirname(__FILE__) + "/.."

require 'osc-scripter'

$starting_port = 0

class TestUtils < Test::Unit::TestCase

  include Neurogami::OscScripter
  include OSC
  include Utils

  def setup
    @script_path = "sample_script.txt"
    @address = '127.0.0.1'
    @port = 8003
    @internal_port = $starting_port 
    @script = sample_script @address, @port, @internal_port 
    File.open(@script_path, 'w')  { |f|  f.print @script }
    @scripter = ScriptRunner.new   @script_path 
  end

  def teardown
    @script = nil
    # @scripter.stop_server
    sleep 2
    @scripter = nil

    File.unlink @script_path
  end



  # First line must always be the destination IP and port
  # Do we want a way to indicate multiple servers? This way a single script could drive
  # multiple applications.  Maye have first line hold all servers, seperate by ';'
  # What is the syntax of the script?
  # OSC messags can just be text, and we can use the code from osc-repl to convert args to types
  # What about delays between messages? Or bundled messages?
  # For now, a line that begins with a digits is a sleep duration in seconds
  #
  def sample_script address, port, internal_port 
    %~#{address}:#{port}
#{internal_port}
0.5
/animata/sprite/orientation/left
5
/animata/sprite/orientation/right
2.5
/animata/sprite/orientation/left
/animata/sprite_left/joint/chin_joint/move 100 300
3
/animata/sprite_left/joint/chin_joint/move 100 100
    4
/animata/sprite_left/layer/main_head/move   500.0 30.0
  3
/animata/sprite_left/bone/l_mouth/length 20.8
5
/animata/sprite_left/bone/l_mouth/length 200.3
# This is a comment.  This next line means to call the `interpolate2` method passing all these args
:interpolate2||/animata/sprite  _left/layer/main_head/move||500.0||30.0||100.0||120.0||5
~.split("\n").map{|l| l.strip}.join("\n")


  end


  def test_creating_instance
    assert_equal ScriptRunner, @scripter.class
    assert_equal @port, @scripter.port
    assert_equal @address, @scripter.address
    assert_equal IO.readlines(@script_path).size - 2,   @scripter.instance_variable_get("@commands").size
  end

  def test_loading_handlers
    handler_file = File.basename __FILE__
    handler_path = File.dirname __FILE__    
    results = File.join handler_path, handler_file
    assert_equal results, @scripter.load_handlers( results)
  end

  def test_osc_instantiation
    assert_equal Client,  @scripter.instance_variable_get("@client").class
  end

  def test_complex_command
    data = @scripter.chunk_complex_command_string  ':interpolate2||/animata/sprite_left/layer/main_head/move||500.0||30.0||100.0||120.0||5'
    assert_equal 'interpolate2',  data[:command]
    assert_equal 6,  data[:args].size
    assert_equal false,  data[:looped]
    start_val = 100
    end_val = 110 
    duration = 2.0
    steps_num = @scripter.number_of_steps duration

    assert_equal 20,  steps_num
    val_steps = @scripter.calculate_value_steps  start_val, end_val, duration

    data = @scripter.chunk_complex_command_string  ':@interpolate2||/animata/sprite_left/layer/main_head/move||500.0||30.0||100.0||120.0||5'
    assert_equal 'interpolate2',  data[:command]
    assert_equal 6,  data[:args].size
    assert_equal true,  data[:looped]
    assert_equal nil,  data[:label]
    start_val = 0.0
    end_val = 1.0
    duration = 5.0
    steps_num = @scripter.number_of_steps duration

    assert_equal 50,  steps_num
    val_steps = @scripter.calculate_value_steps  start_val, end_val, duration


    data = @scripter.chunk_complex_command_string  ':@interpolate2[alpha-loop]||/animata/sprite_left/layer/main_head/move||500.0||30.0||100.0||120.0||5'
    assert_equal 'interpolate2',  data[:command]
    assert_equal 6,  data[:args].size
    assert_equal true,  data[:looped]
    assert_equal 'alpha-loop',  data[:label]

    data = @scripter.chunk_complex_command_string  ':stoploop[alpha-loop]'
    assert_equal 'stoploop',  data[:command]
    assert_equal 0,  data[:args].size
    assert_equal false,  data[:looped]

  end

  def test_simple
    s = '24 "002" "Some text"'
    assert_equal ["24", "\"002\"", "\"Some text\""], string_to_args(s)
  end

  def test_number_strings
    s = '003 "002" "Some text"'
    assert_equal [ '003', "\"002\"", "\"Some text\""], string_to_args(s)
    #    assert_equal [3, "002", "Some text"], string_to_args(s).map { |a| arg_to_type a }
  end

  def test_number_strings_to_args
    s = '003 "002" "Some text" 200.3'
    #    assert_equal [ '003', "\"002\"", "\"Some text\""], string_to_args(s)
    assert_equal [3, "002", "Some text", 200.3], string_to_args(s).map { |a| arg_to_type a }
  end

end



