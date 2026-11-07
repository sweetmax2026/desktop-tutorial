# v1.2.7 自动循环开关，2026-11-04

独立测试构建已完成。按用户确认的缩小稿，在计时操作旁显示28.8点小开关、36点透明点击区域，关闭后可恢复原配置。模型回归、准备/运行/休息原生示例渲染和沙盒构建检查通过。完整源稿对照及尚待实机hover/点击验收的边界见`design/automatic-cycle-toggle-2026-11-04/design-qa.md`。未替换正式应用。

---

# v1.2.5 本轮任务合并，2026-11-03

final result: passed

按确认稿移除类别，任务选择整框展开，预制与自建任务合并，新增/删除随保存生效，取消保留原配置。上次任务与时长在阶段结束与重启后恢复。完整同画布对照、实现修订和验证边界见`design/unified-task-2026-11-03/design-qa.md`。

已安装v1.2.5/build39，174条记录与原设置完整保留，正式新版任务弹窗保持打开。本轮未推送远端。

---

# v1.2.3 专注进入交互，2026-10-31

final result: passed

按用户确认的三帧稿实现同一计时器从首页移至专注中央，复用首页DIN数字，0.35秒背景与字色渐变，点击立即计时。已修复首版中帧字色瞬跳；默认速度、恢复运行、取消/确认放弃均在独立预览验证。完整同画布对照、迭代证据与验证边界见 `design/focus-entry-2026-10-31/design-qa.md`。

v1.2.3/build37已本机安装、构建和严格签名通过；168条记录及设置摘要一致，任务历史及完整计时存储也逐字节一致。未推送远端。

---

# v1.2.2 本轮任务统一编辑与数字修复，2026-10-31

final result: passed

用户指定首页局部交互修改：点击数字的计时设置移除，任务入口统一名称/时长/类别；历史任务可选择、添加和删除。原生sheet和独立存储已落实，删除不影响完成记录。数字按真实轮廓绘制以修复字体上沿裁切。完整报告与同图对比见 `design/task-editor-2026-10-31/verification.md` 和 `timer-before-after.png`。

正式安装v1.2.2/build36通过；任务面板真实中文输入/取消核对通过，166条记录及原设置/心情/冥想摘要一致。旧版已本机备份。以下保留统计页及更早轮次证据。

---

# 数据统计侧栏改版验证，2026-10-31

final result: passed

本轮使用用户选定的第2张设计，直接修改现有原生统计页。完整报告见 `design/statistics-sidebar-2026-10-31/design-qa.md`。以下为旧轮次的历史验证记录，保留供追溯。

- source visual truth: `design/statistics-sidebar-2026-10-31/selected-reference.png`（1448×1086）。
- implementation screenshot: `design/statistics-sidebar-2026-10-31/native-800-spacious.png`（1600×1200，2×，逻辑800×600）；按用户“布局紧凑”的反馈修订留白。
- normalization: 两边均归一至800×600，当前合成 `compare-spacious.png`（1600×600）；原生窗口无CSS尺寸。
- state: 专注、近7天、325分钟/13轮示例记录。
- full-view comparison: 同目录 `compare-initial.png` → `compare-final.png` → `compare-spacious.png`；`compare-spacing-before-after.png` 记录最近一次间距修订。
- focused comparison: 同目录 `compare-header.png`、`compare-records.png`。
- iteration history: 修复大数字与日期过近、侧栏间距、柱形日期对齐和末日标签、最小窗口记录行高，最终对照无待修P0/P1/P2问题。
- 最新反馈：增加标题、日期、数字和轮数间距，调轻日期/单位，左右留白增加；800×600首屏有意由3条记录改为2条，其余滚动。当前对照与重新构建通过，逻辑未改。
- required surfaces: 字体沿用首页DIN与系统中文；统一侧栏与正文间距；暖白/蓝色及分类颜色明确；配图为单独生成位图、图标复用首页；文案保持现有数据口径。
- verification: 原生三类切换、今日/自定义范围、成果笔记展开、早期记录滚动、切换后回到顶部、空记录、800×600和1100×760适配；StatisticsChecks通过；完整应用构建与签名、工程资源校验通过。
- follow-up P3: 系统滚动条、原生字体及新插画局部与生成稿略有差异；完整VoiceOver/键盘遍历未做穷尽验证。
- delivery: v1.2.1/build35 已安装到本机正式应用；签名与可执行文件一致性验证通过，正式统计页已打开。安装前后166条专注记录及设置、心情、冥想数据摘要一致；旧应用和偏好备份在 `/private/tmp/pang-before-v1.2.1-x6weRT/`。本次尚未推送远端。

---

# v1.2.0 主页面改版验证，2026-10-30

final result: passed

## 设计依据与比较范围

源图为 /Users/tiantian.xu/.codex/generated_images/8a144811-9815-59ae-bac2-6f7be03fcc6c/exec-a94b6290-d4c4-4a38-b4a3-f0e3a41c3757.png（1448×1086）。后续确认的修改是任务旁显示低对比“编辑”，默认无底色的冥想和心情入口在 hover 时浮现按钮面与阴影。应用名称保留 Pāng 的一声，不加入页面内 Logo、箭头或分隔线。

实现是原生 FocusReadySurface，不是浏览器原型。源图和原生截图通过同一 CUA 返回一起查看。原生窗口为 800×600 points，截图为 1600×1200，按同一逻辑尺寸比较。最终截图在本次会话的“检查键盘聚焦与最终原生布局”工具输出中，工具未返回可保存路径；报告不声称已另存截图文件。截图中任务、图标、按钮和文字在 2x 下均可辨认，不需要额外放大裁切。示例今日总时长为 58 分钟，源图为 50 分钟，此差异来自独立测试数据。

## 比较过程与结果

- 首次比较发现数字比设计高约 24 points。只调整数字绘制位置，不移动任务和按钮，重新编译、打开并捕获后，数字、任务、开始按钮和底部入口的相对位置与设计接近。
- 字体采用本机 DINCondensed-Bold，冒号用 ArialRoundedMTBold 单独对齐。保留窄长、粗重的数字方向。与生成图的具体字形仍有细小差异，列为 P3，不声称能从生成图识别原字体。
- 主按钮保留蓝色胶囊。任务、冥想、心情和统计按钮不常驻底色；hover 时使用淡白面和短阴影，按下时减轻阴影，布局尺寸不变。
- 背景使用独立生成的无 UI 插画。四枚细线图标从原型使用的 Phosphor 库导出，随应用打包，未用近似符号代替。MIT 授权说明一并保留。
- 页面不新增口号、功能卡片、表单说明或重复品牌。心情、冥想、设置、统计内页仍使用现有原生页面，未采用浏览器原型的临时表情。

## 已验证的原生交互

- 点击任务后在原位置进入输入。输入“整理本轮方案”并按 Enter 后，再打开输入框能读回相同内容。改成其他文字后按 Escape，重新打开仍是原任务。测试只操作独立预览。
- 点击计时数字，能看到时长 Stepper、类别、重置本轮和完成；关闭后返回原页面。
- 心情入口打开原 MoodJournalPage，五个原有心情与原生文字输入框保留，返回后仍在同一窗口。
- 原生截图观察到冥想入口的 hover 按钮面，移开后恢复无底色。原生完整键盘和 VoiceOver 遍历未完成，不把浏览器的键盘测试当成原生测试。
- scripts/check-focus-flow.sh 完整通过，覆盖原有计时、自动循环、每日长休息、App 管控和统计。模型代码未因本次视觉改版而修改。

## 安装与保留数据

v1.2.0/build 34 已安装并通过严格签名检查，构建和安装后的可执行文件摘要相同。正式界面显示准备页，今日 1 轮、27 分钟。对比安装备份与当前偏好，全部历史记录、时长设置和 App 管控设置保持相同。未启动、放弃或重置真实计时，未保存真实心情。

旧应用和偏好保存在 /private/tmp/pang-before-v1.2.0-LVzNeN/。随后经用户要求，v1.2.0 已推送至 sweetmax2026/desktop-tutorial 的 main，提交 6e1dcbe；本报告和个人数据未上传。最小窗口的准备页与上述原生操作通过；超宽窗口、完整键盘导航和 VoiceOver 可在后续验收中补测。

---

# Completion reminder repair verification — 2026-10-16

Functional repair, not a visual redesign. Reuses the existing BubbleView and native symbols.

- Added an independent completion card event, per-record persistent deduplication and replay when a completed snapshot is restored before UI callbacks are wired. Existing phase transitions and record contents unchanged.
- System notifications log authorization/alert/sound state, request submission acceptance and error domain/code. No task text or notification body is logged. Acceptance is not proof of visible notification delivery.
- FocusStoreChecks passes completion event, repeated refresh, reload dedup and pending-replay assertions. AppGuardChecks and StatisticsChecks also pass.
- Independent native preview reached completion with the nonactivating panel callback and its keyboard-focus-preservation assertion intact. Production panel is created with nonactivating style from initialization, uses orderFrontRegardless without application activation, and times out after 30 seconds. Opening the result is an explicit action.
- Installed v1.1.3/build 30 at /Users/tiantian.xu/Applications/Pang 大师.app; strict signature/plist checks pass. Previous application and preferences backed up at /private/tmp/pang-before-v1.1.3-Ll5UD7/.
- Actual installed startup AX showed “这一轮，完成了”, “已专注 25 分钟，猫爪已收好。准备好了再休息。”, “稍后查看” and “查看收获”. The card later disappeared; completion remained today one round/25 minutes, with manual rest still available. No real timer, reset, record mutation or reminder setting change was performed.
- The screenshot attempt switched its selected window before the subsequent action; the “查看收获” click was not executed because its element ID had expired. Do not claim that installed action click was tested. System notification delivery remains unverified under suppression settings; the observed independent card is the repaired fallback.
- No remote push in this repair turn. Prior design QA and install reports below remain historical.

---

# Previous control and copy refinement QA — 2026-10-15

final result: passed

## Installed release verification — v1.1.2/build 29

After explicit user approval to install, built the production application with scripts/build-app.sh. Final Info.plist is 1.1.2/build 29 with unchanged com.tiantian.pangpang-desktop-pet identity; project plist validation and strict code-signature verification passed. Installed at /Users/tiantian.xu/Applications/Pang 大师.app. Installed executable SHA-256 matches the built executable: 57c14a4ac1a7b51580668da2183202a01bd01dd62e0533b1d2027cca0b5a927c.

Old v1.1.1 application and a local preferences snapshot are recoverable at /private/tmp/pang-before-v1.1.2-e9CVhN/. Preferences were byte-identical to the backup immediately after installation. CUA confirmed ready 25:00 and the same existing today total of one completed round/25 minutes; statistics shows the existing three records, including two early-ended entries. No real timer, reset, reminder mutation or mood save was triggered.

Installed AX checks: direct statistics navigation and return, direct meditation navigation with shortened Start, reminder add/done controls, and compact disabled mood save are present. Screenshots saved under design/installed-v1.1.2/: ready.png, reminders.png and mood.png. These multi-display screenshots include a 1x window in the top-left of a larger white canvas. Statistics screenshot capture encountered ScreenCaptureKit -3811; its installed AX navigation/record check succeeded, while detailed statistics visual comparison remains the already-passed isolated preview evidence. Returned the installed application to ready 25:00. No remote push in this installation turn. The preview-only boundary described below applies to the earlier design pass, before this explicit install approval.

## Current target and comparison evidence

This is a scoped revision of the existing approved native UI, following the user's annotated meditation screenshot and explicit control-placement requests. No new visual direction or assets were introduced. Source and rendered comparisons are under design/control-refinement-2026-10-15/.

Source captures: before-ready.png, before-meditation.png, before-reminders.png, before-mood.png. These multi-display captures have a 1600×1200 raster canvas containing the complete 800×600 point window at 1x in the top-left region, with white padding elsewhere. scripts/normalize-capture.swift extracts that observed region to before-*-normalized.png. Initial centered sips crops were invalid and discarded from assessment; the final comparisons were regenerated after correct normalization.

Rendered implementation: after-ready.png, after-meditation.png, after-reminders.png, after-mood.png, after-meditation-active.png, after-mood-saved.png and after-focus-active.png. These fill 1600×1200 pixels at 2x for the same 800×600 point window. compare-ready.png, compare-meditation.png, compare-reminders.png and compare-mood.png pair each normalized source and implementation at equal logical density. All four final paired images and the original rendered captures were opened and inspected. Separate focused crops were not needed because text, icon strokes and button proportions are readable in the paired 800-point views and full 2x captures.

## Findings and five fidelity surfaces

No actionable P0/P1/P2 issue remains in the first valid, correctly normalized comparison pass. Changes from the sources are intentional responses to the user's annotations:

- Fonts/typography: reminder add/done and mood save now share the existing settings action style, 15-point medium text and 34-point height. The meditation start action is 17 points in a 160×40 capsule instead of 21 points in 224×46. The large meditation cue is 15-point medium instead of 19-point semibold. Existing countdown and page-title typography remains unchanged; no truncation or wrapping issue was observed.
- Spacing/layout: meditation removes the extra idle subtitle. Its existing animation/cat/footer composition remains intact. Reminder add is a compact outlined secondary action; done is a filled primary action with the same height and font. Mood save uses a content-sized button instead of a fixed 160-point width. Reset sits to the timer's right without shifting its centered position. Settings and statistics each occupy the same 36×36 frame with 19-point SF Symbols. No overlap in the normal 800×600 viewport.
- Colors/tokens: existing accent, secondary ink, backgrounds, disabled opacity and semantic colors retained. Settings action treatment removes oversized pill shadows from reminder add and mood save. No palette change.
- Image quality: existing flower animation, mood images, cats and paws are retained, not regenerated or substituted. Statistics and reset use native SF Symbols, chart.bar and arrow.counterclockwise. Existing flower drawing implementation is unchanged.
- Copy/content: meditation retains its page title, one breathing cue and a short start/restart action. The redundant idle “给自己一分钟” line is removed; the remaining time appears only during meditation. Overflow menu is removed, and its statistics/reset actions are direct controls with explicit accessibility labels/help. Data and timer rules unchanged.

## Native interaction verification

- Direct statistics icon opens statistics and back returns in place.
- Reset on ready is callable, leaves the ready timer and accumulated demo records intact. Existing automated checks still establish active-focus reset guard and legacy paused reset behavior.
- Reminder add inserts a disposable time; removing that exact test reminder restores the original three preview times. Done returns to breathing. Preview callbacks do not schedule real application notifications.
- Meditation start visibly enters 01:00, changes cue to inhale and action to restart; later capture reads 00:57. Animation geometry changes between captures. No production meditation was started.
- Selecting a demo mood enables save; clicking save shows the saved message, clears selection, disables save and increments the preview count to one.
- Active focus AX and screenshot show only countdown and long-press abandon, with no reset/statistics/settings/wellbeing controls. Demo session completed through the preview test clock and preview returned to ready.
- FocusStoreChecks, AppGuardChecks and StatisticsChecks pass through scripts/check-focus-flow.sh. Initial sandbox macro-plugin failure resolved by running the local compiler with the allowed escalation; final preview builds and signs successfully.

## Delivery boundary and residual gaps

Only the independent build/PangpangFlowPreview.app was refreshed. No production install, production data/settings change, release bump or remote push. Preview actions used demo data only. Full VoiceOver traversal and a new resize sweep were not performed in this scoped pass. Controls retain native button semantics and accessibility labels; disabled save state is intentional. Earlier QA records below describe previous iterations, not additional production changes in this pass.

---

# Previous local refinement design QA — 2026-10-15

final result: passed

## Current preview scope and evidence

Approved changes: direct meditation/mood entries on ready and rest pages; rest status above the timer with one action below; statistics grouped by whitespace instead of separators. Timer rules, palette, cats and record calculations are unchanged.

Baselines: design/interaction-review-2026-10-15/01-ready-normalized.png, 03-statistics-normalized.png, and the user's rest screenshot normalized as design/local-refinement-2026-10-15/source-rest.png. Its red rectangle is a user annotation, not UI.

Implementation evidence under design/local-refinement-2026-10-15/: ready.png, rest.png, statistics-final.png, statistics-empty.png, running-unchanged.png and statistics-wide.png. Normal window is 800×600 native points, captured at 1600×1200 pixels (2x). compare-ready.png, compare-rest.png and compare-statistics.png show baseline and implementation side by side, each normalized to 800×600. Full 2x captures were also inspected; controls are readable without an additional focused crop. Demo counts differ from baseline data by design.

## Current visual review

First valid comparison pass found no actionable P0/P1/P2 issue within the approved scope. An initial statistics capture included a hover highlight; the final comparison uses statistics-final.png with a neutral pointer state.

- Typography: native system fonts retained. Rest status is 15 points above the timer; action is 17 points. Wellbeing shortcuts use 13-point labels and 17-point symbols.
- Layout: shortcut spacing is 24 points; statistics column spacing is 32 points. Decorative module/list separators removed. Normal ready/rest/running and normal/maximized statistics have no overlap or clipping.
- Colors: existing tokens retained, including semantic green leaf/coral heart. Chart reference lines are sparse, pale and 0.5 points wide.
- Imagery: existing brand PNGs unchanged; native leaf/heart symbols reused. No new mascot or rasterized UI text.
- Copy: direct entries replace overflow-menu duplicates. “休息中” appears above the countdown, with one “结束休息” action below. Explanation is help text rather than another permanent line.

## Current interaction checks and delivery boundary

CUA in isolated preview: both direct entries open and return in place; no meditation started or mood record saved. Entering mood from rest and returning preserves the simulated 05:00 state. Running view remains timer plus long-press abandon only. Statistics record expansion, meditation empty state, seven-day filtering and switching back to focus statistics work with consistent demo totals. Window zoom was restored and preview left on ready.

FocusStoreChecks, AppGuardChecks and StatisticsChecks passed via scripts/check-focus-flow.sh. Independent preview compiled and signed at build/PangpangFlowPreview.app. No production install, production version bump, real data/settings change or remote push occurred. This is not a full keyboard/VoiceOver audit; new entries retain native button semantics, text labels and 40-point hit areas. Existing very-wide statistics column spreading is outside this refinement scope.

The previous report below describes an older installed release, not this preview. It is also backed up at design/design-qa-before-local-refinement.md.

---

# Previous focus lifecycle design QA — v1.1.0

final result: passed

## Evidence and normalization

Source visual truth: design/focus-flow-v1/selected-concept.png (1499 × 1049). This is the first displayed image selected by the user, not another direction.
Implementation: native SwiftUI/AppKit app, not a web prototype. CUA screenshots:
- design/focus-flow-v1/ready-final.png
- design/focus-flow-v1/running-final.png
- design/focus-flow-v1/completed-final.png
- design/focus-flow-v1/abandoned-final.png
- design/focus-flow-v1/rest-final.png
- design/focus-flow-v1/resized.png

Viewport: 800 × 600 native points, 1600 × 1200 raster pixels (2x). Resized capture: 920 × 680 points, 1840 × 1360 pixels.
Board panels are generated approximations, not perfectly equal 4:3 windows: 596×404 ready, 597×404 running, 435×328 completed, 428×328 abandoned and rest. Crops exclude external headings and flow arrows. scripts/compare-lifecycle.swift normalizes each panel and implementation to adjacent 800×600 regions in a 1600×600 image. Minor aspect-ratio distortion of board content is not a product defect; compare hierarchy and region proportions rather than treating it as exact typography measurement.
Full-view combined comparisons opened and inspected together:
- compare-ready-final.png
- compare-running-final.png
- compare-completed-final.png
- compare-abandoned-final.png
- compare-rest-final.png
(all under design/focus-flow-v1/).

A separate focused crop was not necessary: the paired 800-point panels make main typography, controls, paws and footer readable; original 2x native captures were also inspected for edges, transparency and small text. OS capture badge/cursor shadow and inactive traffic lights are capture/system chrome, not app art.

## Comparison history

1. Initial ready comparison: compare-ready.png paired selected source with ready.png.
   - [P2, typography/layout] Primary action was too small (216×52) and group sat too high.
   - Fixed: action 272×64, 23-point label, ready composition at 52 percent height, stronger 24-point brand wordmark, 160-point peeking cat.
   - Re-captured ready-final.png, reopened compare-ready-final.png: hierarchy now matches, no overlap.
2. Completion/rest comparison: earlier completed-before-polish.png/rest-before-polish.png and first final comparisons showed undersized reward and secondary rest action; rest surface missed the blue atmosphere.
   - [P2, imagery/layout/colors] Fixed: reward 152 points, completion heading 26, duration 60; rest timer 124, rest action 224×56; low-opacity source backdrop reused for pale-blue rest surface. Footer paws 40 points, last eight records bounded to avoid overflow.
   - Re-captured completed-final.png and rest-final.png and reopened their regenerated paired comparisons: main groups balanced, secondary controls readable, footer clear.
3. [P2, legibility] White small abandon text on light blue was weaker than needed.
   - Fixed: dark abandon label and darker running background while retaining white large timer. No extra control added.
   - running-final.png and compare-running-final.png show the same timer-only hierarchy with improved legibility. This intentional darker blue is an accessibility refinement, not a new direction.

## Required fidelity surfaces

- Fonts/typography: native system rounded semibold for countdown, system Chinese text for UI; no rasterized UI text. Clear brand → timer → task → action hierarchy. Countdown monospaced digits. Source generated glyph details are not used as a custom font.
- Spacing/layout: single primary action, no old shelf/card grid or duplicate immersive entry. Centered focus state, deliberate whitespace. Bottom collection and cat remain outside controls; resize tested to 920×680 without overlap.
- Colors/tokens: existing icy white, periwinkle accent and ink retained. Blue completed paw and desaturated gray incomplete paw distinct. Running blue is intentionally darker and abandon label dark for readability. No claim of full WCAG compliance or complete assistive-technology audit.
- Image quality: actual existing brand cat and simple paw PNGs reused. New transparent sleeping head preserves narrow face and illustration style; alpha validated. Real raster quiet background, no fake SVG/CSS mascot. No visible dashed stickers or compression seams.
- Copy/content: ready/start, explicit completion/rest decision, neutral actual-time abandon feedback, no pause controls in new focus. Completion notes bind to record ID. Counts differ from mock because they reflect disposable test records, not placeholders.

## Interaction and model checks

CUA, isolated preview only:
- Ready start immediately becomes timer + long-press abandon, no intermediate page.
- Short hold (350 ms) leaves focus unchanged; 1900 ms hold returns ready and displays 10 seconds recorded. Tested again on final styling.
- Complete using preview clock menu: result remains until user chooses rest/skip.
- Note editor opens; an eight-character disposable note accepted and saved; rest still starts only on explicit action.
- Start rest displays 05:00; end rest returns ready without auto-start.
- Settings opens/returns in the same window.
- Dragged bottom-right edge: 800×600 → 920×680, no clipping/overlap.
- Preview left ready, never used real user records.

Automated checks: FocusStoreChecks, AppGuardChecks, StatisticsChecks passed via scripts/check-focus-flow.sh. Checks include no new pause, reset cannot bypass active focus, partial time retention, idempotent completion/reset, persisted pending completion/long break, legacy 04:47 paused rest, legacy paused focus resume/reset, settings deadlines, notes, visibility and old-record migration.
Final app compiles, signs, and final Info.plist is 1.1.0/build 27 with original bundle ID. Xcode project plist valid and both new resources included.

## Intentional differences / follow-up polish

- P3: no confetti scatter around the reward; use a single paw spring and quiet footer to avoid ornamental noise. Existing peeking cat retained instead of regenerating a near-duplicate.
- P3: native wordmark/font and rounded button slightly differ from image-generated letterforms. System chrome and capture badge excluded from fidelity assessment.
- Animation is one-shot, keyed by completion record; reduced-motion setting skips it. No claim of competitor physics cloning or continuous draggable paw simulation.
- Real notification delivery/click-through and a complete keyboard/VoiceOver audit are not established by preview screenshots. Notification category routing compiled; do not describe it as a real delivered notification test.
- No remote push or release created in this change.

## Implementation checklist

- [x] First selected flow translated into the existing native app.
- [x] Remove new pause behavior across model/menu/mini card.
- [x] Explicit completion → rest choice, actual-time abandon, no history-clearing reset.
- [x] Preserve old paused state, bundle ID and storage keys.
- [x] Same-state combined comparisons, iterate P2 findings, re-capture and inspect.
- [x] Native interactions and isolated automated regressions verified.

## Installed build check

Installed v1.1.0/build 27 at /Users/tiantian.xu/Applications/Pang 大师.app and verified signature. Original v1.0.6 application preserved at /private/tmp/pang-before-v1.1.0-iEKLXw/Pang 大师.app; intermediate build also preserved at /private/tmp/pang-v1.1.0-before-seconds-fix-6rLcBY/Pang 大师.app.

Actual installed application AX state confirms “上次的计时已暂停 04:47”, “继续这轮计时”, “重置，重新准备”, “已完成记录不会清空”, and today's zero rounds/minutes. Neither resume nor reset was clicked on real data. Initial installed check found fractional seconds rounded up to 04:48; restored the legacy truncation behavior and added 287.97857-second regression input. Rebuilt/reinstalled, then verified 04:47 in actual AX text. Final screenshot capture encountered intermittent ScreenCaptureKit -3811, so do not claim an installed-app screenshot exists; visual comparisons remain from the isolated native preview. Final native AX check, signatures and automated regressions passed.
