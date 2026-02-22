# DA Backend (Rails Oracle Worker)

## Action Library

The backend includes a built-in action catalog under `ActionOracle::ActionLibrary`.
It seeds reusable off-chain web actions into the `actions` table:

- `discord_send_message`
- `slack_send_message`
- `http_get_json`

Install/update these definitions:

```bash
bin/rails action_oracle:install_library
```

or:

```bash
bin/rails db:seed
```

## Discord Sample Action

`discord_send_message` uses:

- URL: `https://discord.com/api/v10/channels/{{channel_id}}/messages`
- Header template: `Authorization: Bot {{credentials.discord_bot_token}}`
- Body template: `{ "content": "{{content}}" }`

Store the bot token off-chain in encrypted credentials table:

```bash
bin/rails runner "Credential.find_or_initialize_by(name: 'discord_bot_token').tap { |c| c.value = ENV.fetch('DISCORD_BOT_TOKEN'); c.save! }"
```

Trigger an action request:

```bash
curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "action_slug": "discord_send_message",
    "params_json": {
      "channel_id": "123456789012345678",
      "content": "hello from oracle"
    }
  }'
```

## Action Definition Fields

`Action` supports:

- `http_method`
- `url_template`
- `headers_template`
- `body_template` (new)
- `request_schema`
- `response_schema`

Template placeholders use `{{variable}}` and nested paths (for example `{{credentials.discord_bot_token}}`).
