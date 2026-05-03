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
                       ※ all と個別指定を混在させた場合は all が優先されます
  --force              既存ファイルを確認なしで上書き
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

# --- 安全なコピー（既存ファイルの上書き警告） ---
FORCE=false

safe_cp() {
  local src="$1"
  local dest="$2"
  if [[ -f "$dest" && "$FORCE" != "true" ]]; then
    warn "既存ファイルを上書きします: $dest"
  fi
  cp "$src" "$dest"
}

# --- 引数パース ---
PROJECT_DIR=""
TOOLS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)
      if [[ -z "${2:-}" ]]; then
        echo "エラー: --tool にはツール名を指定してください"
        echo ""
        show_help
        exit 1
      fi
      TOOLS+=("$2")
      shift 2
      ;;
    --force)
      FORCE=true
      shift
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

INPUT_DIR="$PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
  echo "エラー: ディレクトリが存在しません: $INPUT_DIR"
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

  if [[ -z "$selection" ]]; then
    echo "ツールが選択されませんでした。"
    exit 1
  fi

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
      "") ;;
      *) warn "不明な選択: $sel（スキップ）" ;;
    esac
  done
fi

if [[ ${#TOOLS[@]} -eq 0 ]]; then
  echo "ツールが選択されませんでした。"
  exit 1
fi

# "all" の展開（all と個別指定の混在時は all が優先）
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
safe_cp "$SCRIPT_DIR/AGENTS.md" "$PROJECT_DIR/AGENTS.md"
success "AGENTS.md をコピーしました"

# --- 2. Claude Code ---
if has_tool "claude-code"; then
  safe_cp "$SCRIPT_DIR/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"
  safe_cp "$SCRIPT_DIR/.mcp.json" "$PROJECT_DIR/.mcp.json"
  mkdir -p "$PROJECT_DIR/.claude/agents"
  cp "$SCRIPT_DIR/.claude/agents/"*.md "$PROJECT_DIR/.claude/agents/"
  success "Claude Code: CLAUDE.md, .mcp.json, .claude/agents/ をセットアップ"
fi

# --- 3. GitHub Copilot ---
if has_tool "copilot"; then
  mkdir -p "$PROJECT_DIR/.github/agents"
  cp "$SCRIPT_DIR/.github/agents/"*.md "$PROJECT_DIR/.github/agents/"
  mkdir -p "$PROJECT_DIR/.vscode"
  safe_cp "$SCRIPT_DIR/.vscode/mcp.json" "$PROJECT_DIR/.vscode/mcp.json"
  success "GitHub Copilot: .github/agents/, .vscode/mcp.json をセットアップ"
fi

# --- 4. Cline ---
if has_tool "cline"; then
  mkdir -p "$PROJECT_DIR/.cline/agents"
  cp "$SCRIPT_DIR/.cline/agents/"*.md "$PROJECT_DIR/.cline/agents/"
  safe_cp "$SCRIPT_DIR/.cline/mcp_settings.json" "$PROJECT_DIR/.cline/mcp_settings.json"
  success "Cline: .cline/agents/, .cline/mcp_settings.json をセットアップ"
fi

# --- 5. Codex CLI ---
if has_tool "codex"; then
  success "Codex CLI: AGENTS.md で対応（追加ファイルなし）"
fi

# --- 6. Gemini CLI ---
if has_tool "gemini"; then
  safe_cp "$SCRIPT_DIR/GEMINI.md" "$PROJECT_DIR/GEMINI.md"
  success "Gemini CLI: GEMINI.md をセットアップ"
fi

# --- 7. OpenClaw ---
if has_tool "openclaw"; then
  success "OpenClaw: AGENTS.md で対応（追加ファイルなし）"
fi

# --- 8. 不要ファイルのクリーンアップ ---
CLEANED=false

if ! has_tool "claude-code"; then
  for f in "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/.mcp.json"; do
    if [[ -f "$f" ]]; then
      rm "$f"
      CLEANED=true
    fi
  done
  if [[ -d "$PROJECT_DIR/.claude/agents" ]]; then
    rm -rf "$PROJECT_DIR/.claude/agents"
    # .claude/ が空なら削除
    rmdir "$PROJECT_DIR/.claude" 2>/dev/null || true
    CLEANED=true
  fi
fi

if ! has_tool "copilot"; then
  if [[ -d "$PROJECT_DIR/.github/agents" ]]; then
    rm -rf "$PROJECT_DIR/.github/agents"
    # .github/ が空なら削除（他の用途で使われている場合は残す）
    rmdir "$PROJECT_DIR/.github" 2>/dev/null || true
    CLEANED=true
  fi
  if [[ -f "$PROJECT_DIR/.vscode/mcp.json" ]]; then
    rm "$PROJECT_DIR/.vscode/mcp.json"
    rmdir "$PROJECT_DIR/.vscode" 2>/dev/null || true
    CLEANED=true
  fi
fi

if ! has_tool "cline"; then
  if [[ -d "$PROJECT_DIR/.cline" ]]; then
    rm -rf "$PROJECT_DIR/.cline"
    CLEANED=true
  fi
fi

if ! has_tool "gemini"; then
  if [[ -f "$PROJECT_DIR/GEMINI.md" ]]; then
    rm "$PROJECT_DIR/GEMINI.md"
    CLEANED=true
  fi
fi

if [[ "$CLEANED" == "true" ]]; then
  success "選択されなかったツールの不要ファイルを削除しました"
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
echo "  3. 詳細は https://github.com/fukui-yuto/ai-coding-setup/blob/main/docs/usage.md を参照"
echo ""
