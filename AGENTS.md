# ai-coding-setup

AI コーディングエージェントのハーネス（プロジェクト設定一式）を構築するための実践ガイドとテンプレート集。
Claude Code / GitHub Copilot / Cline 等のマルチツール対応。

## 技術スタック
- 言語: Markdown, JSON, YAML
- 対象ツール: Claude Code, GitHub Copilot, Cline, OpenClaw, Codex CLI, Gemini CLI

## ディレクトリ構成
```
ai-coding-setup/
├── AGENTS.md                          # プロジェクト指示書（全ツール共通）
├── CLAUDE.md                          # Claude Code 固有設定
├── GEMINI.md                          # Gemini CLI 固有設定
├── .mcp.json                          # Claude Code 用 MCP 設定
├── .claude/agents/                    # Claude Code 用ロール定義
├── .github/agents/                    # GitHub Copilot 用ロール定義
├── .cline/                            # Cline 用設定（ロール + MCP）
├── .vscode/mcp.json                   # Copilot 用 MCP 設定
├── docs/                              # ガイド・使い方
└── README.md
```

## コーディング規約
- ファイル命名: kebab-case
- ロール定義: Markdown + YAML frontmatter 形式
- AGENTS.md: 100 行以内を目標
- ロール description: 「いつ呼ばれるか」を明示するトリガー文で書く

## 制約（絶対にしてはいけないこと）
- `.env` や `secrets/` 配下を絶対にコミットしない
- `.mcp.json` にトークンをハードコードしない（常に `${ENV_VAR}` 経由）
- ロールに全権限（Read/Edit/Write/Bash すべて）を与えない
- AGENTS.md に抽象的なマニフェスト（「品質を重視」等）を書かない

## エージェントロール
- explorer / planner / generator / critic / evaluator

## 推奨ワークフロー
- 複雑なタスク: Explorer → Planner → Generator → Critic → Evaluator
- 簡単な変更: Generator → Evaluator
