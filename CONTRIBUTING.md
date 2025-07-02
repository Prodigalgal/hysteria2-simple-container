# 为 Hysteria 2 简单容器项目贡献

首先，非常感谢您考虑为本项目做出贡献！这个项目旨在保持简单和可靠，我们非常感谢您为之付出的努力。

我们欢迎所有形式的贡献，包括 Bug 报告、功能请求、文档改进和代码提交。

请注意，我们有一个[行为准则](./CODE_OF_CONDUCT.md)，请在与项目的所有互动中遵守它。

## 贡献方式

### 报告 Bug
如果您发现了一个 Bug，请提交一个 [Bug 报告 Issue](https://github.com/Prodigalgal/hysteria2-simple-container/issues/new?template=bug_report.yml)。在提交前，请先检查现有的 issue，看看是否有人已经报告过相同的问题。

在报告 Bug 时，请包含以下信息：
- 对 Bug 的清晰、简洁的描述。
- 复现该行为的步骤。
- `traefik` 和 `hysteria-server` 两个容器的日志。您可以通过运行 `docker-compose logs traefik` 和 `docker-compose logs hysteria-server` 来获取。
- 您的环境详情（操作系统、Docker 版本等）。

### 建议新功能
如果您对新功能或改进有任何想法，请提交一个[功能请求 Issue](https://github.com/Prodigalgal/hysteria2-simple-container/issues/new?template=feature_request.yml)。

### 提交 Pull Request
如果您想贡献代码或文档，可以通过 Pull Request (PR) 的方式进行。

1.  **Fork 本仓库** 并将其克隆到您的本地机器。
2.  为您的改动**创建一个新分支**。请使用一个有描述性的名称，例如 `feature/add-new-obfuscation` 或 `fix/entrypoint-logic`。
    ```bash
    git checkout -b feature/my-awesome-feature
    ```
3.  **进行修改。** 项目的核心文件包括：
    - `docker-compose.yml`: 服务定义。
    - `Dockerfile`: Hysteria 2 镜像的构建过程。
    - `entrypoint.sh`: 容器的启动逻辑。
    - `README.md`: 面向用户的文档。
4.  **在本地测试您的改动。** 确保使用您自己的测试域名和邮箱，整个部署流程仍然可以正常工作。
    ```bash
    # (修改后)
    # 如果您修改了脚本，请赋予执行权限
    chmod +x entrypoint.sh

    # 使用您的测试变量来构建和运行
    LE_EMAIL="test@example.com" \
    DOMAIN="test.your-domain.com" \
    PASSWORD="a-test-password" \
    docker-compose up -d --build

    # 检查日志和功能
    docker-compose logs -f
    ```
5.  **提交您的改动**，并附上清晰、有描述性的提交信息。
    ```bash
    git commit -m "feat: 增加对 X 功能的支持"
    ```
6.  **将您的分支推送**到您的 Fork 仓库。
    ```bash
    git push origin feature/my-awesome-feature
    ```
7.  **向本仓库的 `main` 分支发起一个 Pull Request**。请填写 PR 模板，详细说明您的改动。

感谢您的贡献！
