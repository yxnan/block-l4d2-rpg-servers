# 文件说明
|      文件名      |                    说明                     |
| :--------------: | :-----------------------------------------: |
|   rpglist.json   | IP屏蔽列表名单，包含常见的求生之路RPG服务器 |
| rpglist-build.py |     用于交互式建立屏蔽列表的python脚本      |

永久更新地址（每周五晚更新）：https://yxnan.cn/misc/rpglist.json



# 屏蔽方法

### Windows

下载`rpglist.json`，导入火绒或者其他类似能提供IP过滤名单的软件，不再赘述



### Linux

（提供Ubuntu/Mint的方案，其他distro请自行对号入座）


1. 下载屏蔽IP名单

   ```bash
   curl https://raw.githubusercontent.com/typowritter/block-l4d2-rpg-servers/master/rpglist.json -o rpglist.json
   ```

2. 安装命令行JSON parser和ipset

   ```bash
   sudo apt install jq ipset
   ```

3. 新建屏蔽列表 l4d2-rpg-blacklist

   ```bash
   sudo ipset create l4d2-rpg-blacklist hash:ip hashsize 4096
   ```

4. 解析名单里的所有IP并加入屏蔽列表

   ```bash
   jq -r '.data[].raddr' rpglist.json | xargs -L1 sudo ipset add l4d2-rpg-blacklist
   ```

5. 启用屏蔽列表

   ```bash
   sudo iptables -I OUTPUT -p UDP -m set --match-set l4d2-rpg-blacklist dst -j DROP
   ```

OK，现在列表中的RPG服就被全部屏蔽了，你将不会在游戏中任何地方看到它们。

如果要手动加入你自己的IP，直接`sudo ipset add l4d2-rpg-blacklist xx.xx.xx.xx`

### 更新列表

如果本列表有更新，只需要`sudo ipset flush l4d2-rpg-blacklist`先清空旧的ipset列表再导入新的即可，无需重新添加iptables规则。

### 持久化

上述方法存在一个问题，由于iptables和ipset规则默认并不会保存，会在重启后丢失。可以有两种方法解决：

- 方法一（**推荐**，方便更新列表）：将上述步骤保存为Shell Script，设置每次开机时执行
- 方法二（如果你知道自己在做什么）：建立一个持久化服务，在每次退出时保存iptables和ipset规则，并在启动时恢复。参考：[Using ipset to block IP addresses - firewall](https://confluence.jaytaala.com/display/TKB/Using+ipset+to+block+IP+addresses+-+firewall)，以及[Make ip-tables (firewall) rules persistent](https://confluence.jaytaala.com/display/TKB/Make+ip-tables+(firewall)+rules+persistent)





