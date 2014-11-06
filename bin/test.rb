#!/usr/bin/env ruby
require 'fileutils'
require "ostruct"
require "fileutils"
BIN_DIR = File.expand_path(File.dirname(__FILE__))
HOME_DIR = File.expand_path(File.join(BIN_DIR, '..'))
CONF_DIR = File.join(HOME_DIR, 'conf')
LIB_DIR = File.join(HOME_DIR, 'lib')
TMPL_DIR = File.join(HOME_DIR, 'templates')
LOAD_PATH.unshift(LIB_DIR)
require "tools"
require "gerrit"
require "email"
require "sonar"


if __FILE__ == $0
  ENV['SONAR_RUNNER_OPTS'] = '-Xms256m -Xmx768m'
  # Sonar command line arguments
  sonar_cmd_args = {
    'projectKey' => 'SONAR_PROJECT_KEY',
    'projectName' => 'SONAR_PROJECT_NAME',
    'projectVersion' => 'SONAR_PROJECT_VERSION',
    'sources' => 'SONAR_SOURCES',
    'language' => 'SONAR_LANGUAGE',
  }
  $sonar_config = Tools::hash_to_ostruct(Tools::load_env(sonar_cmd_args))
  # configuration
  sonar_args = {
    'url' => 'SONAR_URL',
    'runner_path' => 'RUNNER_PATH',
    'base_branch' => 'BASE_BRANCH',
  }
  $sonar_config = Tools::hash_to_ostruct(Tools::load_env(sonar_args))
  # Gerrit
  gerrit_args = {
    'url' => 'GERRIT_URL',
    'username' => 'GERRIT_USERNAME',
    'password' => 'GERRIT_PASSWORD',
    'email' => 'GERRIT_EVENT_ACCOUNT_EMAIL',
  }
  $gerrit_config = Tools::hash_to_ostruct(Tools::load_env(gerrit_args))
  revision_id = ENV['GERRIT_PATCHSET_REVISION'] ? ENV['GERRIT_PATCHSET_REVISION'] : ENV['GERRIT_NEWREV']
  # Search for changes by revision id
  gerrit_client = Gerrit.new($gerrit_config.url)
  gerrit_client.auth($gerrit_config.username, $gerrit_config.password)
  changes = gerrit_client.query_changes_by_revision(revision_id)
  $gerrit_config.change_id = changes[0]['change_id']
  # Get review
  review = gerrit_client.get_review($config.change_id, revision_id)
  $config.revision_id = review['revisions'].keys[0]
  $config.target_branch = review['branch']
  $config.base_branch = ENV['BASE_BRANCH']
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
  base_project_key = "#{sonar_cmd_args['sonar.projectKey']}:#{$config.base_branch}"
  target_project_key = "#{sonar_cmd_args['sonar.projectKey']}:#{$config.target_branch}"
  result_link = Sonar::gen_comparison_url(ENV['SONAR_URL'], base_project_key, target_project_key, 'json')
  res = Rest::get(result_link)
  if res.status_code < 200 or res.status_code >= 300
    raise StandardError.new("HTTP #{res.status_code}: Failed to get branch comparison result")
  end
  measure_data = JSON.load(res.text)
  # send email
  html = Sonar::comparison_to_email($config.base_branch, $config.target_branch, measure_data, result_link)
  email = Email.new
  email.subject = "[sonar branch comparison] #{$config.project}: #{$config.base_branch} <=> #{$config.target_branch}"
  email.body = html
  email.receiver = ENV['GERRIT_EVENT_ACCOUNT_EMAIL']
  email.sender = 'sonar-noreply@redhat.com'
  begin
    email.send
  rescue => e
    STDERR.write("Failed to send email to #{ENV['GERRIT_EVENT_ACCOUNT_EMAIL']}: #{e}")
  end
  # gerrit review
  review_value = Sonar::analyze_comparison(measure_data)
  message = "Branch comparison result: #{result_link}"
  gerrit_client.set_review($config.change_id, $config.revision_id,
                          {'labels' => {'Code-Review' => review_value}, 'message' => message})
end
