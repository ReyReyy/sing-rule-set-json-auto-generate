import os
import json
import subprocess
import shutil

repo_url = "https://github.com/SagerNet/sing-geosite.git"
branch = "rule-set"
local_dir = "/etc/sing-box/sing-geosite"
output_file = "/etc/sing-box/rule_set.json"

if os.path.exists(local_dir):
    # print(f"Deleted {local_dir}...")
    shutil.rmtree(local_dir)

print(f"git cloning {repo_url} ...")
subprocess.run(["git", "clone", "-b", branch, repo_url, local_dir])

config = {
    "route": {
        "rule_set": []
    }
}

for filename in os.listdir(local_dir):
    if filename.startswith("geosite-") and filename.endswith(".srs"):
        tag = filename.replace(".srs", "")
        config["route"]["rule_set"].append({
            "tag": tag,
            "type": "local",
            "format": "binary",
            "path": os.path.join(local_dir, filename)
        })

config_json = json.dumps(config, indent=2)
# print(config_json)

with open(output_file, "w") as f:
    f.write(config_json)

print(f"The rule_set.json is successfully generated in {output_file}")
