# Security Policy

agentsbox runs AI coding agents inside a rootless, ephemeral Podman container.
The isolation is real, but it is defense-in-depth, not a guarantee. This
document describes the reporting process and the security model so you can
judge what the sandbox does and does not protect.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting: **Security → Report a
vulnerability** on https://github.com/mrdaak/agentsbox. Do not open a public
issue for a security bug.

Please include:

- a description of the issue and its impact;
- steps to reproduce;
- the version or commit you tested;
- any relevant config (`.agentsbox/config.toml`, `~/.config/agentsbox.toml`),
  with secrets redacted.

This is a volunteer project with no service-level agreement. Reports are
acknowledged as time permits. Coordinated disclosure is appreciated, and
reporters are credited unless they ask to stay anonymous.

## Supported versions

Only the latest release and `main` receive fixes. While the project is
pre-1.0, security fixes are not backported to older tags — upgrade with
`agentsbox upgrade`.

## Security model

### What the sandbox protects against

- Accidental host writes and `rm -rf ~` mistakes.
- Dependency-install pollution of the host.
- The agent reading host files outside `/workspace` and the paths you
  explicitly mount.
- Privilege escalation to host root: rootless Podman has no root daemon, and
  the container runs with `--security-opt no-new-privileges:true`.

### Known limitations

These are current, documented limitations, not claims that the control is
present.

- **Network access is unrestricted.** No egress allowlist ships today, so an
  agent can send anything it can read to a remote host. Treat network access
  as a trust boundary.
- **Mounted agent config is writable.** Host agent-config directories are
  mounted read-write so your settings and sessions carry into the box. A
  sandboxed agent can therefore modify them, and those files are loaded
  unsandboxed the next time you run the agent on the host. Treat every mount
  you grant as a trust boundary.
- **The workspace is mounted read-write.** The project tree itself is inside
  the blast radius.
- **Kernel escapes.** The isolation holds only as long as the host kernel
  holds; a kernel or user-namespace 0-day defeats it.

Prompt injection is the primary threat: coding agents read untrusted text
(READMEs, package metadata, web pages, issue comments) by design. Sandboxing
reduces the blast radius of an injected instruction; it does not eliminate
risk.

If you enable `--a2a`, the listener is not yet authenticated. Do not enable it
on an untrusted network.

## Scope

**In scope** — report these:

- escaping the container to host code execution;
- reading host filesystem paths that are not mounted;
- privilege escalation inside the container or its user namespace;
- a secret leaking through the delivery mechanism (for example in
  `podman inspect` output, logs, or environment variables);
- bypassing a documented mount or precedence rule.

**Out of scope:**

- model behavior or prompt injection by itself;
- an agent doing what you asked with the tooling you granted it;
- bypassing a control that is not shipped (the limitations above are tracked
  work, not vulnerabilities);
- kernel or user-namespace 0-days — report those upstream.

## Roadmap

Network egress control and authentication for the A2A listener are tracked as
security priorities. See `CHANGELOG.md` for shipped changes.