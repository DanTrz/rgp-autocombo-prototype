using System;
using System.Collections.Generic;
using Godot;

public partial class ShaftChunkController : Area3D
{
	[ExportGroup("Mandatory Node References")]
	[Export] public CollisionShape3D _collisionShape { get; set; }
	[Export] public ShaftMultiMeshController _shaftMultiMesh { get; set; }

	[ExportGroup("Chunk Settings")]
	[Export] bool _isChunkActive { get; set; } = true;
	[Export] bool _useRandomSpread { get; set; } = true;
	[Export] bool _useFixedCount { get; set; } = false;
	[Export] int _fixCountPerChunk { get; set; } = 10;
	[Export] float _chunkDensity { get; set; } = 50.0f;
	[Export] float _minimumSpacing { get; set; } = 1.5f; // Minimum distance between instances

	[ExportGroup("Shaft Generation")]
	[Export] bool _isShaftMMActive { get; set; } = true;
	[Export] Vector3 _intialScale { get; set; } = Vector3.One;

	[Export(PropertyHint.Enum, "InstanceBased,NodeBased")] public int RotationType { get; set; } = 0;
	[Export] float _instancesRotationZ { get; set; } = 0.0f;
	[Export] float _nodeRotationZ { get; set; } = 0.0f;
	[Export] private float _worldBoundMaxSize { get; set; } = 500.0f;

	[ExportGroup("Raycast")]
	[Export] bool _raycastEnabled { get; set; } = true;
	[Export] bool _resizeShaftOnCollision { get; set; } = true;
	[Export] private float _rayLenght { get; set; } = 80.0f;
	[Export(PropertyHint.Layers3DRender)] public uint RaycastCollisionLayers { get; set; } = 1;

	[ExportGroup("Debugging")]
	[Export] private bool _showDebugSpheres { get; set; } = false;
	[Export] SphereDebugVisualizer _debuggerSphere { get; set; }
	[Export] private bool _showOnlyColliders { get; set; } = true;

	public float DistanceToCamera { get; set; }




	public override void _Ready()
	{
		if (_collisionShape == null || _shaftMultiMesh == null)
		{
			try
			{
				_collisionShape = GetNode<CollisionShape3D>("CollisionShape3D");
				_shaftMultiMesh = GetNode<ShaftMultiMeshController>("ShaftMultiMeshController");
			}
			catch (System.Exception exception)
			{

				Log.Error($"ShaftChunkController error: Missing references for CollisionShape3D and {nameof(ShaftMultiMeshController)} : {exception.Message}");
				return;
			}
		}

		var bounds = ((BoxShape3D)_collisionShape.Shape).Size;

		List<Vector3> spawnPositions = _useRandomSpread
			? GenerateRandomPositions(bounds)
			: GenerateGridPositions(bounds);

		SetupMultiMeshController();
		_shaftMultiMesh.SpawnInstances(spawnPositions);
	}

	private void SetupMultiMeshController()
	{

		_shaftMultiMesh.IsShaftMMActive = _isShaftMMActive;
		_shaftMultiMesh.InitialScale = _intialScale;
		_shaftMultiMesh.WorldBoundMaxSize = _worldBoundMaxSize;
		_shaftMultiMesh.RaycastEnabled = _raycastEnabled;
		_shaftMultiMesh.ResizeShaftOnCollision = _resizeShaftOnCollision;
		_shaftMultiMesh.RayLenght = _rayLenght;
		_shaftMultiMesh.RaycastCollisionLayers = RaycastCollisionLayers;
		_shaftMultiMesh.ShowDebugSpheres = _showDebugSpheres;
		_shaftMultiMesh.DebuggerSphere = _debuggerSphere;
		_shaftMultiMesh.ShowOnlyColliders = _showOnlyColliders;

		switch (RotationType)
		{
			case 0:
				_shaftMultiMesh.InstancesRotationZ = _instancesRotationZ;
				break;
			case 1:
				_shaftMultiMesh.RotateZ(Mathf.DegToRad(_nodeRotationZ));
				_shaftMultiMesh.InstancesRotationZ = 0.0f;
				break;

			default:
				break;
		}
	}

	public void ActivateChunk()
	{
		Visible = true;
		SetProcess(true);
		_isChunkActive = true;
		Log.Debug($"Activated chunk: {Name}");
		// Future: trigger shader fade-in
	}

	public void DeactivateChunk()
	{
		Visible = false;
		SetProcess(false);
		_isChunkActive = false;
		Log.Debug($"Deactivated chunk: {Name}");
		// Future: trigger shader fade-out
	}
	private List<Vector3> GenerateGridPositions(Vector3 bounds)
	{
		Log.Debug("GenerateGridPositions started");

		int count = _useFixedCount
			? _fixCountPerChunk
			: Mathf.RoundToInt(bounds.X * bounds.Z * (_chunkDensity / 100f));
		count = Mathf.Max(count, 1);

		// Adjust grid layout based on minimum spacing
		int columns = Mathf.Max(1, Mathf.FloorToInt(bounds.X / _minimumSpacing));
		int rows = Mathf.Max(1, Mathf.FloorToInt(bounds.Z / _minimumSpacing));
		int maxCount = columns * rows;
		count = Mathf.Min(count, maxCount);

		float cellSizeX = bounds.X / columns;
		float cellSizeZ = bounds.Z / rows;

		List<Vector3> positions = new();
		float originX = -bounds.X / 2f + cellSizeX / 2f;
		float originZ = -bounds.Z / 2f + cellSizeZ / 2f;

		for (int x = 0; x < columns; x++)
		{
			for (int z = 0; z < rows; z++)
			{
				Vector3 localPos = new(
					originX + x * cellSizeX,
					0f,
					originZ + z * cellSizeZ
				);
				positions.Add(localPos);
				if (positions.Count >= count) return positions;
			}
		}

		return positions;
	}

	private List<Vector3> GenerateRandomPositions(Vector3 bounds)
	{
		Log.Debug("GenerateRandomPositions started");

		float area = bounds.X * bounds.Z;
		float effectiveCellArea = _minimumSpacing * _minimumSpacing;
		int maxCountBySpacing = Mathf.FloorToInt(area / effectiveCellArea);
		int count = _useFixedCount ? _fixCountPerChunk : Mathf.Min(Mathf.RoundToInt(area * (_chunkDensity / 100f)), maxCountBySpacing);
		count = Mathf.Max(count, 1);

		List<Vector3> positions = new();
		int attempts = 0;
		const int maxAttempts = 10000;

		while (positions.Count < count && attempts < maxAttempts)
		{
			attempts++;
			Vector3 candidate = new(
				(float)GD.RandRange(-bounds.X / 2f, bounds.X / 2f),
				0f,
				(float)GD.RandRange(-bounds.Z / 2f, bounds.Z / 2f)
			);

			bool isFarEnough = true;
			foreach (var pos in positions)
			{
				if (candidate.DistanceTo(pos) < _minimumSpacing)
				{
					isFarEnough = false;
					break;
				}
			}

			if (isFarEnough)
			{
				positions.Add(candidate);
			}
		}

		return positions;
	}
}