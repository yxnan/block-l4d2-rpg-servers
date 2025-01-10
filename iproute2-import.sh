#!/usr/bin/bash
# iproute2-import.sh
#
# 该脚本用于导入黑洞路由，并提供清理黑洞路由的功能。
# 作者对 zsh 的语法更加熟悉，因此在编写 bash 脚本时尽可能使用了不会出错的方法。

# ANSI 转义序列用于设置文本颜色
# 该字符可以在大多数 Linux 终端中被识别，并执行特殊操作
# 更多信息请参考 [ANSI escape code](https://www.detailedpedia.com/wiki-ANSI_escape_code)

LOG_FORMATER="\033[%sm%s: %b\033[0m\n"

# 提供一个简单的日志方法
# 参数：
#   $1 - 日志级别（n|i|w|e|f）
#   $2... - 日志内容
# 输出：
#   将 Noice, Info 级别的日志输出到 stdout
#   将 Warn, Error, Fail 级别的日志输出到 stderr
# 返回值：
#   没有参数、参数小于二或参数错误则返回 0
function _log() {
    if [[ "$#" -lt 2 ]]; then
        return 0
    fi

    local level="$1"
    shift # 移除第一个参数，剩余参数为日志内容

    local content="$*"

    case "$level" in
    n | N)
        printf "$LOG_FORMATER" 35 "详细" "$content"
        ;;
    i | I)
        printf "$LOG_FORMATER" 32 "信息" "$content"
        ;;
    w | W)
        printf "$LOG_FORMATER" 33 "警告" "$content" >&2
        ;;
    e | E)
        printf "$LOG_FORMATER" 31 "错误" "$content" >&2
        ;;
    *)
        return 0
        ;;
    esac
}

# Noice 级别日志
function noice() { _log n "$@"; }

# Info 级别日志
function info() { _log i "$@"; }

# Warn 级别日志
function warn() { _log w "$@"; }

# Error 级别日志
function error() { _log e "$@"; }

# 等待用户按下 Enter
function pause() {
    read -p "按下 Enter 以继续..."
}

# 删除一条黑洞路由
function delete_blackhole() {
    ip route delete blackhole "$1" && info "已删除: $1"
}

# 添加一条黑洞路由
function add_blackhole() {
    ip route add blackhole "$1" && info "已添加: $1"
}

function show_blackhole() {
    ip route show type blackhole
}

# 清理黑洞路由
# 参数：
#   $1 - 清理模式（all 或 select）
function clean_up_route() {
    if [[ "$1" == "all" ]]; then
        for addr in "${BLACKHOLE_LIST[@]}"; do
            delete_blackhole "$addr"
        done
        return 0
    fi

    if [[ "$1" != "select" ]]; then
        return 1
    fi

    if [[ -z "$(which fzf)" ]]; then
        warn "未找到可用的 fzf 命令。使用 native 实现"
        clean_up_route_use_native "${BLACKHOLE_LIST[@]}"
    else
        clean_up_route_use_fzf "${BLACKHOLE_LIST[@]}"
    fi
}

# 使用 native 实现清理黑洞路由
# 参数：
#   $@ - 黑洞路由地址列表
function clean_up_route_use_native() {
    for addr in "$@"; do
        while :; do
            read -r -p "是否要删除条目 ${addr} [Y/n]" input
            case "$input" in
            y | Y | '') delete_blackhole "$addr" ;;
            n | N) ;;
            *) continue ;;
            esac
            break
        done
    done
}

# 使用 fzf 实现清理黑洞路由
# 参数：
#   $@ - 黑洞路由地址列表
function clean_up_route_use_fzf() {
    declare -A list=()
    for addr in "$@"; do
        list["$addr"]="$addr"
    done

    while [[ "${#list[@]}" -gt 0 ]]; do
        local addr="$({
            echo "按下 Esc 结束"
            for addr in "${list[@]}"; do
                echo "$addr"
            done
        } | fzf --header-lines=1)"

        if [[ -z "$addr" ]]; then
            break
        fi

        unset list["$addr"]
        delete_blackhole "$addr"
    done
}

# 检查权限
if [[ "$(id -u)" != "0" ]]; then
    error "请使用 root 权限运行脚本"
    exit 1
fi

# 检查参数
if [[ -z "$1" ]]; then
    error "请提供一个 RPG 服务器列表文件作为参数"
    exit 1
fi

# 检查文件是否存在
if [[ ! -f "$1" ]]; then
    error "$1 不是一个文件"
    exit 1
fi

# 检查 jq 命令是否存在
if [[ -z "$(which jq)" ]]; then
    warn "未找到可用的 jq 命令。但这并不是必须的，现有的 RPG 服务器列表文件可以使用系统内置命令完成解析。你可以忽略这个提示"
    pause
fi

# 检查 fzf 命令是否存在
if [[ -z "$(which fzf)" ]]; then
    warn "未找到可用的 fzf 命令。但这并不是必须的，该命令仅提供更方便的用户选择界面。你可以忽略这个提示"
    pause
fi

# 获取当前的黑洞路由列表
declare -a BLACKHOLE_LIST
while read -r addr; do
    BLACKHOLE_LIST+=("$addr")
done <<<"$(show_blackhole | cut -d ' ' -f 2 | sort -n)"

# 如果存在黑洞路由，询问用户是否清理
if [[ "${#BLACKHOLE_LIST}" -gt 0 ]]; then
    while :; do
        info "发现已有黑洞路由, 请问是否清理?"
        read -p "1.全部 2.自选 3.什么都不做 [默认选项: 3]: " input

        case "$input" in
        1) clean_up_route all ;;
        2) clean_up_route select ;;
        3 | '') ;;
        *) continue ;;
        esac

        break
    done
fi

while :; do
    read -p "要导入 RPG 服务器列表吗?[Y/n]: " input

    case "$input" in
    y | Y | '') break ;;
    n | N) exit 0 ;;
    *) continue ;;
    esac
done

# 从 RPG 服务器列表文件中导入黑洞路由
if [[ -z "$(which jq)" ]]; then
    warn "未找到可用的 jq 命令。使用 native 实现"
    grep -e "raddr" "$1" | sed -e 's/^ *"raddr": "//;s/",$//'
else
    jq -r '.data[].raddr' "$1"
fi | sort -n | while read -r addr; do
    add_blackhole "$addr"
done
