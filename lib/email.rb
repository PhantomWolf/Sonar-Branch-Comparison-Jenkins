#!/usr/bin/env ruby
require "conf"
require 'net/smtp'

class Email
  attr_reader :sender, :receiver
  attr_accessor :subject, :body

  def initialize
    begin
      config = MyConf::load(File.join(CONF_DIR, 'email.conf'))
    rescue IOError => e
      config = {}
    end
    @smtp_server = config['SmtpServer'] ? config['SmtpServer'] : 'localhost'
    @sender = config['Sender'] ? config['Sender'] : "#{ENV['USER']}@#{ENV['HOSTNAME']}"
  end

  def validate_email(email)
    if not sender =~ /[\w_\-.]+@[\w_\-.]+/i
      raise ArgumentError.new("Invalid email address: #{sender}")
    end
  end

  def sender=(sender)
    self.validate_email(sender)
    @sender = sender
  end

  def receiver=(receiver)
    self.validate_email(receiver)
    @receiver = receiver
  end

  def send
    msg = <<MESSAGE_END
From: #{@sender}
To: #{@receiver}
MIME-Version: 1.0
Content-type: text/html; charset=UTF-8
Subject: #{@subject}

#{@body}
MESSAGE_END
    Net::SMTP.start(@smtp_server) do |smtp|
      smtp.send_message(msg, @sender, @receiver)
    end
  end
end
