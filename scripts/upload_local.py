#!/usr/bin/env python3
import os
import subprocess
import argparse
from datetime import datetime
import getpass
import shutil
import sys

def main():
    parser = argparse.ArgumentParser(description="LumiROM Build Synchronization Utility (Hugging Face)")
    parser.add_argument("-t", "--token", help="Hugging Face API Access Token (if not in HF_TOKEN env variable)")
    parser.add_argument("-s", "--source", default="./OUT", help="Source directory (default: ./OUT)")
    parser.add_argument("-e", "--endpoint", default="hf://buckets/Zears14/lumifiles/out", help="Xet bucket endpoint")
    
    args = parser.parse_args()
    
    # Check for hf binary
    if not shutil.which("hf"):
        print("[!] HF CLI tool not found. Install it first.")
        sys.exit(1)
        
    # Handle Token
    token = args.token or os.environ.get("HF_TOKEN")
    if not token:
        print("HF_TOKEN not found in environment.")
        token = getpass.getpass("Enter HF Access Token: ")
        if not token:
            print("[!] Token required for upload.")
            return
        os.environ["HF_TOKEN"] = token
    else:
        os.environ["HF_TOKEN"] = token

    # Configuration
    # Use URL-safe timestamp and add -local suffix to distinguish from workflow builds
    date_str = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ") + "-local"
    target_url = f"{args.endpoint}/{date_str}/"
    os.environ["HF_XET_HIGH_PERFORMANCE"] = "1"

    print(f"Syncing {args.source} to {target_url}")

    # Synchronize
    try:
        subprocess.run(
            ["hf", "buckets", "sync", args.source, target_url, "--include", "*.zip"],
            check=True
        )
        print("Upload complete.")
    except subprocess.CalledProcessError:
        print("[!] Sync failed. Check network or token permissions.")

if __name__ == "__main__":
    main()
