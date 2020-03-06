# GHC, Alpine, Stack, and Docker

This is a somewhat stripped-down fork of <https://github.com/jkachmar/alpine-haskell-stack>. Go there for more information.

The primary aim is to have a minimalist-ish repo for building GHC docker images.

# "Quick" Start

To build the Docker images, navigate to the project root directory and run:

```bash
make build
```

Keep in mind that this compiles GHC, which can take anywhere from 30 mins to upwards of an hour depending on how fast your computer is.

You can specify a particular version via

```bash
make TARGET_GHC_VERSION=8.8.3 build
```

Bear in mind at the time of writing, Alpine 3.11 has GHC 8.6.5, so you really only need this to get GHC 8.8.
