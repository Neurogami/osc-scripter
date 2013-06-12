require 'osc-ruby'
require 'utils'

Thread.abort_on_exception = true

module Neurogami
  module OscScripter

    class OscServer

      include  OSC

      def initialize port, runner 
        @runner = runner 
        @server = Server.new port

       Thread.new do 
          serve
       end
      end

      def serve
        @server.add_method /.*/ do |msg|
          # The assumption is that content of the OSC message is simply a string such as what
          # you owuld have in a script file.  This method just takes that string and
          # has the runner execute it
            puts "* #{msg.address} -  #{ msg.to_a.join(', ') }"
            @runner.execute_command msg.to_a.join(' ')
        end

        @thread = Thread.new do
          @server.run
        end
      end

      def kill 
        @thread.kill
      end

    end
    class ScriptRunner

      include  OSC
      include Utils
      TIME_FRACTION = 0.1

      def initialize script_path
        @raw_script_lines = IO.readlines script_path
        parse_script @raw_script_lines 
        @client = Client.new @address, @port
        @threaded_loops = {}
        @server = OscServer.new @internal_port, self
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
        raise "OSC server port cannot be '#{@port}'" unless @port > 1000 # Need sure if this is ideal, but it's a start
        @internal_port = raw_script_lines.shift
        @internal_port = @internal_port.to_i
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
        h[:label] = nil

        h[:command] = parts.shift

        if  h[:command] =~ /(.+)\[(.+)\]/
          h[:command] = $1
          h[:label] = $2
        end

        h[:args] = parts
        h
      end


      # The idea is to be able to define some sort of messaging sequence that is executed inside an endless loop
      # Later commands in a script could then stop this loop
      # 
      # So, two problems.  One, how can we wrap other helper methods (such as `interpolate2`) in a loop?
      #  Right now, if a complex command is encountered, we do chunk it out and then do this:
      #      send data[:command], *data[:args] 
      # Suppose we looked for yet another marker, perhaps  a leading '@', and that meant we did this:
      #  
      #  Thread.new do
      #     while true;  send data[:command], *data[:args] ; end
      #  end
      #
      #   The trouble is that the command would be using a Thread, so we get endless threads created.
      #
      #   If we told that iner method not to thread, then the master loop would be the only thread.
      #
      #   Seems that some guidelines would have to be followed when creating custom handlers for complex commands
      #   If they employ a thread they have to have a way to know if that thread should be skipped because the
      #   whole thing is inside a master loop.
      #
      def loop
      end

      # We have 2 methods that are basically the same.  Is there a sensible way to abstract them so
      # that we can have methods that handle inteprolated values for any number of values?
      # Or, if not that, consider a way to keep such methods in helper libs so that users can
      # add their own for the needs of their particualr scripts and OSC?

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

        t.join
        sleep 0.02

      end

    end
  end 
end
