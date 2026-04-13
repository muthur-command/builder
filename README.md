# MCOS Builder (reusable GitHub Actions)

This repository provides build tooling for the **MCOS** full-stack migration under the **muthur-command** organization.

## Actions

### [`actions/prepare-multi-arch-matrix`](actions/prepare-multi-arch-matrix/action.yml)

Given a JSON array of architectures (e.g. `["amd64", "aarch64"]`) and an **image name without an arch prefix** (e.g. `mcio-supervisor`), outputs a matrix for `build-image`, including the full image name `ghcr.io/<owner>/{arch}-<image-name>`.

### [`actions/build-image`](actions/build-image/action.yml)

Single-architecture Buildx builds; optional push and Cosign signing; GHA and registry caching; optional base-image signature verification. Outputs the image digest.

### [`actions/publish-multi-arch-manifest`](actions/publish-multi-arch-manifest/action.yml)

Combines per-arch images into a **multi-arch manifest** (`docker buildx imagetools create`) and can Cosign-sign the manifest.

### [`actions/cosign-verify`](actions/cosign-verify/action.yml)

Cosign verification with retries; used inside `build-image` for cache/base checks, or standalone.

## Example workflow

Replace **`[version]`** with a tag or SHA from this repository (e.g. `main`, `2026.03.2`). Choose image names per **P0 appendix A** (BRAND); the example uses a supervisor-style name.

```yaml
name: Build

on:
  release:
    types: [published]

env:
  ARCHITECTURES: '["amd64", "aarch64"]'
  IMAGE_NAME: mcio-supervisor

permissions:
  contents: read

jobs:
  init:
    name: Initialize build
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v6
      - name: Get build matrix
        id: matrix
        uses: muthur-command/builder/actions/prepare-multi-arch-matrix@[version]
        with:
          architectures: ${{ env.ARCHITECTURES }}
          image-name: ${{ env.IMAGE_NAME }}

  build:
    name: Build ${{ matrix.arch }} image
    needs: init
    runs-on: ${{ matrix.os }}
    permissions:
      contents: read
      id-token: write
      packages: write
    strategy:
      fail-fast: false
      matrix: ${{ fromJSON(needs.init.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v6
      - name: Build image
        uses: muthur-command/builder/actions/build-image@[version]
        with:
          arch: ${{ matrix.arch }}
          container-registry-password: ${{ secrets.GITHUB_TOKEN }}
          image: ${{ matrix.image }}
          image-tags: |
            ${{ github.event.release.tag_name }}
            latest
          push: "true"
          version: ${{ github.event.release.tag_name }}

  manifest:
    name: Publish multi-arch manifest
    needs: [init, build]
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      packages: write
    steps:
      - name: Publish multi-arch manifest
        uses: muthur-command/builder/actions/publish-multi-arch-manifest@[version]
        with:
          architectures: ${{ env.ARCHITECTURES }}
          container-registry-password: ${{ secrets.GITHUB_TOKEN }}
          image-name: ${{ env.IMAGE_NAME }}
          image-tags: |
            ${{ github.event.release.tag_name }}
            latest
```

## CI in this repository

[`.github/workflows/test.yml`](.github/workflows/test.yml) runs a smoke test of `prepare-multi-arch-matrix` and `build-image` against **`tests/fixtures/minimal`** (`push: false`, `load: true`, `cosign: false`).

## Derivative work and license

This project is maintained under the **Apache-2.0** license and may include derivative work from upstream build tooling; **LICENSE** and copyright notices are kept as required upstream. A formal **NOTICE** can be added after legal review.
