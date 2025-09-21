# anh-stacks Repository Instructions

This repository contains Komodo configuration files for managing Docker Swarm stacks and encrypted secrets using SOPS (Secrets OPerationS). It provides infrastructure-as-code for deploying and managing containerized applications with Traefik as the load balancer.

**ALWAYS FOLLOW THESE INSTRUCTIONS FIRST.** Only use additional search or bash commands if you encounter information that contradicts or is missing from these instructions.

## Repository Structure

- `komodo/` - Komodo configuration files (TOML format)
  - `komodo/stacks/` - Stack definitions for services
  - `komodo/releases/` - Release configurations
- `stacks/` - Docker Compose files for individual stacks
- `swarm/` - Docker Compose files optimized for Docker Swarm
- `shared/` - Shared encrypted secrets and environment files
- `scripts/` - Shell scripts for secret management
- `.sops.yaml` - SOPS configuration for encryption

## Required Tools and Installation

**CRITICAL: Always install all required tools before attempting any operations.**

### Install Required Tools
```bash
# Install dependencies - NEVER CANCEL: Takes 1-2 minutes. Set timeout to 300+ seconds.
make install-tools
```

**Note:** The Makefile has a bug in the age download URL. If `make install-tools` fails, run these corrected commands:
```bash
# Install age (encryption tool)
curl -Lo age.tar.gz https://github.com/FiloSottile/age/releases/download/v1.1.1/age-v1.1.1-linux-amd64.tar.gz
tar -xzf age.tar.gz
sudo install age/age /usr/local/bin/
sudo install age/age-keygen /usr/local/bin/
rm -rf age age.tar.gz

# Install sops (secrets management)
curl -LO https://github.com/getsops/sops/releases/download/v3.10.2/sops-v3.10.2.linux.amd64
chmod +x sops-v3.10.2.linux.amd64
sudo mv sops-v3.10.2.linux.amd64 /usr/local/bin/sops
```

### Verify Installation
```bash
age --version     # Should show v1.1.1
sops --version    # Should show 3.10.2
python3 --version # Should be available (3.12+)
docker --version  # Should be available
```

## Working Effectively

### Bootstrap and Validation
**ALWAYS run these validation steps before making changes:**

```bash
# Validate TOML configuration files - Fast: ~1 second
make validate

# Lint shell scripts - Fast: ~1 second  
make lint

# Install required Python dependencies (if needed)
python3 -m pip install --quiet toml
```

**Timing:** Validation commands are fast (under 1 second each). Always run both before making changes.

### Secret Management

**CRITICAL:** This repository uses SOPS encryption with age keys. You CANNOT decrypt existing secrets without the proper age key.

#### Generate Age Key (for new setups)
```bash
# Generate new age key for encryption
make age-key
```

#### Encrypt New Secrets
```bash
# For shared secrets
make encrypt-secrets TARGET=shared

# For stack-specific secrets  
make encrypt-secrets TARGET=stackname
```

#### Decrypt Secrets (requires proper age key)
```bash
# Decrypt shared secrets
make decrypt-secrets TARGET=shared

# Decrypt stack secrets
make decrypt-secrets TARGET=traefik
```

**Note:** Decryption will fail unless you have the correct age key. This is expected behavior in a fresh clone.

## Docker Stack Deployment and Testing

### Test Docker Compose Configuration
```bash
# Validate compose file syntax
cd stacks/traefik
docker compose config

# Test with environment variables
cd swarm/traefik  
docker compose config
```

### Deploy Test Services
```bash
# Deploy a simple test service (no secrets required)
cd /tmp
cat > simple-test.yml << EOF
services:
  nginx:
    image: nginx:alpine
    ports:
      - "8080:80"
    networks:
      - test-net

networks:
  test-net:
    driver: bridge
EOF

# Deploy and test - NEVER CANCEL: Initial pull takes 2-3 minutes. Set timeout to 300+ seconds.
docker compose -f simple-test.yml up -d

# Verify deployment
docker compose -f simple-test.yml ps
curl -s http://localhost:8080 | head -5

# Clean up
docker compose -f simple-test.yml down
```

## Validation Scenarios

**ALWAYS run these complete scenarios after making changes:**

### 1. Configuration Validation Workflow
```bash
# Full validation pipeline (fast - under 5 seconds total)
make validate && make lint
echo "✓ All validations passed"
```

### 2. Docker Stack Validation Workflow
```bash
# Test stack configuration without deployment
cd stacks/traefik
docker compose config > /dev/null && echo "✓ Traefik stack config valid"

cd ../../swarm/traefik  
docker compose config > /dev/null && echo "✓ Swarm traefik config valid"
```

### 3. Secret Management Workflow (if you have age keys)
```bash
# Test secret decryption (will fail without proper keys - this is expected)
./scripts/decrypt-secrets.sh shared 2>/dev/null || echo "✓ Secret decryption requires proper age key (expected)"
```

## Development Workflow

### Before Making Changes
1. **ALWAYS** run `make validate && make lint` 
2. Verify Docker Compose syntax with `docker compose config`
3. Test any new stack configurations

### After Making Changes
1. **ALWAYS** run `make validate && make lint` before committing
2. Test Docker Compose configurations: `docker compose config`
3. Deploy and test simple services if changing compose files
4. **ALWAYS** run complete validation scenarios

### Common Tasks

#### Adding a New Stack
1. Create TOML config in `komodo/stacks/`
2. Create Docker Compose file in `stacks/` and/or `swarm/`
3. Add any required secrets to `shared/` or stack directory
4. Test with `docker compose config`
5. Validate with `make validate && make lint`

#### Modifying Existing Stacks
1. Update TOML or Docker Compose files
2. **ALWAYS** test configuration: `docker compose config`
3. **ALWAYS** validate: `make validate && make lint`
4. Deploy test service to verify functionality

#### Managing Secrets
1. Create unencrypted files (`.secret.yaml` or `.env`)
2. Use `make encrypt-secrets TARGET=stackname` to encrypt
3. Encrypted files use `.sops.yaml` or `.sop.env` extensions
4. **NEVER** commit unencrypted secret files

## Key Files and Locations

### Frequently Modified Files
- `komodo/stacks/*.toml` - Stack configurations
- `komodo/releases/*.toml` - Release definitions  
- `stacks/*/docker-compose.yml` - Stack compose files
- `swarm/*/docker-compose.yml` - Swarm compose files
- `shared/*.sops.yaml` - Shared encrypted secrets
- `shared/*.sop.env` - Shared encrypted environment files

### Important Configuration Files
- `.sops.yaml` - SOPS encryption configuration
- `Makefile` - Build and validation targets
- `.github/workflows/ci.yml` - CI pipeline
- `scripts/decrypt-secrets.sh` - Secret decryption script

## Troubleshooting

### Build/Validation Failures
- **TOML syntax errors:** Check `komodo/**/*.toml` files for syntax
- **Shell script issues:** Run `shellcheck scripts/*.sh` for details
- **Docker Compose errors:** Use `docker compose config` to validate

### Secret Management Issues
- **Decryption failures:** Normal without proper age key
- **Encryption failures:** Ensure age key exists and SOPS is configured
- **Missing tools:** Run corrected install commands if `make install-tools` fails

### Docker Issues  
- **Image pull failures:** Check network connectivity
- **Port conflicts:** Ensure ports 8080, 80, 443 are available for testing
- **Permission issues:** Ensure Docker daemon is running and accessible

## Commands Reference

### Fast Commands (< 5 seconds)
```bash
make validate          # Validate TOML files
make lint             # Lint shell scripts  
docker compose config # Validate compose syntax
```

### Medium Commands (5-60 seconds)
```bash
make install-tools    # Install age and sops (30-60 seconds with network)
make age-key         # Generate new age key
```

### Long Commands (1-5 minutes)
```bash
docker compose up -d  # NEVER CANCEL: First run downloads images (2-3 minutes)
```

**CRITICAL TIMING:** Always set timeouts of 300+ seconds for Docker operations that download images. Never cancel long-running operations.

## CI/CD Integration

The repository includes GitHub Actions workflow (`.github/workflows/ci.yml`) that:
- Validates TOML syntax
- Lints shell scripts  
- Tests secret decryption (requires AGE_KEY secret)

**Always ensure your changes pass `make validate && make lint` before pushing.**