<p align="center">
  <img src="LumiROM/logo/LumiROM.png" alt="LumiROM Logo">
</p>

<p align="center">
  <a href="https://github.com/Luminous418/LumiROM/actions/workflows/OneUi8-5.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/Luminous418/LumiROM/OneUi8-5.yml?branch=OneUI8.5&label=Specific%20Device&logo=github" alt="Specific Device Workflow">
  </a>
  <a href="https://github.com/Luminous418/LumiROM/actions/workflows/OneUi8-5-Matrix.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/Luminous418/LumiROM/OneUi8-5-Matrix.yml?branch=OneUI8.5&label=All%20Devices&logo=github" alt="All Devices Workflow">
  </a>
  <a href="https://github.com/Luminous418/LumiROM/stargazers">
    <img src="https://img.shields.io/github/stars/Luminous418/LumiROM?style=flat&logo=github&label=Stars" alt="Stars">
  </a>
  <a href="https://github.com/Luminous418/LumiROM/network/members">
    <img src="https://img.shields.io/github/forks/Luminous418/LumiROM?style=flat&logo=github&label=Forks" alt="Forks">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/github/license/Luminous418/LumiROM?style=flat&label=License" alt="License">
  </a>
</p>

This custom ROM is created to provide a totally new experience to Low end Mediatek devices.
- It is focused on stability while upgrading the android version so we can test new One Ui releases and adding new features such as Galaxy AI✨

## What it does?

It downloads the firmware from Samsung servers using [samloader](https://github.com/ananjaser1211/samloader), or custom firmware downloader, merges OTA patches, extracts the partition images and then applies all the features implemented in the repository - Galaxy AI, heavy debloat, Knox patches, performance tweaks and QoL improvements - so the device can be used again with a fresh and modern experience.

The whole process can run either on **GitHub Actions** or **locally** on your machine (requires Ubuntu/Debian distro or WSL).

## Changelogs
Refer to [changelogs](https://github.com/Luminous418/LumiROM/blob/OneUI8.5/changelogs/README.md) folder to know more about releases and useful information.

## Supported Devices

| Device | Model |
| :--- | :--- |
| Samsung Galaxy A22 | SM-A225F |
| Samsung Galaxy A22 5G | SM-A226B |
| Samsung Galaxy A32 | SM-A325F |
| Samsung Galaxy A32 | SM-A325M |
| Samsung Galaxy F22 | SM-E225F |
| Samsung Galaxy M32 | SM-M325F |

> **Note:** FOD devices will use FOD bases (e.g. A32 → A34 base), and Side-FP devices will use Side-FP bases (e.g. A22 → A24 base).

## Features

### System Optimization
- Heavy debloated system (150+ bloatware apps removed).
- Deodexed ROM for cleaner and smaller partitions.
- Improved performance and smoother UI experience.
- Optimized background processes.
- Better battery efficiency.
- Enhanced CPU responsiveness and processing.
- HighEnd launcher animations.
- EROFS filesystem - compressed, read-only, saves storage space.
- Disabled file-based encryption (FBE) and full-disk encryption (FDE).
- VNDK and SELinux fixes applied per-device.
- Init tweaks for extra performance.
- VoLTE fix.
- Custom wallpapers included.

### Galaxy AI ✨
- **Call assist** - change caller voice, make real time translated calls.
- **Writing assist** - tools for composing, translating the text, summarize long texts and more.
- **Note assist** - automatic text organization and summarization.
- **Transcript assist** - AI-powered voice transcriptions.
- **Browsing assist** - summarized web browsing.
- **Photo assist** - AI photo editing and object removal.
- **Weather wallpaper** - wallpapers that change based on time and weather conditions.
- **Now brief** - smart notification summaries.
- **Now nudge** - intelligent reminders and prompts.
- **Health assist** - AI-powered health assistance.

### Enhanced Functionality
- Screenshot anywhere (enabled globally).
- More floating features enabled.
- Screen recorder support.
- Bluetooth recording support.

### Knox Patches (built-in, no root needed)
Knox functionality is patched directly via smali modifications - no modules or root required:
- **Knox Guard** - disabled to prevent carrier locking.
- **Flag Secure** - bypassed to allow screenshots everywhere.
- **Secure Folder** - patched to work without Knox integrity checks.
- **Private Share** - patched for integrity verification bypass.
- **Signature Verification** - minimum scheme lowered for sideloading.
- **SSRM** - patched to match stock device policies.
- **ICCC** - removed to prevent soft-bootloops.
- **KnoxGuard app** - removed from system.

### Supported apps with Knox Patches
-  [Auto Blocker](https://www.samsung.com/uk/support/mobile-devices/protect-your-galaxy-device-with-the-new-auto-blocker-feature/)
-  Samsung Cloud ([FMM](https://www.samsung.com/uk/support/mobile-devices/what-is-find-my-mobile-and-how-can-i-use-it-to-locate-lock-or-wipe-my-device/), [Enhanced data protection](https://www.samsung.com/ae/support/mobile-devices/what-is-the-enhanced-data-protection-function-and-when-can-i-use-it/))
-  [Samsung Flow](https://www.samsung.com/uk/apps/samsung-flow/)
-  [Samsung Health](https://www.samsung.com/uk/apps/samsung-health/)
-  [Samsung Health Monitor](https://www.samsung.com/uk/apps/samsung-health-monitor/)
-  [Secure Folder](https://www.samsungknox.com/en/solutions/personal-apps/secure-folder)
-  [Secure Wi-Fi](https://www.samsung.com/uk/support/mobile-devices/what-is-the-secure-wifi-feature-and-how-do-i-enable-or-use-it/)
-  [SmartThings](https://www.samsung.com/uk/smartthings/app/)

This apps will work without installing any module or having root on the device.

## How to Use

### Method 1: GitHub Actions

#### 1. Fork the Repository
Give a ⭐ star to the repository.
Fork the repository to your GitHub account.

#### 2. Run the Workflow:
Open your forked repository.
- Go to the Actions tab.
- Select LumiROM Tools.
- Click Run workflow.

#### 3. Set Your Device Model:
Update your device model in the STOCK_DEVICE_MODEL option.
- If your model is available in /LumiROM/Devices folder of this repository, the tool will work for your device.
- If your model is not present, it will not work.

> I recommend for forks, to use the Specific Device workflow instead of the All Devices workflow if you building it via GitHub Actions.

#### 4. Kernel BPF Version Option:
Set this option to True if your kernel BPF version is 5.4 (lower than 5.10).
- Otherwise, set it to False.

#### 5. Output Filesystem:
My tool can only build images in erofs because:
  - It is recommended if your device partition size is small.
  - Saves storage space.
  - Can add more things as it gets compressed

> Only downside is: Your kernel must support EROFS.

But all of the devices I support got EROFS kernel so there isn't a problem

#### 6. Upload (only on GH Actions)
The ROM will be auto uploaded to Hugging Face servers, but you need to create an account and generate a token to be able to upload the file. 

> [!TIP]
> - Create a Hugging Face account.
> - Go to settings and then to Access Tokens. Create a new token with write permissions and copy it.
> - Create a bucket.
> - Go back to the repository and go to repository settings and add the token as a secret with the name HF_TOKEN.

### Method 2: Local Build

You can also build LumiROM directly on your Linux machine using the local build script. This method includes a **firmware cache system** so you only need to download the firmware once.

#### 1. Clone the repository:
```bash
git clone https://github.com/Luminous418/LumiROM.git
cd LumiROM
```

#### 2. Configure your build:
Edit the variables at the top of `build_local.sh`:
```bash
STOCK_DEVICE="SM-A325F"       # Your device model
USE_MODS="Yes"                # Include mods (Vulkan fix, VoLTE fix, tweaks, wallpapers)
USE_GALAXY_AI="Yes"           # Include Galaxy AI features
USE_UI_8_TETHERING_APEX="False"  # Set to True if kernel BPF < 5.10
```

#### 3. Run the build:
```bash
bash build_local.sh
```
The script will install dependencies, download firmware (if not cached), apply all patches and build the ROM. The output ZIP will be in the `ROM/` folder.

#### 4. Manage firmware cache:
Use the cache manager to check, list or clear your cached firmware images:
```bash
bash scripts/cache_manager.sh status    # Show cache status
bash scripts/cache_manager.sh check     # Verify required images
bash scripts/cache_manager.sh size      # Show cache size
bash scripts/cache_manager.sh list      # List all images with sizes
bash scripts/cache_manager.sh clear     # Clear cached images
```

> [!IMPORTANT]
> If you're building locally, script will log all actions that is happening, if something fails, report the error to me via GitHub issues or on my Telegram channel by uploading the LOGS folder.

> [!NOTE]
> If you dont wanna mess with the repo or dont know how to do any of this things, I will continue releasing updates of my rom on my Telegram channel, that you can join clicking on the link on the repository bio.
> Also I accept suggestions aswell as im still learning from it, so if you see a bug, or wanna make the code a bit more easy to understand, you can always create a pull request!

## Licensing
This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
- **[android-tools](https://github.com/nmeum/android-tools)** - Licensed under Apache License 2.0
- **[apktool](https://github.com/iBotPeaches/Apktool)** - Licensed under Apache License 2.0  
- **[erofs-utils](https://github.com/sekaiacg/erofs-utils)** - Dual licensed (GPL-2.0, Apache-2.0)
- **[platform_build](https://android.googlesource.com/platform/build)** - Licensed under Apache License 2.0
- **[e2fsprogs](https://github.com/tytso/e2fsprogs)** - Licensed under GPL-2.0 / LGPL-2.1
- **[img2sdat](https://github.com/xpirt/img2sdat)** - Licensed under the MIT License
- **[samloader](https://github.com/samloader/samloader)** - Licensed under GPL-3.0
