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

Some agents accept a structured `DataPart` (e.g. an op like `put`, `search`, or `delete`). Two steps.

**1. Preflight — confirm the target supports the op.** Read its agent card (this `curl` is the *only* place `curl` is used; it is not how you send the op):

```bash
curl -s http://<agent-name>:4096/.well-known/agent-card.json
```

**2. Send the op as a DataPart via `send-message --data`.** Do not build the HTTP request yourself or hand-write JSON with embedded content — `send-message` builds the envelope and escapes safely. For a fixed payload, pass JSON inline:

```bash
send-message --data '{"op":"search","query":"auth"}' notes
```

When the payload embeds file contents (e.g. a `put` whose `body` is a whole document), build the `--data` JSON with `jq --rawfile` so the file is loaded verbatim and escaped for you — never inline a multi-line file as a string literal:

```bash
DATA="$(jq -n --rawfile body docs/note.md '{op:"put",type:"reference",title:"Note",body:$body}')"
send-message --data "$DATA" notes "persisting docs/note.md"
```

The agent card's schema names which fields the caller supplies (e.g. `body`, `source`, `title`) versus which the server derives (e.g. `project`, `id`). For `body`, send the verbatim file contents — do not author or summarize it.

**Completion criterion:** the op is listed in the agent card *and* the reply reflects the op's success (e.g. an ack/confirmation object, not an error).

## Errors

`could not reach agent '<name>'` means the container is not running with `--a2a`, or the alias is wrong. Tell the user to start it with `agentsbox enter --a2a` and confirm the alias. Do not retry blindly.
