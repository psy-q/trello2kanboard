## trello2kanboard

An attempt to read Trello boards via API and write them to Kanboard (also via API).

### Quick start

  - Install the required gems with bundler: `bundle install`
  - Copy config/trello2kanboard.yml.sampl to config/trello2kanboard.yml and add options for your various API keys as well as your Kanboard server address.
  - List the boards that you have access to on both systems: `bundle exec trello2kanboard list`
  - See a board you'd like to import? `bundle exec trello2kanboard import f00b4r123 22`. The first is your Trello board ID, the second the ID of the board to import to on Kanboard. trello2kanboard will create any columns it finds in Trello with the same names in Kanboard, if they don't exist already.


### Configuration

Here's a commented version of config/trello2kanboard.yml:

```yaml
---
trello:
  developer_public_key: # Your developer public key for Trello goes here
  member_token: # And this is for your member token

kanboard:
  host: somehost.example.com # The hostname (just the hostname!) of your Kanboard instance 
  path: jsonrpc.php  # The path to jsonrpc.php on the Kanboard server
  api_token: # Your Kanboard API token
  user_map:  # A map of Trello usernames and which Kanboard users they match
    trellouser1: kanboarduser1
    trellouser2: surprisingkanboarduser
```
