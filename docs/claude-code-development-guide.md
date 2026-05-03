# Claude Code 開発ガイド: エージェントハーネス構築

このドキュメントは、Claude Code を中心に AI コーディングエージェントの「ハーネス」(プロジェクト用設定一式) を設計・構築するための実践ガイドです。マルチツール対応 (Copilot / Cline / OpenClaw 等) と Skill 配布までカバーしています。

---

## 目次

1. [基本コンセプト](#基本コンセプト)
2. [6 つの汎用エージェントロール](#6-つの汎用エージェントロール)
3. [プロジェクト指示書 (AGENTS.md)](#プロジェクト指示書-agentsmd)
4. [MCP サーバ設定](#mcp-サーバ設定)
5. [Skill としてパッケージ化](#skill-としてパッケージ化)
6. [マルチツール対応](#マルチツール対応)
7. [チーム共有・配布](#チーム共有配布)
8. [推奨ワークフロー](#推奨ワークフロー)
9. [アンチパターン集](#アンチパターン集)

---

## 基本コンセプト

### ハーネスとは

エージェントが一貫した品質で動作するための設定一式:

- エージェントロール定義 (サブエージェント)
- プロジェクト指示書 (`AGENTS.md` / `CLAUDE.md`)
- MCP サーバ設定 (`.mcp.json`)

「同じプロジェクトで何度も同じ手順を踏む」状態を解消し、エージェントの出力品質を安定させる。

### 設計の核となる原則

1. **6 つの汎用ロール (Planner/Generator/Critic 等) で大半をカバー**
2. **専門エージェントは VoltAgent 等の既存カタログから補完** (任意、必要時のみ)
3. **AGENTS.md を主軸にしてマルチツール対応**
4. **ツール権限を最小化** (read-only ロールは Edit 権限を持たない)
5. **副作用ある操作は Executor に隔離**

---

## 6 つの汎用エージェントロール

実務で繰り返し有効と確認されている古典的な役割分担。プロジェクトに必要なものだけ採用する。

### ロール一覧

| ロール | 責務 | 副作用 | 推奨モデル |
|---|---|---|---|
| **Explorer** | 既存コード/ドキュメント/外部仕様の調査 | なし (read-only) | 軽量 |
| **Planner** | タスクの分解、実装計画の作成 | なし | 中〜上位 |
| **Generator** | 計画に従ってコード/設定/ドキュメントを生成 | ファイル編集 | 中〜上位 |
| **Critic** | Generator の出力を品質観点でレビュー | なし (read-only) | 中〜上位 |
| **Evaluator** | テスト/ビルド/ベンチマークを実行し合否判定 | コマンド実行 | 軽量 |
| **Executor** | デプロイ/マイグレーション等の副作用ある実行 | 強い副作用 | 中〜上位 |

### 構成パターン

- **最小構成 (3ロール)**: Planner / Generator / Evaluator
- **推奨構成 (5ロール)**: Explorer / Planner / Generator / Critic / Evaluator
- **フル構成 (6ロール)**: 上記 + Executor (副作用ある操作を分離管理)

### ツール権限の表

| ロール | Read | Edit | Write | Bash | Grep | Glob |
|---|---|---|---|---|---|---|
| Explorer | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ |
| Planner | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ |
| Generator | ✓ | ✓ | ✓ | △ | ✓ | ✓ |
| Critic | ✓ | ✗ | ✗ | ✗ | ✓ | ✓ |
| Evaluator | ✓ | ✗ | ✗ | ✓ | ✓ | ✗ |
| Executor | ✓ | ✗ | ✗ | ✓ | ✗ | ✗ |

### ロール定義ファイルの構造

`.claude/agents/<role-name>.md` に配置 (Markdown + YAML frontmatter):

```markdown
---
name: planner
description: タスクを実装可能な単位に分解し、実装計画を作成する専門。新機能追加、リファクタリング、複雑なバグ修正など、複数ステップを要するタスクで必ず使用する。
tools: Read, Grep, Glob
model: sonnet
---

あなたは Planner です。受け取った要求を実装可能な計画に変換します。

## 役割
- 要求を読み解き、必要な作業を明確化する
- 既存コードベースの制約を踏まえる
- 実装ステップに分解する

## ワークフロー
1. 要求を再確認し、曖昧な点を洗い出す
2. 既存コードへの影響範囲を見積もる
3. 作業を 3〜10 ステップに分解する
4. 各ステップの完了条件を明示する
5. リスクと代替案を記述する

## 制約
- ファイルを編集しない
- コマンドを実行しない
- 計画は具体的であること (「適切に修正する」のような曖昧表現は禁止)
- 1ステップ = 1コミット相当が目安
```

### description は「ラベル」ではなく「トリガー文」

最も重要なフィールド。これが「いつ呼ばれるか」を決める。

- **悪い例**: `description: コードレビュアー`
- **良い例**: `description: コミット前にコード変更を必ずレビューする。Generator の出力直後にも proactively 使用する。`

「MUST BE USED」「proactively」のような表現は自動発動を促す。

---

## プロジェクト指示書 (AGENTS.md)

毎セッションでエージェントが読むプロジェクトのコンテキスト。100 行以内に収める。

### テンプレート

```markdown
# <プロジェクト名>

<1〜3 行で説明>

## 技術スタック
- 言語/ランタイム: <例: Python 3.12 / Node 20 / Rust 1.78>
- パッケージマネージャ: <例: uv / pnpm / cargo>
- 主要フレームワーク: <例: FastAPI, React>
- テストフレームワーク: <例: pytest, vitest>

## 開発コマンド
- セットアップ: `<command>`
- テスト: `<command>`
- リント: `<command>`
- 型チェック: `<command>`
- フォーマット: `<command>`
- ビルド: `<command>`

## ディレクトリ構成
<主要なディレクトリ構造>

## コーディング規約
- ファイル命名: <例: kebab-case>
- 型: <例: 型ヒント必須>
- エラーハンドリング: <例: 例外を握りつぶさない>
- テスト: 新機能には必ずテストを追加
- コミットメッセージ: <例: Conventional Commits>

## 制約 (絶対にしてはいけないこと)
- `.env` や `secrets/` 配下を絶対にコミットしない
- 本番環境への破壊的な操作を確認なしに実行しない
- メジャーバージョンの依存関係更新を勝手に行わない

## エージェントロール
- explorer / planner / generator / critic / evaluator / executor

## 推奨ワークフロー
複雑なタスク: Explorer → Planner → Generator → Critic → Evaluator → (Executor)
簡単な変更: Generator → Evaluator
```

### 指示書のコツ

- **短く具体的に**: 「良いコードを書く」のような抽象論は無価値
- **否定形が強い**: 「○○しない」は守られやすい
- **コマンドは具体的に**: エージェントが推測しないよう実コマンドを書く

---

## MCP サーバ設定

プロジェクトレベルの設定は `.mcp.json` (リポジトリルート、`.claude/` の中ではない)。

### 基本形式

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

### 主要サーバの選定ガイド

| サーバ | 用途 | 推奨ケース |
|---|---|---|
| **context7** | ライブラリ最新ドキュメント参照 | 依存関係が頻繁に更新されるプロジェクト |
| **GitHub MCP** | Issue/PR/コード検索 | クロスリポ作業、自動化 |
| **DB MCP** | DB クエリ | 開発時のスキーマ確認 (本番は禁止) |
| **Filesystem MCP** | スコープ付きファイルアクセス | ほぼ不要 (Claude Code 標準で十分) |
| **ベクトルストア MCP** | RAG 検索 | RAG 開発中 |

### 鉄則

- **数を絞る**: 各サーバが毎ターンのコンテキストを消費する
- **トークンは環境変数経由**: `${ENV_VAR}` で参照、ハードコード厳禁
- **`.mcp.json` はリポジトリルート**: `.claude/` の中ではない

---

## Skill としてパッケージ化

### Skill の構造

```
my-skill/
├── SKILL.md                  # 発動条件 + ワークフロー (200 行以内)
├── references/               # 詳細ドキュメント (必要時のみ読み込み)
│   ├── role-patterns.md
│   ├── mcp-catalog.md
│   └── design-principles.md
└── templates/                # 自動生成に使うテンプレート
    ├── agents/
    │   ├── explorer.md
    │   ├── planner.md
    │   └── ...
    └── configs/
        ├── AGENTS.md
        └── mcp.json
```

### SKILL.md の frontmatter

```yaml
---
name: agent-harness-setup
description: "プロジェクトに AI エージェントハーネスを自動セットアップする。Planner/Generator/Evaluator 等のロール定義、AGENTS.md、MCP 設定を生成する。「ハーネスをセットアップして」「サブエージェントを設定して」「AGENTS.md を作って」のような依頼で発動する。"
---
```

**注意**: `description` にコロン `:` が含まれると YAML パースエラーになるので、ダブルクォートで囲むか、コロンを別の記号 (em dash `—` など) に置き換える。

### 配置場所

| スコープ | パス |
|---|---|
| ユーザー全体 (個人用) | `~/.claude/skills/<skill-name>/` |
| プロジェクト単位 (チーム共有) | `.claude/skills/<skill-name>/` |

---

## マルチツール対応

### 各ツールの設定ファイル

| ツール | プライマリ指示書 | エージェント定義 | Skill 配置 | MCP 設定 |
|---|---|---|---|---|
| Claude Code | `CLAUDE.md` | `.claude/agents/` | `.claude/skills/` | `.mcp.json` |
| GitHub Copilot | `AGENTS.md` | `.github/agents/` | `.agents/skills/` または `~/.copilot/skills/` | UI 経由 |
| Cline (VS Code 拡張) | カスタム指示 (UI) | (subagents 機能) | `~/.cline/skills/` または `.cline/skills/` | UI / 設定ファイル |
| OpenClaw | `AGENTS.md` | (限定的) | `~/.openclaw/workspace/skills/` | `~/.openclaw/workspace/config/mcporter.json` |
| Codex CLI | `AGENTS.md` | (限定的) | (限定的) | (限定的) |
| Gemini CLI | `GEMINI.md` または `AGENTS.md` | - | - | - |

### 推奨戦略: AGENTS.md を主軸に

**`AGENTS.md` をプロジェクトの主指示書とする**のが最もメンテしやすい。理由:

- ほぼ全ての主要エージェントツールが読む
- 1 ファイルで済むので情報の二重管理を避けられる
- 業界標準として定着している

### ファイル配置パターン

#### パターン A: 単一ツール利用

```
プロジェクト/
├── AGENTS.md
├── .claude/
│   └── agents/
│       ├── explorer.md
│       └── ...
└── .mcp.json
```

#### パターン B: マルチツール (Claude Code + Copilot + Cline)

```
プロジェクト/
├── AGENTS.md                    # 全ツール共通
├── .agents/skills/              # Copilot/オープン標準
│   └── agent-harness-setup/
├── .claude/
│   ├── agents/                  # Claude Code 用ロール
│   └── skills/                  # Claude Code 用 Skill
├── .github/agents/              # Copilot 用ロール (任意)
└── .mcp.json
```

#### 一括対応: シンボリックリンクで一元管理

```bash
# マスターを 1 箇所に置く
mkdir -p ~/skills-master
git clone https://github.com/fukui-yuto/agent-harness-skills.git ~/skills-master/

# 各ツールのパスにリンク
mkdir -p ~/.claude/skills ~/.copilot/skills ~/.cline/skills ~/.openclaw/workspace/skills

ln -sf ~/skills-master/agent-harness-skills/.agents/skills/agent-harness-setup ~/.claude/skills/agent-harness-setup
ln -sf ~/skills-master/agent-harness-skills/.agents/skills/agent-harness-setup ~/.copilot/skills/agent-harness-setup
ln -sf ~/skills-master/agent-harness-skills/.agents/skills/agent-harness-setup ~/.cline/skills/agent-harness-setup
ln -sf ~/skills-master/agent-harness-skills/.agents/skills/agent-harness-setup ~/.openclaw/workspace/skills/agent-harness-setup
```

`git pull` するだけで全 CLI の Skill が同時更新される。

---

## チーム共有・配布

### 配布方式の選択肢

| 方式 | 規模 | 自動更新 | 推奨度 |
|---|---|---|---|
| ファイル直接共有 (Slack/Drive) | 個人〜小規模 | × | △ |
| **GitHub プラグインマーケットプレイス** | 中規模〜公開 | ✓ | ◎ |
| 公式マーケットプレイス | 公開・OSS | ✓ | ○ |
| Claude Cowork (Team/Enterprise) | 組織内限定 | ✓ | ○ |

### GitHub マーケットプレイス公開 (推奨)

#### リポジトリ構造

```
my-marketplace/
├── README.md
├── LICENSE
├── .claude-plugin/
│   └── marketplace.json
└── plugins/
    └── agent-harness-setup/
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            └── agent-harness-setup/
                ├── SKILL.md
                ├── references/
                └── templates/
```

#### marketplace.json

```json
{
  "name": "fukui-yuto-tools",
  "owner": {
    "name": "Yuto Fukui",
    "url": "https://fukui-yuto.github.io/"
  },
  "description": "インフラ仮想化エンジニアが作る Claude Code プラグイン集",
  "plugins": [
    {
      "name": "agent-harness-setup",
      "source": "./plugins/agent-harness-setup",
      "description": "AI コーディングエージェントのハーネス自動セットアップ",
      "version": "1.0.0"
    }
  ]
}
```

#### plugin.json

```json
{
  "name": "agent-harness-setup",
  "version": "1.0.0",
  "description": "Planner/Generator/Evaluator 等の汎用ロールと AGENTS.md を自動生成",
  "author": { "name": "Yuto Fukui" }
}
```

#### 検証コマンド

```bash
claude plugin validate .
```

#### 利用者側のコマンド

```bash
# マーケットプレイス追加 (一度だけ)
claude plugin marketplace add fukui-yuto/my-marketplace

# プラグインインストール
claude plugin install agent-harness-setup@fukui-yuto-tools

# 後日アップデート
claude plugin marketplace update
```

### 更新フロー

1. `plugin.json` の `version` を上げる (semver)
2. `marketplace.json` の該当プラグインの `version` も合わせる
3. `git push`
4. 利用者は `claude plugin marketplace update` で取得

### マルチツール対応の配布リポジトリ構造

```
agent-harness-skills/
├── README.md
├── LICENSE
├── CHANGELOG.md
└── .agents/                          # オープン標準 (Copilot/Cline 等が読む)
    └── skills/
        └── agent-harness-setup/
            ├── SKILL.md
            ├── references/
            └── templates/
```

`.agents/skills/` 配下に置くだけで Copilot / Claude Code / Cline すべてが認識する。

---

## 推奨ワークフロー

### 複雑なタスクの場合

```
1. Explorer    → 既存コードを調査、関連箇所を特定
   ↓
2. Planner     → 実装計画を作成、ステップ分解
   ↓
3. Generator   → 計画に従って実装
   ↓
4. Critic      → 品質レビュー (バグ、セキュリティ、可読性)
   ↓
5. Evaluator   → テスト/ビルド/型チェック
   ↓
6. (Executor)  → デプロイや本番反映 (必要時のみ、dry-run 必須)
```

### 簡単な変更の場合

```
1. Generator   → タイポ修正、ログ追加など
   ↓
2. Evaluator   → 検証
```

### Executor の必須プロセス (副作用ある操作)

```
1. 意図確認
   ↓
2. Dry-run / Plan / Preview を提示
   ↓
3. 影響範囲とロールバック手順を明示
   ↓
4. ユーザー確認 (明示的承認)
   ↓
5. 適用
   ↓
6. 検証と報告
```

---

## アンチパターン集

### 過剰なロール定義

最初から 10 個のロールを定義しても誰も使わない。**2〜3 個で開始**し、繰り返し手動でやっている作業を発見したらロール化する。

### 全権限を持つロール

Read/Edit/Write/Bash すべてを持つロールは安全機構を失う。役割ごとに最小権限。

### AGENTS.md がマニフェスト化

「我々のチームは品質を重視します」のような抽象論は無価値。具体的なコマンド、規約、制約を書く。

### ロール間の責務重複

「テストもレビューもする」ロールは Critic と Evaluator を混ぜたもの。観点が違うので分けた方が品質が上がる。

### ハードコードされた秘密情報

`.mcp.json` などにトークンを直書きする事故は頻発する。常に `${ENV_VAR}` 経由で。

### 複数ツールで指示書が分裂

Claude Code、Copilot、Codex がそれぞれ別の指示を読んでいるとカオスになる。`AGENTS.md` を主軸に統合。

### ロール定義が更新されない

プロジェクトが進化するとコマンドや規約が変わる。ロール定義も更新しないと害になる。古くなったら削除する勇気を持つ。

### dry-run なしの Executor

副作用ある操作を確認なしに実行するのは事故のもと。Executor は必ず段階的実行。

### MCP サーバを増やしすぎる

各 MCP サーバが毎ターンのコンテキストを消費する。本当に必要なものだけに絞る。**3 個以下が目安**。

### `.mcp.json` を `.claude/` の中に置く

リポジトリルートが正しい配置。`.claude/` の中では認識されない。

### description が「ラベル」

```yaml
description: コードレビュアー  # 悪い: 発動しない
```

「いつ呼ばれるべきか」を書く:

```yaml
description: コミット前にコード変更を必ずレビューする。Generator の出力直後にも proactively 使用する。
```

---

## プロジェクト種別ごとの推奨セット

| プロジェクト種別 | ロール構成 | MCP サーバ |
|---|---|---|
| ライブラリ / CLI | Planner / Generator / Critic / Evaluator | なし or context7 |
| Web アプリケーション | Explorer / Planner / Generator / Critic / Evaluator | context7、ブラウザ MCP |
| データ処理 / ETL | Planner / Generator / Evaluator | DB MCP (開発環境) |
| LLM / RAG / ML | Explorer / Planner / Generator / Critic / Evaluator (フル) | context7、ベクトルストア MCP |
| インフラ自動化 (k8s/IaC) | フル 6 ロール (Executor 必須) | GitHub MCP |

---

## 既存カタログ (任意・補完用)

汎用 6 ロールでカバーしきれない特殊なニーズが出てきた場合のみ参照:

| カタログ | スター | 特徴 |
|---|---|---|
| **VoltAgent/awesome-claude-code-subagents** | 14.6k★ | 100+ 専門エージェント、10 カテゴリ |
| **wshobson/agents** | 大規模 | 184 エージェント、プラグイン形式 |
| **github/awesome-copilot** | - | Copilot 公式コミュニティカタログ |

導入例 (検討した場合):

```bash
claude plugin marketplace add VoltAgent/awesome-claude-code-subagents
claude plugin install voltagent-lang        # 言語専門家
claude plugin install voltagent-infra       # インフラ
```

**注意**: 補完は 0〜2 個に抑える。多すぎると混乱の元。

---

## 開発の進め方 (Claude Code で)

このドキュメントを Claude Code から参照する場合:

```bash
# プロジェクトルートで
mkdir -p docs
cp claude-code-development-guide.md docs/

# または CLAUDE.md からリンク
echo "詳細は [docs/claude-code-development-guide.md](docs/claude-code-development-guide.md) を参照" >> CLAUDE.md
```

Claude Code に「このプロジェクトにエージェントハーネスをセットアップして」と頼むときに、このドキュメントを @ で参照に含めると、設計思想に沿った構成を作ってくれる:

```
@docs/claude-code-development-guide.md に従って、
このプロジェクトにエージェントハーネスをセットアップして
```

---

## 参考リンク

- AGENTS.md 標準: https://agents.md/
- Claude Code ドキュメント: https://docs.claude.com/
- GitHub Copilot Skills: GitHub 公式ドキュメント
- Cline ドキュメント: https://docs.cline.bot/
- VoltAgent カタログ: https://github.com/VoltAgent/awesome-claude-code-subagents
- wshobson/agents: https://github.com/wshobson/agents

---

## 作者

[Yuto Fukui](https://fukui-yuto.github.io/) — インフラ仮想化領域のエンジニア

このガイドは Claude との対話を通じて作成された、AI エージェントハーネス設計の実践記録です。
