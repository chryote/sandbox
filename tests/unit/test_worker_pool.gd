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
		generator.generate_surface_shell(data)
		var mesh_and_shape: Dictionary = ChunkMesherScript.build_chunk_mesh_and_shape(data, registry)
		mutex.lock()
		result_data["mesh"] = mesh_and_shape["mesh"]
		result_data["shape"] = mesh_and_shape["shape"]
		result_data["data"] = data
		mutex.unlock()

	var task_id: int = WorkerThreadPool.add_task(worker_fn)
	WorkerThreadPool.wait_for_task_completion(task_id)

	if not result_data.has("mesh") or result_data["mesh"] == null:
		printerr("FAIL: Worker thread did not produce surface mesh")
		return false

	if not result_data.has("shape") or result_data["shape"] == null:
		printerr("FAIL: Worker thread did not produce prebaked surface collision shape")
		return false

	var data = result_data["data"]
	if not data.is_surface_only():
		printerr("FAIL: Surface shell chunk must report is_surface_only() == true")
		return false

	var shape: ConcavePolygonShape3D = result_data["shape"] as ConcavePolygonShape3D
	var faces: PackedVector3Array = shape.get_faces()
	if faces.is_empty():
		printerr("FAIL: Prebaked collision shape has empty face buffer")
		return false

	# Test 2: Deferred background subsurface fill (Phase B)
	var sub_worker_fn = func():
		generator.fill_subsurface(data)

	var sub_task_id: int = WorkerThreadPool.add_task(sub_worker_fn)
	WorkerThreadPool.wait_for_task_completion(sub_task_id)

	if not data.is_full():
		printerr("FAIL: Chunk must report is_full() == true after subsurface fill")
		return false

	Logger.info("Two-phase worker thread pipeline succeeded! Surface faces: %d, GenState: FULL" % (faces.size() / 3), "TestWorkerPool")
	return true
