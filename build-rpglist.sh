#!/bin/bash

api_key="$1"

if [ ${#api_key} -ne 32 ]; then
    echo -e "Usage: \n\t $(basename "$0") API_KEY\n"
    echo "ERROR: need a valid api_key, get it from https://steamcommunity.com/dev/apikey"
    exit 1
fi

rpg_name_pattern=$(echo '
      [^非]RPG
    | 戮
    | 弑
    | 巅
    | 凡
    | 玄
    | 天下
    | 神域
    | 完美世界
    | 一念仙行录
    | 窥仙之路
    | 风花雪月
    | 暗黑之魂
    | 午夜狂欢
    | 無人永生
    | 神之右手
    | 军魂
    | 星缘
    | 破晓
    | 腐尸之地
    | 猎人
    | 通天塔
    | 无法逃脱
    | 穷途末路
    ' \
    | tr -d '[:space:]'
)

# Generate rpglist.json
curl -sS --get \
    'http://api.steampowered.com/IGameServersService/GetServerList/v1' \
    --header 'Accept: application/json' \
    --data-urlencode "key=$api_key" \
    --data-urlencode "filter=\appid\550\nor\9\gametype\official\white\1\region\0\region\1\region\2\region\3\region\5\region\6\region\7" \
    --data-urlencode "limit=100000" \
| jq '
    {
        "ver": "5.1",
        "tag": "ipblacklist",
        "data": [
            .response.servers[]
            | with_entries( select([.key] | inside( ["name", "addr"] )) )
            | select( .name | test("'"$rpg_name_pattern"'") )
            | .addr = (.addr | split(":") | .[0])
            | .["raddr"] = .addr | del(.addr)
            | .["memo"] = .name | del(.name)
        ]
        | unique_by(.raddr)
    }' \
> rpglist.json

# Generate for win: BlockRpg.ps1
iplist_ps1=$(cat rpglist.json | jq --raw-output '
    .data
    | map(.raddr)
    | join("\", \"")
')

echo '
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$rulename = "Block L4D2 RPG Servers"
$iplist = @("'"$iplist_ps1"'")

if ( Get-NetFirewallRule -DisplayName $rulename 2>$null ) {
    echo "Updating existing rule: ""$rulename"""
    Set-NetFirewallRule `
        -DisplayName $rulename `
        -RemoteAddress $iplist
} else {
    echo "Creating new rule: ""$rulename"""
    New-NetFirewallRule `
        -DisplayName $rulename `
        -Direction Outbound `
        -Protocol "udp" `
        -Action Block `
        -RemoteAddress $iplist
}

Read-Host -Prompt "------------- Done. -------------" | Out-Null
' \
> BlockRpg.ps1

# Generate for unix: block-rpg.sh
iplistname=l4d2-rpg-blacklist
iplist_bash=$(cat rpglist.json | jq --raw-output '
    .data
    | map(["add '"$iplistname"'", .raddr])[]
    | join(" ")
')

echo '#!/bin/bash
iplistname='"$iplistname"'
tmpfile=$(mktemp -t ipset-XXXX)

cat << EOF > $tmpfile
create $iplistname hash:ip family inet hashsize 4096 maxelem 65536
flush $iplistname
'"$iplist_bash"'
EOF

ipset restore -! < $tmpfile
rm -rf $tmpfile

if [ $(iptables -L | grep -c $iplistname) -eq 0 ]; then
    iptables -I OUTPUT -p UDP -m set --match-set $iplistname dst -j DROP
fi
' \
> block-rpg.sh

