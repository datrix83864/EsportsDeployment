# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**DO NOT** create a public GitHub issue for security vulnerabilities.

Instead:
1. Email: security@yourorg.edu
2. Use GitHub Security Advisories (private)
3. Expect response within 48 hours

## Security Features

- Automated secret scanning
- Dependency vulnerability alerts
- Code security analysis
- Branch protection

## What We Protect

This repository contains:
- Infrastructure-as-code (safe to be public)
- Configuration templates (no sensitive data)
- Deployment scripts (no credentials)
- Documentation (public information)

## What Users Must Protect

Users must secure their own:
- config.yaml (contains IPs, credentials)
- Ansible inventory files
- Terraform state files
- SSH keys and certificates
