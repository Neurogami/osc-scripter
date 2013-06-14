require 'osc-ruby'
require 'utils'

Thread.abort_on_exception = true

module Neurogami
  module OscScripter

    class OscServer

      include  OSC

      def initialize port, runner 
        @runner = runner 
        if port.to_i > 0
       
        @server = Server.new port

       Thread.new do 
          serve
       end
        else
           warn "OscServer has been given port 0, so no server will be available"
        end

      end

      def serve
        @server.add_method /.*/ do |msg|
          # The assumption is that content of the OSC message is simply a string such as what
          # you would have in a script file.  This method just takes that string and
          # has the runner execute it
            puts "* #{msg.address} -  #{ msg.to_a.join(', ') }"
            @runner.execute_command msg.to_a.join(' ')
        end

        @thread = Thread.new do
          @server.run
        end
      end

      def kill 
       
        @server = nil
        @thread.kill if @thread
      end

    end


    class ScriptRunner

      include  OSC
      include Utils
      
      TIME_FRACTION = 0.1

      def initialize script_path, custom_hander_file_path=nil
        @raw_script_lines = IO.readlines script_path
        parse_script @raw_script_lines 
        @client = Client.new @address, @port
        @threaded_loops = {}
        @server = OscServer.new @internal_port, self
        load_file custom_hander_file_path
      end

      def stop_server
        @server.kill
      end

      def load_file file_path
        return nil unless file_path
        warn "We are currently in #{Dir.pwd}"
        file_path = File.expand_path file_path
        if File.exist? file_path
          load file_path
          return file_path
        else
          warn "load_file cannot find '#{file_path}'"
          return nil
        end
      end

      def port
        @port 
      end

      def address
        @address
      end

      def execute_command c
        if c =~ /^\d/
          tnow = Time.now
          pause = c.to_f
          warn  "Pause for #{pause} seconds ..."
          while Time.now  < tnow + pause
            print '.'
            sleep TIME_FRACTION 
          end
        else
          if  c =~ /^:/ # This is a complex command request
            
            warn "==================== COMPLEX COMMAND ===================="
            data = chunk_complex_command_string c

            if data[:command] == 'stoploop' # special command
              stoploop data[:label]
            else

              if data[:looped]  # Use a forever loop
                warn "\n LOOP LOOP LOOP LOOP LOOP LOOP LOOP LOOP LOOP LOOP LOOP LOOP"
                data[:args] << data[:looped]
                t = Thread.new do
                  while true
                    send data[:command], *data[:args] 
                  end
                end

                if data[:label]
                  @threaded_loops[data[:label]] = t 
                end
             
              else
                send data[:command], *data[:args] 
              end
            end

          else
            warn "\nSend message: #{c}"
            send_osc c
          end
        end
      end


      def parse_script raw_script_lines 
        @address, @port= raw_script_lines.shift.split ':'
        @port = @port.to_i
        raise "OSC server port cannot be '#{@port}'" unless @port > 0 # Not ideal, but it's a start
        @internal_port = raw_script_lines.shift
        @internal_port = @internal_port.to_i
        #####raise "Internal OSC server port cannot be '#{@internal_port}'" unless @internal_port > 0
        @commands = raw_script_lines.clone
      end

      def stoploop label
        warn "STOP LOOP '#{label}' '"
        t = @threaded_loops[label]
        if t
          t.kill
        else
          warn "stoploop cannot find a loop with label '#{label}'"
        end
      end

      def chunk_complex_command_string s
        h = {}
        h[:looped] = (s =~ /^:@/ ? true : false )

        s.sub!  /^:@/, ''
        s.sub!  /^:/, ''
        parts = s.split '||'
        parts.map!{ |_| _.strip }
        h[:command] = parts.shift

        if  h[:command] =~ /(.+)\[(.+)\]/
          h[:command] = $1
          h[:label] = $2
        end

        h[:args] = parts
        h
      end



      # We have 2 methods that are basically the same.  Is there a sensible way to abstract them so
      # that we can have methods that handle interpolated values for any number of values?
      # Or, if not that, consider a way to keep such methods in helper libs so that users can
      # add their own for the needs of their particular scripts and OSC?

      def interpolate2 addr_pattern, startx, starty, endx, endy, duration, looped=false
        warn "******** interpolate2 #{addr_pattern} looped = #{looped} ************" 
        steps_num = (duration.to_f/TIME_FRACTION).to_i 

        xsteps = calculate_value_steps startx, endx, duration
        ysteps = calculate_value_steps starty, endy, duration

        steps = xsteps.zip ysteps

        if !looped
          Thread.new(steps) do |steps|
            steps.each do |xy|   
              send_osc addr_pattern + " #{xy[0]} #{xy[1]}"
              sleep TIME_FRACTION
            end
          end
        else
          steps.each do |xy|   
            send_osc addr_pattern + " #{xy[0]} #{xy[1]}"
            sleep TIME_FRACTION
          end
        end
      end

      def interpolate1 addr_pattern, startx,  endx,  duration, looped=false
        warn "******** interpolate1 #{addr_pattern} looped = #{looped} ************" 
        steps_num = (duration.to_f/TIME_FRACTION).to_i 
        steps = calculate_value_steps startx, endx, duration
        if !looped
          Thread.new(steps) do |steps|
            steps.each do |x|   
              send_osc addr_pattern + " #{x}"
              sleep TIME_FRACTION
            end
          end
        else
          steps.each do |x|   
            send_osc addr_pattern + " #{x}"
            sleep TIME_FRACTION
          end
        end
      end


      def number_of_steps duration
        (duration.to_f/TIME_FRACTION).to_i
      end

      def calculate_value_steps start_val, end_val, duration
        start_val, end_val, duration = start_val.to_f, end_val.to_f, duration.to_f
        steps_num = number_of_steps  duration
        delta = calculate_steps_delta  start_val, end_val, steps_num

        val = start_val
        a = []
        steps_num.times do |i|
          a << (start_val +  delta*i)
        end
        a

      end

      def calculate_steps_delta start_val, end_val, steps_num
        diff = end_val.to_f - start_val.to_f
        diff/(steps_num-1).to_f 
      end

      # Something to consider:  If the list of commands is exhusted, the runner stops.
      # However, it *could* keep running and wait for commands over OSC.
      #
      def run
        @commands.each do |c|
          next  if c =~ /^#/
          execute_command c
        end
      end

      def send_osc s
        warn s
        message, s = *(s.split /\s/, 2)

        args = string_to_args s
        args.map! { |a| arg_to_type a }
        msg = OSC::Message.new message, *args  

        t = Thread.new do
          begin
            @client.send msg
          rescue 
            warn '!'*80
            warn "Error sending OSC message: #{$!}"
            warn '!'*80
          end
        end
        sleep TIME_FRACTION
      end

    end
  end 
end
