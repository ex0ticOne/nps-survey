# nps-survey

A web service to implement Net Promoter Score surveys in your helpdesk/e-commerce.

I'm using the [Kemal](https://kemalcr.com/) web framework to deliver this, due to it's capacity to handle a large pool of requests, something that we need to account for when dealing with e-commerce/helpdesk scenarios.

This is my first project written in Crystal, a language that deserves more attention due to the Ruby-like syntax with superior performance. Give it a shot!

## How to use

Run `shards install` to populate a lib folder with the dependecies.

Go to `config.json` to setup your sender e-mail and other parameters.

Use the Crystal interpreter to run the web service on the desired port. To make it easier to manage the webservice on a Linux VM, create a systemd unit with the `crystal nps.cr` command and you will be able to turn on/off the service with a simple `systemctl start/stop`

To expose the web service to the public, you can `proxy_pass` the localhost:port address on `nginx`. When deploying with this way, pay attention to the `base_url` parameter that you put on `config.json`, because that parameter is going to be rendered on the answer link embedded in the survey e-mail.

You tipically will want to use this integrated with some helpdesk solution such as ZenDesk, FreshDesk, etc. Configure the `/send-survey` endpoint combined with the `base_url` to be triggered when a ticket is marked as resolved, or any other action that results in the end of customer journey. You will need to pass the `token` that you defined on `config.json` as a header on this endpoint, otherwise you will get a 403 response.

Set `live` to 0 for debug purposes and 1 for a production environment. When changing this, you need to restart the web service.

You are free to edit the ECR templates to suit your needs, but don't remove the tags embedded on the URLs, because the webservice relies on them to work properly (endpoints to answer the surveys).



In the future I want to make this project email provider agnostic (whole universe of email authentication) and database agnostic (not just SQLite3, but all SQL databases).

Enjoy!