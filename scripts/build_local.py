#!/usr/bin/env python3
import argparse
import os
import subprocess
import shutil
import sys
import signal
from datetime import datetime

class LumiROMBuilder:
    def __init__(self, device="SM-A325F", verbose=False, cache_dir="./CACHE", tethering=False, show_progress=True):
        self.device = device
        self.verbose = verbose
        # Strictly disable progress bar if verbose is requested
        self.show_progress = show_progress and not verbose
        self.cache_dir = os.path.abspath(cache_dir)
        self.ws_root = os.getcwd()
        
        self.total_steps = 12
        self.current_step = 0
        # Check for sudo upfront to cache credentials
        if os.name != 'nt':
            print(">>> Requesting sudo for build operations...")
            try:
                subprocess.run(["sudo", "-v"], check=True)
            except subprocess.CalledProcessError:
                print("[!] Error: Sudo is required for some build steps.")
                sys.exit(1)

        # Configuration
        self.env = os.environ.copy()
        self.env.update({
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
            "ROM_TAG": "🛠️ LumiROM Local Build"
        })

    @staticmethod
    def check_workspace_cleanliness():
        """Ensure transient build directories do not exist before starting."""
        transient = ["FIRMWARE", "WORK", "OUT", "TMP", "/dev/shm/WORK"]
        found = [d for d in transient if os.path.exists(d)]
        
        if found:
            print(f"[!] Error: Workspace is dirty. Found existing build directories: {', '.join(found)}")
            print("    Please run './make clean' before starting a new build.")
            sys.exit(1)

    def check_dependencies(self):
        """Verify that required system binaries and project files exist."""
        required_bins = ["7z", "java", "python3", "simg2img", "aria2c", "brotli", "lz4", "tar", "file", "unzip"]
        missing = []
        for b in required_bins:
            if not shutil.which(b):
                missing.append(b)
        
        if missing:
            print(f"[!] Missing system dependencies: {', '.join(missing)}")
            sys.exit(1)

        # Check project-specific paths
        required_paths = [
            self.env["APKTOOL"],
            "scripts/LumiROM.sh",
            "scripts/zip_creation.sh",
            "scripts/Knox_script.sh",
            "bin/erofs-utils/extract.erofs",
            "bin/erofs-utils/mkfs.erofs",
            os.path.join(self.env["DEVICES_DIR"], self.device, "config")
        ]
        
        for p in required_paths:
            if not os.path.exists(p):
                print(f"[!] Missing project file/tool: {p}")
                sys.exit(1)

    def render_progress(self, milestone, sub_label=None):
        """Render a two-line text-based progress bar."""
        if not self.show_progress:
            return
            
        self.current_step += 1
        percent = int((self.current_step / self.total_steps) * 100)
        bar_length = 30
        filled_length = int(bar_length * self.current_step // self.total_steps)
        bar = '█' * filled_length + '-' * (bar_length - filled_length)
        
        # Line 1: Main Progress Bar
        sys.stdout.write(f'\r>>> Progress: |{bar}| {percent}% [{milestone}]\033[K\n')
        
        # Line 2: Active Task (shipped one line down)
        if sub_label:
            sys.stdout.write(f'    └─ Status: {sub_label}\033[K\r')
        else:
            sys.stdout.write('\033[K\r')
            
        # Move cursor back up for next cycle
        sys.stdout.write('\033[A')
        sys.stdout.flush()

        if self.current_step == self.total_steps:
            # Clear subline and move down on final step
            sys.stdout.write('\n\033[K\r')
            sys.stdout.flush()

    def run_bash_cmd(self, cmd, label=None):
        if label and self.verbose:
            print(f"\n>>> {label}...")
        
        full_cmd = f"source scripts/LumiROM.sh; source scripts/zip_creation.sh; source scripts/Knox_script.sh; {cmd}"
        
        process = subprocess.run(
            ["bash", "-c", full_cmd],
            env=self.env,
            cwd=self.ws_root,
            capture_output=not self.verbose,
            text=True
        )
        
        if process.returncode != 0:
            print(f"\n[!] Error during: {label if label else cmd}")
            if not self.verbose:
                print(process.stdout)
                print(process.stderr)
            sys.exit(1)
        return process.stdout

    def setup_directories(self):
        # Ensure all binaries in bin/ are executable
        subprocess.run(["find", "bin/", "-type", "f", "-exec", "chmod", "+x", "{}", "+"], check=False)
        self.run_bash_cmd("bash scripts/setup_directories.sh FIRMWARE WORK OUT")
        os.makedirs(self.cache_dir, exist_ok=True)

    def handle_firmware(self):
        if any(x in self.device for x in ["A325", "M325"]):
            cache_name = "A34.tar.zst"
        else:
            cache_name = "A24.tar.zst"
            
        cache_path = os.path.join(self.cache_dir, cache_name)
        target_path = os.path.join(self.env["FIRM_DIR"], "BASE_FW.tar.zst")

        if os.path.exists(cache_path):
            shutil.copy2(cache_path, target_path)
        else:
            self.run_bash_cmd(
                f"source $DEVICES_DIR/$STOCK_DEVICE/config; DOWNLOAD_FIRMWARE \"$TARGET_DEVICE\" \"$FIRM_DIR\"",
                "Firmware download"
            )
            shutil.copy2(target_path, cache_path)

    def build(self):
        try:
            self.check_workspace_cleanliness()
            
            self.render_progress("Build Pipeline", "Dependency Check")
            self.check_dependencies()
            
            self.render_progress("Build Pipeline", "Directory Setup")
            self.setup_directories()
            
            self.render_progress("Build Pipeline", "Firmware Cache")
            self.handle_firmware()
            
            self.render_progress("Extraction", "Archive Extraction")
            self.run_bash_cmd("EXTRACT_FIRMWARE \"FIRMWARE\"")
            
            self.render_progress("Extraction", "Partition Selection")
            self.run_bash_cmd("PREPARE_PARTITIONS \"FIRMWARE\"")
            
            self.render_progress("Extraction", "Image Extraction")
            self.run_bash_cmd("EXTRACT_FIRMWARE_IMG \"FIRMWARE\"")
            
            self.render_progress("ROM Modification", "Patching & Debloating")
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
            self.run_bash_cmd(patch_cmd)

            self.render_progress("ROM Modification", "LumiBombs & Features")
            features_cmd = "APPLY_FEATURES \"FIRMWARE\" & LUMI_BOMBS \"FIRMWARE\" & wait"
            self.run_bash_cmd(features_cmd)
            self.run_bash_cmd("APPENDING_DISPLAY_ID \"FIRMWARE\"")
            
            self.render_progress("ROM Modification", "Framework Patching")
            framework_cmd = """
            INSTALL_FRAMEWORK "FIRMWARE/system/system/framework/framework-res.apk"
            RUN_SILENT java -jar "$APKTOOL" d -f "FIRMWARE/system/system/framework/ssrm.jar" -o "$WORK_DIR/ssrm" &
            RUN_SILENT java -jar "$APKTOOL" d -f "FIRMWARE/system/system/framework/services.jar" -o "$WORK_DIR/services" &
            wait
            PATCH_SSRM "$WORK_DIR/ssrm"
            PATCH_KNOX_GUARD "$WORK_DIR/services"
            PATCH_FLAG_SECURE "$WORK_DIR/services"
            PATCH_SECURE_FOLDER "$WORK_DIR/services"
            PATCH_PRIVATE_SHARE "$WORK_DIR/services"
            DISABLE_SIGNATURE_VERIFICATION "$WORK_DIR/services"
            RUN_SILENT java -jar "$APKTOOL" b "$WORK_DIR/ssrm" --copy-original -p "$WORK_DIR" -o "$WORK_DIR/ssrm_built.jar" &
            RUN_SILENT java -jar "$APKTOOL" b "$WORK_DIR/services" --copy-original -p "$WORK_DIR" -o "$WORK_DIR/services_built.jar" &
            wait
            cp -fv "$WORK_DIR"/*_built.jar "FIRMWARE/system/system/framework/"
            mv "FIRMWARE/system/system/framework/ssrm_built.jar" "FIRMWARE/system/system/framework/ssrm.jar"
            mv "FIRMWARE/system/system/framework/services_built.jar" "FIRMWARE/system/system/framework/services.jar"
            """
            self.run_bash_cmd(framework_cmd)

            self.render_progress("Packaging", "Building Partitions")
            self.run_bash_cmd("BUILD_IMG \"FIRMWARE\" \"$OUTPUT_FILESYSTEM\" \"$OUT_DIR\"")
            
            self.render_progress("Packaging", "Updating Metadata")
            self.run_bash_cmd("UPDATE_ZIP_SCRIPT \"FIRMWARE\" \"$OUT_DIR/ZIP_PACKAGE\"")
            
            self.render_progress("Build Pipeline", "ZIP Package Creation")
            self.run_bash_cmd("FLASHABLE_ZIP_CREATION")

            print("\nBuild completed.")
            print(f"Output: {os.path.join(self.ws_root, 'OUT/*.zip')}")
            return True
            
        finally:
            self.cleanup_workdir()
            self.restore_tool_permissions()

    def cleanup_workdir(self):
        """Purge the RAM-disk workspace."""
        work_dir = self.env["WORK_DIR"]
        if os.path.exists(work_dir):
            if self.verbose: print(f">>> Cleaning up RAM-disk workspace: {work_dir}")
            subprocess.run(["sudo", "rm", "-rf", work_dir], check=False)

    def restore_tool_permissions(self):
        """Restore tool binaries to non-executable state (0644), excluding only the primary img2sdat binary."""
        if self.verbose: print(">>> Restoring tool permissions (0644), excluding bin/img2sdat/img2sdat...")
        # find bin/ -type f ! -path "bin/img2sdat/img2sdat" -exec chmod 0644 {} +
        subprocess.run(["find", "bin/", "-type", "f", "!", "-path", "bin/img2sdat/img2sdat", "-exec", "chmod", "0644", "{}", "+"], check=False)

    @staticmethod
    def clean(clean_cache=False, cache_dir="./CACHE"):
        print(">>> Cleaning build environment...")
        paths_to_remove = ["FIRMWARE", "WORK", "OUT", "TMP", "/dev/shm/WORK"]
        
        for p in paths_to_remove:
            if os.path.isdir(p):
                shutil.rmtree(p)
                print(f"  Removed directory: {p}")
            elif os.path.isfile(p):
                os.remove(p)
                print(f"  Removed file: {p}")

        if clean_cache:
            if os.path.isdir(cache_dir):
                shutil.rmtree(cache_dir)
                print(f"  Removed cache directory: {cache_dir}")

        subprocess.run(["find", "bin/", "-type", "f", "!", "-path", "bin/img2sdat/img2sdat", "-exec", "chmod", "0644", "{}", "+"], check=False)
        print("Cleanup complete.")

def signal_handler(sig, frame):
    """Handle interrupt signals by cleaning up and exiting."""
    print("\n\n[!] Build interrupted. Cleaning up transient workspace...")
    LumiROMBuilder.clean()
    sys.exit(130)

def main():
    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    parser = argparse.ArgumentParser(description="LumiROM Build System")
    subparsers = parser.add_subparsers(dest="command", required=True, help="Available commands")

    # LumiROM subcommand
    build_parser = subparsers.add_parser("lumirom", help="Execute the ROM build pipeline")
    build_parser.add_argument("-d", "--device", default="SM-A325F", help="Device model (default: SM-A325F)")
    build_parser.add_argument("-v", "--verbose", action="store_true", help="Enable command output")
    build_parser.add_argument("-c", "--cache", default="./CACHE", help="Firmware cache directory (default: ./CACHE)")
    build_parser.add_argument("-t", "--tethering", action="store_true", help="Enable UI 8.5 Tethering APEX patch")
    build_parser.add_argument("--no-progress", action="store_true", help="Disable the visual progress bar")
    build_parser.add_argument("--upload", action="store_true", help="Automatically upload the result to Hugging Face")
    build_parser.add_argument("-i", "--interactive", action="store_true", help="Interactively configure the build")

    # Clean subcommand
    clean_parser = subparsers.add_parser("clean", help="Purge temporary build files")
    clean_parser.add_argument("--clean-cache", action="store_true", help="Also remove the firmware cache directory")
    clean_parser.add_argument("-c", "--cache", default="./CACHE", help="Cache directory to clean (default: ./CACHE)")

    # Integrity check for repository root
    if not os.path.isdir("scripts") or not os.path.exists("scripts/LumiROM.sh"):
        print("[!] Execution must occur from the repository root.")
        sys.exit(1)

    args = parser.parse_args()

    if args.command == "clean":
        LumiROMBuilder.clean(clean_cache=args.clean_cache, cache_dir=args.cache)
    elif args.command == "lumirom":
        # Check workspace cleanliness BEFORE starting interactive prompts
        LumiROMBuilder.check_workspace_cleanliness()

        if args.interactive:
            print("\n>>> Entering Interactive Build Setup...")
            devices = os.listdir("LumiROM/Devices")
            print(f"Available models: {', '.join(devices)}")
            
            d_input = input(f"Select device model [default: {args.device}]: ").strip()
            if d_input: args.device = d_input
            
            t_input = input("Enable UI 8.5 Tethering patch? (y/N): ").strip().lower()
            args.tethering = t_input == 'y'
            
            v_input = input("Enable verbose output? (y/N): ").strip().lower()
            args.verbose = v_input == 'y'
            
            p_input = input("Show progress bar? (Y/n): ").strip().lower()
            args.no_progress = p_input == 'n'
            
            u_input = input("Automatically upload after build? (y/N): ").strip().lower()
            args.upload = u_input == 'y'
            print("")

        builder = LumiROMBuilder(
            device=args.device, 
            verbose=args.verbose, 
            cache_dir=args.cache, 
            tethering=args.tethering,
            show_progress=not args.no_progress
        )
        
        start_time = datetime.now()
        success = builder.build()
        end_time = datetime.now()
        print(f"Elapsed: {end_time - start_time}")

        if success and args.upload:
            print("\n>>> Starting automated upload...")
            upload_script = os.path.join("scripts", "upload_local.py")
            subprocess.run([sys.executable, upload_script])

if __name__ == "__main__":
    main()
