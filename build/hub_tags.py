#!/usr/bin/env python3

import sys
import argparse
import json
import urllib.request


def iter_tags(ns, repo, page_size=10000):
    url = (
        f"https://hub.docker.com/v2/repositories/{ns}/{repo}/tags?page_size={page_size}"
    )
    while url:
        print(f"Fetching {url}", file=sys.stderr)
        with urllib.request.urlopen(url) as res:
            if res.status != 200:
                raise IOError(f"URL '{url}' returned status {res.status}")
            data = json.load(res)
            for tag in data["results"]:
                yield tag["name"]
            url = data.get("next")


def go():
    parser = argparse.ArgumentParser(description="List tags from Docker Hub")
    parser.add_argument("namespace", help="image namespace")
    parser.add_argument("repository", help="image repository")
    args = parser.parse_args()
    for tag in iter_tags(args.namespace, args.repository):
        print(tag)


if __name__ == "__main__":
    go()
