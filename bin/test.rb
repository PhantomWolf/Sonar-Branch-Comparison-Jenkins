#!/usr/bin/env ruby
require 'fileutils'
require "ostruct"
BIN_DIR = File.expand_path(File.dirname(__FILE__))
HOME_DIR = File.expand_path(File.join(BIN_DIR, '..'))
CONF_DIR = File.join(HOME_DIR, 'conf')
LIB_DIR = File.join(HOME_DIR, 'lib')
$LOAD_PATH.unshift(LIB_DIR)
require "conf"
require "gerrit"
require "email"
require "sonar"


if __FILE__ == $0
  # check environment variables
  required_env_vars = ['SONAR_URL', 'SONAR_USERNAME', 'SONAR_PASSWORD',
                      'RUNNER_PATH', 'BASE_BRANCH', 'GERRIT_EVENT_ACCOUNT_EMAIL']
  required_env_vars.each do |item|
    raise ArgumentError.new("Env var #{item} doesn't exist!") unless ENV[item]
  end
  # check sonar command line args
  sonar_cmd_args = {
    'sonar.projectKey' => 'SONAR_PROJECT_KEY',
    'sonar.projectName' => 'SONAR_PROJECT_NAME',
    'sonar.projectVersion' => 'SONAR_PROJECT_VERSION',
    'sonar.sources' => 'SONAR_SOURCES',
    'sonar.language' => 'SONAR_LANGUAGE',
  }
  sonar_cmd_args.each_pair do |key, value|
    if ENV[value]
      sonar_cmd_args[key] = ENV[value]
    else
      raise ArgumentError.new("Env var #{value} doesn't exist!") unless ENV[value]
    end
  end
  # configuration
  ENV['SONAR_ARGS'] = " " unless ENV['SONAR_ARGS']
  ENV['SONAR_RUNNER_OPTS'] = '-Xms256m -Xmx768m'
  $config = OpenStruct.new
  args = {
    'runner_path' => 'RUNNER_PATH',
    'base_branch' => 'BASE_BRANCH',
    'sonar_url' => 'SONAR_URL',
    'sonar_args' => 'SONAR_ARGS',
    'email' => 'GERRIT_EVENT_ACCOUNT_EMAIL',
    'sonar_username' => 'SONAR_USERNAME',
    'sonar_password' => 'SONAR_PASSWORD',
  }
  args.each_pair do |key, value|
    if ENV[value]
      args[key] = ENV[value]
    end
  end
  # Gerrit
  revision_id = ENV['GERRIT_PATCHSET_REVISION'] ? ENV['GERRIT_PATCHSET_REVISION'] : ENV['GERRIT_NEWREV']
  gerrit_client = Gerrit.new(ENV['SONAR_URL'])
  gerrit_client.auth(ENV['SONAR_USERNAME'], ENV['SONAR_PASSWORD'])
  changes = gerrit_client.query_changes_by_revision(revision_id)
  $config.change_id = changes[0]['change_id']
  # Get review
  review = gerrit_client.get_review($config.change_id, revision_id)
  $config.revision_id = review['revisions'].keys[0]
  $config.branch = review['branch']
  sonar_cmd_args['sonar.branch'] = review['branch']
  $config.project = review['project']
  $config.git_url = review['revisions'][$config.revision_id]['fetch']['ssh']['url']
  # local repo
  $config.local_repo = "/tmp/#{$config.project}-#{Time.now.strftime("%H:%M:%S")}"
  # remove existing dir
  FileUtils.rm_rf($config.local_repo)
  # clone the repo
  output = `git clone '#{$config.git_url}' '#{$config.local_repo}'`
  if $?.exitstatus != 0
    raise StandardError.new("Failed to clone repo: #{$config.git_url}\n#{output}")
  end
  # fetch patch set
  gerrit_client.fetch_change($config.change_id, $config.local_repo)
  # start analysis
  cmd = "#{ENV['RUNNER_PATH']} #{ENV['SONAR_ARGS']}"
  sonar_cmd_args.each_pair do |key, value|
    cmd << " -D#{key}='#{value}'"
  end
  Dir::chdir($config.local_repo) do
    output = `#{cmd}`
    if $?.exitstatus != 0
      raise StandardError.new("Sonar analysis failed:\n#{output}")
    end
  end
  # get branch comparison result
  base_project_key = "#{sonar_cmd_args['sonar.projectKey']}:#{ENV['BASE_BRANCH']}"
  target_project_key = "#{sonar_cmd_args['sonar.projectKey']}:#{$config.branch}"
  result_link = Sonar::gen_comparison_result_url(ENV['SONAR_URL'], base_project_key, target_project_key, 'json')
  res = Rest::get(result_link)
  if res.status_code < 200 or res.status_code >= 300
    raise StandardError.new("HTTP #{res.status_code}: Failed to get branch comparison result")
  end
  data = JSON.load(res.text)
  # send email
  html = Sonar::comparison_to_html(data)
  email = Email.new
  email.subject = "[sonar branch comparison] #{$config.project}: #{ENV['BASE_BRANCH']} <=> #{$config.branch}"
  email.body = html
  email.receiver = ENV['GERRIT_EVENT_ACCOUNT_EMAIL']
  email.sender = 'sonar-noreply@redhat.com'
  begin
    email.send
  rescue => e
    STDERR.write("Failed to send email to #{ENV['GERRIT_EVENT_ACCOUNT_EMAIL']}: #{e}")
  end
  # gerrit review
  review_value = Sonar::analyze_comparison(data)
  message = "Branch comparison result: #{result_link}"
  gerrit_client.set_review($config.change_id, $config.revision_id,
                          {'labels' => {'Code-Review' => review_value}, 'message' => message})
end
