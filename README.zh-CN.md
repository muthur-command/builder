# MCOS Builder（可复用 GitHub Actions）

本仓库为 **muthur-command** 组织下 **MCOS** 全栈迁移提供镜像构建工具链。

## Actions

### [`actions/prepare-multi-arch-matrix`](actions/prepare-multi-arch-matrix/action.yml)

输入架构 JSON 数组（例如 `["amd64", "aarch64"]`）和**不带架构前缀**的镜像名（例如 `mcio-supervisor`），输出 `build-image` 所需的矩阵，并生成完整镜像名 `ghcr.io/<owner>/{arch}-<image-name>`。

### [`actions/build-image`](actions/build-image/action.yml)

单架构 Buildx 构建；支持可选推送与 Cosign 签名；支持 GHA 与 registry 缓存；支持可选基础镜像签名校验。会输出镜像 digest。

### [`actions/publish-multi-arch-manifest`](actions/publish-multi-arch-manifest/action.yml)

将各架构镜像合并为**多架构清单**（`docker buildx imagetools create`），并可对清单进行 Cosign 签名。

### [`actions/cosign-verify`](actions/cosign-verify/action.yml)

带重试的 Cosign 校验；可在 `build-image` 内用于缓存/基础镜像校验，也可独立使用。

## 工作流示例

将 **`[version]`** 替换为本仓库的 tag 或 SHA（例如 `main`、`2026.03.2`）。镜像命名请遵循 **P0 附录 A**（品牌规范）；示例使用 supervisor 风格命名。

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
    name: 初始化构建
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v6
      - name: 生成构建矩阵
        id: matrix
        uses: muthur-command/builder/actions/prepare-multi-arch-matrix@[version]
        with:
          architectures: ${{ env.ARCHITECTURES }}
          image-name: ${{ env.IMAGE_NAME }}

  build:
    name: 构建 ${{ matrix.arch }} 镜像
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
      - name: 构建镜像
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
    name: 发布多架构清单
    needs: [init, build]
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      packages: write
    steps:
      - name: 发布多架构清单
        uses: muthur-command/builder/actions/publish-multi-arch-manifest@[version]
        with:
          architectures: ${{ env.ARCHITECTURES }}
          container-registry-password: ${{ secrets.GITHUB_TOKEN }}
          image-name: ${{ env.IMAGE_NAME }}
          image-tags: |
            ${{ github.event.release.tag_name }}
            latest
```

## 本仓库 CI

[`/.github/workflows/test.yml`](.github/workflows/test.yml) 会对 **`tests/fixtures/minimal`** 执行 `prepare-multi-arch-matrix` 与 `build-image` 的冒烟测试（`push: false`、`load: true`、`cosign: false`）。

## 衍生作品与许可证

本项目采用 **Apache-2.0** 许可证，可能包含来自上游构建工具的衍生内容；按上游要求保留 **LICENSE** 与版权声明。正式 **NOTICE** 可在法务评审后补充。
