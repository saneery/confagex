# Confagex

Elixir [Confage](https://github.com/saneery/confage) client

## Installation

```elixir
def deps do
  [
    {:confagex, git: "https://github.com/saneery/confagex.git"}}
  ]
end
```

## Configuration
```elixir
config :confagex,
  app_name: "confagex", # application name in confage
  subscribe: true # subscribe for updates, default false
```
