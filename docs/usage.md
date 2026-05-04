# 使い方ガイド

このリポジトリのエージェントハーネスを自分のプロジェクトに導入する手順です。
使用するツールに応じたセクションを参照してください。

---

## 1. セットアップ

### Step 1: リポジトリをクローン

```bash
git clone https://github.com/fukui-yuto/ai-coding-setup.git
cd ai-coding-setup
```

### Step 2: セットアップスクリプトを実行

```bash
# 対話的に選択（番号で選ぶ）
./setup.sh ~/my-project

# ツールを直接指定
./setup.sh ~/my-project --tool claude-code
./setup.sh ~/my-project --tool copilot
./setup.sh ~/my-project --tool claude-code --tool copilot
./setup.sh ~/my-project --tool all
```

#### オプション

| オプション | 説明 |
|---|---|
| `--tool <名前>` | 使用するツールを指定（複数指定可）。`claude-code`, `copilot`, `cline`, `codex`, `gemini`, `openclaw`, `all` |
| `--force` | 既存ファイルを確認なしで上書き |
| `--clean` | 選択されなかったツールの既存ファイルを削除する |
| `--dry-run` | 実際にはファイルを変更せず、何が行われるかを表示する |

```bash
# 例: Claude Code のみに切り替え、他ツールのファイルを削除
./setup.sh ~/my-project --tool claude-code --clean

# 例: 変更内容をプレビュー
./setup.sh ~/my-project --tool all --dry-run
```

スクリプトが選択したツールに応じて、必要なファイル（指示書・ロール定義・MCP 設定）をプロジェクトにコピーします。

### Step 3: AGENTS.md を自分のプロジェクトに合わせて編集

| セクション | 書き換える内容 |
|---|---|
| プロジェクト名・説明 | 自分のプロジェクトの概要 |
| 技術スタック | 使用言語、フレームワーク、パッケージマネージャ等 |
| ディレクトリ構成 | 実際のディレクトリ構造 |
| コーディング規約 | プロジェクト固有のルール |
| 制約 | プロジェクト固有の禁止事項 |

---

## 2. ツール別の使い方

### Claude Code

#### セットアップで導入されるファイル

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

#### セットアップで導入されるファイル

```
プロジェクト/
├── AGENTS.md                # 共通指示書（Copilot が自動で読む）
├── .vscode/
│   └── mcp.json             # MCP 設定
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

- MCP 設定は `.vscode/mcp.json` に配置するか、VS Code の設定 UI から追加します
- ロール定義の `tools:` や `model:` は Copilot では無視されます。`description` と本文の指示が重要です
- YAML frontmatter の `description` がロールの説明として Copilot Chat に表示されます

---

### Cline（VS Code 拡張）

#### セットアップで導入されるファイル

```
プロジェクト/
├── AGENTS.md                # 共通指示書
└── .cline/
    ├── agents/              # ロール定義（プロンプト指示時の参照用）
    │   ├── explorer.md
    │   └── ...
    └── mcp_settings.json    # MCP 設定
```

#### セットアップ後の追加設定

1. VS Code で Cline 拡張を開く
2. 設定 → Custom Instructions に `AGENTS.md` の内容を貼り付ける（または「AGENTS.md を読んで従ってください」と記載）

#### ロールの呼び出し方

Cline はロール定義ファイルを自動認識しません。`.cline/agents/` のファイルはプロンプト指示時の参照用です。プロンプトでロールを明示的に指示します:

```
Explorer として認証モジュールの実装を調査してください。ファイルの編集は行わないでください。
Planner として OAuth 対応の実装計画を作ってください。
Generator として計画の Step 1 を実装してください。
```

---

### Codex CLI

#### セットアップで導入されるファイル

```
プロジェクト/
└── AGENTS.md                # 共通指示書（Codex CLI が自動で読む）
```

#### ロールの呼び出し方

Codex CLI にはサブエージェント機能がないため、プロンプトでロールを指示します:

```bash
codex "Explorer として認証モジュールの実装を調査して"
codex "Planner として OAuth 対応の実装計画を作って"
```

---

### Gemini CLI

#### セットアップで導入されるファイル

```
プロジェクト/
├── AGENTS.md                # 共通指示書
└── GEMINI.md                # Gemini CLI 固有設定（AGENTS.md への参照）
```

`GEMINI.md` がある場合はそちらが優先されます。AGENTS.md への参照を記載するだけなので、Gemini 固有の指示がなければ `AGENTS.md` だけで十分です。

#### ロールの呼び出し方

Gemini CLI にはサブエージェント機能がないため、プロンプトでロールを指示します:

```bash
gemini "Explorer として認証モジュールの実装を調査して"
gemini "Planner として OAuth 対応の実装計画を作って"
```

---

### OpenClaw

#### セットアップで導入されるファイル

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
| 専用指示書 | CLAUDE.md | - | - | - | GEMINI.md | - |
| サブエージェント定義 | `.claude/agents/` | `.github/agents/` | 参考用のみ | x | x | 限定的 |
| ロール呼び出し | 自動発動 | `@ロール名` | プロンプト指示 | プロンプト指示 | プロンプト指示 | プロンプト指示 |
| MCP 設定 | `.mcp.json` | `.vscode/mcp.json` | `.cline/mcp_settings.json` | x | x | 独自設定 |

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

**複雑なタスク** (Explorer → Planner → Generator → Critic → Evaluator):

```
「認証周りの実装を調べて」 → 「OAuth 対応の実装計画を作って」 → 「計画の Step 1 を実装して」 → 「変更をレビューして」 → 「テストを実行して」
```

**簡単な変更** (Generator → Evaluator):

```
「この null チェック漏れを修正して」 → 「テストが通るか確認して」
```

ワークフローの詳細は [requirements.md のセクション 7](requirements.md#7-ワークフロー要件) を参照。

---

## 6. マルチツール併用時のコツ

複数のツールを同時に使う場合:

```bash
./setup.sh ~/my-project --tool claude-code --tool copilot --tool cline
```

**ポイント**:
- `AGENTS.md` を 1 箇所で管理し、情報の二重管理を避ける
- ツール固有の設定だけを個別ファイルに分ける
- ロール定義は内容が同じまま、各ツールのパスに自動配置される

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

リポジトリルートに置いてください。`.claude/` の中に置くと認識されません。また、`.mcp.json` を読むのは Claude Code のみです。他のツールは各自の設定ファイルで MCP を設定します。
