#!/usr/bin/env ruby
require 'json'
require 'uri'
require 'openssl'
require 'net/http'
require 'net/http/digest_auth'

module CurlRest
  def self.request(cmd, auth=nil)
    auth = "--digest -u'#{auth[0]}:#{auth[1]}'" if not auth.nil?
    cmd << " " << auth if not auth.nil?
    puts "Command: #{cmd}"
    output = `#{cmd}`
    return output
  end

  def self.parse(output)
    magic_prefix = ")]}'\n"
    if not output.nil? and output.start_with?(magic_prefix)
      output = output[magic_prefix.length, output.length]
      return JSON::load(output)
    else
      return nil
    end
  end

  def self.get(url, auth=nil)
    cmd = "curl -sk -X GET '#{url}'"
    return self.request(cmd, auth)
  end

  def self.post(url, data, auth=nil)
    cmd = "curl -sk -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' -d '#{JSON.dump(data)}' '#{url}'"
    return self.request(cmd, auth)
  end

  def self.put(url, data, auth=nil)
    cmd = "curl -sk -X PUT -H 'Content-Type: application/json' -H 'Accept: application/json' -d '#{JSON.dump(data)}' '#{url}'"
    return self.request(cmd, auth)
  end

  def self.delete(url, auth=nil)
    cmd = "curl -sk -X DELETE '#{url}'"
    return self.request(cmd, auth)
  end
end

module Rest
  def self.get(url, auth=nil)
    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    return self.request(req, auth)
  end

  def self.post(url, data, auth=nil)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    req['Accept'] = 'application/json'
    req.body = JSON.dump(data)
    return self.request(req, auth)
  end

  def self.put(url, data, auth=nil)
    uri = URI(url)
    req = Net::HTTP::Put.new(uri)
    req['Content-Type'] = 'application/json'
    req['Accept'] = 'application/json'
    req.body = JSON.dump(data)
    return self.request(req, auth)
  end

  def self.delete(url, auth=nil)
    uri = URI(url)
    req = Net::HTTP::Delete.new(uri)
    return self.request(req, auth)
  end

  def self.request(req, auth=nil)
    # Parse url
    uri = req.uri
    if not auth.nil?
        raise ArgumentError.new("auth must be an array containing username and password") if auth.length != 2
        uri.user = auth[0]
        uri.password = auth[1]
    end
    http = Net::HTTP.new(uri.host, uri.port)
    # Handle ssl
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    # Get WWW-Authenticate header
    if not auth.nil?
      digest_auth = Net::HTTP::DigestAuth.new
      res = http.request(req)
      auth = digest_auth.auth_header(uri, res['www-authenticate'], req.method)
    end
    # create a new request with the authorization header
    req.add_field('Authorization', auth)
    req['Accept'] = 'application/json'
    res = http.request(req)
    return res
  end

  def self.parse(res)
    magic_prefix = ")]}'\n"
    body = res.body
    if not body.nil? and body.start_with?(magic_prefix)
      body = body[magic_prefix.length, body.length]
      return JSON::load(body)
    end
    return nil
  end
end


class Gerrit
  def initialize(base_url)
    @base_url = base_url
    @auth = nil
  end

  def auth(user, passwd)
    @auth = [user, passwd]
  end
  ################################################################################
  # Change endpoints
  ################################################################################
  def get_change(change_id)
    url = "#{@base_url}/a/changes/#{change_id}"
    return Rest::parse(Rest::get(url, @auth))
  end

  def query_changes_by_revision(revision_id)
    url = "#{@base_url}/a/changes/?q=#{revision_id}"
    return Rest::parse(Rest::get(url, @auth))
  end

  def abandon_change(change_id, data=nil)
    url = "#{@base_url}/a/changes/#{change_id}/abandon"
    return Rest::parse(Rest::post(url, data, @auth))
  end

  def restore_change(change_id, data=nil)
    url = "#{@base_url}/a/changes/#{change_id}/restore"
    return Rest::parse(Rest::post(url, data, @auth))
  end

  def rebase_change(change_id, data=nil)
    url = "#{@base_url}/a/changes/#{change_id}/rebase"
    return Rest::parse(Rest::post(url, data, @auth))
  end

  def revert_change(change_id, data=nil)
    url = "#{@base_url}/a/changes/#{change_id}/revert"
    return Rest::parse(Rest::post(url, data, @auth))
  end

  def submit_change(change_id, data=nil)
    url = "#{@base_url}/a/changes/#{change_id}/submit"
    return Rest::parse(Rest::post(url, data, @auth))
  end
  ################################################################################
  # Reviewer endpoints
  ################################################################################
  def list_reviewers(change_id)
    url = "#{@base_url}/a/changes/#{change_id}/reviewers"
    return Rest::parse(Rest::get(url, @auth))
  end

  def get_reviewer(change_id, account_id)
    url = "#{@base_url}/a/changes/#{change_id}/reviewers/#{account_id}"
    return Rest::parse(Rest::get(url, @auth))
  end

  def add_reviewer(change_id, data=nil)
    url = "#{@base_url}/a/changes/#{change_id}/reviewers"
    return Rest::parse(Rest::post(url, data, @auth))
  end

  def delete_reviewer(change_id, account_id)
    url = "#{@base_url}/a/changes/#{change_id}/reviewers/"
    return Rest::parse(Rest::delete(url, @auth))
  end
  ################################################################################
  # Revision endpoints
  ################################################################################
  def get_commit(change_id, revision_id='current')
    url = "#{@base_url}/a/changes/#{change_id}/revisions/#{revision_id}/commit"
    return Rest::parse(Rest::get(url, @auth))
  end

  def get_review(change_id, revision_id='current')
    url = "#{@base_url}/a/changes/#{change_id}/revisions/#{revision_id}/review"
    return Rest::parse(Rest::get(url, @auth))
  end

  def get_related_changes(change_id, revision_id='current')
    url = "#{@base_url}/a/changes/#{change_id}/revisions/#{revision_id}/related"
    return Rest::parse(Rest::get(url, @auth))
  end

  def set_review(change_id, revision_id='current', data=nil)
    url = "#{@base_url}/a/changes/#{change_id}/revisions/#{revision_id}/review"
    return Rest::parse(Rest::post(url, data, @auth))
  end

  def fetch_change(change_id, local_repo, method='checkout', link_type='ssh')
    # Get repo url and ref
    data = self.get_review(change_id, 'current')
    raise StandardError.new("Failed to get change via rest api: #{change_id}") if data.nil?
    revision_id = data['revisions'].keys[0]
    url = data['revisions'][revision_id]['fetch'][link_type]['url']
    ref = data['revisions'][revision_id]['fetch'][link_type]['ref']
    case method
      when 'checkout'
        cmd = "git fetch '#{url}' '#{ref}' && git checkout FETCH_HEAD"
      when 'pull'
        cmd = "git pull '#{url}' '#{ref}'"
      when 'cherry-pick'
        cmd = "git fetch '#{url}' '#{ref}' && git cherry-pick FETCH_HEAD"
      when 'patch'
        cmd = "git fetch '#{url}' '#{ref}' && git format-patch -1 --stdout FETCH_HEAD"
      else
        raise ArgumentError.new("Fetch method not supported: #{method}")
    end
    # Run git
    Dir::chdir(local_repo) do
      output = `#{cmd}`
      return $?.exitstatus
    end
  end
end
