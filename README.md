# Star Strike - Godot 4.7 Android space-combat game

A 3D touch-controlled spaceship shooter in the style of EverSpace 2.
Engine: **Godot 4.7.x** · Language: **GDScript** · Renderer: **Compatibility** (best Android device support).

## 1. Open the project
1. Install Godot **4.7.2** (standard build, not .NET).
2. Project Manager -> **Import** -> select `project.godot`.
3. First open takes a minute (it imports the ship models and builds the script cache).
   If you see "Could not find type ..." errors once, choose **Project -> Reload Current Project**.
4. Press **F5**. Desktop test controls: **WASD / arrows** steer, **Space** fires
   (mouse clicks on the on-screen joystick and FIRE button also work).

## 2. Game flow
Main Menu (Play / Select Ship / Select Level / Quit) -> Level -> Main Menu.
* **Select Ship**: 3 ships with different max speed and acceleration (shown as bars).
* **Select Level**: Asteroid Belt (space) or Canyon Run (planet surface).
* Goal: destroy all 5 enemy fighters, then fly through the glowing ring.
* Level complete shows your total time -> Replay or Main Menu.
* Health 0 -> Game Over -> Continue (restart level) or Quit (main menu).

## 3. Requirement checklist
| Requirement | Where |
|---|---|
| Godot 4.7.2, GDScript | whole project |
| Main menu with sub-menus, 3 ships, level select | `scripts/main_menu.gd`, `scripts/game_data.gd` |
| Ships differ in max speed and acceleration, shown on selection screen | `GameData.SHIPS`, ship page bars |
| Health, game over (continue/quit), level complete with time (replay/menu) | `scripts/hud.gd`, `scripts/level_base.gd` |
| HUD: health + images showing where to touch | `scripts/hud.gd`, `scripts/touch_controls.gd` |
| Virtual joystick steering + laser shooting (touch) | `scripts/touch_controls.gd`, `scripts/player_ship.gd` |
| Perspective chase camera like EverSpace 2 | `scripts/follow_camera.gd` |
| 2 levels: space + planet surface | `scripts/level_space.gd`, `scripts/level_planet.gd` |
| Enemies (flying models, lasers, icons visible at distance) | `scripts/enemy_ship.gd`, `scripts/marker_layer.gd` |
| FSM: wander / chase / attack | `EnemyShip.State` |
| 3+ steering behaviours: path following, wander (+ pursue, seek, arrive, obstacle avoidance) | `scripts/steering.gd`, `scripts/path_follower.gd` |
| Godot Flight Navigation 3D plugin | `res://src`, `addons/flight_navigation_3d`, baked in `LevelBase._build_navigation()` |
| Obstacles, environment personality | asteroids / canyon rocks / alien trees |
| Lighting, particles | glow, fog, sun + shadows (planet), engine trails, explosions, sparks, dust, goal sparkles |
| Sound effects + music | `scripts/audio_manager.gd` |

## 4. Export the APK (Windows)
1. Install **JDK 17** and the Android SDK (Android Studio's SDK folder is fine).
2. Godot: **Editor -> Editor Settings -> Export -> Android**: set *Java SDK Path* and *Android SDK Path*
   (and create a debug keystore with `keytool` as described in the Godot docs).
3. **Project -> Export -> Add -> Android**. Leave *Use Gradle Build* off for a simple APK.
4. Enable USB debugging on the phone, plug it in and press the **Android one-click deploy** button
   (top right), or *Export Project* to produce the `.apk`.
5. Record the 3-minute gameplay video from the **real device** with a mirroring tool (e.g. scrcpy) as MP4.

## 5. Tuning knobs (all in code, no editor work needed)
* Ship stats: `GameData.SHIPS`. Enemy toughness/speed: top of `enemy_ship.gd`.
* Enemies per level: `enemy_count` in each level's `_configure()`.
* Ships flying backwards? Set `GameData.MODEL_YAW` to `0.0`.
* Navigation bake detail: `nav_layers` in `level_base.gd` (6 = fast, 7 = finer but slower).
* Faster phones can use the Mobile renderer: Project Settings -> Rendering -> Renderer.

## 6. Credits
* Ships and environment: Quaternius (see `assets/ships/License.txt`).
* UI / crosshair / sounds: Kenney (CC0).
* Music: "8-Bit Video Game Music" by Florian Stracker.
* Godot Flight Navigation 3D: RevolNoom, https://github.com/RevolNoom/godot_flight_navigation_3d
  (copied into `src/`, `utility/`, `godot_morton_code/`, `addons/flight_navigation_3d/`; see its LICENSE).
* Steering behaviours after Craig Reynolds, "Steering Behaviors For Autonomous Characters" (1999).
* Laser/projectile idea after KidsCanCode Godot recipes (3D shooting); code re-written for this project.
