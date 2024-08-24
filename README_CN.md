[English](https://github.com/ReyReyy/sing-rule-set-json-auto-generate/blob/main/README.md) | 中文

# sing-box 规则集本地化脚本
自动生成包含所有 sing-box 规则集的 rule_set.json 文件

## 关于
众所周知，sing-box 有一个非常强大的功能 —— rule_set（规则集），它给我们带来很多有趣的玩法，但它不像 xray 的 geoip geosite 一样，把 dat 文件下载到本地，便于规则的书写/更改。这个脚本的目的就是为了改变这一状况，让 sing-box 也能像 xray 那样，只需简单几步便可轻松书写内建 geo 规则而不用额外写入规则集。

## 要求
系统：
- Debian / Ubuntu
- CentOS
- Fedora
- Arch Linux
- Maybe other similar systems 

软件包：
- Python
- git
- wget

## 如何使用
```
bash <(curl -L -s ruleset.reyreyy.net) [额外参数]
```

## 额外参数
```
menu               打开菜单。
generate           一次性生成，无额外系统更改。
install            安装脚本，每日自动更新规则。
uninstall          卸载脚本，包括已安装的脚本、rule_set.json 和 geo 文件。
```

## 例如
自动下载并写入规则集至 rule_set.json 并每日更新规则。
```
bash <(curl -L -s ruleset.reyreyy.net) install
```
打开菜单选择你想做的事情。
```
bash <(curl -L -s ruleset.reyreyy.net) menu
```

## 安装了，然后呢？
直接像写 xray 一样，写你想实现的规则。虽然可能和 xray 有点不太一样，但脚本帮了大忙了。

### 示例:

```
// sing-box 示例
{
    "route": {
        "rules": [
            {  // 拒绝 QUIC
                "port": 443,
                "network": "udp",
                "outbound": "block-out"
            },
            {  // 流媒体分流
                "rule_set": [
                    "geosite-netflix",
                    "geosite-openai",
                    "geosite-disney"
                ],
                "outbound": "warp-out"
            },
            {  // 中国网站分流
                "rule_set": "geosite-cn",
                "outbound": "warp-out"
            },
            {  // 中国ip分流
                "rule_set": "geoip-cn",
                "outbound": "warp-out"
            }
        ]
    }
}
```
```
// xray 示例
{
    "routing": {
        "rules": [
            {  // 拒绝 QUIC
                "port": "443",
                "network": "udp",
                "outboundTag": "block-out"
            },
            {  // 流媒体分流
                "domain": [
                    "geosite:netflix",
                    "geosite:openai",
                    "geosite:disney"
                ],
                "outboundTag": "warp-out"
            },
            {  // 中国网站分流
                "domain": "geosite:cn",
                "outboundTag": "warp-out"
            },
            {  // 中国ip分流
                "ip": "geoip:cn",
                "outboundTag": "warp-out"
            }
        ]
    }
}
```
一般来说，没有脚本的情况下 sing-box 示例并不能直接使用，需要额外规定 rule_set，但这个脚本免去了这个烦恼。
## 感谢
感谢 ChatGPT <br>
这个脚本 90% 是由 ChatGPT 生成，我只是做了一点小小的更改。 <br>
我其实完全不会写代码。 :\
