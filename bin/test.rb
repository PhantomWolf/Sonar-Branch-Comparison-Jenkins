#!/usr/bin/env ruby
require "fileutils"
require "ostruct"
require "fileutils"
BIN_DIR = File.expand_path(File.dirname(__FILE__))
HOME_DIR = File.expand_path(File.join(BIN_DIR, '..'))
LIB_DIR = File.join(HOME_DIR, 'lib')
TMPL_DIR = File.join(HOME_DIR, 'templates')
$LOAD_PATH.unshift(LIB_DIR)
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
  sonar_cmd_config = Tools::hash_to_ostruct(Tools::load_env(sonar_cmd_args))
  # Sonar config
  sonar_args = {
    'url' => 'SONAR_URL',
    'runner_path' => 'RUNNER_PATH',
    'base_branch' => 'BASE_BRANCH',
  }
  sonar_config = Tools::hash_to_ostruct(Tools::load_env(sonar_args))
  # Email config
  email_args = {
    'smtp_server' => 'SMTP_SERVER',
    'sender' => 'EMAIL_SENDER',
  }
  email_config = Tools::hash_to_ostruct(Tools::load_env(email_args, true))
  # Gerrit
  gerrit_args = {
    'url' => 'GERRIT_URL',
    'username' => 'GERRIT_USERNAME',
    'password' => 'GERRIT_PASSWORD',
    'email' => 'GERRIT_EVENT_ACCOUNT_EMAIL',
  }
  gerrit_config = Tools::hash_to_ostruct(Tools::load_env(gerrit_args))
  # Search for changes by revision id
  revision_id = ENV['GERRIT_PATCHSET_REVISION'] ? ENV['GERRIT_PATCHSET_REVISION'] : ENV['GERRIT_NEWREV']
  gerrit_client = Gerrit.new(gerrit_config.url)
  gerrit_client.auth(gerrit_config.username, gerrit_config.password)
  changes = gerrit_client.query_changes_by_revision(revision_id)
  gerrit_config.change_id = changes[0]['change_id']
  # Get review
  review = gerrit_client.get_review(gerrit_config.change_id, revision_id)
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
  output = `git clone '#{gerrit_config.git_url}' '#{local_repo}'`
  if $?.exitstatus != 0
    raise StandardError.new("Failed to clone repo: #{gerrit_config.git_url}\n#{output}")
  end
  # fetch patch set
  gerrit_client.fetch_change(gerrit_config.change_id, gerrit_config.revision_id, local_repo)
  # start analysis
  cmd = "#{ENV['RUNNER_PATH']} #{ENV['SONAR_ARGS']}"
  sonar_cmd_config.each_pair do |key, value|
    cmd << " -Dsonar.#{key.to_s}='#{value}'"
  end
  Dir::chdir(local_repo) do
    puts "=" * 80
    puts "cmd: #{cmd}"
    output = `#{cmd}`
    if $?.exitstatus != 0
      raise StandardError.new("Sonar analysis failed:\n#{output}")
    end
  end
  # get branch comparison result
  if sonar_config.base_branch == sonar_config.target_branch
    puts "Target branch is the same as the base one. Skip branch comparing."
    exit 0
  end
  sonar_comparison = SonarComparison.new( :sonar_url => sonar_config.url,
                                          :project_key => sonar_cmd_config.projectKey,
                                          :base_branch => sonar_config.base_branch,
                                          :target_branch => sonar_config.target_branch)
  sonar_comparison.run
  # send email
  html = sonar_comparison.to_html
  email = Email.new
  email.subject = "[sonar branch comparison] #{gerrit_config.project}: #{sonar_config.base_branch} <=> #{sonar_config.target_branch}"
  email.body = html
  email.receiver = ENV['GERRIT_EVENT_ACCOUNT_EMAIL']
  email.sender = 'sonar-noreply@redhat.com'
  begin
    email.send
  rescue => e
    info = <<END
Failed to send notification email
    smtp server: #{email_config.smtp_server}
    from: #{email_config.sender}
    to: #{ENV['GERRIT_EVENT_ACCOUNT_EMAIL']}
    error: #{e}
END
    STDERR.write(info)
  end
  # gerrit review
  review_value = sonar_comparison.review_value
  message = "Branch comparison result: #{sonar_comparison.get_url}"
  gerrit_client.set_review(gerrit_config.change_id, gerrit_config.revision_id,
                          {'labels' => {'Code-Review' => review_value}, 'message' => message})
end
