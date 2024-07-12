FROM mcr.microsoft.com/devcontainers/go:1-1.22-bookworm

# [Optional] Uncomment this section to install additional OS packages.
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get -y install --no-install-recommends postgresql

# install goose migration tool
USER vscode
RUN go install github.com/pressly/goose/v3/cmd/goose@latest

