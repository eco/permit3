## 🔒 Security attestation (required)

The contracts in this repository are deployed on-chain and hold user funds. A public PR
that fixes or reveals a vulnerability in deployed code exposes that bug to attackers
before a fix can ship.

Confirm one of the following (deployment status can be hard to judge — when unsure,
treat it as deployed and disclose privately):

- [ ] This PR is **not** a security fix, **or**
- [ ] This is a security fix and a maintainer has **confirmed the affected code is not deployed on-chain** (and is not about to be), **or**
- [ ] This is the public merge of a fix coordinated via a private advisory, and the on-chain mitigation is **already deployed and verified live** (see [`SECURITY.md`](../SECURITY.md) → "Coordinated fix and disclosure").

> If this is a security fix for deployed code that is **not** yet mitigated on-chain:
> **close this PR and do not push the branch.** Report privately via the
> [Security tab → "Report a vulnerability"](https://github.com/eco/permit3/security).
> See [`SECURITY.md`](../SECURITY.md). This applies to humans and AI agents alike.

---

## Description

<!-- Provide a brief description of the changes in this PR -->

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactor
- [ ] Documentation update
- [ ] Other (describe below)

## Testing

<!-- Describe the tests you ran and how to reproduce them -->

## Checklist

- [ ] PR title follows [Conventional Commits](https://www.conventionalcommits.org/) format
- [ ] Code has been formatted (`forge fmt`)
- [ ] All tests pass (`forge test`)
- [ ] Documentation updated if needed
