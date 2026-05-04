# ai-coding-setup

AI コーディングエージェントのハーネス（プロジェクト用設定一式）を構築するための実践ガイドとテンプレート集です。

Claude Code を中心に、GitHub Copilot / Cline / OpenClaw / Codex CLI / Gemini CLI 等のマルチツールに対応しています。

## 特徴

- **5 つの汎用エージェントロール** (Explorer / Planner / Generator / Critic / Evaluator) + オプションの Executor による役割分担
- **AGENTS.md を主軸** にしたマルチツール対応設計
- **最小権限の原則** に基づくツール権限管理
- **副作用の隔離** (Executor ロールへの分離)

## 構成

```
ai-coding-setup/
├── setup.sh                           # セットアップスクリプト
├── AGENTS.md                          # プロジェクト指示書（全ツール共通）
├── CLAUDE.md                          # Claude Code 固有設定
├── GEMINI.md                          # Gemini CLI 固有設定
├── .mcp.json                          # Claude Code 用 MCP 設定
│
├── .claude/agents/                    # Claude Code 用ロール定義
│   ├── explorer.md
│   ├── planner.md
│   ├── generator.md
│   ├── critic.md
│   └── evaluator.md
│
├── .github/agents/                    # GitHub Copilot 用ロール定義
│   ├── explorer.md
│   ├── planner.md
│   ├── generator.md
│   ├── critic.md
│   └── evaluator.md
│
├── .cline/                            # Cline 用設定
│   ├── agents/                        # ロール定義
│   └── mcp_settings.json             # MCP 設定
│
├── .vscode/mcp.json                   # Copilot 用 MCP 設定
│
├── docs/
│   ├── usage.md                       # 使い方ガイド
│   └── requirements.md                # 詳細要件定義
└── README.md
```

## 対応ツール

| ツール | 指示書 | ロール定義 | MCP 設定 |
|---|---|---|---|
| Claude Code | `AGENTS.md` + `CLAUDE.md` | `.claude/agents/` | `.mcp.json` |
| GitHub Copilot | `AGENTS.md` | `.github/agents/` | `.vscode/mcp.json` |
| Cline | `AGENTS.md` | 参考用のみ | `.cline/mcp_settings.json` |
| Codex CLI | `AGENTS.md` | - | - |
| Gemini CLI | `AGENTS.md` + `GEMINI.md` | - | - |
| OpenClaw | `AGENTS.md` | - | 独自設定 |

## クイックスタート

### セットアップスクリプトで導入（推奨）

```bash
git clone https://github.com/fukui-yuto/ai-coding-setup.git
cd ai-coding-setup

# 対話的に選択
./setup.sh ~/my-project

# ツールを直接指定
./setup.sh ~/my-project --tool claude-code
./setup.sh ~/my-project --tool copilot
./setup.sh ~/my-project --tool claude-code --tool copilot
./setup.sh ~/my-project --tool all

# オプション
./setup.sh ~/my-project --tool claude-code --force    # 既存ファイルを確認なしで上書き
./setup.sh ~/my-project --tool claude-code --clean    # 他ツールの不要ファイルを削除
./setup.sh ~/my-project --tool all --dry-run          # 変更内容をプレビュー（実行しない）
./setup.sh --help                                     # 全オプションを表示
```

セットアップ後、`AGENTS.md` を自分のプロジェクトに合わせて編集してください。

詳細は [docs/usage.md](docs/usage.md) を参照してください。

### 推奨ワークフロー

```
複雑なタスク: Explorer → Planner → Generator → Critic → Evaluator
簡単な変更:   Generator → Evaluator
```

詳細は [docs/usage.md のワークフロー例](docs/usage.md#5-ワークフロー例) を参照。

## 設計原則

詳細は [docs/requirements.md](docs/requirements.md) を参照してください。

1. 汎用ロールで大半をカバーし、専門エージェントは必要時のみ補完
2. AGENTS.md を主軸にしてマルチツール対応
3. ツール権限を最小化（read-only ロールは Edit 権限を持たない）
4. 副作用ある操作は Executor に隔離

## ライセンス

MIT

## 作者

[Yuto Fukui](https://fukui-yuto.github.io/)
