# Gitea Action runner QEMU KVM Solution

## Features

- Run your Gitea Actions workflow in ephemeral virtual machine.
- Isolate gitea act runner `.runner` file from workflow running environment.

## Choices

- [Daemon and Worker in VM](./daemon-and-worker-in-vm.md)
- [Daemon in Docker, Worker in VM](./daemon-in-docker-worker-in-vm.md)
