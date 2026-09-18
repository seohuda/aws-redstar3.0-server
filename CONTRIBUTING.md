# Contributing

Contributions that improve portability, documentation, infrastructure safety,
VM lifecycle automation, or troubleshooting are welcome.

## Before you start

1. Fork the repository and create a focused branch.
2. Keep changes small and scoped to one purpose.
3. Do not commit Red Star OS media, VM images, Terraform state, generated SSH
   keys, credentials, or other private files.
4. Keep both `README.md` and `README.en.md` in sync when changing user-facing
   setup instructions.

## Local checks

For Terraform changes:

```bash
terraform -chdir=infra fmt -check
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
```

For shell changes:

```bash
bash -n infra/user_data.sh
find scripts -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
```

If ShellCheck is installed, running it against the modified scripts is also
recommended.

## Pull requests

A pull request should explain:

- what changed
- why the change is needed
- how it was tested
- whether infrastructure, networking, security, or installation behavior
  changed

Do not include copyrighted installation media or sensitive data in test
artifacts, screenshots, logs, or pull request comments.

## Documentation

When behavior changes, update the relevant documents under `docs/` and keep
the Korean and English README files aligned.
