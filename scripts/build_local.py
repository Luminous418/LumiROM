#!/usr/bin/env python3

import argparse
import os
import subprocess
import shutil
import sys
import signal
from datetime import datetime

# ── Paths that must not exist before a clean build ──────────────────────────
TRANSIENT_DIRS = ["FIRMWARE", "WORK", "OUT", "TMP", "/dev/shm/WORK"]

# ── Required system binaries ─────────────────────────────────────────────────
REQUIRED_BINS = [
    "7z", "java", "python3", "simg2img",
    "aria2c", "brotli", "lz4", "tar", "file", "unzip",
]

class LumiROMBuilder:
    def __init__(
        self,
        device="SM-A325F",
        verbose=False,
        cache_dir="./CACHE",
        tethering=False,
        show_progress=True,
    ):
        self.device = device
        self.verbose = verbose
        self.show_progress = show_progress and not verbose
        self.cache_dir = os.path.abspath(cache_dir)
        self.ws_root = os.path.dirname(os.path.abspath(__file__))

        self.total_steps = 12
        self.current_step = 0

        self._acquire_sudo()

        self.env = os.environ.copy()
        self.env.update(
            {
                "STOCK_DEVICE": self.device,
                "USE_UI_8_TETHERING_APEX": "True" if tethering else "False",
                "OUTPUT_FILESYSTEM": "erofs",
                "LUMIROM_VERSION": "8.6.1",
                "OUT_DIR": os.path.join(self.ws_root, "OUT"),
                "TMP_DIR": os.path.join(self.ws_root, "TMP"),
                "WORK_DIR": "/dev/shm/WORK",
                "FIRM_DIR": os.path.join(self.ws_root, "FIRMWARE"),
                "DEVICES_DIR": os.path.join(self.ws_root, "LumiROM/Devices"),
                "APKTOOL": os.path.join(self.ws_root, "bin/apktool/apktool.jar"),
                "VNDKS_COLLECTION": os.path.join(self.ws_root, "LumiROM/vndks"),
                "BUILD_PARTITIONS": "product,vendor,odm,system_ext,system",
                "LUMI_VERBOSE": "True" if self.verbose else "False",
                "BUILD_STATUS": "UNOFFICIAL",
                "ROM_TAG": "🛠️ LumiROM Local Build",
            }
        )

    # ── Internal helpers ─────────────────────────────────────────────────────

    def _acquire_sudo(self):
        """Cache sudo credentials upfront so later calls never prompt mid-build."""
        if os.name == "nt":
            return
        print(">>> Requesting sudo for build operations...")
        try:
            subprocess.run(["sudo", "-v"], check=True)
        except subprocess.CalledProcessError:
            self._die("Sudo is required for some build steps.")

    @staticmethod
    def _die(msg, code=1):
        print(f"[!] {msg}")
        sys.exit(code)

    # ── Pre-flight checks ────────────────────────────────────────────────────

    @staticmethod
    def check_workspace_cleanliness():
        found = [d for d in TRANSIENT_DIRS if os.path.exists(d)]
        if found:
            LumiROMBuilder._die(
                f"Workspace is dirty. Found: {', '.join(found)}\n"
                "    Run './make clean' before starting a new build."
            )

    def check_dependencies(self):
        missing_bins = [b for b in REQUIRED_BINS if not shutil.which(b)]
        if missing_bins:
            self._die(f"Missing system dependencies: {', '.join(missing_bins)}")

        required_paths = [
            self.env["APKTOOL"],
            "scripts/LumiROM.sh",
            "scripts/zip_creation.sh",
            "scripts/Knox_script.sh",
            "bin/erofs-utils/extract.erofs",
            "bin/erofs-utils/mkfs.erofs",
            os.path.join(self.env["DEVICES_DIR"], self.device, "config"),
        ]
        missing_paths = [p for p in required_paths if not os.path.exists(p)]
        if missing_paths:
            self._die(
                "Missing project files/tools:\n"
                + "\n".join(f"  - {p}" for p in missing_paths)
            )

    # ── Progress bar ─────────────────────────────────────────────────────────

    def render_progress(self, milestone, sub_label=None):
        if not self.show_progress:
            return

        self.current_step += 1
        percent = int((self.current_step / self.total_steps) * 100)
        bar_length = 30
        filled = int(bar_length * self.current_step // self.total_steps)
        bar = "█" * filled + "-" * (bar_length - filled)

        sys.stdout.write(f"\r>>> Progress: |{bar}| {percent}% [{milestone}]\033[K\n")
        if sub_label:
            sys.stdout.write(f"    └─ Status: {sub_label}\033[K\r")
        else:
            sys.stdout.write("\033[K\r")
        sys.stdout.write("\033[A")
        sys.stdout.flush()

        if self.current_step == self.total_steps:
            sys.stdout.write("\n\033[K\r")
            sys.stdout.flush()

    # ── Shell runner ─────────────────────────────────────────────────────────

    def run_bash_cmd(self, cmd, label=None):
        """Source all helper scripts then run cmd in a single bash invocation."""
        if label and self.verbose:
            print(f"\n>>> {label}...")

        full_cmd = (
            "source scripts/LumiROM.sh; "
            "source scripts/zip_creation.sh; "
            "source scripts/Knox_script.sh; "
            f"{cmd}"
        )

        result = subprocess.run(
            ["bash", "-c", full_cmd],
            env=self.env,
            cwd=self.ws_root,
            capture_output=not self.verbose,
            text=True,
        )

        if result.returncode != 0:
            print(f"\n[!] Error during: {label or cmd}")
            if not self.verbose:
                if result.stdout:
                    print(result.stdout)
                if result.stderr:
                    print(result.stderr)
            sys.exit(1)

        return result.stdout

    # ── Build stages ─────────────────────────────────────────────────────────

    def setup_directories(self):
        # Make every binary in bin/ executable (ignoring __pycache__)
        subprocess.run(
            ["find", "bin/", "-type", "f", "-not", "-path", "*/__pycache__/*", "-exec", "chmod", "+x", "{}", "+"],
            check=False,
            cwd=self.ws_root,
        )
        # Create /dev/shm/WORK explicitly
        os.makedirs("/dev/shm/WORK", exist_ok=True)
        self.run_bash_cmd(
            "bash scripts/setup_directories.sh FIRMWARE WORK OUT TMP",
            "Directory setup",
        )
        os.makedirs(self.cache_dir, exist_ok=True)

    def handle_firmware(self):
        """
        Restore BASE_FW and vendor.img from cache when available;
        download and cache them otherwise.
        """
        if any(x in self.device for x in ["A325", "M325"]):
            fw_cache_name = "A34.tar.zst"
        else:
            fw_cache_name = "A24.tar.zst"

        cache_fw     = os.path.join(self.cache_dir, fw_cache_name)
        cache_vendor = os.path.join(self.cache_dir, f"{self.device}_vendor.img")
        target_fw     = os.path.join(self.env["FIRM_DIR"], "BASE_FW.tar.zst")
        target_vendor = os.path.join(self.env["FIRM_DIR"], "vendor.img")

        # ── BASE_FW ──────────────────────────────────────────────────────────
        if os.path.exists(cache_fw):
            print(">>> Using cached firmware.")
            shutil.copy2(cache_fw, target_fw)
        else:
            self.run_bash_cmd(
                'source "$DEVICES_DIR/$STOCK_DEVICE/config"; '
                'DOWNLOAD_FIRMWARE "$TARGET_DEVICE" "$FIRM_DIR"',
                "Firmware download",
            )
            if os.path.exists(target_fw):
                shutil.copy2(target_fw, cache_fw)
            # Cache vendor.img produced by the download while we're here
            if os.path.exists(target_vendor) and not os.path.exists(cache_vendor):
                shutil.copy2(target_vendor, cache_vendor)

        # ── vendor.img ───────────────────────────────────────────────────────
        if os.path.exists(cache_vendor):
            print(">>> Using cached vendor.img.")
            shutil.copy2(cache_vendor, target_vendor)
        elif not os.path.exists(target_vendor):
            self.run_bash_cmd(
                'source "$DEVICES_DIR/$STOCK_DEVICE/config"; '
                'DOWNLOAD_FIRMWARE "$TARGET_DEVICE" "$FIRM_DIR"',
                "Vendor download",
            )
            if os.path.exists(target_vendor):
                shutil.copy2(target_vendor, cache_vendor)

    def _patch_and_debloat(self):
        patch_cmd = """
        (
            DISABLE_FBE "FIRMWARE"
            DISABLE_FDE "FIRMWARE"
            DELETE_ICCC "FIRMWARE"
            DEBLOAT_VENDOR "FIRMWARE"
            PATCH_FSTAB_EROFS "FIRMWARE"
        ) &
        (
            APPLY_STOCK_CONFIG "FIRMWARE"
            DEBLOAT "FIRMWARE"
        ) &
        wait
        """
        self.run_bash_cmd(patch_cmd, "Patching & debloating")

    def _apply_features(self):
        features_cmd = 'APPLY_FEATURES "FIRMWARE" & LUMI_BOMBS "FIRMWARE" & wait'
        self.run_bash_cmd(features_cmd, "LumiBombs & features")
        self.run_bash_cmd('APPENDING_DISPLAY_ID "FIRMWARE"', "Appending display ID")

    def _patch_framework(self):
        framework_cmd = """
        INSTALL_FRAMEWORK "FIRMWARE/system/system/framework/framework-res.apk"
        RUN_SILENT java -jar "$APKTOOL" d -f "FIRMWARE/system/system/framework/ssrm.jar"     -o "$WORK_DIR/ssrm"     &
        RUN_SILENT java -jar "$APKTOOL" d -f "FIRMWARE/system/system/framework/services.jar" -o "$WORK_DIR/services" &
        wait
        PATCH_SSRM                    "$WORK_DIR/ssrm"
        PATCH_KNOX_GUARD              "$WORK_DIR/services"
        PATCH_FLAG_SECURE             "$WORK_DIR/services"
        PATCH_SECURE_FOLDER           "$WORK_DIR/services"
        PATCH_PRIVATE_SHARE           "$WORK_DIR/services"
        DISABLE_SIGNATURE_VERIFICATION "$WORK_DIR/services"
        RUN_SILENT java -jar "$APKTOOL" b "$WORK_DIR/ssrm"     --copy-original -p "$WORK_DIR" -o "$WORK_DIR/ssrm_built.jar"     &
        RUN_SILENT java -jar "$APKTOOL" b "$WORK_DIR/services" --copy-original -p "$WORK_DIR" -o "$WORK_DIR/services_built.jar" &
        wait
        cp -f "$WORK_DIR/ssrm_built.jar"     "FIRMWARE/system/system/framework/ssrm.jar"
        cp -f "$WORK_DIR/services_built.jar" "FIRMWARE/system/system/framework/services.jar"
        """
        self.run_bash_cmd(framework_cmd, "Framework patching")

    # ── Main build entry point ───────────────────────────────────────────────

    def build(self):
        success = False
        try:
            self.render_progress("Build Pipeline", "Dependency check")
            self.check_dependencies()

            self.render_progress("Build Pipeline", "Directory setup")
            self.setup_directories()

            self.render_progress("Build Pipeline", "Firmware cache")
            self.handle_firmware()

            self.render_progress("Extraction", "Archive extraction")
            self.run_bash_cmd('EXTRACT_FIRMWARE "FIRMWARE"', "Extracting firmware")

            self.render_progress("Extraction", "Partition selection")
            self.run_bash_cmd('PREPARE_PARTITIONS "FIRMWARE"', "Preparing partitions")

            self.render_progress("Extraction", "Image extraction")
            self.run_bash_cmd('EXTRACT_FIRMWARE_IMG "FIRMWARE"', "Extracting images")

            self.render_progress("ROM Modification", "Patching & debloating")
            self._patch_and_debloat()

            self.render_progress("ROM Modification", "LumiBombs & features")
            self._apply_features()

            self.render_progress("ROM Modification", "Framework patching")
            self._patch_framework()

            self.render_progress("Packaging", "Building partitions")
            self.run_bash_cmd(
                'BUILD_IMG "FIRMWARE" "$OUTPUT_FILESYSTEM" "$OUT_DIR"',
                "Building partition images",
            )

            self.render_progress("Packaging", "Updating metadata")
            self.run_bash_cmd(
                'UPDATE_ZIP_SCRIPT "FIRMWARE" "$OUT_DIR/ZIP_PACKAGE"',
                "Updating zip metadata",
            )

            self.render_progress("Build Pipeline", "ZIP creation")
            self.run_bash_cmd("FLASHABLE_ZIP_CREATION", "Creating flashable zip")

            out_dir = os.path.join(self.ws_root, "OUT")
            print(f"\n✓ Build completed. Output: {out_dir}/")
            success = True

        finally:
            self._cleanup()

        return success

    # ── Cleanup ──────────────────────────────────────────────────────────────

    def _cleanup(self):
        work_dir = self.env["WORK_DIR"]
        if os.path.exists(work_dir):
            if self.verbose:
                print(f">>> Cleaning RAM-disk workspace: {work_dir}")
            subprocess.run(["sudo", "rm", "-rf", work_dir], check=False)

        # Restore bin/ permissions (exclude img2sdat and __pycache__)
        subprocess.run(
            [
                "find", "bin/", "-type", "f",
                "!", "-path", "bin/img2sdat/img2sdat",
                "-not", "-path", "*/__pycache__/*",
                "-exec", "chmod", "0644", "{}", "+",
            ],
            check=False,
            cwd=self.ws_root,
        )

    @staticmethod
    def clean(clean_cache=False, cache_dir="./CACHE"):
        print(">>> Cleaning build environment...")
        
        # Using sudo rm -rf instead of shutil to bypass root-owned files/perms
        for p in TRANSIENT_DIRS:
            if os.path.exists(p):
                subprocess.run(["sudo", "rm", "-rf", p], check=False)
                print(f"  Removed: {p}")

        if clean_cache and os.path.isdir(cache_dir):
            subprocess.run(["sudo", "rm", "-rf", cache_dir], check=False)
            print(f"  Removed cache: {cache_dir}/")

        subprocess.run(
            [
                "find", "bin/", "-type", "f",
                "!", "-path", "bin/img2sdat/img2sdat",
                "-not", "-path", "*/__pycache__/*",
                "-exec", "chmod", "0644", "{}", "+",
            ],
            check=False,
        )
        print("Cleanup complete.")

# ── Signal handling ───────────────────────────────────────────────────────────

def _signal_handler(sig, frame):
    # Cursor down 2 lines and clear the line to gracefully escape progress bar rendering
    sys.stdout.write("\033[2E\r\033[K")
    sys.stdout.flush()
    print("[!] Build interrupted. Cleaning up...")
    LumiROMBuilder.clean()
    sys.exit(130)

# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    signal.signal(signal.SIGINT, _signal_handler)
    signal.signal(signal.SIGTERM, _signal_handler)

    # Integrity check — must run from repo root
    if not os.path.isdir("scripts") or not os.path.exists("scripts/LumiROM.sh"):
        print("[!] Must be run from the repository root.")
        sys.exit(1)

    parser = argparse.ArgumentParser(description="LumiROM Build System")
    sub = parser.add_subparsers(dest="command", required=True)

    # lumirom subcommand
    bp = sub.add_parser("lumirom", help="Execute the ROM build pipeline")
    bp.add_argument("-d", "--device",    default="SM-A325F", help="Device model (default: SM-A325F)")
    bp.add_argument("-v", "--verbose",   action="store_true", help="Show full command output")
    bp.add_argument("-c", "--cache",     default="./CACHE",   help="Firmware cache directory (default: ./CACHE)")
    bp.add_argument("-t", "--tethering", action="store_true", help="Enable UI 8.5 Tethering APEX patch")
    bp.add_argument("--no-progress",     action="store_true", help="Disable progress bar")
    bp.add_argument("--upload",          action="store_true", help="Upload result to Hugging Face after build")
    bp.add_argument("-i", "--interactive", action="store_true", help="Interactively configure the build")

    # clean subcommand
    cp = sub.add_parser("clean", help="Purge temporary build files")
    cp.add_argument("--clean-cache", action="store_true", help="Also remove the firmware cache")
    cp.add_argument("-c", "--cache", default="./CACHE", help="Cache directory (default: ./CACHE)")

    args = parser.parse_args()

    if args.command == "clean":
        LumiROMBuilder.clean(clean_cache=args.clean_cache, cache_dir=args.cache)
        return

    # ── lumirom ──────────────────────────────────────────────────────────────
    LumiROMBuilder.check_workspace_cleanliness()

    if args.interactive:
        print("\n>>> Interactive Build Setup")
        devices = sorted(os.listdir("LumiROM/Devices"))
        print(f"    Available models: {', '.join(devices)}")

        d = input(f"    Device model [{args.device}]: ").strip()
        if d:
            args.device = d

        args.tethering  = input("    UI 8.5 Tethering patch? (y/N): ").strip().lower() == "y"
        args.verbose    = input("    Verbose output? (y/N): ").strip().lower() == "y"
        args.no_progress = input("    Show progress bar? (Y/n): ").strip().lower() == "n"
        args.upload     = input("    Upload after build? (y/N): ").strip().lower() == "y"
        print()

    builder = LumiROMBuilder(
        device=args.device,
        verbose=args.verbose,
        cache_dir=args.cache,
        tethering=args.tethering,
        show_progress=not args.no_progress,
    )

    start = datetime.now()
    success = builder.build()
    elapsed = datetime.now() - start
    print(f"Elapsed: {elapsed}")

    if success and args.upload:
        print("\n>>> Starting upload...")
        upload_script = os.path.join("scripts", "upload_local.py")
        subprocess.run([sys.executable, upload_script], check=False)

if __name__ == "__main__":
    main()