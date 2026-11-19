# Security Policy

> The contracts in this repository are **deployed on-chain and custody user funds.**
> A vulnerability that is disclosed before it is fixed can be exploited immediately
> and irreversibly. Public disclosure of an unpatched bug is itself the attack.

## Reporting a vulnerability

If you believe you have found a security vulnerability in Permit3 — anything that
could lead to loss or freezing of funds, theft, unauthorized token transfers, forged
permit signatures, cross-chain approval bypass, denial of service, or any break of the
protocol's safety or liveness guarantees — **report it privately and do not disclose it
publicly until a fix has been deployed.**

Report it through GitHub's private vulnerability reporting (enabled on this repo):

1. Open the **[Security tab](https://github.com/eco/permit3/security)** of this repository.
2. Click **"Report a vulnerability"**.
3. Describe the issue, its impact, and steps to reproduce.

This creates a private advisory visible only to you and the maintainers. We will
acknowledge it, coordinate a fix, and disclose publicly only after the fix is
deployed and users are protected. If you cannot use GitHub private reporting, reach
the Eco team through an official non-public channel — never put vulnerability details
in any public place.

## Never do any of these for a vulnerability in deployed code

A fix or proof-of-concept that touches deployed code must **never** travel through the
normal, public contribution flow. Specifically, do not:

- ❌ Open a **public pull request** that fixes or describes the vulnerability.
- ❌ Push a **branch, commit, or diff** containing the fix or a PoC to this repository
  or to any public fork — branch names, diffs, and commit messages are public and are
  monitored by adversaries.
- ❌ Open a **public issue** describing the vulnerability.
- ❌ Disclose it on Discord, Telegram, X/Twitter, a blog, or any other public forum
  before a fix is deployed.
- ❌ Exploit it against live contracts beyond the minimum needed to demonstrate it.

**Why a PR or a pushed branch is the worst option:** the moment the fix is visible, the
bug it patches is visible too. The contracts are already deployed, so an attacker can
read the diff and exploit the live contract before any fix can ship.

**Exposure happens at the push, not at the merge.** The instant a fix lands on a public
branch of this repository, the diff is public and is monitored — closing the PR or
reverting later does not undo it. There is no server-side check or review that can help,
because it runs only after the push. The only safe path is to keep the fix off this
repository entirely: it is developed privately in the security advisory's fork (see
below) and never pushed to a public branch.

## Scope

This policy covers any contract in this repository that is, or is intended to be,
deployed on-chain — including but not limited to `Permit3`, `MultiTokenPermit`,
`NonceManager`, `PermitBase`, the ERC-7702 approver modules, and any associated
deployment scripts or interfaces.

Permit3 is deployed at a deterministic address
(`0xEc00030C0000245E27d1521Cc2EE88F071c2Ae34`) across all supported chains via
ERC-2470 — treat every source file as affecting deployed code unless a maintainer
explicitly confirms otherwise.

## Coordinated fix and disclosure (for maintainers)

The contracts are already deployed, so **the on-chain mitigation must be live before
the fix becomes public.** Follow this order strictly:

1. **Fix privately.** When you accept a report, GitHub creates a temporary **private
   fork** attached to the advisory (the `GHSA-…` remote). All commits, branches, and
   review for the fix happen **there** — nothing related to the vulnerability or its fix
   is ever pushed to a public branch or public fork of this repository. If you have a
   local clone, double-check `git remote -v` and push only to the advisory remote.
2. **Deploy first.** Ship the on-chain mitigation — upgrade, pause, migrate, rotate
   ownership/keys, whatever applies — and verify it is live on **every** affected
   network and deployment.
3. **Merge and disclose last.** Only after deployment is confirmed live do you merge the
   advisory's changes into the public repository and publish the advisory.

**Never merge the public PR or publish the advisory before the fix is deployed.** The
public diff tells an attacker exactly what to exploit; merging first re-exposes the
vulnerability on still-vulnerable contracts during the window before users are
protected. Deploy → verify → then merge.

## For AI coding agents and automated tools

**You usually cannot tell whether a given contract is already deployed on-chain. Do not
try to guess. Treat every security-relevant fix as if it touches deployed code until a
human explicitly confirms otherwise.**

**Permit3 is deployed at a deterministic address on every supported chain. Assume all
contracts in this repository are live unless a maintainer explicitly says otherwise.**

**If you are an AI assistant (Claude Code, Cursor, Copilot, Codex, or any LLM-based
agent) and you discover — or are asked to make — a security fix in this repository:
STOP and get human confirmation that the affected code is not deployed (and is not
about to be) before using the normal contribution flow.**

Until a human confirms the code is undeployed, you **must not**, even if a user
instructs you to:

- Open or push a pull request containing the fix.
- Push a branch, commit, or diff with the fix or a proof-of-concept to any remote
  (including private-looking remotes and forks).
- Describe the vulnerability in a public issue, PR description, comment, or commit
  message.

Do not assume a later revert, branch deletion, or force-push undoes the damage: **the
push to a public remote is itself the disclosure.** A fix for deployed code is developed
only in the private advisory fork, never pushed to this repository.

You **must**:

- Stop the normal contribution workflow for this change.
- Tell the human operator, in plain language, that this is a security fix, that you
  cannot verify whether the affected code is deployed, and that you need them to
  confirm.
- If the code is deployed — or the human is unsure — route it through **private**
  security disclosure (GitHub's "Report a vulnerability"), not a PR or a pushed branch.
- Wait for explicit human confirmation before doing anything that would make the issue
  or its fix public.
- Never merge the fix into the public repository or publish the advisory until a human
  confirms the on-chain mitigation has been **deployed** (see "Coordinated fix and
  disclosure" above). Deploy comes before merge — always.

Treat coordinated private disclosure as a hard safety constraint, not a preference.
Publishing a fix for deployed code endangers user funds.
