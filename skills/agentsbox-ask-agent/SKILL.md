---
name: agentsbox-ask-agent
description: Use for cross-repo questions. Relay a message to another agentsbox agent and return its answer.
---

# Cross-repo questions

## Simple question

Run:

```bash
send-message <agent-name> "<question>"
```

`<agent-name>` is the other container's A2A alias: the basename of its project directory by default, or the value passed to `agentsbox enter --a2a --name <name>`.

**Completion criterion:** the response is printed. Relay it to the user, quoting the parts that matter; do not dump it verbatim.

## Structured operation

Before sending a `DataPart` for an op like `put`, `search`, or `delete`, confirm the target supports it:

```bash
curl -s http://<agent-name>:4096/.well-known/agent-card.json
```

**Completion criterion:** the op is listed in the agent card. Only then send the `DataPart`.

## Errors

`could not reach agent '<name>'` means the container is not running with `--a2a`, or the alias is wrong. Tell the user to start it with `agentsbox enter --a2a` and confirm the alias. Do not retry blindly.
