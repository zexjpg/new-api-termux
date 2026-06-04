# New API for Termux

[New API](https://github.com/QuantumNous/new-api) LLM gateway packaged as a Termux .deb package.

## Install

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/zexjpg/new-api-termux/main/install.sh)"
```

Or specify a version:

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/zexjpg/new-api-termux/main/install.sh)" -- 1.0.0-rc.10
```

## Usage

```bash
new-api --help              # Show help
new-api --port 3000         # Start on custom port
new-api-start               # Quick start (port 3000, log dir)
```

## What's inside

The `.deb` package installs:

- `$PREFIX/bin/new-api` - launcher (unset LD_PRELOAD, exec via glibc)
- `$PREFIX/bin/new-api-start` - convenience start script
- `$PREFIX/lib/new-api/new-api-bin` - the glibc-linked aarch64 binary

Dependencies: `glibc`

## Auto-build

This repo checks [QuantumNous/new-api](https://github.com/QuantumNous/new-api) every 6 hours
for new releases and automatically builds updated .deb packages.
