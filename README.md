# Toolchain

A comprehensive development toolchain and environment setup for modern software development.

---

[![OpenSSF Scorecard][ossf-score-badge]][ossf-score-link]
[![Contiuos Integration][ci-badge]][ci-link]
[![Review][review-badge]][review-link]

[ossf-score-badge]: https://api.securityscorecards.dev/projects/github.com/anselmes/tooling/badge
[ossf-score-link]: https://securityscorecards.dev/viewer/?uri=github.com/anselmes/tooling
[ci-badge]: https://github.com/anselmes/tooling/actions/workflows/cicd.yml/badge.svg
[ci-link]: https://github.com/anselmes/tooling/actions/workflows/cicd.yml
[review-badge]: https://github.com/anselmes/tooling/actions/workflows/required/anselmes/cicd/.github/workflows/review.yml/badge.svg
[review-link]: https://github.com/anselmes/tooling/actions/workflows/required/anselmes/cicd/.github/workflows/review.yml

---

## Overview

This repository provides a complete development toolchain with:

- **Development Environment**: Preconfigured devcontainer with essential tools
- **Automation Scripts**: Installation, configuration, and utility scripts
- **Kubernetes Cluster Management**: Bootstrap scripts for Kind, Minikube, and K0s
- **Security Tools**: Certificate generation and security utilities
- **Hardware Tools**: ESP32 flashing and embedded development support
- **Quality Assurance**: Comprehensive linting, formatting, and security scanning

## Quick Start

### Using Dev Container

1. Open the repository in VS Code
2. When prompted, click "Reopen in Container"
3. The environment will be automatically configured

### Manual Setup

```bash
# Configure the environment
./scripts/configure.sh

# Install development tools
./scripts/install.sh
```

## Tools and Scripts

### Core Scripts

- [`scripts/install.sh`](scripts/install.sh) - Install development tools and binaries
- [`scripts/configure.sh`](scripts/configure.sh) - Configure development environment
- [`scripts/environment.sh`](scripts/environment.sh) - Environment variable setup
- [`scripts/utils.sh`](scripts/utils.sh) - Utility functions for other scripts

### Language-Specific Installers

- [`scripts/install/go.sh`](scripts/install/go.sh) - Go toolchain setup
- [`scripts/install/rust.sh`](scripts/install/rust.sh) - Rust toolchain setup
- [`scripts/install/swift.sh`](scripts/install/swift.sh) - Swift toolchain setup

### Cluster Management

- [`tools/bootstrap/bootstrap-kind`](tools/bootstrap/bootstrap-kind) - Bootstrap Kind cluster
- [`tools/bootstrap/bootstrap-minikube`](tools/bootstrap/bootstrap-minikube) - Bootstrap Minikube cluster
- [`tools/bootstrap/bootstrap-cluster`](tools/bootstrap/bootstrap-cluster) - Bootstrap K0s cluster

### Security and Certificates

- [`tools/gencert`](tools/gencert) - Generate SSL certificates with CFSSL
- [`scripts/gencert.sh`](scripts/gencert.sh) - Certificate generation utilities

### Hardware Development

- [`tools/flash-esp`](tools/flash-esp) - Flash ESP32 devices

### Utilities

- [`scripts/createvm.sh`](scripts/createvm.sh) - Create and manage VMs
- [`scripts/genswaggerui.sh`](scripts/genswaggerui.sh) - Generate Swagger UI documentation
- [`scripts/pull-images.sh`](scripts/pull-images.sh) - Pull Docker images

## Features

### Development Environment

- **Devcontainer**: Fully configured development environment with VS Code extensions
- **Shell Setup**: Oh My Zsh configuration with custom aliases and environment
- **Tool Installation**: Automated installation of development tools and binaries

### Kubernetes Support

- **Multiple Distributions**: Support for Kind, Minikube, and K0s clusters
- **Gateway API**: Automatic installation of Gateway API CRDs
- **Volume Snapshots**: External snapshotter support

### Security

- **Certificate Management**: Automated CA and intermediate certificate generation
- **Security Scanning**: Integrated security scanning with Trivy and other tools
- **Secrets Management**: Secure handling of sensitive data

### Quality Assurance

- **Linting**: Comprehensive linting with Trunk.io
- **Pre-commit Hooks**: Automated code quality checks
- **CI/CD**: GitHub Actions workflows for continuous integration

## Configuration

The toolchain uses YAML configuration files for various components:

- Tool versions and installation settings
- Cluster configurations
- VM specifications
- Security policies

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Security

For security concerns, please see [SECURITY.md](SECURITY.md).

## License

Copyright (c) [<schubert@anselm.es>](mailto:schubert@anselm.es)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
