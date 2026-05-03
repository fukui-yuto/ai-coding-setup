# Gemini CLI 設定

このプロジェクトの主指示書は [AGENTS.md](AGENTS.md) を参照。
詳細な設計思想は [docs/requirements.md](docs/requirements.md) を参照。

## エージェントロール
- Explorer: 既存コード・ドキュメントの調査（read-only）
- Planner: タスク分解と実装計画の作成（read-only）
- Generator: 計画に従ったコード生成・編集
- Critic: 品質レビュー（read-only）
- Evaluator: テスト・ビルド・リントの実行と合否判定

## 推奨ワークフロー
- 複雑なタスク: Explorer → Planner → Generator → Critic → Evaluator
- 簡単な変更: Generator → Evaluator

## 制約
- `.env` や `secrets/` 配下を絶対にコミットしない
- 抽象的な指示（「適切に修正する」等）ではなく具体的なコマンド・ファイル名で指示する
