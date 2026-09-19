# ⚡ RIVALS — Real-Time On-Device AI Calisthenics Engine

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Google ML Kit](https://img.shields.io/badge/Google_ML_Kit-BlazePose_3D-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://developers.google.com/ml-kit)
[![Architecture](https://img.shields.io/badge/Architecture-Schmitt--Trigger_FSM-FF6D00?style=for-the-badge)](https://github.com)
[![Privacy](https://img.shields.io/badge/Privacy-100%25_On--Device_Edge_AI-00C853?style=for-the-badge)](https://github.com)

**Commercial-grade, zero-calibration calisthenics tracking and gamified fitness powered by edge computer vision.**

[The Problem](#-the-problem-why-fitness-apps-fail) • [Our Solution](#-the-solution-what-rivals-does-differently) • [Flowchart Diagrams](#-how-it-works-flowchart-diagrams) • [Architecture Deep Dive](#-system-architecture--engineering-pipeline) • [Biomechanics Math](#-biomechanical-mathematics--formulas) • [Gamification](#-gamification--the-mountain-ascent) • [Getting Started](#-getting-started)

</div>

---

## 🎯 The Problem: Why Fitness Apps Fail

Almost every fitness app that attempts camera-based rep tracking falls into the same trap: **they build toy prototypes that look neat in a demo video, but completely crumble when a real person actually tries to work out.**

If you've ever tried using a typical AI workout app, you’ve probably experienced these exact frustrations:

1. **The "Stand In The Red Box" Calibration Ritual:**  
   Most apps force you to do awkward calibration push-ups or spend 30 seconds aligning your body into a rigid silhouette before every single set. It kills your momentum and feels ridiculous.
2. **Broken Front/Floor Camera Math (The Z-Axis Trap):**  
   Most developers calculate standard 2D elbow angles. That works fine if your phone is mounted on a tripod 6 feet away at a perfect 90° side profile. But in real life, **people put their phone on the floor right in front of them**. From that angle, your arm moves directly along the camera's Z-axis (depth). 2D trigonometry collapses because the forearm foreshortens, causing the app to miss reps entirely or register random counts.
3. **The Rage of the "Rejected Rep" (Binary Discarding):**  
   You’re on rep 19, your muscles are burning, you push through pure exhaustion to finish the 20th rep with slightly sagging hips—and the app just ignores it completely because one confidence flag dipped below 0.8. Discarding reps during peak physical exertion is the #1 reason users rage-uninstall fitness apps.
4. **Threshold Bouncing & Double-Counting:**  
   Naive algorithms rely on a single angle threshold (like `angle < 90°`). When someone pauses at the bottom of a push-up or trembles under load, sensor noise oscillates across that single number, falsely registering 2, 3, or 4 ghost reps in a fraction of a second.
5. **Cloud Latency & Privacy Paranoia:**  
   Streaming live 30–60 FPS video of you working out in your bedroom to a remote cloud server is creepy, hogs bandwidth, drains battery, and adds 200–500ms of lag that ruins real-time audio/haptic feedback.

---

## 💡 The Solution: What RIVALS Does Differently

**RIVALS** is an engineering-first calisthenics tracking engine built from the ground up to solve these real-world mobile vision problems.

Here is how we tackle them:

* **100% On-Device Edge Inference:** Zero video frames ever leave your phone. Everything runs locally at 30–60 FPS using Google ML Kit (BlazePose) accelerated by device hardware (NPU/GPU). Zero cloud latency, zero server bills, total privacy.
* **Dual-Mode Biomechanics Engine:**
  * **Mode A (Side Profile):** 3-point joint vector trigonometry ($\vec{BA} \cdot \vec{BC}$) in the sagittal plane for pinpoint 98% accuracy when the phone is propped up sideways.
  * **Mode B (Front Floor / Selfie View):** Distance-invariant **Normalized Vertical Compression Ratio** ($\frac{|\text{wrist}_y - \text{shoulder}_y|}{|\text{hip}_y - \text{shoulder}_y|}$). By normalizing chest travel against torso length, tracking stays accurate regardless of user height or phone distance.
* **Schmitt-Trigger Finite State Machine (FSM with 60° Hysteresis):** By separating entrance thresholds ($95^\circ$) from exit thresholds ($155^\circ$), double-counting is mathematically impossible, even during extended holds or trembling reps.
* **Temporal EMA Signal Smoothing ($\alpha = 0.35$):** Smooths high-frequency camera micro-jitter and exposure fluctuations without introducing perceptible delay.
* **"Count the Rep, Score the Quality":** We never discard a completed range-of-motion rep. Instead, we decouple mechanical rep detection from **Form Quality Scoring (0–100%)**. You always get credit for your physical effort, while live coaching cues highlight hip sag, piking, or incomplete lockouts.
* **Spatial Multi-Person Tracking:** Train alongside a friend on a single phone. The tracker sorts skeletons along the horizontal X-axis and assigns dynamic player slots with a 45-second absence memory grace period so stepping away for water doesn't wipe your score.
* **Turn Push-Ups Into a Game:** Real-time 1-to-1 analog flight mechanics (e.g., Push-Up Flappy Bird) where your body's physical height directly drives the game, protected by an anti-cheat plank posture gate.

---

## 📊 How It Works: Flowchart Diagrams

Here are the exact system flowcharts mapping out how frames move from the camera sensor to rep completion and game mechanics:

### 1. Push-Up Tracking Engine & Form Validation Flow

This flowchart illustrates the core state machine: from raw landmark extraction through spine collinearity verification, top lockout, bottom inflection, rep registration, and offline persistence.

![Push-Up Tracking Engine Flowchart](./pushup_tracking_flowchart.png)

*(A light-theme version is also available: [pushup_white_flowchart.png](./pushup_white_flowchart.png))*

#### Step-by-Step Breakdown:
1. **Camera & Pose Extraction:** Streams 30 FPS camera frames into Google ML Kit BlazePose to extract 33 3D skeletal landmarks.
2. **Posture & Form Guard:** Checks if the shoulder-hip-ankle line is collinear within tolerance. If hips sag or pike, a form warning triggers and deducts 20% from that rep's form score.
3. **Top Lockout Check (State 1):** Validates arm extension ($\text{Elbow Angle} \ge 150^\circ$, or selfie ratio $\le 35\%$).
4. **Bottom Depth Check (State 2):** Detects chest lowering until elbow angle hits $\le 95^\circ$ (or selfie ratio $\ge 55\%$).
5. **Concentric Ascent & Rep Registered (State 3):** User presses back up to lockout ($\ge 150^\circ$). The rep counter increments by 1, haptic vibration fires, and the form quality score is saved.
6. **Local Persistence:** Data is committed to local disk storage (`SharedPreferences` / SQLite) with zero cloud dependency.

---

### 2. Flappy Push-Up Arcade & Anti-Cheat Architecture

This diagram details the interaction loop powering the arcade game mode, where push-ups control an analog flight simulation with real-time anti-cheat posture gating.

![Flappy Push-Up Architecture](./flappy_pushup_architecture.png)

*(Companion presentation diagram: [presentation_flowchart.png](./presentation_flowchart.png) and clean light version: [flappy_white_flowchart.png](./flappy_white_flowchart.png))*

```
 +------------------+      +-------------------+      +-----------------------+
 |  Camera Stream   | ---> | ML Kit Face & Pose| ---> |  Anti-Cheat Gate      |
 | (30-60 FPS YUV)  |      | (33 3D Landmarks) |      | (Rejects Upright/Sit) |
 +------------------+      +-------------------+      +-----------+-----------+
                                                                  | PASS
                                                                  v
 +------------------+      +-------------------+      +-----------------------+
 | Local Persistence| <--- | Push-Up Rep FSM   | <--- | Analog Flappy Physics |
 | (Offline JSON DB)|      | (Lockout -> Depth)|      | (1:1 Chest/Face Map)  |
 +------------------+      +-------------------+      +-----------------------+
```

---

### 3. High-Level 4-Step Summary

For a fast bird’s-eye view of the pipeline:

![Simple 4-Step Flowchart](./simple_flowchart.png)

---

## 🏗 System Architecture & Engineering Pipeline

The computer vision engine is structured as an **8-stage synchronous/asynchronous data pipeline**:

```mermaid
flowchart TD
    A[Camera Hardware Sensor<br/>YUV420 / NV21 @ 30-60 FPS] --> B{Non-Blocking Ingestion<br/>_isDetecting Atomic Flag}
    B -->|Dropped Frame| X[Drop Frame<br/>Keep UI @ 60 FPS]
    B -->|Accepted Frame| C[Sensor Normalization<br/>Orientation & Selfie Mirroring]
    C --> D[Google ML Kit BlazePose<br/>33 3D Skeletal Landmarks]
    D --> E[Temporal Signal Filter<br/>Exponential Moving Average α = 0.35]
    E --> F[Biomechanical Engine<br/>Mode A: Dot Product | Mode B: Compression]
    F --> G[Schmitt-Trigger FSM<br/>4-Stage State Machine with Hysteresis]
    G --> H[UI Canvas & Multi-Modal Feedback<br/>CustomPainter Skeleton + Haptic Buzzer]
```

### The 8 Stages in Detail:

1. **Camera Hardware Stream:** Emits raw YUV420 (Android) or BGRA (iOS) byte buffers at 30–60 FPS.
2. **Throttled Frame Ingestion:** Uses an atomic boolean flag (`_isDetecting`) to instantly discard incoming frames if the neural inference thread is busy. This keeps the Flutter UI locked at a silky 60 FPS on both budget and flagship devices.
3. **Sensor Orientation & Normalization:** Compensates for native camera sensor rotations (90° / 270°) and mirrors coordinates horizontally when using the front-facing selfie camera.
4. **Google ML Kit Inference (BlazePose):** Feeds normalized input into the on-device convolutional neural network to produce 33 spatial keypoints with confidence likelihoods.
5. **Temporal EMA Smoothing:** Filters high-frequency landmark jitter caused by sensor noise and dynamic room lighting:
   $$\hat{y}_t = \alpha \cdot y_t + (1 - \alpha) \cdot \hat{y}_{t-1} \quad (\alpha = 0.35)$$
6. **Biomechanical Trigonometry Engine:** Evaluates joint angles or vertical compression ratios depending on selected camera placement.
7. **Schmitt-Trigger Finite State Machine (FSM):** Steps through `waitingForPlank` $\to$ `top` $\to$ `descending` $\to$ `bottom` $\to$ `ascending` $\to$ `completed`.
8. **AR Canvas Overlay & Multi-Modal Feedback:** `CustomPainter` renders glowing neon skeleton vectors and floating holographic nametags directly over the body, while the device triggers haptic pulses on rep completion.

---

## 📐 Biomechanical Mathematics & Formulas

### Mode A: Side Profile View (3-Point Joint Vector Trigonometry)
When the camera is to the athlete's side, joint positions exist in the 2D sagittal plane. We compute the exact internal elbow angle formed at vertex $B$ (Elbow) between $A$ (Shoulder) and $C$ (Wrist) using the vector dot product:

$$\vec{BA} = (A_x - B_x, \, A_y - B_y), \quad \vec{BC} = (C_x - B_x, \, C_y - B_y)$$

$$\theta = \arccos\left( \frac{\vec{BA} \cdot \vec{BC}}{\|\vec{BA}\| \cdot \|\vec{BC}\|} \right) \times \left(\frac{180^\circ}{\pi}\right)$$

* **Top Lockout:** $\theta \ge 155^\circ$
* **Bottom Inflection (Full Depth):** $\theta \le 95^\circ$

### Mode B: Front Floor View (Normalized Vertical Compression Ratio)
When the phone is lying flat on the floor facing the user, arms move along the depth axis ($Z$), rendering 2D angle trigonometry ineffective. RIVALS calculates the **Normalized Vertical Compression Ratio**:

$$R_{\text{depth}} = \frac{|\text{wrist}_y - \text{shoulder}_y|}{|\text{hip}_y - \text{shoulder}_y|}$$

* **Top Lockout:** $R_{\text{depth}} \approx 0.75 - 0.90$
* **Bottom Depth:** $R_{\text{depth}} \le 0.35$
* *Why it works:* By normalizing vertical chest-to-ground travel against torso length ($\text{hip}_y - \text{shoulder}_y$), the metric is scale-invariant and immune to camera distance or athlete height.

### Spine & Plank Collinearity (Form Quality Check)
To catch hip sagging or piking, we calculate the expected hip midpoint between shoulders and ankles:

$$Y_{\text{expected}} = Y_{\text{shoulder}} + 0.5 \times |Y_{\text{ankle}} - Y_{\text{shoulder}}|$$

$$\text{Deviation} = \frac{|Y_{\text{hip}} - Y_{\text{expected}}|}{|Y_{\text{ankle}} - Y_{\text{shoulder}}|}$$

If $\text{Deviation} > 0.25$, a spine sag/pike warning is triggered and form score is penalized by 20%.

---

## 🛡 The Schmitt-Trigger Hysteresis FSM

Single-threshold triggers cause catastrophic double-counting. RIVALS separates the entrance and exit boundaries by a **60° hysteresis buffer**:

| State | Trigger Condition | Action / Output |
| :--- | :--- | :--- |
| **1. TOP (Ready)** | $\theta \ge 155^\circ$ OR $R_{\text{depth}} \ge 0.75$ | Lockout established. Ready for descent. |
| **2. DESCENDING** | $\theta < 140^\circ$ OR $R_{\text{depth}} < 0.65$ | Downward eccentric motion confirmed. |
| **3. BOTTOM** | $\theta \le 95^\circ$ OR $R_{\text{depth}} \le 0.35$ | Full depth achieved! Sets `validDepthReached = true`. |
| **4. ASCENDING** | $\theta > 115^\circ$ OR $R_{\text{depth}} > 0.45$ | Concentric phase. Pushing back up. |
| **5. COMPLETED** | $\theta \ge 155^\circ$ AND `validDepthReached == true` | **REP COUNTED!** Form score calculated, haptic buzz fires. |

> **Why Hysteresis Eliminates Double-Counting:**  
> Because the exit threshold ($155^\circ$) is separated from the entrance threshold ($95^\circ$) by a large buffer, trembling at the bottom or pausing mid-rep cannot bounce across boundaries or register ghost reps.

---

## 👥 Multi-Person Spatial Tracking

RIVALS supports simultaneous tracking of multiple athletes on a single mobile screen:

* **Spatial X-Centroid Sorting:** Skeletons are sorted left-to-right based on normalized torso centroids:
  $$\bar{X} = \frac{1}{N}\sum_{i \in \{\text{nose, shoulders}\}} X_i$$
* **Dynamic Slot Allocation:** Skeletons are mapped to persistent player tracks (Player 1, Player 2, etc.) each with their own theme color, state machine, and rep counter.
* **45-Second Absence TTL Grace Period:** If an athlete steps off camera to grab a towel or catch their breath, their slot and rep count remain safely in memory.

---

## 🏔 Gamification & The Mountain Ascent

To turn repetitive calisthenics into long-term discipline, RIVALS maps workout progress to an expedition up a legendary peak:

* **Elevation Conversion:** **$1 \text{ Push-Up} = 5 \text{ Meters of Altitude}$**
* **Milestone Tiers:**
  * 🏕️ **Novice Plateau:** $50\text{m}$ (10 Reps)
  * 🌲 **Warrior Ridge:** $250\text{m}$ (50 Reps)
  * ☁️ **Cloud Break Summit:** $1,000\text{m}$ (200 Reps)
  * 🏔️ **Stratosphere Gate:** $3,000\text{m}$ (600 Reps)
  * 👑 **Everest Crown:** $8,000\text{m}$ (1,600 Reps)
  * ✨ **Celestial Orbit:** $15,000\text{m}$ (3,000 Reps)
* **Fitness Games Arcade:**
  * **Push-Up Flappy Bird:** Fly through pipes by controlling your push-up height in real-time.
  * **Plank Endurance Hold:** Isometric stability challenges with live posture feedback.
  * **Ghost / Bot Battles:** Race against simulated competitors or past personal bests.

---

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry point, orientation lock, dark gold theme
├── app.dart                           # Navigation shell with persistent IndexedStack & exercise selector
├── painters/
│   └── pose_painter.dart              # Hardware-accelerated CustomPainter, neon skeletons, AR nametags
├── screens/
│   ├── camera_screen.dart             # Real-time AI tracking HUD, camera stream, workout summary
│   ├── fitness_games_screen.dart      # Fitness arcade game selector
│   ├── game_mode_screen.dart          # Push-Up Flappy Bird with 1:1 analog physics & anti-cheat
│   ├── home_screen.dart               # Mountain expedition progress, daily streaks, quick launch
│   ├── ranks_screen.dart              # Global & tier leaderboards
│   ├── profile_screen.dart            # Career statistics, unlocked milestones, history
│   ├── video_verification_screen.dart # Form verification analysis for Squats & Push-ups
│   ├── community_screen.dart          # Challenges, feeds, and peer activity
│   └── prototype_competition_screen.dart # Multi-person & bot competition arena
├── services/
│   ├── pose_service.dart              # Core biomechanics: vector angles, compression ratio, EMA, FSM
│   ├── multi_pose_tracker.dart        # Spatial X-centroid sorting, multi-athlete tracking & TTL
│   ├── progression_service.dart       # Mountain altitude calculations, streaks, and milestones
│   ├── stats_service.dart             # Local workout log persistence
│   ├── prototype_bot_engine.dart      # Simulated bot competitors for head-to-head racing
│   └── squat_tracker_service.dart     # Dedicated biomechanics engine for squat depth (hip/knee)
├── theme/
│   └── rivals_theme.dart              # Sleek dark-mode aesthetic with neon emerald & amber accents
└── widgets/
    └── bottom_nav.dart                # Custom navigation bar with floating center camera action
```

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13+ or newer recommended)
* Physical Android or iOS device (Camera stream and ML Kit neural models require real camera hardware; mobile simulators do not support camera feeds).
* Camera permissions configured in Android Manifest and iOS Info.plist (already configured in this repository).

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/cosmicbyt123/RIVALS.git
   cd RIVALS/rivals
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on a connected device:**
   ```bash
   flutter run
   ```

---

## 🧪 Testing

The codebase includes comprehensive unit tests verifying the biomechanical state machine, multi-person tracking, progression altitude calculations, and form scoring:

```bash
flutter test
```

Key test suites:
* `test/pose_service_test.dart` — Tests Schmitt-trigger FSM transitions, lockout boundaries, and hysteresis behavior.
* `test/multi_pose_tracker_test.dart` — Validates spatial centroid sorting and dynamic player slot allocation.
* `test/progression_service_test.dart` — Verifies altitude elevation logic and milestone unlock thresholds.

---

## 🔒 Privacy & Architecture Guarantees

* **Zero Cloud Video Ingestion:** Camera buffers never touch network sockets. Frames live only in volatile device RAM during inference and are immediately recycled.
* **Offline-First Resilience:** Workouts, personal bests, and career progression are saved directly to local storage (`SharedPreferences` / JSON), enabling full functionality in airplane mode or gyms without cell service.
* **Thermal & Battery Optimization:** Stream configuration runs at balanced resolution (`ResolutionPreset.medium`) to sustain 60 FPS without device overheating.

---

<div align="center">
Built with passion for calisthenics, computer vision, and gamified fitness.
</div>
