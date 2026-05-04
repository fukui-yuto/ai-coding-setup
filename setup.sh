#!/bin/bash
set -euo pipefail
shopt -s nullglob

# ai-coding-setup セットアップスクリプト
# 使用するツールを選択し、必要なファイルのみをプロジェクトに導入します。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

VALID_TOOLS="claude-code copilot cline codex gemini openclaw all"

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
  --clean              選択されなかったツールの既存ファイルを削除する
  --dry-run            実際にはファイルを変更せず、何が行われるかを表示する
  --help               このヘルプを表示

例:
  ./setup.sh ~/my-project --tool claude-code
  ./setup.sh ~/my-project --tool copilot
  ./setup.sh ~/my-project --tool claude-code --tool copilot
  ./setup.sh ~/my-project --tool all
  ./setup.sh ~/my-project --tool claude-code --clean
  ./setup.sh ~/my-project --tool all --dry-run

ツールを指定しない場合は対話的に選択できます。
HELP
}

# --- 色付き出力 ---
info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[OK]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }

# --- 安全なコピー（既存ファイルの上書き警告） ---
FORCE=false
CLEAN=false
DRY_RUN=false

safe_cp() {
  local src="$1"
  local dest="$2"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] コピー: $src → $dest"
    return
  fi
  if [[ -f "$dest" ]]; then
    if [[ "$FORCE" == "true" ]]; then
      info "上書き: $dest"
    else
      warn "既存ファイルを上書きします: $dest"
    fi
  fi
  cp "$src" "$dest"
}

safe_mkdir() {
  local dir="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] ディレクトリ作成: $dir"
    return
  fi
  mkdir -p "$dir"
}

safe_rm() {
  local target="$1"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] 削除: $target"
    return
  fi
  if [[ -d "$target" ]]; then
    rm -rf "$target"
  elif [[ -f "$target" ]]; then
    rm "$target"
  fi
}

safe_rmdir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    return
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] 空ディレクトリ削除: $dir"
    return
  fi
  rmdir "$dir" 2>/dev/null || warn "ディレクトリが空でないため残しました: $dir"
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
      if ! echo "$VALID_TOOLS" | grep -qw "$2"; then
        echo "エラー: 不明なツール名: $2"
        echo "有効なツール名: $VALID_TOOLS"
        exit 1
      fi
      TOOLS+=("$2")
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
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
[[ "$DRY_RUN" == "true" ]] && info "モード: dry-run（実際の変更は行いません）"
[[ "$CLEAN" == "true" ]] && info "クリーンアップ: 有効"
echo ""

# --- 1. AGENTS.md（全ツール共通、必須） ---
safe_cp "$SCRIPT_DIR/AGENTS.md" "$PROJECT_DIR/AGENTS.md"
success "AGENTS.md をコピーしました"

# --- 2. Claude Code ---
if has_tool "claude-code"; then
  safe_cp "$SCRIPT_DIR/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"
  safe_cp "$SCRIPT_DIR/.mcp.json" "$PROJECT_DIR/.mcp.json"
  safe_mkdir "$PROJECT_DIR/.claude/agents"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] コピー: $SCRIPT_DIR/.claude/agents/*.md → $PROJECT_DIR/.claude/agents/"
  else
    local_files=("$SCRIPT_DIR/.claude/agents/"*.md)
    [[ ${#local_files[@]} -gt 0 ]] && cp "${local_files[@]}" "$PROJECT_DIR/.claude/agents/"
  fi
  success "Claude Code: CLAUDE.md, .mcp.json, .claude/agents/ をセットアップ"
fi

# --- 3. GitHub Copilot ---
if has_tool "copilot"; then
  safe_mkdir "$PROJECT_DIR/.github/agents"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] コピー: $SCRIPT_DIR/.github/agents/*.md → $PROJECT_DIR/.github/agents/"
  else
    local_files=("$SCRIPT_DIR/.github/agents/"*.md)
    [[ ${#local_files[@]} -gt 0 ]] && cp "${local_files[@]}" "$PROJECT_DIR/.github/agents/"
  fi
  safe_mkdir "$PROJECT_DIR/.vscode"
  safe_cp "$SCRIPT_DIR/.vscode/mcp.json" "$PROJECT_DIR/.vscode/mcp.json"
  success "GitHub Copilot: .github/agents/, .vscode/mcp.json をセットアップ"
fi

# --- 4. Cline ---
if has_tool "cline"; then
  safe_mkdir "$PROJECT_DIR/.cline/agents"
  if [[ "$DRY_RUN" == "true" ]]; then
    info "[dry-run] コピー: $SCRIPT_DIR/.cline/agents/*.md → $PROJECT_DIR/.cline/agents/"
  else
    local_files=("$SCRIPT_DIR/.cline/agents/"*.md)
    [[ ${#local_files[@]} -gt 0 ]] && cp "${local_files[@]}" "$PROJECT_DIR/.cline/agents/"
  fi
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

# --- 8. 不要ファイルのクリーンアップ（--clean 指定時のみ） ---
if [[ "$CLEAN" == "true" ]]; then
  CLEANED=false

  if ! has_tool "claude-code"; then
    for f in "$PROJECT_DIR/CLAUDE.md" "$PROJECT_DIR/.mcp.json"; do
      if [[ -f "$f" ]]; then
        safe_rm "$f"
        CLEANED=true
      fi
    done
    if [[ -d "$PROJECT_DIR/.claude/agents" ]]; then
      safe_rm "$PROJECT_DIR/.claude/agents"
      safe_rmdir "$PROJECT_DIR/.claude"
      CLEANED=true
    fi
  fi

  if ! has_tool "copilot"; then
    if [[ -d "$PROJECT_DIR/.github/agents" ]]; then
      safe_rm "$PROJECT_DIR/.github/agents"
      safe_rmdir "$PROJECT_DIR/.github"
      CLEANED=true
    fi
    if [[ -f "$PROJECT_DIR/.vscode/mcp.json" ]]; then
      safe_rm "$PROJECT_DIR/.vscode/mcp.json"
      safe_rmdir "$PROJECT_DIR/.vscode"
      CLEANED=true
    fi
  fi

  if ! has_tool "cline"; then
    if [[ -d "$PROJECT_DIR/.cline" ]]; then
      safe_rm "$PROJECT_DIR/.cline"
      CLEANED=true
    fi
  fi

  if ! has_tool "gemini"; then
    if [[ -f "$PROJECT_DIR/GEMINI.md" ]]; then
      safe_rm "$PROJECT_DIR/GEMINI.md"
      CLEANED=true
    fi
  fi

  if [[ "$CLEANED" == "true" ]]; then
    success "選択されなかったツールの不要ファイルを削除しました"
  fi
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
