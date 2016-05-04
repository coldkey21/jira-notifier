#!/usr/bin/env ruby

# Matthew Birky Jan 2016
# Usefull links
#   https://api.slack.com/incoming-webhooks

require 'rubygems'
require 'bundler/setup'

require 'jira'
require 'logger'

# Sets up the connection to both Jira and Slack then
#   looks for relvent Jira issues and posts them
class Notifier
  def initialize(options, logger)
    @options = options
    init_jira
    init_slack
    @logger = logger
  end

  def run(notification)
    issues = @jira_client.Issue.jql(notification['jira_query'])

    if issues.any?
      output = format_message(notification)
      output << format_issues(issues)

      @options[:debug] ? debug_output(output) : post(notification, output)
    end

  rescue JIRA::HTTPError => e
    @logger.fatal(format('%s-%s', e.code, e.message))
  end

  private

  def init_jira
    jira_options = { site: @options.fetch(:jira_server), auth_type: :basic,
                     username: @options.fetch(:jira_username),
                     password: @options.fetch(:jira_password),
                     context_path: '',
                     ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE }

    @jira_client = JIRA::Client.new(jira_options)
  end

  def init_slack
    uri = URI.parse(@options.fetch(:slack_hooks_url))
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = true
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end

  def format_message(notification)
    jira_query = CGI.escape(notification['jira_query'])
    format("<%s/issues/?jql=%s|%s>\n", @options.fetch(:jira_server), \
           jira_query, notification['message'].to_s)
  end

  def format_issues(issues)
    output = ''
    issues.each do |issue|
      output << format("\t* <%s/browse/%s|%s> - %s\n", \
                       @options.fetch(:jira_server), issue.key, issue.key, \
                       issue.summary.chomp('.'))
    end
    output
  end

  def debug_output(output)
    @logger.info('Debug Mode')
    puts output
  end

  def post(notification, output)
    @request = Net::HTTP::Post.new(notification['channel'])
    @request.add_field('Content-Type', 'application/json')

    @request.body = { 'text' => output }.to_json
    response = @http.request(@request)

    logger_output = format('%s-%s', response.code, response.message)
    if response.code == '200'
      @logger.info(logger_output)
    else
      @logger.fatal(logger_output)
    end
  end
end

logger = Logger.new('.jira_notifier.log')

options = { slack_hooks_url: 'https://hooks.slack.com' }

OptionParser.new do |opts|
  opts.on('-d', '--debug') do
    options[:debug] = true
  end
end.parse!

begin
  file = File.read(ARGV[0])
  hash = JSON.parse(file)
rescue Errno::ENOENT, JSON::ParserError, TypeError => e
  logger.fatal(e.message)
  puts 'File read error!'
  exit
end

notifications = []

hash.each do |key, value|
  case key
  when 'jira_server'
    options[:jira_server] = value
  when 'jira_username'
    options[:jira_username] = value
  when 'jira_password'
    options[:jira_password] = value
  when 'notification'
    notifications.push(value)
  end
end

swarm_notifier = Notifier.new(options, logger)

notifications.each do |notification|
  swarm_notifier.run(notification)
end
