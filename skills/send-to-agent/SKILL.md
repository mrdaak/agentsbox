---
name: send-to-agent
description: Use when the user asks to ask, query, consult, or get knowledge from ANOTHER project's or repo's agent (e.g. "ask the repo2 agent how it does X", "check with the api-service agent", "find out from the frontend agent"). Sends an A2A message to that agent and returns its answer.
---

# Talking to another agent (A2A)

Agents running in other agentsbox containers are reachable over the shared
`agentsbox-net` network. To ask one a question, run the `send-message` command:

```bash
send-message <agent-name> "<question>"
```

- `<agent-name>` is the other container's A2A alias — by default the basename of
  that project's directory (e.g. a project at `~/src/repo2` answers as `repo2`),
  or whatever was passed to `agentsbox enter --a2a --name <name>`.
- The command prints the other agent's answer to stdout. Relay that answer back
  to the user; quote the parts that matter rather than dumping it verbatim.

## Example

User: "Ask the repo2 agent how it authenticates API calls."

```bash
send-message repo2 "How do you authenticate API calls? Point me at the relevant files."
```

Then summarize the response for the user.

## Notes

- Ask one clear, self-contained question per call — the other agent has no
  memory of your conversation and only sees the text you send.
- If you get `could not reach agent '<name>'`, that container isn't running with
  A2A enabled, or the name is wrong. Tell the user to start it with
  `agentsbox enter --a2a` (and confirm the alias). Don't retry blindly.
- The other agent answers using its own `/workspace`, so it's the authority on
  *its* codebase — good for cross-repo questions, not for things in this repo.
