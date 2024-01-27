NIX_FILES = $(shell find . -name '*.nix' -type f)

.PHONY: all build run rebuild

all: help

help:
	@echo Usage
	@echo
	@echo "  make setup                    install Nix and dependencies (Fedora only at the moment)"
	@echo "  make build-image              build qemu image on host"
	@echo "  make build                    rebuild system from inside guest"
	@echo "  make flash DEVICE=/dev/sda    flash raspberry pi"
	@echo "  make run                      run mediaserver x86 image locally for testing"
	@echo "  make ssh                      SSH into running local mediaserver kvm"

build-image:
	./build-image.sh

build:
	./build.sh

run:
	./run.sh

flash:
ifndef DEVICE
	$(error please set a device, e.g. "make flash DEVICE=/dev/sda")
endif
	./flash.sh $(DEVICE)

setup:
	./setup.sh

ssh:
	ssh-keygen -R "[localhost]:2223"
	ssh -o StrictHostKeychecking=no -p 2223 mediaserver@localhost
