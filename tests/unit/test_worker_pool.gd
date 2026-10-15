class_name TestWorkerPool
extends RefCounted

const ConstantsScript = preload("res://core/constants.gd")
const BlockRegistryScript = preload("res://modules/world/data/block_registry.gd")
const ChunkDataScript = preload("res://modules/world/chunk/chunk_data.gd")
const ChunkMesherScript = preload("res://modules/world/chunk/chunk_mesher.gd")
const TerrainGeneratorScript = preload("res://modules/world/generation/terrain_generator.gd")
const WorldGenConfigScript = preload("res://modules/world/data/world_gen_config.gd")

static func run_all() -> bool:
	var registry = BlockRegistryScript.new()
	var config = WorldGenConfigScript.new()
	var generator = TerrainGeneratorScript.new(config)

	var target_coord = Vector3i(10, 0, 10)
	var result_data: Dictionary = {}
	var mutex = Mutex.new()

	var worker_fn = func():
		var data = ChunkDataScript.new(target_coord)
		generator.generate_chunk_data(data)
		var mesh = ChunkMesherScript.build_chunk_mesh(data, registry)
		mutex.lock()
		result_data["mesh"] = mesh
		mutex.unlock()

	var task_id: int = WorkerThreadPool.add_task(worker_fn)
	WorkerThreadPool.wait_for_task_completion(task_id)

	if not result_data.has("mesh") or result_data["mesh"] == null:
		printerr("FAIL: Worker thread did not produce mesh")
		return false

	var shape = result_data["mesh"].create_trimesh_shape()
	if shape == null:
		printerr("FAIL: Main thread could not produce shape from mesh")
		return false

	Logger.info("Worker thread chunk generation & meshing succeeded!", "TestWorkerPool")
	return true
