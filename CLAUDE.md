# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the OpenProject Helm Charts repository, containing Kubernetes deployment configurations for the OpenProject project management software. The repository is structured as a self-contained Helm chart registry published via GitHub Pages using Helm's chart-releaser action.

## Key Commands

### Testing
- `bundle install` - Install Ruby dependencies for testing
- `bin/rspec` - Run the complete RSpec test suite for Helm templates
- `bin/rspec spec/charts/openproject/<specific_test>.rb` - Run individual test files

### Release Management
- `npm run changeset:version` - Update version numbers and generate changelog using changesets
- `bin/update_from_core_release <version>` - Update chart to track a new OpenProject core release
- `script/version` - Sync Chart.yaml version with package.json version

### Helm Operations
- `helm dependency update` - Update chart dependencies (required before testing)
- `helm template --debug optest . -f -` - Debug template rendering with custom values
- `helm lint charts/openproject` - Validate chart syntax and structure

## Architecture

### Chart Structure
The main chart is located in `charts/openproject/` and follows standard Helm conventions:
- `Chart.yaml` - Chart metadata, dependencies, and versioning
- `values.yaml` - Default configuration values
- `templates/` - Kubernetes resource templates with Go templating
- `templates/_helpers.tpl` - Shared template helpers and functions

### Key Components
The chart deploys OpenProject with these main components:
- **Web deployment** (`web-deployment.yaml`) - Main OpenProject web application
- **Worker deployment** (`worker-deployment.yaml`) - Background job processing
- **Cron deployment** (`cron-deployment.yaml`) - Scheduled tasks
- **Seeder job** (`seeder-job.yaml`) - Database initialization and seeding

### Dependencies
External dependencies managed via `Chart.yaml`:
- PostgreSQL (Bitnami chart) - Database backend
- Memcached (Bitnami chart) - Caching layer
- Common (Bitnami chart) - Shared utilities

### Testing Framework
Uses Ruby RSpec with custom `HelmTemplate` class (`spec/helm_template.rb`) to:
- Render Helm templates with test values
- Parse generated Kubernetes YAML
- Assert on resource configurations and relationships
- Test various configuration scenarios (S3, OIDC, scaling, etc.)

## Version Management

This repository uses a dual-versioning approach:
- **Chart version** (`Chart.yaml` version field) - Helm chart releases
- **App version** (`Chart.yaml` appVersion field) - OpenProject core version being deployed

The `bin/update_from_core_release` script automates updating to new OpenProject releases by:
1. Updating `appVersion` in Chart.yaml
2. Updating image tags in values.yaml
3. Creating appropriate changeset files for release tracking

## Release Process

Uses Changesets for automated release management:
- `.changeset/` directory contains pending changes
- `npm run changeset:version` processes changesets and updates versions
- Chart releases are automated via GitHub Actions with chart-releaser
- Charts are signed using GPG key (fingerprint in `Chart.yaml` annotations)

## Development Workflow

1. Make changes to chart templates or values
2. Update chart dependencies: `helm dependency update`
3. Run tests: `bin/rspec`
4. For core version updates: `bin/update_from_core_release <version>`
5. For chart changes: Create changeset files in `.changeset/`
6. Version and release: `npm run changeset:version`

## Key Files
- `charts/openproject/Chart.yaml:8` - App version (OpenProject core version)
- `charts/openproject/Chart.yaml:9` - Chart version  
- `package.json:5` - NPM package version (synced with chart version)
- `spec/helm_template.rb` - Test framework for Helm template rendering
- `bin/update_from_core_release` - Core version update automation