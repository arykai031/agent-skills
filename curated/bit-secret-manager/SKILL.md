---
name: bit-secret-manager
description: Use for API keys, Tokens, credentials, credential configuration, .env requests, tool authentication, or Bitwarden Secrets Manager access. Route secret consumption through bit-secret-manager execution-time profiles; guide non-secret mappings and private initialization when a profile is missing. Never accept secret values in chat.
---

# Bit Secret Manager

`bit-secret-manager` is the execution boundary for local secrets. Bitwarden
Secrets Manager is the only authority for values; local TOML stores only Secret
IDs, expected keys, and target environment names.

## Route

1. Identify the executable and the environment variables it needs. Treat Secret
   IDs, expected keys, profile names, and environment names as non-secret
   metadata. The step is complete when every required variable has one mapping.
2. Find an existing profile in
   `~/.config/bit-secret-manager/config.toml`. Keep the directory `0700` and the
   configuration `0600`. When the configuration is absent, do not create it by
   hand: have the human run `bit-secret-manager init` and enter the non-secret
   mappings in its first-use prompts. When a valid configuration exists but a
   mapping is missing, stop execution and ask the user to create or select the
   BWS Secret and approve adding only its ID, expected key, profile, and target
   environment name. The step is complete when one profile covers the command
   atomically.
3. Require `bit-secret-manager doctor` to pass. Interactive `init` creates the
   first configuration when absent; with an existing configuration it only
   initializes or rotates the Token without rewriting mappings. A trusted local
   pipe may use `init --token-stdin` only after a valid configuration exists.
   Keep Machine Account Tokens out of chat, argv, command output, logs, notes,
   and shell-sourceable files. If a value is pasted in chat, do not repeat or
   persist it; stop and direct the user to rotate it.
4. Execute an argv through the profile:

   ```bash
   bit-secret-manager run PROFILE -- executable arg1 arg2
   ```

   Pass arguments separately. Completion means the real operation ran through
   the manager and its exit status was observed.

## Boundaries

- Convert `.env`, exported-variable, plaintext credential-file, direct `bws`,
  and secret-in-argument requests into execution-time `run` usage. When a tool
  cannot consume inherited environment variables, stop and report that it is
  incompatible with this contract.
- Use a separate read-only BWS Machine Account for each machine. Do not claim
  that this removes the accepted risk of a shared high-privilege GitHub PAT.
- `doctor` may report profile and expected-key names with status. Secret values,
  BWS output, and Token material remain undisclosed.
- The manager installs separately from this skill. Installation never installs
  `bws`, changes shell startup, or creates credentials.
- The executable is `~/.local/bin/bit-secret-manager`; files under
  `~/.local/lib/bit-secret-manager` are implementation files, not commands.

## GitHub

Run `gh api user`, `gh auth setup-git`, and Git operations through the GitHub
profile. `gh auth setup-git` may persist the Git credential helper; keep PATs
out of `gh auth login` and `hosts.yml`.
