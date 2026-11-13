# Palermo × 初鸣 (Breathnote) 设计系统与组件规范 v2.0

> **交互式设计系统参考站点**：[design/palermo-system/index.html](file:///Users/smartisan/qinyin/design/palermo-system/index.html)
> **Flutter Token 核心实现**：[lib/src/theme/palermo_tokens.dart](file:///Users/smartisan/qinyin/lib/src/theme/palermo_tokens.dart)
> **初鸣小老师引导组件**：[lib/src/widgets/chuming_coach.dart](file:///Users/smartisan/qinyin/lib/src/widgets/chuming_coach.dart)

---

## 1. 为什么旧版配色与图标被彻底重构？

| 维度 | 旧版问题 (已废弃) | Palermo 2.0 方案 (`palermo.tryprofound.com` 复刻) |
| :--- | :--- | :--- |
| **背景与卡片色** | 泛黄米色 `#F6F1E9` / 泥灰色 `#EFE7DA`，视觉浑浊显脏 | **纯净中性层级**：画布 `#FAFAFA` + 纯白卡片 `#FFFFFF` + 浅灰二级面板 `#F5F5F5` + `1px` `#EBEBEB` 描边 |
| **主色与功能色** | 暗沉藏青 `#3B4C75` + 土黄 `#B28A43`，缺乏现代感 | **Palermo 4-Tier 语义色板**：Blue `#376CFF` (吹气/主操作)、Emerald `#15B462` (音准锁定)、Orange `#FE6E00` (吸气/连胜) |
| **字体排版** | 标题使用 `MingjieSerif` 宋体，与精密调音仪表割裂 | **全栈现代无衬线**：统一使用紧凑字距 (`-0.25px ~ -0.75px`) 的 `MingjieSans` + `tabular-nums` 等宽数字 |
| **口琴图标** | 顶部单侧阶梯凸起，24px 下像白色文件夹 `📁` 或长角 | **对称双护板口琴**：上下对称圆角金属护板 + 5 枚竖向音簧格栅 + 第 4 孔翡翠绿高亮 |
| **初鸣小鸟** | 深蓝黑底 + 棕色呆毛，缩略图下像深色炸弹 `💣` | **天蓝白腹萌鸟**：清澈天蓝 `#4785FF` 羽毛 + 大面积纯白肚皮面罩 `#FFFFFF` + 粉红腮红 `#FF7EB6` |

---

## 2. Foundations：Palermo Token 体系

### 2.1 Surface & Neutral 层级
- **Light Mode**:
  - `surfaceCanvas`: `#FAFAFA`
  - `surface`: `#FFFFFF`
  - `surface200`: `#F5F5F5`
  - `surface300`: `#E8E8E8`
  - `borderSubtle`: `#EBEBEB`
  - `textPrimary`: `#18181A`
  - `textSecondary`: `#787878`
- **Dark Mode**:
  - `surfaceCanvas`: `#18181A`
  - `surface`: `#222224`
  - `surface200`: `#2C2C30`
  - `borderSubtle`: `#323236`
  - `textPrimary`: `#FAFAFA`
  - `textSecondary`: `#A0A0A6`

### 2.2 Palermo 4-Tier 语义色彩架构 (`base` / `border` / `mutedFill` / `emphasis`)

| 语义角色 | 用途映射 | `base` (Light / Dark) | `border` (Light / Dark) | `mutedFill` (Light / Dark) | `emphasis` (Light / Dark) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Blue** | 主操作 / 吹气 `↑` / 孔位激活 | `#376CFF` / `#5E9EFF` | `#ADC4FF` / `#28467A` | `#EBF1FF` / `#17233B` | `#1E4FD9` / `#99C2FF` |
| **Emerald** | 音准锁定 (`±10¢`) / 已完成 | `#15B462` / `#60F178` | `#9EE4BF` / `#1E542B` | `#E8F8F0` / `#122B18` | `#0E8A4A` / `#98F7A7` |
| **Orange** | 吸气 `↓` / 连胜徽章 | `#FE6E00` / `#FF8940` | `#FFC299` / `#613417` | `#FFF1E6` / `#2E190B` | `#CC5800` / `#FFB380` |
| **Amber** | 临近音准提示 (`10¢~25¢`) | `#F59E0B` / `#FBBF24` | `#FDE68A` / `#5E450B` | `#FEF3C7` / `#2E2105` | `#B45309` / `#FDE68A` |
| **Red** | 音高偏差过大 (`>25¢`) | `#FF5F57` / `#FF6369` | `#FFB8B4` / `#632427` | `#FFEFEE` / `#301214` | `#D93830` / `#FFA1A4` |

---

## 3. 初鸣专属复刻组件库 (Palermo Adapted Components)

1. **`HarmonicaBrandIcon`（无角对称双护板口琴图标）**
   - 位置：[cute_illustrations.dart](file:///Users/smartisan/qinyin/lib/src/widgets/cute_illustrations.dart) & [app-icon.svg](file:///Users/smartisan/qinyin/design/app-icon.svg)
   - 结构：上下对称圆角金属护板 + 中央多孔琴格 + 左右铆钉 + 5 枚竖向音簧槽（第 4 孔翡翠绿高亮）。
2. **`ChumingBird`（天蓝白腹初鸣小鸟吉祥物）**
   - 位置：[cute_illustrations.dart](file:///Users/smartisan/qinyin/lib/src/widgets/cute_illustrations.dart)
   - 5 种状态：`idle`（待机）、`listening`（倾听音高）、`celebrating`（音准命中欢呼）、`encouraging`（鼓励）、`sleeping`（休眠）。
3. **`SwipeGestureGuide` / `BreathGestureGuide` / `TapGesturePulse`（首次播放 + 点击重播手势引导）**
   - 位置：[gesture_guide.dart](file:///Users/smartisan/qinyin/lib/src/widgets/gesture_guide.dart)
   - 行为：组件首次挂载自动播放 1 次有界引导动效，用户点击胶囊可随时重播，并提供 `↻` 重播视觉提示。
4. **`HarmonicaDiagram`（10 孔口琴交互孔位图）**
   - 位置：[shared_widgets.dart](file:///Users/smartisan/qinyin/lib/src/widgets/shared_widgets.dart)
   - 行为：顶部采用 Palermo 10 孔光谱色带，吹气孔激活显示 Palermo Blue，吸气孔激活显示 Palermo Orange。
5. **`ChumingCoachBanner`（初鸣小老师首次功能引导气泡）**
   - 位置：[chuming_coach.dart](file:///Users/smartisan/qinyin/lib/src/widgets/chuming_coach.dart)
   - 行为：用户首次进入「学习」、「曲谱」、「调音」、「单音练习」时，由初鸣小鸟展示简短功能用法说明；点击「知道了」后持久化收起，点击页面顶部的初鸣小鸟可随时重播引导。
