import os
import json
import subprocess
import shutil

site_url = "https://github.com/SagerNet/sing-geosite.git"
ip_url = "https://github.com/SagerNet/sing-geoip.git"
branch = "rule-set"
site_dir = "/etc/sing-box/sing-geosite"
ip_dir = "/etc/sing-box/sing-geoip"
output_file = "/etc/sing-box/rule_set.json"

if os.path.exists(site_dir):
    # print(f"Deleted {site_dir}...")
    shutil.rmtree(site_dir)

if os.path.exists(ip_dir):
    # print(f"Deleted {ip_dir}...")
    shutil.rmtree(ip_dir)

print(f"git cloning {site_url} ...")
subprocess.run(["git", "clone", "-b", branch, site_url, site_dir])

print(f"git cloning {ip_url} ...")
subprocess.run(["git", "clone", "-b", branch, ip_url, ip_dir])

config = {
    "route": {
        "rule_set": []
    }
}

for filename in os.listdir(site_dir):
    if filename.startswith("geosite-") and filename.endswith(".srs"):
        tag = filename.replace(".srs", "")
        config["route"]["rule_set"].append({
            "tag": tag,
            "type": "local",
            "format": "binary",
            "path": os.path.join(site_dir, filename)
        })

for filename in os.listdir(ip_dir):
    if filename.startswith("geoip-") and filename.endswith(".srs"):
        tag = filename.replace(".srs", "")
        config["route"]["rule_set"].append({
            "tag": tag,
            "type": "local",
            "format": "binary",
            "path": os.path.join(ip_dir, filename)
        })

config_json = json.dumps(config, indent=2)
# print(config_json)

with open(output_file, "w") as f:
    f.write(config_json)

print(f"The rule_set.json is successfully generated in {output_file}")
