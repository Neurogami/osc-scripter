#!/usr/bin/env ruby

require 'osc-ruby'

include  OSC

@listen_on_port = 8000


warn "If you pass an arg it will be used as the port numnber instead of #{@listen_on_port}"

if !ARGV.empty?
  @listen_on_port  = ARGV.shift.to_i
end

warn "Listening on #{@listen_on_port}"

@server = Server.new @listen_on_port

maps = {}

if !ARGV.empty?
  eval(IO.read ARGV.first)
end

@server.add_method /.*/ do |msg|
  # warn "Have args #{msg.inspect}"
   puts "#{msg.address}  #{ msg.to_a.join(', ') }"
end

t = Thread.new do
  @server.run
end

t.join


