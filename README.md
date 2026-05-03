# ai-coding-setup

AI コーディングエージェントのハーネス（プロジェクト用設定一式）を構築するための実践ガイドとテンプレート集です。

Claude Code を中心に、GitHub Copilot / Cline / OpenClaw / Codex CLI / Gemini CLI 等のマルチツールに対応しています。

## 特徴

- **6 つの汎用エージェントロール** (Explorer / Planner / Generator / Critic / Evaluator / Executor) による役割分担
- **AGENTS.md を主軸** にしたマルチツール対応設計
- **最小権限の原則** に基づくツール権限管理
- **副作用の隔離** (Executor ロールへの分離)

## 構成

```
ai-coding-setup/
├── AGENTS.md                          # プロジェクト指示書（全ツール共通）
├── CLAUDE.md                          # Claude Code 固有設定
├── .mcp.json                          # MCP サーバ設定
├── claude-code-development-guide.md   # 開発ガイド本体
├── docs/                              # 補足資料
├── .claude/
│   └── agents/                        # Claude Code 用ロール定義
│       ├── explorer.md                # 調査専門（read-only）
│       ├── planner.md                 # 計画作成（read-only）
│       ├── generator.md               # コード生成・編集
│       ├── critic.md                  # 品質レビュー（read-only）
│       └── evaluator.md               # テスト・ビルド検証
└── README.md
```

## クイックスタート

### 自分のプロジェクトに導入する

1. `AGENTS.md` をプロジェクトのルートにコピーし、内容を自分のプロジェクトに合わせて編集
2. `.claude/agents/` 配下のロール定義を必要に応じてコピー
3. `.mcp.json` を必要に応じて配置

### 推奨ワークフロー

**複雑なタスク:**
```
Explorer → Planner → Generator → Critic → Evaluator
```

**簡単な変更:**
```
Generator → Evaluator
```

## 設計原則

詳細は [claude-code-development-guide.md](claude-code-development-guide.md) を参照してください。

1. 汎用ロールで大半をカバーし、専門エージェントは必要時のみ補完
2. AGENTS.md を主軸にしてマルチツール対応
3. ツール権限を最小化（read-only ロールは Edit 権限を持たない）
4. 副作用ある操作は Executor に隔離

## ライセンス

MIT

## 作者

[Yuto Fukui](https://fukui-yuto.github.io/)
