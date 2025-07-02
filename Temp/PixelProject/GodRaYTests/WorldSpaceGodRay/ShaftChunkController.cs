using System;
using System.Collections.Generic;
using Godot;

public partial class ShaftChunkController : Area3D
{
	[ExportGroup("Chunk Settings")]
	[Export] bool _isChunkActive { get; set; } = true;
	[Export] bool _useRandomSpread { get; set; } = true;
	[Export] bool _useFixedCount { get; set; } = false;
	[Export] int _fixCountPerChunk { get; set; } = 10;
	[Export] float _chunkDensity { get; set; } = 50.0f;
	[Export] float _minimumSpacing { get; set; } = 1.5f; // Minimum distance between instances

	[ExportGroup("Node References")]
	[Export] CollisionShape3D _collisionShape { get; set; }
	[Export] ShaftMultiMeshController _shaftMultiMesh { get; set; }

	public override void _Ready()
	{
		Log.Debug($"{this.Name} Ready");

		var bounds = ((BoxShape3D)_collisionShape.Shape).Size;

		List<Vector3> spawnPositions = _useRandomSpread
			? GenerateRandomPositions(bounds)
			: GenerateGridPositions(bounds);

		_shaftMultiMesh.SpawnInstances(spawnPositions);
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