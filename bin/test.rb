#!/usr/bin/env ruby
require "fileutils"
require "ostruct"
require "fileutils"
require "logger"
require "open3"
BIN_DIR = File.expand_path(File.dirname(__FILE__))
HOME_DIR = File.expand_path(File.join(BIN_DIR, '..'))
LIB_DIR = File.join(HOME_DIR, 'lib')
TMPL_DIR = File.join(HOME_DIR, 'templates')
$LOAD_PATH.unshift(LIB_DIR)
require "tools"
require "gerrit"
require "sonar"


if __FILE__ == $0
  # init logger
  $logger = Logger.new(STDOUT)
  $logger.datetime_format = '%H:%M:%S'
  if ENV['DEBUG'] == 'true'
    $logger.level = Logger::DEBUG
  else
    $logger.level = Logger::INFO
  end

  ENV['SONAR_RUNNER_OPTS'] = '-Xms256m -Xmx768m' unless ENV['SONAR_RUNNER_OPTS']
  # Sonar command line arguments
  sonar_cmd_args = {
    'projectKey' => 'SONAR_PROJECT_KEY',
    'projectName' => 'SONAR_PROJECT_NAME',
    'projectVersion' => 'SONAR_PROJECT_VERSION',
    'sources' => 'SONAR_SOURCES',
    'language' => 'SONAR_LANGUAGE',
    'host.url' => 'SONAR_HOST_URL',
    'jdbc.url' => 'SONAR_JDBC_URL',
    'jdbc.username' => 'SONAR_JDBC_USERNAME',
    'jdbc.password' => 'SONAR_JDBC_PASSWORD',
  }
  $logger.debug("Loading sonar cmd environment variables: #{sonar_cmd_args.values}")
  sonar_cmd_config = Tools::hash_to_ostruct(Tools::load_env(sonar_cmd_args))
  # Sonar config
  sonar_args = {
    'base_branch' => 'BASE_BRANCH',
  }
  $logger.debug("Loading sonar environment variables: #{sonar_args.values}")
  sonar_config = Tools::hash_to_ostruct(Tools::load_env(sonar_args))
  # Gerrit
  gerrit_args = {
    'url' => 'GERRIT_URL',
    'username' => 'GERRIT_USERNAME',
    'password' => 'GERRIT_PASSWORD',
    'email' => 'GERRIT_EVENT_ACCOUNT_EMAIL',
  }
  $logger.debug("Loading gerrit environment variables: #{gerrit_args.values}")
  gerrit_config = Tools::hash_to_ostruct(Tools::load_env(gerrit_args))
  # Search for changes by revision id
  revision_id = ENV['GERRIT_PATCHSET_REVISION'] ? ENV['GERRIT_PATCHSET_REVISION'] : ENV['GERRIT_NEWREV']
  $logger.debug("Connecting to gerrit server #{gerrit_config.url}")
  gerrit_client = Gerrit.new(gerrit_config.url)
  gerrit_client.auth(gerrit_config.username, gerrit_config.password)
  $logger.debug("Querying changes by revision id #{revision_id}")
  changes = gerrit_client.query_changes_by_revision(revision_id).parse_body
  gerrit_config.change_id = changes[0]['change_id']
  # Get review
  $logger.debug("Fetching review #{revision_id} of change #{gerrit_config.change_id}")
  review = gerrit_client.get_review(gerrit_config.change_id, revision_id).parse_body
  gerrit_config.revision_id = review['revisions'].keys[0]
  gerrit_config.project = review['project']
  gerrit_config.git_url = review['revisions'][gerrit_config.revision_id]['fetch']['ssh']['url']
  sonar_config.target_branch = review['branch']
  sonar_cmd_config.branch = review['branch']
  # local repo
  local_repo = "/tmp/#{gerrit_config.project}-#{Time.now.strftime("%H:%M:%S")}"
  # remove existing dir
  FileUtils.rm_rf(local_repo)
  # clone the repo
  $logger.info("Cloning git repo to #{local_repo}")
  output, status = Open3::capture2e('git', 'clone', gerrit_config.git_url, local_repo)
  if status != 0
    $logger.fatal("Failed to clone repo: #{gerrit_config.git_url}")
    $logger.debug(output)
    exit 1
  end
  # fetch patch set
  gerrit_client.fetch_change(gerrit_config.change_id, gerrit_config.revision_id, local_repo)
  # start analysis
  opts = ['java', '-jar', File.join(BIN_DIR, 'sonar-runner.jar'), '-e']
  #cmd = "java -jar '#{File.join(BIN_DIR, 'sonar-runner.jar')}'"
  sonar_cmd_config.each_pair do |key, value|
    #opts.push("-Dsonar.#{key.to_s}='#{value}'")
    opts.push("-Dsonar.#{key.to_s}")
    opts.push(value)
  end
  unless ENV['SONAR_ARGS'].nil?
    opts.concat(ENV['SONAR_ARGS'].split(' '))
  end
  Dir::chdir(local_repo) do
    $logger.info("Running sonar runner: #{opts.join(' ')}")
    output, status = Open3::capture2e({'SONAR_RUNNER_OPTS' => ENV['SONAR_RUNNER_OPTS']}, *opts)
    if status != 0
      $logger.fatal("sonar analysis failed")
      $logger.debug(output)
      exit 2
    end
  end
  # get branch comparison result
  if sonar_config.base_branch == sonar_config.target_branch
    $logger.info("Target branch is the same as the base one. Skip branch comparing.")
    exit 0
  end
  sonar_comparison = SonarComparison.new( :sonar_url => sonar_cmd_config[:'host.url'],
                                          :project_key => sonar_cmd_config.projectKey,
                                          :base_branch => sonar_config.base_branch,
                                          :target_branch => sonar_config.target_branch)
  $logger.info("Getting branch comparison result")
  sonar_comparison.run
  # gerrit review
  review_value = sonar_comparison.review_value
  message = "Branch comparison result: #{sonar_comparison.get_url}"
  $logger.info("Reviewing gerrit patch set")
  gerrit_client.set_review(gerrit_config.change_id, gerrit_config.revision_id,
                          {'labels' => {'Code-Review' => review_value}, 'message' => message})
end
