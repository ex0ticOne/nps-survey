require "carbon"
require "json"
require "carbon_smtp_adapter"

config = File.open("./config.json") do |file|
  JSON.parse(file)
end

abstract class BaseEmail < Carbon::Email
end

BaseEmail.configure do |settings|

  Carbon::SmtpAdapter.configure do |settings|
    settings.host = config["host"].to_s
    settings.port = config["smtp_port"].as_i
    settings.helo_domain = config["helo_domain"].to_s
    settings.use_tls = config["use_tls"].as_bool
    settings.username = config["email_username"].to_s
    settings.password = config["email_password"].to_s
  end
  
    #settings.adapter = Carbon::DevAdapter.new(print_emails: true)
    settings.adapter = Carbon::SmtpAdapter.new
  end

# Create an email class
class EmailNps < BaseEmail
    def initialize(
      @from_company_name : String,
      @email_from : String,
      @base_url : String,
      @ticket : String,
      @hash : String,
      @subject : String,
      @customer_name : String, 
      @customer_email : String)
    end
    
    from Carbon::Address.new(@from_company_name, @from_email)
    from @email_from
    to @customer_email
    subject @subject
    reply_to "no-reply@noreply.com"
    templates text, html
  end