# 使い方ガイド

このリポジトリのエージェントハーネスを自分のプロジェクトに導入する手順です。
使用するツールに応じたセクションを参照してください。

---

## 1. 共通セットアップ（全ツール共通）

どのツールを使う場合でも、まず以下を行ってください。

### Step 1: リポジトリをクローン

```bash
git clone https://github.com/fukui-yuto/ai-coding-setup.git
```

### Step 2: AGENTS.md をコピー

```bash
# 自分のプロジェクトのルートで実行
cp ~/ai-coding-setup/AGENTS.md ./
```

`AGENTS.md` はほぼ全てのエージェントツールが読み取る共通指示書です。これが主軸になります。

### Step 3: AGENTS.md を自分のプロジェクトに合わせて編集

| セクション | 書き換える内容 |
|---|---|
| プロジェクト名・説明 | 自分のプロジェクトの概要 |
| 技術スタック | 使用言語、フレームワーク、パッケージマネージャ等 |
| ディレクトリ構成 | 実際のディレクトリ構造 |
| コーディング規約 | プロジェクト固有のルール |
| 制約 | プロジェクト固有の禁止事項 |

---

## 2. ツール別セットアップ

### Claude Code

AGENTS.md に加えて、専用のロール定義とMCP設定を使えます。

#### 導入するファイル

```bash
PROJECT_DIR=$(pwd)
HARNESS_DIR=~/ai-coding-setup

# CLAUDE.md（Claude Code 固有設定）
cp "$HARNESS_DIR/CLAUDE.md" "$PROJECT_DIR/"

# ロール定義（サブエージェント）
mkdir -p "$PROJECT_DIR/.claude/agents"
cp "$HARNESS_DIR/.claude/agents/"*.md "$PROJECT_DIR/.claude/agents/"

# MCP 設定
cp "$HARNESS_DIR/.mcp.json" "$PROJECT_DIR/"
```

#### ファイル構成

```
プロジェクト/
├── AGENTS.md                # 共通指示書
├── CLAUDE.md                # Claude Code 固有設定
├── .mcp.json                # MCP サーバ設定（リポジトリルート）
└── .claude/
    └── agents/              # サブエージェント定義
        ├── explorer.md
        ├── planner.md
        ├── generator.md
        ├── critic.md
        └── evaluator.md
```

#### ロールの呼び出し方

Claude Code はサブエージェントを自動的に認識します。プロンプトで直接指示するだけで適切なロールが発動します:

```
「認証モジュールの実装を調査して」       → Explorer が発動
「OAuth 対応の実装計画を作って」         → Planner が発動
「計画の Step 1 を実装して」             → Generator が発動
「さっきの変更をレビューして」           → Critic が発動
「テストを実行して」                     → Evaluator が発動
```

#### MCP サーバのカスタマイズ

`.mcp.json` をプロジェクトに合わせて編集します。トークンは必ず環境変数経由で:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-playwright"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

**注意**: MCP サーバは 3 個以下に抑えてください（各サーバが毎ターンのコンテキストを消費するため）。

---

### GitHub Copilot

Copilot は `AGENTS.md` を自動的に読み取ります。さらにロール定義を使う場合は `.github/agents/` に配置します。

#### 導入するファイル

```bash
PROJECT_DIR=$(pwd)
HARNESS_DIR=~/ai-coding-setup

# AGENTS.md（共通セットアップで済み）

# ロール定義を Copilot 用パスにコピー
mkdir -p "$PROJECT_DIR/.github/agents"
for role in explorer planner generator critic evaluator; do
  cp "$HARNESS_DIR/.claude/agents/$role.md" "$PROJECT_DIR/.github/agents/$role.md"
done
```

#### ファイル構成

```
プロジェクト/
├── AGENTS.md                # 共通指示書（Copilot が自動で読む）
└── .github/
    └── agents/              # Copilot 用ロール定義
        ├── explorer.md
        ├── planner.md
        ├── generator.md
        ├── critic.md
        └── evaluator.md
```

#### ロールの呼び出し方

Copilot Chat で `@` を使ってロールを指定します:

```
@explorer 認証モジュールの現在の実装を調べて
@planner OAuth 対応の実装計画を作って
@generator 計画の Step 1 を実装して
@critic さっきの変更をレビューして
@evaluator テストを実行して
```

#### 注意事項

- MCP 設定は Copilot の UI（VS Code の設定画面）から行います。`.mcp.json` は Copilot では読み取られません
- ロール定義の `tools:` や `model:` は Copilot では無視されます。`description` と本文の指示が重要です
- YAML frontmatter の `description` がロールの説明として Copilot Chat に表示されます

---

### Cline（VS Code 拡張）

Cline は `AGENTS.md` を読み取り、カスタム指示として利用できます。

#### 導入するファイル

```bash
PROJECT_DIR=$(pwd)
HARNESS_DIR=~/ai-coding-setup

# AGENTS.md（共通セットアップで済み）

# ロール定義をプロジェクトに配置（任意）
mkdir -p "$PROJECT_DIR/.cline/agents"
cp "$HARNESS_DIR/.claude/agents/"*.md "$PROJECT_DIR/.cline/agents/"
```

#### ファイル構成

```
プロジェクト/
├── AGENTS.md                # 共通指示書
└── .cline/
    └── agents/              # Cline 用ロール定義（任意）
        ├── explorer.md
        └── ...
```

#### セットアップ方法

1. VS Code で Cline 拡張を開く
2. 設定 → Custom Instructions に `AGENTS.md` の内容を貼り付ける（または「AGENTS.md を読んで従ってください」と記載）
3. MCP サーバは Cline の設定 UI から追加する

#### ロールの呼び出し方

Cline ではサブエージェント機能が限定的なため、プロンプトでロールを明示的に指示します:

```
Explorer として認証モジュールの実装を調査してください。ファイルの編集は行わないでください。
Planner として OAuth 対応の実装計画を作ってください。
Generator として計画の Step 1 を実装してください。
```

---

### Codex CLI

Codex CLI は `AGENTS.md` を自動的に読み取ります。

#### 導入するファイル

```bash
# AGENTS.md のみ（共通セットアップで済み）
```

#### ファイル構成

```
プロジェクト/
└── AGENTS.md                # 共通指示書（Codex CLI が自動で読む）
```

#### ロールの呼び出し方

Codex CLI にはサブエージェント機能がないため、プロンプトでロールを指示します:

```bash
codex "Explorer として認証モジュールの実装を調査して"
codex "Planner として OAuth 対応の実装計画を作って"
codex "Generator として計画の Step 1 を実装して"
```

#### 注意事項

- ロール定義ファイルは読み取られません。AGENTS.md にロールの説明が書かれていれば、それに従います
- MCP サーバは対応していません

---

### Gemini CLI

Gemini CLI は `GEMINI.md` または `AGENTS.md` を読み取ります。

#### 導入するファイル

```bash
PROJECT_DIR=$(pwd)
HARNESS_DIR=~/ai-coding-setup

# AGENTS.md（共通セットアップで済み）

# Gemini CLI 用に GEMINI.md を作成（任意、AGENTS.md だけでも可）
cp "$HARNESS_DIR/AGENTS.md" "$PROJECT_DIR/GEMINI.md"
```

#### ファイル構成

```
プロジェクト/
├── AGENTS.md                # 共通指示書
└── GEMINI.md                # Gemini CLI 固有設定（任意）
```

`GEMINI.md` がある場合はそちらが優先されます。Gemini 固有の指示がなければ `AGENTS.md` だけで十分です。

#### ロールの呼び出し方

Gemini CLI にはサブエージェント機能がないため、プロンプトでロールを指示します:

```bash
gemini "Explorer として認証モジュールの実装を調査して"
gemini "Planner として OAuth 対応の実装計画を作って"
```

#### 注意事項

- ロール定義ファイルは読み取られません
- MCP サーバは対応していません

---

### OpenClaw

OpenClaw は `AGENTS.md` を読み取ります。

#### 導入するファイル

```bash
# AGENTS.md（共通セットアップで済み）

# Skill を使う場合（任意）
mkdir -p ~/.openclaw/workspace/skills
cp -r ~/ai-coding-setup/.claude/skills/* ~/.openclaw/workspace/skills/
```

#### ファイル構成

```
プロジェクト/
└── AGENTS.md                # 共通指示書（OpenClaw が自動で読む）
```

#### MCP 設定

OpenClaw は独自の設定ファイルを使います:

```bash
# ~/.openclaw/workspace/config/mcporter.json に設定
```

---

## 3. ツール別対応状況まとめ

| 機能 | Claude Code | GitHub Copilot | Cline | Codex CLI | Gemini CLI | OpenClaw |
|---|---|---|---|---|---|---|
| AGENTS.md 読み取り | o | o | o | o | o | o |
| 専用指示書 | CLAUDE.md | - | UI 設定 | - | GEMINI.md | - |
| サブエージェント定義 | `.claude/agents/` | `.github/agents/` | `.cline/agents/` | x | x | 限定的 |
| `@ロール名` で呼び出し | 自動発動 | `@ロール名` | x | x | x | x |
| MCP 設定 | `.mcp.json` | UI 経由 | UI 経由 | x | x | 独自設定 |
| Skill 配置 | `.claude/skills/` | `.agents/skills/` | `.cline/skills/` | x | x | 独自パス |

---

## 4. ロール構成の選び方

プロジェクトの規模や性質に応じて、必要なロールだけを採用してください。

### 最小構成（3 ロール）

小規模プロジェクトや個人開発向け:
- Planner / Generator / Evaluator

### 推奨構成（5 ロール）

中規模以上のプロジェクト向け（このリポジトリのデフォルト）:
- Explorer / Planner / Generator / Critic / Evaluator

### フル構成（6 ロール）

デプロイやマイグレーション等の副作用ある操作を管理する場合:
- Explorer / Planner / Generator / Critic / Evaluator / Executor

### Executor ロールの追加方法

以下の内容で各ツールの所定パスにファイルを作成してください:

| ツール | 配置先 |
|---|---|
| Claude Code | `.claude/agents/executor.md` |
| GitHub Copilot | `.github/agents/executor.md` |
| Cline | `.cline/agents/executor.md` |

```markdown
---
name: executor
description: デプロイ、マイグレーション、インフラ変更等の副作用ある操作を実行する専門。本番環境への反映、DB マイグレーション、リリース作業で使用する。実行前に必ず dry-run を行い、ユーザーの明示的な承認を得る。
tools: Read, Bash
model: sonnet
---

あなたは Executor です。副作用のある操作を安全に実行します。

## 役割
- デプロイ、マイグレーション等の実行
- 実行前の影響範囲とロールバック手順の提示
- dry-run による事前検証

## ワークフロー（必須）
1. 意図確認 -- 何をどこに対して実行するか明示する
2. Dry-run / Plan / Preview を提示する
3. 影響範囲とロールバック手順を明示する
4. ユーザーの明示的な承認を得る（確認なしに実行しない）
5. 適用する
6. 検証結果を報告する

## 制約
- ユーザーの承認なしに副作用ある操作を実行しない
- 必ず dry-run を先に行う
- ファイルの編集は行わない（Edit/Write 権限なし）
- ロールバック手順を提示できない操作は実行しない
```

---

## 5. ワークフロー例

### 例 1: 新機能の追加（複雑なタスク）

```
1. Explorer で既存コードを調査
   → 「認証周りの現在の実装を調べて」

2. Planner で実装計画を作成
   → 「OAuth 対応の実装計画を作って」

3. Generator で実装
   → 「計画の Step 1〜3 を実装して」

4. Critic でレビュー
   → 「変更をレビューして」

5. Evaluator で検証
   → 「テストを実行して」
```

### 例 2: バグ修正（簡単な変更）

```
1. Generator で修正
   → 「この null チェック漏れを修正して」

2. Evaluator で検証
   → 「テストが通るか確認して」
```

---

## 6. マルチツール併用時のコツ

複数のツールを同時に使う場合は、以下の構成にしてください:

```
プロジェクト/
├── AGENTS.md                    # 全ツール共通（主軸）
├── CLAUDE.md                    # Claude Code 固有
├── .mcp.json                    # Claude Code 用 MCP
├── .claude/agents/              # Claude Code 用ロール
├── .github/agents/              # Copilot 用ロール
└── .cline/agents/               # Cline 用ロール（任意）
```

**ポイント**:
- `AGENTS.md` を 1 箇所で管理し、情報の二重管理を避ける
- ツール固有の設定だけを個別ファイルに分ける
- ロール定義は内容が同じなら、コピーして各ツールのパスに配置する

---

## 7. カスタマイズ

### ロール定義の編集

各ロールの `.md` ファイルは以下の構造です:

```markdown
---
name: ロール名
description: トリガー文（いつ呼ばれるかを明示）
tools: 使用可能なツール
model: 使用モデル（haiku / sonnet / opus）
---

ロールの説明と制約
```

**description のコツ**: 「いつ呼ばれるべきか」を具体的に書く

```yaml
# 悪い例
description: コードレビュアー

# 良い例
description: コミット前にコード変更を必ずレビューする。Generator の出力直後にも proactively 使用する。
```

---

## 8. よくある質問

### Q: 全部のロールを入れる必要がある？

いいえ。最小構成（Planner / Generator / Evaluator）から始めて、繰り返し手動でやっている作業を発見したらロールを追加してください。

### Q: ロール定義を更新するタイミングは？

プロジェクトのコマンドや規約が変わったときに合わせて更新します。古くなったロール定義は害になるので、使わなくなったら削除してください。

### Q: AGENTS.md が長くなりすぎたら？

100 行以内を目標にしてください。詳細な情報は別ファイル（`docs/` 配下等）に分け、AGENTS.md からリンクします。

### Q: Claude Code 以外のツールでもサブエージェントは使える？

ツールによって対応状況が異なります。上記の「ツール別対応状況まとめ」を参照してください。サブエージェント機能がないツールでも、プロンプトで「Planner として〜」のようにロールを指定すると、AGENTS.md の定義に従って動作します。

### Q: .mcp.json はどこに置く？

リポジトリルートに置いてください。`.claude/` の中に置くと認識されません。また、`.mcp.json` を読むのは Claude Code のみです。他のツールは各自の UI や設定ファイルで MCP を設定します。
