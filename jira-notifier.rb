#!/usr/bin/env ruby

# Matthew Birky Jan 2016
# Usefull links
#   https://api.slack.com/incoming-webhooks

require 'net/http'
require 'optparse'
require 'jira'
require 'json'
require 'logger'
require 'uri'

class Notifier

    def initialize(options, logger)
        @jira_client = JIRA::Client.new({   :site=>options[:jira_server],
                                            :auth_type=>:basic,
                                            :username=>options[:jira_username],
                                            :password=>options[:jira_password],
                                            :context_path=>'',
                                            :ssl_verify_mode=>OpenSSL::SSL::VERIFY_NONE})

        uri = URI.parse(options[:slack_hooks_url])
        @http = Net::HTTP.new(uri.host, uri.port)
        @http.use_ssl = true
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE

        @logger = logger
    end

    def run(options, notification)
        @request = Net::HTTP::Post.new(notification["channel"])
        @request.add_field('Content-Type', 'application/json')

        begin
            issues = @jira_client.Issue.jql(notification["jira_query"])

            if issues.any?
                output = "<" + options[:jira_server] + "/issues/?jql=" + URI.escape(notification["jira_query"]) + "|" + notification["message"].to_s + ">\n"

                issues.each do |issue|
                    output += "\t* <" + options[:jira_server] + "/browse/" + issue.key + "|" + issue.key + "> - " + issue.summary.chomp(".") + "\n"
                end

                if !options[:debug]
                    @request.body = {"text" => output}.to_json
                    response = @http.request(@request)
    
                    logger_output = response.code + "-" + response.message

                    if response.code == "200"
	            	    @logger.info(logger_output)
                    else
                        @logger.fatal(logger_output)
                    end
                else
                    @logger.info("Debug Mode")
                    puts output
                end
            end

        rescue JIRA::HTTPError => e
            @logger.fatal(e.code + "-" + e.message)
        end
    end

end

logger = Logger.new(".jira_notifier.log")

options = {:slack_hooks_url => 'https://hooks.slack.com'}

OptionParser.new do |opts|
    opts.on("-d", "--debug") do
        options[:debug] = true
    end
end.parse!

begin
    file = File.read(ARGV[0])
    hash = JSON.parse(file)
rescue Errno::ENOENT, JSON::ParserError, TypeError => e 
    logger.fatal(e.message)
    puts "File read error!"
    exit
end

notifications = []

hash.each do | key, value |
    case key
    when "jira_server"
        options[:jira_server] = value
    when "jira_username"
        options[:jira_username] = value
    when "jira_password"
        options[:jira_password] = value
    when "notification"
        notifications.push(value)
    end
end

swarm_notifier = Notifier.new(options, logger)

notifications.each do | notification |
    swarm_notifier.run(options, notification)
end
