#!/usr/bin/env bash
# Claude Code statusLine command
# Mirrors Powerlevel10k prompt style: dir | git | model | context

input=$(cat)

# Parse all fields in a single node call — outputs tab-separated on one line
_parsed=$(echo "$input" | node -e "
let d='';
process.stdin.on('data',c=>d+=c);
process.stdin.on('end',()=>{
  try {
    const o=JSON.parse(d);
    const cwd=o.workspace?.current_dir||o.cwd||'';
    const model=o.model?.display_name||'';
    const effort=o.effort?.level||'';
    const cw=o.context_window||{};
    const cur=cw.current_usage;
    let used=0;
    if(cur){
      used=(cur.input_tokens||0)+(cur.output_tokens||0)
           +(cur.cache_creation_input_tokens||0)+(cur.cache_read_input_tokens||0);
    }
    const size=cw.context_window_size||200000;
    const pct=cw.used_percentage!=null?cw.used_percentage:(used>0?(used/size*100):null);
    const rl=o.rate_limits||{};
    const fh=rl.five_hour||{};
    const sd=rl.seven_day||{};
    const v=x=>(x==null?'':x);
    const cost=o.cost||{};
    // Any extra rate-limit buckets beyond five_hour/seven_day
    // (e.g. seven_day_sonnet, seven_day_opus) — rendered dynamically.
    const extra=Object.entries(rl)
      .filter(([k])=>k!=='five_hour'&&k!=='seven_day')
      .map(([k,b])=>{
        const label=k.replace('seven_day','7d').replace('five_hour','5h').replace(/_/g,'-');
        return [label,v(b.used_percentage),v(b.resets_at)].join(':');
      }).join(';');
    console.log([
      cwd, model, used, size, pct!=null?pct.toFixed(1):'',
      v(fh.used_percentage), v(fh.resets_at),
      v(sd.used_percentage), v(sd.resets_at), effort,
      v(cost.total_cost_usd), v(cost.total_duration_ms), extra
    ].join('\t'));
  } catch(e){ console.log('\t\t0\t200000\t\t\t\t\t\t\t\t\t'); }
});
" 2>/dev/null)

cwd=$(echo "$_parsed"    | cut -f1)
model=$(echo "$_parsed"  | cut -f2)
ctx_used=$(echo "$_parsed" | cut -f3)
ctx_size=$(echo "$_parsed" | cut -f4)
used_pct=$(echo "$_parsed" | cut -f5)
fh_pct=$(echo "$_parsed"   | cut -f6)
fh_reset=$(echo "$_parsed" | cut -f7)
sd_pct=$(echo "$_parsed"   | cut -f8)
sd_reset=$(echo "$_parsed" | cut -f9)
effort=$(echo "$_parsed"   | cut -f10)
cost_usd=$(echo "$_parsed" | cut -f11)
dur_ms=$(echo "$_parsed"   | cut -f12)
extra_rl=$(echo "$_parsed" | cut -f13)

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch (skip lock to avoid blocking)
git_branch=""
if [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir --no-optional-locks > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$git_branch" ]; then
    git_branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  fi
fi

# Build status line \u2014 three visual blocks:
#   1: path + branch   2: effort + model   3: ctx + quotas
b1=()
b2=()
b3=()

# Directory segment
printf -v dir_seg "\033[34m%s\033[0m" "$short_cwd"
b1+=("$dir_seg")

# Git branch segment
if [ -n "$git_branch" ]; then
  printf -v git_seg "\033[32m\u2387  %s\033[0m" "$git_branch"
  b1+=("$git_seg")
fi

# Model segment
model_seg=""
if [ -n "$model" ]; then
  printf -v model_seg "\033[35m%s\033[0m" "$model"
fi

# Effort segment (reasoning effort level: low / medium / high)
if [ -n "$effort" ]; then
  # Heat scale across the five effort levels: low … max
  case "$effort" in
    low)    eff_color="\033[32m" ;;          # green
    medium) eff_color="\033[33m" ;;          # yellow
    high)   eff_color="\033[38;5;208m" ;;    # orange (256-color)
    xhigh)  eff_color="\033[31m" ;;          # red
    max)    eff_color="\033[1;38;5;201m" ;;  # bold magenta — beyond the scale
    *)      eff_color="\033[35m" ;;          # magenta fallback
  esac
  printf -v eff_seg "${eff_color}ϟ %s\033[0m" "$effort"
fi

# Block 2 order: effort, then model
[ -n "${eff_seg:-}" ] && b2+=("$eff_seg")
[ -n "$model_seg" ] && b2+=("$model_seg")

# Context usage segment: percent only + window size tag (1M / 200k)
if [ -n "$used_pct" ] && [ -n "$ctx_used" ] && [ "$ctx_used" -gt 0 ] 2>/dev/null; then
  used_int=$(printf "%.0f" "$used_pct")

  if [ "$ctx_size" -ge 1000000 ] 2>/dev/null; then
    size_tag="$((ctx_size / 1000000))M"
  else
    size_tag="$((ctx_size / 1000))k"
  fi

  if [ "$used_int" -ge 75 ]; then
    color="\033[31m"  # red when critical (>=75%)
    printf -v ctx_seg "${color}ctx: %d%% [%s] COMPACT!\033[0m" "$used_int" "$size_tag"
  elif [ "$used_int" -ge 50 ]; then
    color="\033[33m"  # yellow when medium
    printf -v ctx_seg "${color}ctx: %d%% [%s]\033[0m" "$used_int" "$size_tag"
  else
    color="\033[36m"  # cyan when low
    printf -v ctx_seg "${color}ctx: %d%% [%s]\033[0m" "$used_int" "$size_tag"
  fi
  b3+=("$ctx_seg")
elif [ -n "$used_pct" ]; then
  # Fallback: no token count available, show percent only
  used_int=$(printf "%.0f" "$used_pct")
  if [ "$used_int" -ge 75 ]; then
    printf -v ctx_seg "\033[31mctx: %d%% COMPACT!\033[0m" "$used_int"
  elif [ "$used_int" -ge 50 ]; then
    printf -v ctx_seg "\033[33mctx: %d%%\033[0m" "$used_int"
  else
    printf -v ctx_seg "\033[36mctx: %d%%\033[0m" "$used_int"
  fi
  b3+=("$ctx_seg")
fi

# Right-aligned block: session cost + duration
right_parts=()

# Session cost segment
if [ -n "$cost_usd" ]; then
  cost_fmt=$(printf "%.2f" "$cost_usd" 2>/dev/null)
  if [ -n "$cost_fmt" ]; then
    printf -v cost_seg "\033[37m\$%s\033[0m" "$cost_fmt"
    right_parts+=("$cost_seg")
  fi
fi

# Session duration segment
if [ -n "$dur_ms" ] && [ "$dur_ms" -gt 0 ] 2>/dev/null; then
  dur_s=$((dur_ms / 1000))
  dur_h=$((dur_s / 3600))
  dur_m=$(((dur_s % 3600) / 60))
  if [ "$dur_h" -gt 0 ]; then
    dur_fmt="${dur_h}h${dur_m}m"
  else
    dur_fmt="${dur_m}m"
  fi
  printf -v dur_seg "\033[37mt: %s\033[0m" "$dur_fmt"
  right_parts+=("$dur_seg")
fi

# Helper: format seconds-until-reset as "Xh Ym" or "Xm"
fmt_eta() {
  local target="$1"
  [ -z "$target" ] && return
  local now=$(date +%s)
  local delta=$((target - now))
  [ "$delta" -le 0 ] && { echo "soon"; return; }
  local h=$((delta / 3600))
  local m=$(((delta % 3600) / 60))
  if [ "$h" -gt 0 ]; then
    echo "${h}h${m}m"
  else
    echo "${m}m"
  fi
}

# Helper: pace indicator — compares quota burn rate vs uniform rate.
# ratio = used% / elapsed% of the window. Tokens cancel out, so the API's
# used_percentage is enough; absolute token counts are not exposed anyway.
pace_ind() {
  local pct="$1" reset="$2" win="$3"
  [ -z "$pct" ] || [ -z "$reset" ] || [ -z "$win" ] && return
  local now=$(date +%s)
  local kind=$(awk -v pct="$pct" -v reset="$reset" -v now="$now" -v win="$win" '
    BEGIN{
      rem = reset - now;
      if (rem < 0) rem = 0;
      if (rem > win) rem = win;
      el = win - rem;
      # First 5% of the window: too early to judge the pace
      if (el < win * 0.05) { print "early"; exit }
      expected = el / win * 100;
      r = pct / expected;
      if      (r >= 2.0) print "hh";
      else if (r >= 1.2) print "h";
      else if (r >  0.8) print "ok";
      else if (r >  0.5) print "l";
      else               print "ll";
    }' 2>/dev/null)
  case "$kind" in
    hh)    printf "\033[1;31m▲▲\033[0m" ;;  # strong overspend (>=2x pace)
    h)     printf "\033[33m▲\033[0m"    ;;  # overspend (>=1.2x)
    ok)    printf "\033[90m◆\033[0m"    ;;  # on pace (0.8–1.2x)
    l)     printf "\033[32m▼\033[0m"    ;;  # underspend (<=0.8x)
    ll)    printf "\033[1;92m▼▼\033[0m" ;;  # strong underspend (<=0.5x)
    early) printf "\033[90m~\033[0m"    ;;  # window just started
  esac
}

# Helper: format quota segment with color by percentage
quota_seg() {
  local label="$1" pct="$2" reset="$3" win="$4"
  [ -z "$pct" ] && return
  local pct_int=$(printf "%.0f" "$pct")
  local color
  if [ "$pct_int" -ge 80 ]; then
    color="\033[31m"   # red
  elif [ "$pct_int" -ge 50 ]; then
    color="\033[33m"   # yellow
  else
    color="\033[32m"   # green
  fi
  local ind=$(pace_ind "$pct" "$reset" "$win")
  local eta=$(fmt_eta "$reset")
  local out
  printf -v out "${color}%s: %d%%\033[0m" "$label" "$pct_int"
  [ -n "$eta" ] && printf -v out "%s${color} [%s]\033[0m" "$out" "$eta"
  [ -n "$ind" ] && out="${out} ${ind}"
  printf '%s' "$out"
}

# 5-hour quota segment
fh_seg=$(quota_seg "5h" "$fh_pct" "$fh_reset" 18000)
[ -n "$fh_seg" ] && b3+=("$fh_seg")

# 7-day quota segment
sd_seg=$(quota_seg "7d" "$sd_pct" "$sd_reset" 604800)
[ -n "$sd_seg" ] && b3+=("$sd_seg")

# Extra per-model quota buckets (e.g. 7d-sonnet, 7d-opus), if the API reports them
if [ -n "$extra_rl" ]; then
  IFS=';' read -ra _buckets <<< "$extra_rl"
  for _b in "${_buckets[@]}"; do
    _label="${_b%%:*}"
    _rest="${_b#*:}"
    _pct="${_rest%%:*}"
    _reset="${_rest#*:}"
    case "$_label" in
      7d*) _win=604800 ;;
      5h*) _win=18000 ;;
      *)   _win="" ;;
    esac
    _seg=$(quota_seg "$_label" "$_pct" "$_reset" "$_win")
    [ -n "$_seg" ] && b3+=("$_seg")
  done
fi

# Join: items within a block by "|", blocks by a wider dotted gap
separator=" \033[90m|\033[0m "
block_sep="   \033[90m·\033[0m   "

join_block() {
  local out="" item
  for item in "$@"; do
    [ -z "$item" ] && continue
    if [ -z "$out" ]; then out="$item"; else out="${out}${separator}${item}"; fi
  done
  printf '%s' "$out"
}

result=""
for blk in "$(join_block "${b1[@]}")" "$(join_block "${b2[@]}")" "$(join_block "${b3[@]}")"; do
  [ -z "$blk" ] && continue
  if [ -z "$result" ]; then result="$blk"; else result="${result}${block_sep}${blk}"; fi
done

# Right-aligned block (cost + duration), padded to terminal width
right=""
for i in "${!right_parts[@]}"; do
  if [ "$i" -eq 0 ]; then
    right="${right_parts[$i]}"
  else
    right="${right}${separator}${right_parts[$i]}"
  fi
done

if [ -n "$right" ]; then
  # Terminal width: stdout is a pipe, so query the controlling tty
  cols=$({ stty size < /dev/tty; } 2>/dev/null | cut -d' ' -f2)
  [ -z "$cols" ] && cols="${COLUMNS:-}"
  [ -z "$cols" ] && cols=$(tput cols 2>/dev/null)
  [ -z "$cols" ] && cols=0

  # Visible length = expanded string minus ANSI escapes (wc -m is UTF-8 aware)
  visible_len() {
    printf "%b" "$1" | sed 's/\x1b\[[0-9;]*m//g' | wc -m
  }

  if [ "$cols" -gt 0 ] 2>/dev/null; then
    left_len=$(visible_len "$result")
    right_len=$(visible_len "$right")
    # Symbols like ⏱ occupy 2 terminal cells but wc -m counts 1 — compensate
    wide_extra=$(printf "%b" "${result}${right}" | grep -o '⏱' | wc -l)
    pad=$((cols - left_len - right_len - wide_extra - 5))
    if [ "$pad" -gt 0 ]; then
      result="${result}$(printf '%*s' "$pad" '')${right}"
    else
      result="${result}${separator}${right}"
    fi
  else
    result="${result}${separator}${right}"
  fi
fi

printf "%b\n" "$result"
