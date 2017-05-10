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


### Usage

You probably have to prefix all these commands with `bundle exec` if you installed the Ruby gems locally using bundler. So whenever it says `trello2kanboard list`, think `bundle exec trello2kanboard list`.


#### Listing boards on both systems

`trello2kanboard list` shows a list of Trello board your developer key/member token has access to, as well as a list of all existing projects in Kanboard. This is useful so you know the IDs to import to from/to on both sides. If you don't see a specific board in the Trello list, whoever is in charge of permissions for that Trello board needs to give your Trello user permission to see it.

#### Importing boards from Trello to Kanboard

`trello2kanboard import f00b4r1234 15` would import the Trello board with ID f00b4r1234 into the Kanboard project with ID 15. It will aggressively create any columns in Kanboard that exist in Trello. It will refuse to create Kanboard tasks that already exist, but other than that it does not much checking.

It imports tasks in exactly the same order as they are in Trello.
