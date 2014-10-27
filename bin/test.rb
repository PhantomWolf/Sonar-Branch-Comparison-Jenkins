#!/usr/bin/env ruby
BIN_DIR = File.expand_path(File.dirname(__FILE__))
HOME_DIR = File.expand_path(File.join(BIN_DIR, '..'))
CONF_DIR = File.join(HOME_DIR, 'conf')
$LOAD_PATH.unshift(HOME_DIR)
require "lib/conf"
require "lib/email"


if __FILE__ == $0
  ENV['SONAR_ARGS'] = " " unless ENV['SONAR_ARGS']
  ENV['SONAR_RUNNER_OPTS'] = '-Xms256m -Xmx768m'
  args = {
    'sonar.projectKey' => 'SONAR_PROJECT_KEY',
    'sonar.projectName' => 'SONAR_PROJECT_NAME',
    'sonar.projectVersion' => 'SONAR_PROJECT_VERSION',
    'sonar.sources' => 'SONAR_SOURCES',
    'sonar.language' => 'SONAR_LANGUAGE',
    'runner_path' => 'RUNNER_PATH',
    'base_branch' => 'BASE_BRANCH',
    'sonar_url' => 'SONAR_URL',
    'sonar_args' => 'SONAR_ARGS',
    'email' => 'GERRIT_EVENT_ACCOUNT_EMAIL',
  }
  args.each_pair do |key, value|
    if ENV[key]
      args[key] = ENV[key]
    end
  end
  # Gerrit
  revision_id = ENV['GERRIT_PATCHSET_REVISION'] ? ENV['GERRIT_PATCHSET_REVISION'] : ENV['GERRIT_NEWREV']
  gerrit_client = Gerrit.new(args['sonar_url'])
  changes = gerrit_client.query_changes_by_revision(revision_id)
end
