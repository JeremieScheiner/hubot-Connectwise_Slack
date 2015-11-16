# hubot-hubot-connectwise_slack

This is a [Hubot](http://hubot.github.com/) script for connecting [ConnectWise](http://www.connectwise.com) with [Slack](https://slack.com). This scrript currently listens for ticket numbers in the channels you have invited the bot to and post a link to the ticket. It will also allow you to watch or ignore ticket so that as tickets are updated, you will be notified via direct message.

##Getting Started

#### Creating a new bot
- `npm install -g hubot coffee-script yo generator-hubot`
- `mkdir -p /path/to/hubot`
- `cd /path/to/hubot`
- `yo hubot`
- `npm install hubot-Connectwise_Slack hubot-slack hubot-redis-brain --save`
- Then add **hubot-connectwise_slack** to your `external-scripts.json`:

```json
["hubot-connectwise_slack"]
```
- Initialize git and name your initial commit
- Check out the [hubot docs](https://github.com/github/hubot/tree/master/docs) for further instructions on building and deploying your bot

## Environment Variables
- `HUBOT_CW_URL=my.connectwiseurl.com`
- `HUBOT_CW_API_URL=my.connectwiseurl.com`
- `HUBOT_CW_COMPANYID=companyid`
- `HUBOT_CW_APIPUBLIC=APIPublicKey`
- `HUBOT_CW_APISECRECT=APIPrivateKey`
- `HUBOT_SLACK_TOKEN=HubotSlackToken`

## Sample Interaction
```
user1>> I think I need help with 27483
hubot>> Ticket Link: 27483
```
```
user1>> watch ticket 12345
hubot>> You are not watching ticket 12345
```
```
user1>> ignore ticket 12345
hubot>> You are now ignoring ticket 12345
```

## Copyright

Copyright &copy; Web Teks, Inc. MIT License; see License for further details.
