# StudyOS iPad 实体真机安装与测试实操手册 (Windows 极简流程)

本文档专为**只有 Windows 电脑 + iPad 设备**的学习者与测试者设计，无需苹果 Mac 电脑，无需购买 99 美元开发者账号，即可直接将 StudyOS 原生 App 安装至 iPad 物理设备并使用 Apple Pencil 进行实测。

---

## 一、前期准备清单

1. **硬件**：
   - 您的 **Windows 电脑**（Win 10 / 11 皆可）；
   - 您的 **iPad**（支持 iPad Pro / Air / mini / 数字系列，已更新至 iPadOS 17+）；
   - **Apple Pencil**（第 1/2 代或 Apple Pencil Pro / USB-C）；
   - 一根连接 iPad 与 Windows 电脑的**数据线**。
2. **软件工具（二选一，推荐 Sideloadly）**：
   - **工具选项 A（推荐）**：**Sideloadly**
     - 官网下载：[https://sideloadly.io/](https://sideloadly.io/)（选择 Windows 64-bit 下载并安装）；
     - 注：若提示需要 iTunes / iCloud，在 Sideloadly 界面点击自动安装即可。
   - **工具选项 B**：**爱思助手**（Windows 版）
     - 官网下载并安装，使用其自带的「工具箱」->「IPA 签名」功能。
3. **Apple ID 账号**：
   - 您平时在 iPad App Store 免费下载 App 用的个人 Apple ID 即可（**完全免费**）。

---

## 二、从 GitHub Actions 下载 StudyOS.ipa 安装包

1. 打开 GitHub 仓库页面：[https://github.com/104215585011/read](https://github.com/104215585011/read)；
2. 点击顶部的 **「Actions」** 标签；
3. 点击最新的那次构建记录（标题通常为 `ci: add automated IPA packaging...`）；
4. 页面滑动至最底部的 **「Artifacts」** 区域；
5. 点击下载 **`StudyOS-iPad-Release-IPA`**（下载下来是一个 zip 包，解压后即可获得 `StudyOS.ipa`）。

---

## 三、Windows 端一键安装到 iPad（以 Sideloadly 为例）

1. **连接 iPad**：
   - 使用数据线将 iPad 连接至 Windows 电脑；
   - 查看 iPad 屏幕，若弹出“要信任此电脑吗？”，点击 **「信任」** 并输入 iPad 锁屏密码；
2. **打开 Sideloadly**：
   - 打开 Sideloadly，它会自动检测并识别到您的 iPad 设备名称；
3. **拖入 IPA 安装包**：
   - 将刚才解压得到的 **`StudyOS.ipa`** 直接拖入 Sideloadly 左侧的「IPA」大方框内；
4. **输入 Apple ID**：
   - 在「Apple ID」输入框中输入您的 Apple 账号邮箱；
5. **开始安装**：
   - 点击底部的 **「Start」** 按钮；
   - 首次安装会弹出密码输入框（输入您的 Apple ID 密码，用于向苹果服务器请求免费个人测试证书；若开启了双重验证，在 iPad 屏幕上确认并输入 6 位验证码）；
   - 进度条跑完显示 **`Done.`**，大约需要 20~30 秒，StudyOS 图标就会直接出现在您的 iPad 桌面上！

---

## 四、在 iPad 上信任证书并打开 App

首次安装侧载应用需要完成一次系统安全信任：
1. 拿起 iPad，打开 **「设置」**；
2. 进入 **「通用」 -> 「VPN 与设备管理」**；
3. 在下方“开发者 App”区域，点击您刚才输入的 Apple ID；
4. 点击蓝色的 **「信任 ...」**，在弹窗中再次点击 **「信任」**；
5. 返回 iPad 桌面，点击 **StudyOS** 图标，即可正式启动原生应用！

---

## 五、开箱体验与重点测试项推荐

启动 StudyOS 后，应用会自动完成冷启动沙盒初始化，您将体验到：
1. **书架自动播种教材**：书架上自动呈现《Chapter 4: 线性代数与深度学习基础.pdf》学术样例；
2. **平铺式可拖拽分栏**：点击进入阅读器，PDF 在左，AI 侧栏在右。用手指或 Apple Pencil 按住中间竖向三圆点手柄，随意左右拖拽，观察无极平滑伸缩；
3. **Apple Pencil 真实手写**：用 Apple Pencil 在 PDF 公式和重点处划线、书写，双击笔身切换笔与橡皮擦，感受 ProMotion 120Hz 极低延迟与手掌防误触；
4. **自适应字号排版**：将 AI 侧栏拉宽（>460pt），观察卡片自动裂变为双列并排排版；
5. **多模型自由配置**：点击顶部 `DeepSeek-R1 ▾` 胶囊，切换您喜欢的模型，配置您的专属 API Key 进行即时握手测速，或体验 ChatGPT Plus 网页直连模式。
