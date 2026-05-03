#!/bin/bash
set -euo pipefail

# ai-coding-setup セットアップスクリプト
# 使用するツールを選択し、必要なファイルのみをプロジェクトに導入します。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- ヘルプ ---
show_help() {
  cat <<'HELP'
使い方:
  ./setup.sh <プロジェクトパス> [オプション]

オプション:
  --tool <ツール名>    使用するツールを指定（複数指定可）
                       claude-code, copilot, cline, codex, gemini, openclaw, all
  --help               このヘルプを表示

例:
  ./setup.sh ~/my-project --tool claude-code
  ./setup.sh ~/my-project --tool copilot
  ./setup.sh ~/my-project --tool claude-code --tool copilot
  ./setup.sh ~/my-project --tool all

ツールを指定しない場合は対話的に選択できます。
HELP
}

# --- 色付き出力 ---
info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[OK]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }

# --- 引数パース ---
PROJECT_DIR=""
TOOLS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)
      TOOLS+=("$2")
      shift 2
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      if [[ -z "$PROJECT_DIR" ]]; then
        PROJECT_DIR="$1"
      else
        echo "不明な引数: $1"
        show_help
        exit 1
      fi
      shift
      ;;
  esac
done

# --- プロジェクトパス確認 ---
if [[ -z "$PROJECT_DIR" ]]; then
  echo "プロジェクトパスを指定してください。"
  echo ""
  show_help
  exit 1
fi

PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
  echo "エラー: ディレクトリが存在しません: $PROJECT_DIR"
  exit 1
}

# --- 対話的ツール選択 ---
if [[ ${#TOOLS[@]} -eq 0 ]]; then
  echo ""
  echo "========================================="
  echo "  ai-coding-setup セットアップ"
  echo "========================================="
  echo ""
  echo "使用するツールを選択してください（複数選択可）:"
  echo ""
  echo "  1) Claude Code"
  echo "  2) GitHub Copilot"
  echo "  3) Cline"
  echo "  4) Codex CLI"
  echo "  5) Gemini CLI"
  echo "  6) OpenClaw"
  echo "  7) すべて"
  echo ""
  read -rp "番号をカンマ区切りで入力 (例: 1,2): " selection

  IFS=',' read -ra SELECTIONS <<< "$selection"
  for sel in "${SELECTIONS[@]}"; do
    sel="$(echo "$sel" | tr -d ' ')"
    case "$sel" in
      1) TOOLS+=("claude-code") ;;
      2) TOOLS+=("copilot") ;;
      3) TOOLS+=("cline") ;;
      4) TOOLS+=("codex") ;;
      5) TOOLS+=("gemini") ;;
      6) TOOLS+=("openclaw") ;;
      7) TOOLS=("all"); break ;;
      *) warn "不明な選択: $sel（スキップ）" ;;
    esac
  done
fi

if [[ ${#TOOLS[@]} -eq 0 ]]; then
  echo "ツールが選択されませんでした。"
  exit 1
fi

# "all" の展開
for tool in "${TOOLS[@]}"; do
  if [[ "$tool" == "all" ]]; then
    TOOLS=("claude-code" "copilot" "cline" "codex" "gemini" "openclaw")
    break
  fi
done

# --- ツール判定ヘルパー ---
has_tool() {
  local target="$1"
  for tool in "${TOOLS[@]}"; do
    [[ "$tool" == "$target" ]] && return 0
  done
  return 1
}

# --- セットアップ開始 ---
echo ""
info "プロジェクト: $PROJECT_DIR"
info "選択ツール: ${TOOLS[*]}"
echo ""

# --- 1. AGENTS.md（全ツール共通、必須） ---
cp "$SCRIPT_DIR/AGENTS.md" "$PROJECT_DIR/AGENTS.md"
success "AGENTS.md をコピーしました"

# --- 2. Claude Code ---
if has_tool "claude-code"; then
  cp "$SCRIPT_DIR/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"
  cp "$SCRIPT_DIR/.mcp.json" "$PROJECT_DIR/.mcp.json"
  mkdir -p "$PROJECT_DIR/.claude/agents"
  cp "$SCRIPT_DIR/.claude/agents/"*.md "$PROJECT_DIR/.claude/agents/"
  success "Claude Code: CLAUDE.md, .mcp.json, .claude/agents/ をセットアップ"
fi

# --- 3. GitHub Copilot ---
if has_tool "copilot"; then
  mkdir -p "$PROJECT_DIR/.github/agents"
  cp "$SCRIPT_DIR/.github/agents/"*.md "$PROJECT_DIR/.github/agents/"
  mkdir -p "$PROJECT_DIR/.vscode"
  cp "$SCRIPT_DIR/.vscode/mcp.json" "$PROJECT_DIR/.vscode/mcp.json"
  success "GitHub Copilot: .github/agents/, .vscode/mcp.json をセットアップ"
fi

# --- 4. Cline ---
if has_tool "cline"; then
  mkdir -p "$PROJECT_DIR/.cline/agents"
  cp "$SCRIPT_DIR/.cline/agents/"*.md "$PROJECT_DIR/.cline/agents/"
  cp "$SCRIPT_DIR/.cline/mcp_settings.json" "$PROJECT_DIR/.cline/mcp_settings.json"
  success "Cline: .cline/agents/, .cline/mcp_settings.json をセットアップ"
fi

# --- 5. Codex CLI ---
if has_tool "codex"; then
  # AGENTS.md のみ（共通セットアップで済み）
  success "Codex CLI: AGENTS.md で対応（追加ファイルなし）"
fi

# --- 6. Gemini CLI ---
if has_tool "gemini"; then
  cp "$SCRIPT_DIR/GEMINI.md" "$PROJECT_DIR/GEMINI.md"
  success "Gemini CLI: GEMINI.md をセットアップ"
fi

# --- 7. OpenClaw ---
if has_tool "openclaw"; then
  # AGENTS.md のみ（共通セットアップで済み）
  success "OpenClaw: AGENTS.md で対応（追加ファイルなし）"
fi

# --- 完了 ---
echo ""
echo "========================================="
echo "  セットアップ完了"
echo "========================================="
echo ""
echo "次のステップ:"
echo "  1. $PROJECT_DIR/AGENTS.md を自分のプロジェクトに合わせて編集"
echo "  2. MCP 設定のトークンを環境変数で設定"
echo "  3. 詳細は docs/usage.md を参照"
echo ""
