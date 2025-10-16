# Contributing to Esports LAN Infrastructure

Thank you for your interest in contributing! This project aims to help esports organizations deploy reliable, scalable tournament infrastructure.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue with:

- A clear, descriptive title
- Steps to reproduce the problem
- Expected behavior vs actual behavior
- Your environment (Proxmox version, network setup, etc.)
- Relevant logs or error messages

### Suggesting Features

We welcome feature suggestions! Please create an issue with:

- A clear description of the feature
- Why this feature would be useful
- How it might work (if you have ideas)
- Any relevant examples from other projects

### Pull Requests

1. **Fork the repository** and create a branch from `develop`
2. **Make your changes** following our coding standards
3. **Test your changes** thoroughly
4. **Update documentation** as needed
5. **Submit a pull request** to the `develop` branch

## Development Guidelines

### Branch Strategy

- `main`: Stable releases only
- `develop`: Active development
- `feature/*`: New features
- `bugfix/*`: Bug fixes
- `hotfix/*`: Urgent fixes for main

### Coding Standards

#### Shell Scripts

```bash
#!/bin/bash
# Use bash strict mode
set -euo pipefail

# Include header comments
# Purpose: Brief description
# Usage: How to run the script

# Use meaningful variable names
organization_name="Your Org"

# Comment complex logic
# This loop iterates through all VMs
for vm in "${vms[@]}"; do
    process_vm "$vm"
done
```

#### Python Scripts

```python
"""Module docstring describing purpose."""

# Follow PEP 8
# Use type hints when possible
def validate_config(config_path: str) -> bool:
    """Validate configuration file.
    
    Args:
        config_path: Path to configuration file
        
    Returns:
        True if valid, False otherwise
    """
    pass
```

#### Ansible Playbooks

```yaml
---
# Use descriptive task names
- name: Install and configure iPXE server
  hosts: ipxe_servers
  become: true
  
  tasks:
    - name: Install TFTP server
      apt:
        name: tftpd-hpa
        state: present
      tags: packages
```

#### YAML Configuration

```yaml
# Use 2-space indentation
# Add comments for complex options
network:
  # Subnet for client machines
  subnet: "192.168.1.0/24"
```

### Documentation Standards

- Use clear, simple language (ELI5 approach)
- Include examples for complex concepts
- Add screenshots for UI-based instructions
- Test all commands and procedures
- Update table of contents when adding sections

### Testing Requirements

All contributions should include appropriate tests:

- **Scripts**: Add test cases in `testing/unit/`
- **Playbooks**: Test with `ansible-lint` and in a VM
- **Documentation**: Verify all links and commands work
- **Configuration changes**: Update `config.example.yaml` and validation schema

### Commit Message Format

Use conventional commits format:

```
type(scope): brief description

Longer description if needed

Fixes #123
```

Types:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:

```
feat(lancache): add support for EA Origin games

fix(ipxe): resolve DHCP timeout on boot

docs(fileserver): add roaming profile troubleshooting guide
```

## Project Structure

Please familiarize yourself with our directory structure (see `STRUCTURE.md`) before contributing.

Key areas:

- `ansible/`: Configuration management
- `terraform/`: Infrastructure provisioning
- `scripts/`: Utility scripts
- `docs/`: User-facing documentation
- `.github/workflows/`: CI/CD pipelines

## Development Environment Setup

### Prerequisites

```bash
# Install required tools
sudo apt install git python3 python3-pip ansible shellcheck

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Clone the repository
git clone https://github.com/your-org/esports-lan-infrastructure.git
cd esports-lan-infrastructure

# Install Python dependencies
pip3 install -r requirements.txt
```

### Local Testing

```bash
# Validate configuration
python scripts/validate_config.py config.example.yaml

# Test shell scripts
shellcheck scripts/*.sh

# Test Ansible playbooks
cd ansible
ansible-lint
ansible-playbook --syntax-check playbooks/deploy_all.yml

# Test Terraform
cd terraform
terraform init
terraform validate
```

## Getting Help

- **Documentation**: Check the `docs/` directory first
- **GitHub Issues**: Search existing issues
- **Discussions**: Use GitHub Discussions for questions
- **Discord**: Join our community Discord (link in README)

## Recognition

Contributors will be recognized in:

- `CONTRIBUTORS.md` file
- Release notes for significant contributions
- Project documentation for major features

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on what's best for the community
- Show empathy towards other contributors

### Unacceptable Behavior

- Harassment or discriminatory language
- Personal attacks or trolling
- Publishing others' private information
- Unprofessional conduct

### Enforcement

Violations may result in:

1. Warning
2. Temporary ban from project
3. Permanent ban from project

Report issues to: <esports-lan-conduct@example.com>

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Feel free to open an issue with the `question` label or reach out to the maintainers.

Thank you for contributing to making high school esports better! 🎮
