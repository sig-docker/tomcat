import sys
import yaml
import json
import argparse
import textwrap
import datetime

from pydantic import BaseModel
from typing import List, Optional
from functools import lru_cache


class AcceptModel(BaseModel):
    id: str
    reason: str
    until: Optional[datetime.date]


class ConfigModel(BaseModel):
    accept: List[AcceptModel]


@lru_cache
def config_accepts_vuln_id(id):
    global config
    accepts = [a for a in config.accept if a.id == id]
    if len(accepts) < 1:
        return False
    a = accepts[0]
    if a.until and a.until < datetime.date.today():
        print(f"NOT accepting {a.id} because its 'until' time has passed: {a.until}\n")

    until = f" UNTIL {a.until}" if a.until else ""
    reason = textwrap.indent(a.reason.strip(), "  ")
    print(f"Accepting {a.id}{until} because:\n{reason}\n")
    return True


def should_accept(vuln):
    return config_accepts_vuln_id(vuln["id"])


def check_path(path):
    if path["ok"]:
        return path

    vulns = [v for v in path["vulnerabilities"] if not should_accept(v)]

    return {**path, "vulnerabilities": vulns, "ok": len(vulns) < 1}


def accepted_not_detected(data):
    global config
    accepted = {a.id for a in config.accept}
    detected = {v["id"] for p in data for v in p["vulnerabilities"]}
    nds = list(accepted - detected)
    nds.sort()
    if len(nds) > 0:
        print(f"\n{'-'*80}\nVulnerabilities accepted but not detected:\n{'-'*80}\n")
        print(yaml.dump(list(nds)))
        print("\n")


def go():
    global config
    parser = argparse.ArgumentParser()
    parser.add_argument("config_path", type=argparse.FileType("r"))
    parser.add_argument("json_path", type=argparse.FileType("r"))
    args = parser.parse_args()

    with args.config_path as fp:
        config = ConfigModel(**yaml.load(fp, Loader=yaml.Loader))

    with args.json_path as fp:
        data = json.load(fp)

    paths = [check_path(p) for p in data]
    paths = [p for p in paths if not p["ok"]]

    vulns = [v for p in paths for v in p["vulnerabilities"]]
    vulns = {v["id"]: v for v in vulns}

    accepted_not_detected(data)

    if len(vulns) > 0:
        print("*" * 80)
        print("Vulnerabilities Detected")
        print("*" * 80)
        print(yaml.dump(vulns))
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    go()
