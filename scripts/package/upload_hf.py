#!/usr/bin/env python3

import argparse
import os
import sys

from huggingface_hub import HfApi


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Upload a ROM zip to a Hugging Face bucket.")
    parser.add_argument("local_path", help="Local path of the .zip file to upload")
    parser.add_argument(
        "remote_path",
        help="Destination path inside the bucket",
    )
    parser.add_argument(
        "--bucket",
        default=os.environ.get("HF_BUCKET", None),
        help="Bucket id (owner/name). Defaults to $HF_BUCKET or $HF_USER/LumiROM",
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("HF_TOKEN", None),
        help="Hugging Face access token. Defaults to $HF_TOKEN",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()

    bucket = args.bucket
    if not bucket:
        hf_user = os.environ.get("HF_USER", "")
        if not hf_user:
            print("ERROR: no bucket given and HF_USER is not set.", file=sys.stderr)
            return 1
        bucket = f"{hf_user}/LumiROM"

    if not os.path.isfile(args.local_path):
        print(f"ERROR: File not found: {args.local_path}", file=sys.stderr)
        return 1

    api = HfApi(token=args.token)

    print(f"Uploading {args.local_path} -> hf://buckets/{bucket}/{args.remote_path}")
    try:
        api.batch_bucket_files(bucket, add=[(args.local_path, args.remote_path)])
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        return 130
    except Exception as exc:
        print(f"ERROR: upload failed: {exc}", file=sys.stderr)
        return 1

    # Verify the file is actually present in the bucket.
    try:
        files = list(api.get_bucket_paths_info(bucket, [args.remote_path]))
    except Exception as exc:
        print(f"ERROR: upload reported success but verification failed: {exc}", file=sys.stderr)
        return 1

    if not files:
        print("ERROR: file not found in the bucket after upload.", file=sys.stderr)
        return 1

    print(f"OK: verified {files[0].path} ({files[0].size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
