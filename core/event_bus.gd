@warning_ignore("unused_signal")
class_name EventBusService
extends Node

## -----------------------------------------------------------------------------
## World & Voxel Modification Signals
## -----------------------------------------------------------------------------
## Emitted when an entity (e.g. Player) requests a block modification.
## [param world_voxel_pos]: Integer 3D coordinate of the targeted voxel.
## [param new_block_id]: ID of the block to place, or Constants.BLOCK_ID_AIR to mine.
@warning_ignore("unused_signal")
signal block_modify_requested(world_voxel_pos: Vector3i, new_block_id: int)

## Emitted by ChunkManager when a block is successfully modified and remeshed.
@warning_ignore("unused_signal")
signal block_modified(world_voxel_pos: Vector3i, new_block_id: int)

## -----------------------------------------------------------------------------
## Chunk Lifecycle Signals
## -----------------------------------------------------------------------------
## Emitted when a chunk finishes generation and is added to the scene tree.
@warning_ignore("unused_signal")
signal chunk_loaded(chunk_coord: Vector3i)

## Emitted when a chunk is unloaded and freed.
@warning_ignore("unused_signal")
signal chunk_unloaded(chunk_coord: Vector3i)

## -----------------------------------------------------------------------------
## Player & UI State Signals
## -----------------------------------------------------------------------------
## Emitted by the player controller periodically or on movement to notify managers.
@warning_ignore("unused_signal")
signal player_position_updated(world_position: Vector3)

## Emitted when player cycles or selects an active block to place.
@warning_ignore("unused_signal")
signal selected_block_changed(block_id: int)

## Emitted when the debug HUD is toggled on or off.
@warning_ignore("unused_signal")
signal debug_overlay_toggled(is_visible: bool)
