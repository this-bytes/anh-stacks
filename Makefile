SHELL := /bin/bash

ANSIBLE_DIR := ansible
INVENTORY := $(ANSIBLE_DIR)/inventories/homelab/hosts.yml

.PHONY: validate lint decrypt-secrets install-tools age-key encrypt-secrets site storage storage-check storage-host storage-check-host ping cleanup-seaweedfs cleanup-seaweedfs-host bootstrap bootstrap-cluster-only bootstrap-secrets-only

validate:
	python3 -m pip install --quiet toml
	python3 -c 'import toml,glob; [toml.load(open(f)) for f in glob.glob("komodo/**/*.toml", recursive=True)]'

lint:
	shellcheck scripts/*.sh

install-tools:
	# Install age
	if ! command -v age >/dev/null 2>&1; then \
		curl -Lo age.tar.gz https://github.com/FiloSottile/age/releases/latest/download/age-v1.1.1-linux-amd64.tar.gz && \
		tar -xzf age.tar.gz && \
		sudo install age/age /usr/local/bin/ && \
		sudo install age/age-keygen /usr/local/bin/ && \
		rm -rf age age.tar.gz; \
	else \
		echo "age already installed"; \
	fi
	# Install sops
	if ! command -v sops >/dev/null 2>&1; then \
		curl -LO https://github.com/getsops/sops/releases/download/v3.10.2/sops-v3.10.2.linux.amd64 && \
		chmod +x sops-v3.10.2.linux.amd64 && \
		sudo mv sops-v3.10.2.linux.amd64 /usr/local/bin/sops; \
	else \
		echo "sops already installed"; \
	fi

age-key:
	if [ ! -f age.key ]; then \
		age-keygen -o age.key; \
		chmod 600 age.key; \
		echo "export SOPS_AGE_KEY_FILE=age.key" >> .env; \
		echo "\nAge key generated at age.key. Add the public key to your .sops.yaml."; \
		age-keygen -y age.key; \
	else \
		echo "Age key already exists at ./age.key"; \
	fi

encrypt-secrets:
	@TARGET=$${TARGET}; \
	if [ -z "$$TARGET" ]; then \
		echo "Usage: make encrypt-secrets TARGET=stackname|shared"; exit 1; \
	fi; \
	if [ "$$TARGET" = "shared" ]; then \
		DIR=shared; \
	else \
		DIR=stacks/$$TARGET; \
	fi; \
	found=0; \
	for f in $$(find $$DIR -maxdepth 1 -type f \( -name '*.secret.yaml' -o -name '*.env' \)); do \
		case "$$f" in \
			*.secret.yaml) encfile="$${f%.secret.yaml}.secret.sops.yaml" ;; \
			*.env) encfile="$${f%.env}.sop.env" ;; \
			*) continue ;; \
		esac; \
		if [ ! -f "$$encfile" ] && [ -s "$$f" ]; then \
			found=1; \
			case "$$f" in \
				*.secret.yaml) sops -e --input-type yaml --output-type yaml "$$f" > "$$encfile" && rm -f "$$f" ;; \
				*.env) sops -e --input-type env --output-type env "$$f" > "$$encfile" && rm -f "$$f" ;; \
			esac; \
		fi; \
	done; \
	if [ $$found -eq 0 ]; then \
		echo "No unencrypted files to encrypt."; \
	fi

decrypt-secrets:
	@TARGET=$${TARGET}; \
	if [ -z "$$TARGET" ]; then \
		echo "Usage: make decrypt-secrets TARGET=stackname|shared"; exit 1; \
	fi; \
	./scripts/decrypt-secrets.sh $$TARGET

# Ansible convenience targets (no -Kk; relies on SSH key auth)
site:
	cd $(ANSIBLE_DIR) && ansible-playbook site.yml

storage:
	cd $(ANSIBLE_DIR) && ansible-playbook storage.yml

storage-check:
	# Check NFS mounts across managers
	cd $(ANSIBLE_DIR) && ansible managers -b -m shell -a 'mount | grep -E " nfs | type nfs|:/srv/nfs/" || true'

storage-host:
	@HOST=$${HOST}; \
	if [ -z "$$HOST" ]; then echo "Usage: make storage-host HOST=<inventory-name|ip>"; exit 1; fi; \
	cd $(ANSIBLE_DIR) && ansible-playbook storage.yml -l $$HOST

storage-check-host:
	@HOST=$${HOST}; \
	if [ -z "$$HOST" ]; then echo "Usage: make storage-check-host HOST=<inventory-name|ip>"; exit 1; fi; \
	# Check NFS mounts on a single host
	cd $(ANSIBLE_DIR) && ansible $$HOST -b -m shell -a 'mount | grep -E " nfs | type nfs|:/srv/nfs/" || true'

cleanup-seaweedfs:
	# Ad-hoc cleanup of SeaweedFS services, mounts, binaries, and data on all managers
	cd $(ANSIBLE_DIR) && ansible-playbook cleanup-seaweedfs.yml

cleanup-seaweedfs-host:
	@HOST=$${HOST}; \
	if [ -z "$$HOST" ]; then echo "Usage: make cleanup-seaweedfs-host HOST=<inventory-name|ip>"; exit 1; fi; \
	cd $(ANSIBLE_DIR) && ansible-playbook cleanup-seaweedfs.yml -l $$HOST

ping:
	@HOST=$${HOST:-managers}; \
	cd $(ANSIBLE_DIR) && ansible $$HOST -m ping

# Bootstrap targets for complete swarm setup
bootstrap:
	@echo "Bootstrapping Docker Swarm cluster with NFS and secrets..."
	./scripts/bootstrap-swarm.sh --all

bootstrap-cluster-only:
	@echo "Bootstrapping Docker Swarm cluster only..."
	./scripts/bootstrap-swarm.sh

bootstrap-secrets-only:
	@echo "Setting up secrets only..."
	./scripts/bootstrap-swarm.sh --generate-key --encrypt-secrets