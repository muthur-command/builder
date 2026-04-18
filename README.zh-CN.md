# Muthur Command Builder

_用于构建 **Muthur Command** 容器镜像的工具链。_

## 可复用的 GitHub Actions

本仓库提供下列可组合的 GitHub Actions，用于构建、签名并发布多架构容器镜像。它们通常在同一工作流中配合使用，也可单独使用。

### [`prepare-multi-arch-matrix`](actions/prepare-multi-arch-matrix/action.yml)

接收架构的 JSON 数组（例如 `["amd64", "aarch64"]`）以及镜像名称，输出适用于 `build-image` 的 GitHub Actions 构建矩阵。

### [`build-image`](actions/build-image/action.yml)

使用 Docker Buildx 构建单架构容器镜像；支持可选推送与 Cosign 签名；支持基于 GHA 与 registry 的构建缓存、基础镜像签名校验，以及自定义 build-args/labels。输出镜像 digest。

### [`publish-multi-arch-manifest`](actions/publish-multi-arch-manifest/action.yml)

将各架构镜像（例如 `amd64-myimage:latest`、`aarch64-myimage:latest`）通过 `docker buildx imagetools create` 合并为单一多架构清单（例如 `myimage:latest`）。可对生成的清单进行 Cosign 签名。

### [`cosign-verify`](actions/cosign-verify/action.yml)

校验容器镜像上的 Cosign 签名，最多重试 5 次并采用指数退避。支持「允许失败」模式：仅发出 warning 而不使步骤失败。在 `build-image` 内用于缓存与基础镜像校验，也可独立使用。

## 工作流示例

以下示例在 GitHub **release** 发布时构建多架构镜像：先生成构建矩阵，再并行构建各架构镜像（例如 `ghcr.io/owner/amd64-my-image`、`ghcr.io/owner/aarch64-my-image`），最后合并为单一多架构清单（`ghcr.io/owner/my-image`）。

_说明：将 **`[version]`** 替换为 [releases](https://github.com/muthur-command/builder/releases) 中所需的 tag。_

```yaml
name: Build

on:
  release:
    types: [published]

env:
  ARCHITECTURES: '["amd64", "aarch64"]'
  IMAGE_NAME: my-image

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
      contents: read # To check out the code
      id-token: write # Write needed for Cosign signing (issue OIDC token for signing)
      packages: write # To push built images to GitHub Container Registry
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
      id-token: write # Write needed for Cosign signing (issue OIDC token for signing)
      packages: write # To push the manifest to GitHub Container Registry
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

## 来源

- **上游：** [home-assistant/builder](https://github.com/home-assistant/builder) — 面向 Home Assistant 相关容器构建的 GitHub Actions，本目录由其移植而来。
- **本仓库：** **Muthur Command** 在本文档所在仓库维护该副本，供 **Muthur Command OS** 的 CI 使用；action 与行为可能随时间与上游产生差异。
- **许可：** 自上游继承的代码仍为 **Apache-2.0**；见 [`LICENSE`](./LICENSE)。
