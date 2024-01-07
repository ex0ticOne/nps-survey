require "kemal"
require "email"
require "json"
require "log"
require "ecr"
require "db"
require "sqlite3"

# Config file
config = File.open("config.json") do |file|
     JSON.parse(file)
end

base_url = config["base_url"].to_s
token_auth = config["token"].to_s

# Rates categories
promoters = [9,10]
neutral = [7,8]
detractors = (0..6).to_a
rate_range = (0..10).to_a

# DB on pool mode
DB.open "sqlite3://./db/db_NPS.sqlite3" do |db|

     get "/ping-nps" do |env|
          if env.request.headers["token"] == token_auth
               "Net Promoter Score service is running and ready to send surveys and receive answers from customers"
          else
               halt env, status_code: 403
          end
     end

     post "/send-survey" do |env|

          token = env.request.headers["token"]

          if token != token_auth || token.nil?
               halt env, status_code: 403, response: "Unauthorized"
          end

          ticket = env.params.json["ticket"].as(String)
          customer_name = env.params.json["customer_name"].as(String)
          customer_email = env.params.json["customer_email"].as(String)

          # Do not sent duplicate survey if already sent, avoid angry customers with spam
          query_survey = db.query_one? "SELECT ticket FROM sent_surveys WHERE ticket = ?", args: [ticket], as: String
     
          unless query_survey.nil?
               halt env, status_code: 400, response: "Survey already sent"
          end

          # Generate a hash to the survey, this avoids abuse
          hash_generator = Random.new
          hash = hash_generator.hex(16)

          begin
               email_nps = EMail::Message.new
               email_nps.from config["email_from"].to_s
               email_nps.to customer_email
               email_nps.subject config["subject"].to_s
               email_nps.message render "./templates/html.ecr"
     
               smtp_config = EMail::Client::Config.new(config["smtp_server"].to_s, config["smtp_port"].as_i, helo_domain: config["helo_domain"].to_s)
               #smtp_config.use_tls(EMail::Client::TLSMode::SMTPS)
               smtp_config.use_auth(config["email_username"].to_s, config["email_password"].to_s)
     
               client = EMail::Client.new(smtp_config)

               client.start do
                    send(email_nps)
               end
          rescue e
               Log.warn(exception: e) {"Failed to deliver e-mail, check your credentials on config.json."}
               halt env, status_code: 500
          end

          begin
               db.exec "INSERT INTO sent_surveys VALUES (?, ?, ?, ?)", args: [Time.local, ticket, customer_email, hash] of DB::Any
          rescue e
               Log.warn(exception: e) {"Can't reach database for registering sent survey, check database file. This will make the answer-nps endpoint fail when trying to receive an answer (ticket and hash will not exist on sent_surveys)."}
          end

     end

     get "/answer-nps" do |env|
          ticket = env.params.query["ticket"].to_s
          rate = env.params.query["rate"].to_i
          hash = env.params.query["hash"].to_s

          # Check if survey exists
          query_survey_exists = db.query_one? "SELECT ticket FROM sent_surveys WHERE ticket = ? AND hash = ?", args: [ticket, hash] of DB::Any, as: String

          if query_survey_exists.nil?
               halt env, status_code: 400, response: "Survey doesn't exist"
          end

          # Avoid duplicate answers
          query_already_answered = db.query_one? "SELECT ticket FROM survey_responses WHERE ticket = ?", args: [ticket] of DB::Any, as: String

          if query_already_answered.nil?

               #Avoid out-of-range rates
               unless rate_range.includes?(rate)
                    halt env, status_code: 400, response: "Rate outside the Net Promoter Score range"
               end

               begin
                    db.exec "INSERT INTO survey_responses(timestamp, ticket, rate) VALUES (?, ?, ?)", args: [Time.local, ticket, rate]  of DB::Any
               rescue e
                    Log.warn(exception: e) {"Can't reach database for registering answer, check database file"}
               end

               # Render different templates based on the rate
               if promoters.includes?(rate)
                    render "./templates/template_promoters.ecr"
               elsif neutral.includes?(rate) 
                    render "./templates/template_neutral.ecr"  
               elsif detractors.includes?(rate) 
                    render "./templates/template_detractors.ecr" 
               end 
          else
               render "./templates/template_already_answered.ecr"
          end
     end

     post "/send-feedback" do |env|
          #Params from the form
          ticket = env.params.body["ticket"]
          feedback = env.params.body["feedback"]

          begin
               db.exec "UPDATE survey_responses SET feedback = ? WHERE ticket = ?", args: [feedback, ticket] of DB::Any
          rescue e
               Log.warn(exception: e) {"Customer feedback was not registered due to an unreachable database, check database file"}
          end

          render "./templates/template_after_feedback.ecr"
     end

     get "/send-feedback" do |env|
          #Just an empty route with a random response if the user hits reload in the browser after sending the feedback, avoid Kemal screen
          "Thank you for your feedback"
     end

     Kemal.run
end