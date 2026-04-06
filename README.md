![LumiROM Logo](LumiROM/logo/LumiROM.png)

This custom ROM is created to provide a totally new experience to Low end Mediatek devices.
- It is focused on stability while upgrading the android version so we can test new One Ui releases and adding new features such as Galaxy AI✨

## What it does?

It downloads the imgs from the server, and adds the features implemented in the repository such as Galaxy AI, heavily debloat and improve the perfomance, aswell as make QoL improvements so the device can be used again!

## Features
- System Optimization.
- Heavy debloated system.
- Improved performance and smoother UI experience.
- Optimized background processes.
- Better battery efficiency.
- Enhanced Functionality.
- Screenshot anywhere (enabled globally).
- More floating features enabled.
- Edge features fully working.
- Object, shadow and reflection remover support.
- [KnoxPatch](https://github.com/salvogiangri/KnoxPatch) integrated

## Supported apps with KnoxPatch
-  [Auto Blocker](https://www.samsung.com/uk/support/mobile-devices/protect-your-galaxy-device-with-the-new-auto-blocker-feature/)
-  Samsung Cloud ([FMM](https://www.samsung.com/uk/support/mobile-devices/what-is-find-my-mobile-and-how-can-i-use-it-to-locate-lock-or-wipe-my-device/), [Enhanced data protection](https://www.samsung.com/ae/support/mobile-devices/what-is-the-enhanced-data-protection-function-and-when-can-i-use-it/))
-  [Samsung Flow](https://www.samsung.com/uk/apps/samsung-flow/)
-  [Samsung Health](https://www.samsung.com/uk/apps/samsung-health/)
-  [Samsung Health Monitor](https://www.samsung.com/uk/apps/samsung-health-monitor/)
-  [Secure Folder](https://www.samsungknox.com/en/solutions/personal-apps/secure-folder)
-  [Secure Wi-Fi](https://www.samsung.com/uk/support/mobile-devices/what-is-the-secure-wifi-feature-and-how-do-i-enable-or-use-it/)
-  [SmartThings](https://www.samsung.com/uk/smartthings/app/)

This apps will work without installing any module or having root on the device.

## How to Use:
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
- If your model is available in /LumiROM/Device folder of this repository, the tool will work for your device.
- If your model is not present, it will not work

Quick reminder: FOD devices will use FOD bases, Side-FP will use Side-FP bases<br>
like if you have an A32, will use A34 base, and if you have A22, will use A24 base.

#### 4. Kernel BPF Version Option:
Set this option to True if your kernel BPF version is 5.4 (lower than 5.10).
- Otherwise, set it to False.

#### 5. Set Target Device Information:
Configure the following options:
- STOCK_DEVICE: The device model from which you want to port the ROM.

#### 6. OUTPUT_FILESYSTEM:
My tool can only build images in erofs because:
  - It is recommended if your device partition size is small.
  - Saves storage space.
  - Can add more things as it gets compressed

Only downside is:
  - Your kernel must support EROFS.

But all of the devices I support got EROFS kernel so there isn't a problem

#### 7. Upload
The ROM will be auto uploaded to GoFile servers, so when the workflow is done, check on the logs the link for it, in "Sending ROM to GoFile" part.

## Note
If you dont wanna mess with the repo or dont know how to do any of this things, I will continue releasing updates of my rom on my Telegram channel, that you can join clicking on the link on the repository bio.

Also I accept suggestions aswell as im still learning from it, so if you see a bug, or wanna make the code a bit more easy to understand, you can always create a pull request!

## Licensing
This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
- **[android-tools](https://github.com/nmeum/android-tools)** - Licensed under Apache License 2.0
- **[apktool](https://github.com/iBotPeaches/Apktool)** - Licensed under Apache License 2.0  
- **[erofs-utils](https://github.com/sekaiacg/erofs-utils)** - Dual licensed (GPL-2.0, Apache-2.0)
- **[platform_build](https://android.googlesource.com/platform/build)** - Licensed under Apache License 2.0
- **[e2fsprogs](https://github.com/tytso/e2fsprogs)** - Licensed under GPL-2.0 / LGPL-2.1
- **[img2sdat](https://github.com/xpirt/img2sdat)** - Licensed under the MIT License
