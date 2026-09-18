# Security Policy

## Scope

This policy covers the Terraform configuration, shell scripts, libvirt
configuration, Nginx configuration, and documentation maintained in this
repository.

Red Star OS itself, installation media, AWS, Terraform, QEMU/KVM, libvirt,
Nginx, and other third-party projects are outside this repository's security
scope.

## Reporting a vulnerability

Please do not publish credentials, private keys, tokens, exploit details, or
other sensitive information in a public issue.

If GitHub private vulnerability reporting is available for this repository,
use the repository's Security tab to submit a private report.

If private reporting is unavailable, open a minimal public issue that only
states that you found a potential security issue and request a private contact
method. Do not include reproduction details or secrets in that issue.

## Sensitive data

Never attach or commit:

- AWS access keys or session tokens
- Terraform state containing sensitive values
- SSH private keys
- Red Star OS ISO images
- VM disk images
- passwords, activation data, or other credentials
- logs containing public IPs, secrets, or personally identifying data unless
  they have been sanitized

## Supported version

Security fixes are applied to the latest revision of the `main` branch.
