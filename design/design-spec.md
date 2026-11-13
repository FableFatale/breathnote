# 初鸣 (Breathnote) 设计系统规范 (Palermo-Inspired Design System)

> 版本：V2.1  
> 参考体系：[Palermo Design System (Profound)](https://palermo.tryprofound.com/docs/get-started)  
> 风格定位：现代质感极简风（Contemporary Tactile Minimalism）+ 萌趣微插画（Cute Vector Micro-illustrations）+ 可重播手势引导（Replayable Interactive Gesture Guides）

---

## 一、 系统架构总览 (System Architecture)

借鉴 Palermo 的三层式设计规范架构，初鸣设计系统划分为：
1. **Foundations（基础底座层）**：Brand & Craft、Semantic Color Tokens、Typography Scale、Spacing & Radii、Soft Elevation、Iconography & App Icon。
2. **Core Components（通用核心组件层）**：Navigation、Card & Dock Containers、Buttons & Inputs、Badge/Pill/Statistic、Empty & Status Feedback。
3. **Domain Specialized（口琴与声学专有扩展层）**：
   - **萌趣吉祥物系统 (`ChumingBird`)**
   - **首次引导 + 可重播手势组件 (`GestureGuides`)**
   - **声学与乐器可视化组件 (`HarmonicaDiagram`, `PitchArc`, `DotDistribution`)**

---

## 二、 Foundations（基础底座规范）

### 1. 品牌标识与 App Icon 规范（去角化一体口琴轮廓）
- **痛点修正**：彻底移除旧版图标顶部容易被误认为“乐器上长了两个角”的突兀波浪折线，并将应用内原有的钢琴图标（`Icons.piano_rounded`）全面替换为定制矢量口琴标识（`HarmonicaBrandIcon`）。
- **新版图标造型 (`design/app-icon.svg` & Adaptive Icon)**：
  - **外轮廓**：采用一体式圆润阶梯护板（左侧平缓起步，中部微升形成一处柔和「鸣阶」高度差，四角 `8px` 圆角），一眼即可识别为十孔口琴。
  - **琴格与孔位**：内嵌象牙暖白琴格（`#FFFCF7`），整齐排列 10 个圆角音孔。
  - **点睛主音（第 4 孔）**：第 4 孔采用暖金渐变（`#E5B869` → `#B28A43`）并微幅加高，象征初学者吹响的第一声标准音 `4↑ (C5)`。

### 2. 语义化色彩系统 (Semantic Color Tokens)

| Token 名称 | 浅色模式 (Light) | 深色模式 (Dark) | Palermo 对应语义与应用场景 |
| :--- | :--- | :--- | :--- |
| `background` | `#F6F1E9` (温润手工纸白) | `#18181A` (深邃炭黑) | 应用级底层画布 (`bg-app`) |
| `surface` | `#FFFCF7` (纯净乳白) | `#222224` (一级炭灰容器) | 卡片、列表项、输入框 (`bg-surface`) |
| `surfaceHigh` | `#EFE7DA` (暖米抬升层) | `#2A2A2D` (二级抬升容器) | 导航栏、悬浮控制坞、次级胶囊 (`bg-raised`) |
| `outline` | `#DDD3C5` (纸感细微边) | `rgba(255,255,255,0.08)` | 1px 精细容器描边 (`border-subtle`) |
| `primary` | `#3B4C75` (鸣阶深靛蓝) | `#6FA8FF` (明澈天蓝) | 主操作按钮、吹气指示 `↑`、激活态 (`brand-primary`) |
| `accent` | `#B28A43` (雅致暖金) | `#F2B272` (暖金晨晖) | 吸气指示 `↓`、连续打卡火苗、第 4 孔高亮 (`brand-accent`) |
| `text` | `#2A2620` (温润浓墨) | `#F2F0EC` (柔和亮白) | 主标题与正文 (`fg-default`) |
| `muted` | `#7A7064` (亚麻暖灰) | `#AAA7A3` (中性浅灰) | 辅助说明、未激活图标 (`fg-muted`) |
| `success` | `#3B4C75` | `#6FA8FF` | 音准锁定、阶段通关 (`status-success`) |
| `warning` | `#B28A43` | `#F2B272` | 音高偏离提示 (`status-warning`) |
| `danger` | `#B3261E` (朱砂红) | `#F08AB8` (柔和珊瑚粉) | 权限拒绝、删除确认 (`status-destructive`) |

### 3. 十孔阶梯彩孔光谱 (Chromatic Hole Spectrum)
为口琴 1~10 孔提供柔和的阶梯色彩参考，辅助空间记忆：
`#C96F6A` (1孔) → `#D48A62` (2孔) → `#D6B35F` (3孔) → `#A8B96B` (4孔) → `#76B58C` (5孔) → `#59AFA9` (6孔) → `#5B9BD1` (7孔) → `#6FA8FF` (8孔) → `#8A8BD1` (9孔) → `#A67BAE` (10孔)。

### 4. 排版与字阶体系 (Typography Scale)
- **`displayLarge` (60px / Bold / MingjieSerif)**：练习页与调音页核心目标大音符。
- **`displaySmall` (30px / Bold / MingjieSerif)**：一级页面主视觉标题。
- **`headlineSmall` / `titleMedium` (20px / Bold / MingjieSerif)**：模块标题、卡片主标题。
- **`bodyMedium` (14px / Medium / MingjieSans)**：常规正文与课程描述。
- **`bodySmall` (11px / Medium / MingjieSans)**：次级辅助说明与底部隐私提示。
- **`monospace` (等宽数字规范)**：所有频率 (`Hz`)、音分 (`cents`)、分贝 (`dBFS`)、连续天数、得分均采用等宽数字渲染，防止实时刷新时发生视觉抖动。

### 5. 圆角、间距与微质感层级 (Radii, Spacing & Tactile Elevation)
- **间距阶梯**：`4px` / `8px` / `12px` / `16px` / `20px` / `24px` / `32px`。
- **圆角阶梯**：
  - 小徽标 (`Badge`)：`8px ~ 12px`
  - 按钮与输入框 (`Button` / `Input`)：`16px`
  - 内容卡片 (`Card`)：`24px`
  - 模态弹窗与底部控制坞 (`BottomSheet` / `ControlDock`)：`28px ~ 32px`
  - 胶囊标签 (`Pill`)：`999px` (StadiumBorder)

---

## 三、 Domain Specialized（初鸣专有组件规范）

### 1. 萌趣吉祥物系统：`ChumingBird`（小鸣鸟）
- **视觉特征**：圆润雏鸟躯干、柔和肚皮绒毛、鹅黄三角形小鸟喙、带高光的圆眼睛、粉嫩腮红，头顶一簇象征音符的呆毛羽冠。
- **五种情绪姿态 (`ChumingMood`)**：
  - `idle`：日常安详陪伴，轻柔呼吸起伏。
  - `listening`：佩戴暖金色小耳机，专注倾听麦克风输入。
  - `blowing`：鼓起腮帮向外吹出蓝色晶莹音符气泡（对应吹音 `↑`）。
  - `drawing`：柔和吸气，暖金色气流向内聚拢（对应吸音 `↓`）。
  - `celebrating`：头戴金色小皇冠、弯弯笑眼 `^_^`，周身闪烁星芒（对应练习通关与打卡）。
- **交互规则**：首次进入页面执行一次问候微动效后保持安静，用户随时点击小鸟即可触发轻触反馈并重播生动动画。

### 2. 手势动态引导规范（首次自动引导 + 用户可多次重播）
遵循**“首次自动播放一次，随后静止不干扰，用户点击可随时无限次重播”**的交互准则：
1. **`SwipeGestureGuide`（左右滑动引导胶囊）**
   - **动效**：小手图标沿水平轨迹平滑摆动一次并停驻，右侧附带 `replay` 重播微图标。
   - **重播**：用户点击整个引导胶囊即可触发触觉反馈并重新播放滑动演示。
2. **`BreathGestureGuide`（吹吸垂直呼吸动势引导）**
   - **吹气 (`isBlow: true`)**：靛蓝色上行箭头与气流轨迹向上升起，提示“向外平稳吹气”。
   - **吸气 (`isBlow: false`)**：暖金色下行箭头与气流轨迹向内沉降，提示“向内柔和吸气”。
   - **重播**：首次进入或切换目标音符时自动播放一次，点击胶囊可随时重播呼吸动势。
3. **`TapGesturePulse`（首次轻触波纹引导）**
   - **动效**：在核心开始按钮周围扩散两道柔和同心光环后自动收起，引导视线聚焦。
