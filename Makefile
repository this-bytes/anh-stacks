SHELL := /bin/bash

.PHONY: validate lint decrypt-secrets install-tools age-key encrypt-secrets

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