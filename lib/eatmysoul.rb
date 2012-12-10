#! /usr/bin/env ruby
## eatmysoul.rb
## Login : <elthariel@gmail.com>
## Started on  Fri Jun  3 12:11:21 2011 Julien 'Lta' BALLET
## $Id$
##
## Author(s):
##  - Julien 'Lta' BALLET <elthariel@gmail.com>
##
## Copyright (C) 2011 Julien 'Lta' BALLET
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'eventmachine'
require 'singleton'
require 'yaml'
require 'logger'
require 'digest/md5'
require 'trollop'

module EatMySoul
  class Settings
    # edit the next line to change the default path
    def initialize()
      begin
        @options = {
          :server => "ns-server.epita.fr",
          :port => 4242,
          :login => "login_x",
          :passwd => "pwd_socks",
          :logfile => "STDOUT",
          :loglevel => "WARN",
          :location => "somewhere",
          :status => "chatless client"
        }

        parser = Trollop::Parser.new
        parser.opt(:config_file, "Configuration file path",
                   :default => (if `id` =~ /root/ then "/etc/eatmysoul.yml"
                                else "#{ENV['HOME']}/.eatmysoul.yml" end))
        @options.each { |k,v| parser.opt(k, k.to_s, :type => :string) }
        cli_opts = parser.parse.delete_if { |k,v| not v or k =~ /_given/ }
        puts cli_opts
        path = cli_opts.delete :config_file

        if File.exists? path
          yaml = YAML::load_file(path)
          @options.merge! yaml
        end
        @options.merge! cli_opts

        save path

      rescue => e
        $stderr.write "Error with settings parsing: #{e}\n"
        $stderr.write "#{e.backtrace}\n"
      end

      init_logger
      validates
    end

    def save(path)
      yaml = YAML::dump(@options)

      if ((File.exists? path and File.writable? path) or not File.exists?(path))
        File.open(path, "w") do |f|
          f << yaml
        end
      end
    end

    def init_logger
      if logfile == "STDOUT" or logfile == "STDERR"
        @options[:logger] = Logger.new Kernel.const_get logfile.to_sym
      else
        @options[:logger] = Logger.new logfile
      end
      logger.level = Logger.const_get loglevel.to_sym
      logger.progname = "eatmysoul"
      logger.warn "Started EatMySoul"
    end

    def validates
      if location.length > 64 or status.length > 64
        logger.fatal "location and status lengths must be < 64 characters"
        exit 42
      end
    end

    def method_missing(sym)
      if @options.has_key? sym
        @options[sym]
      else
        raise NoMethodError
      end
    end
  end

  class Netsoul < EM::Connection
    ERROR = 0
    NOT_CONNECTED = 1
    CONNECTED = 2
    AUTHING = 3
    AUTHACK = 4
    AUTHED = 5

    attr_reader :last_ping

    def initialize(settings)
      @o = settings
      @status = NOT_CONNECTED
      @last_ping = Time.now
      Manager.instance.active_connection = self
    end

    def post_init
      @status = CONNECTED
    end

    def receive_data(data)
      @o.logger.debug "Read from server \"#{data.chomp}\""

      if @status == CONNECTED
        auth_start data
      elsif @status == AUTHING
        auth data
      elsif @status == AUTHACK
        auth_ack data
      elsif @status == AUTHED
        ping (data)
      elsif @status == ERROR
        @o.logger.warn "Receiving data, but connection is in ERROR state"
      end
    end

    def unbind
      Manager.instance.active_connection = nil
      EM.add_timer(5) { EM.connect @o.server, @o.port, Netsoul, @o }
    end

    private

    def auth_start(connect_seed)
      @o.logger.debug "Requesting ext_user auth"

      connect_seed.chomp!
      send_data "auth_ag ext_user none none\n"
      @status = AUTHING
      @seed = connect_seed.split ' '
    end

    def auth(data)
      if data.chomp != "rep 002 -- cmd end"
        @o.logger.fatal "Authentication query didn't succeed"
        @o.logger.debug "Server answer is #{data}"
        @status = ERROR
      else
        md5 = "#{@seed[2]}-#{@seed[3]}/#{@seed[4]}#{@o.passwd}"
        @o.logger.debug md5
        md5 = Digest::MD5.hexdigest md5

        login = "ext_user_log #{@o.login} #{md5} #{ns_encode @o.location} #{ns_encode @o.status}"
        @o.logger.debug login

        send_data login + "\n"
        @status = AUTHACK
      end
    end

    def auth_ack(answer)
      if answer.chomp != "rep 002 -- cmd end"
        @o.logger.fatal "Login didn't succeed"
        @o.logger.debug "Server answer is #{answer}"
        @status = ERROR
      else
        @status = AUTHED
        @last_ping = Time.now
        @o.logger.warn "Connected using #{@o.login} from #{@o.location} (#{@o.status})"
      end
    end

    def ping(msg)
      event = msg.chomp.split ' '

      if event[0] == "ping"
        reply = "#{event[0]} #{event[1]}"
        @o.logger.info "Ping !"
        @o.logger.debug "Ping reply \"#{reply}\""
        send_data "#{reply}\n"
        @last_ping = Time.now
      else
        @o.logger.info "Received a #{event[0]} command, not supported yet"
      end
    end

    def ns_encode(s)
      str = s.gsub("\n", "\\n")
      str.gsub!(/[^a-zA-Z0-9_.\-\\]/) {|s| "%%%02X" % s.ord }
      str.gsub!(' ', '+')
      str
    end
  end # class Netsoul


  class Manager
    include Singleton
    attr_accessor :active_connection, :monitor_timer

    def run(o)
      EM.run do
        monitor_timer = EM::add_periodic_timer(1) { monitor o } unless monitor_timer
        EM.connect o.server, o.port, Netsoul, o
      end
    end

    def connect_loop(o)
      while true do
        sleep_time = 0

        begin
          self.run(o)
        rescue => e
          o.logger.fatal "Rescued from exception #{e}"
          o.logger.debug e.backtrace.join "\n"
        end

        sleep sleep_time
        sleep_time = sleep_time + 5 if sleep_time < 120
      end
    end

    def monitor(o)
      if active_connection
        o.logger.debug "Checking for connection inactivity"
        if (Time.now - active_connection.last_ping) > 650
          o.logger.warn "Connection seems inactive, restarting ..."
          active_connection.close_connection
        end
      end
    end

  end # class Manager


end # module EatmySoul

