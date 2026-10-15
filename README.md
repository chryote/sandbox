# 3D Voxel Sandbox (Godot 4.4)

A modular, data-driven 3D voxel sandbox built with Godot 4.4 featuring $1.0 \times 1.0 \times 1.0\text{ m}$ cube representative blocks, procedural world generation, face-culled `ArrayMesh` generation with physics collision, and a decoupled Third-Person Shooter (TPS) character controller.

---

## 📁 Project Structure

```text
d:/GODOT/sandbox/
├── project.godot                     # Godot 4.4 configuration, input maps & autoloads
├── core/                             # Engine core singletons & utilities
│   ├── constants.gd                  # Project-wide semantic constants (Zero magic variables)
│   ├── logger.gd                     # Dual console & file logger service
│   ├── event_bus.gd                  # Decoupled signal router
│   └── math/
│       └── voxel_coordinates.gd      # World <-> Voxel <-> Chunk math conversions
├── logs/                             # Runtime log destination
│   ├── .gitkeep
│   └── app.log                       # Game execution log with timestamps
├── modules/
│   ├── world/                        # Data-driven world generation & chunk management
│   │   ├── data/
│   │   │   ├── block_definition.gd   # Resource: Block definition schema
│   │   │   ├── block_registry.gd     # Palette registry & ID dictionary
│   │   │   ├── biome_definition.gd   # Resource: Strata & elevation configuration
│   │   │   └── world_gen_config.gd   # Resource: Noise & world parameters
│   │   ├── chunk/
│   │   │   ├── chunk_data.gd         # Fast PackedByteArray 3D voxel buffer
│   │   │   ├── chunk_mesher.gd       # 6-way face culling ArrayMesh generator
│   │   │   └── chunk_view.gd         # MeshInstance3D & StaticBody3D collision node
│   │   ├── generation/
│   │   │   └── terrain_generator.gd  # FastNoiseLite procedural terrain evaluator
│   │   └── management/
│   │       └── chunk_manager.gd      # Chunk lifecycle & cross-boundary remesher
│   └── player/                       # Decoupled Third-Person Shooter module
│       ├── camera/
│       │   └── tps_camera_rig.gd     # SpringArm3D over-the-shoulder camera rig
│       ├── controllers/
│       │   └── tps_controller.gd     # CharacterBody3D locomotion & physics
│       └── interaction/
│           └── voxel_raycaster.gd    # Crosshair targeting & decoupled block events
├── scenes/
│   ├── main.tscn                     # Main assembled game scene
│   ├── world/
│   │   └── world_sandbox.tscn        # Isolated procedural world viewer scene
│   └── player/
│       └── tps_player.tscn           # Standalone TPS character scene
├── tests/
│   ├── test_runner.gd                # Automated test runner suite
│   ├── test_runner.tscn              # Test harness scene
│   └── unit/
│       ├── test_voxel_coordinates.gd # Coordinate conversions & raycast math tests
│       ├── test_block_registry.gd    # Block palette integrity tests
│       └── test_chunk_data.gd        # Voxel storage and boundary bounds tests
└── UI/
    ├── crosshair.gd & .tscn          # Minimalist centered TPS reticle
    └── debug_overlay.gd & .tscn      # Real-time telemetry dashboard (FPS, coords, volume)
```

---

## 🧱 Architectural Principles

1. **Zero Magic Variables / Named Constants**:
   - All geometric dimensions, chunk capacities, layer depths, physics accelerations, raycast distances, camera pitch limits, and block IDs are explicitly declared named constants in [`core/constants.gd`](file:///d:/GODOT/sandbox/core/constants.gd) or class configuration headers.
2. **Data-Driven World Generation**:
   - Terrain behavior, noise settings (`FastNoiseLite`), elevations, and layer strata are parameterized through `WorldGenConfig` and `BiomeDefinition` resources.
   - Block definitions (`BlockDefinition`) cleanly specify solidity, transparency, colors, and hardness in `BlockRegistry`.
3. **Decoupled Player Module**:
   - The Player module never references `ChunkManager` or internal chunk mesh buffers directly.
   - Interaction is mediated exclusively via `EventBus.block_modify_requested(voxel_coord, block_id)` signals and abstract coordinate queries in [`core/math/voxel_coordinates.gd`](file:///d:/GODOT/sandbox/core/math/voxel_coordinates.gd).
4. **Automated Testing Suite**:
   - Run `res://tests/test_runner.tscn` to run the automated unit test suite.
