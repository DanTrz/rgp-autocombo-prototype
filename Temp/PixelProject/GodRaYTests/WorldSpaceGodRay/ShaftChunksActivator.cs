using System;
using Godot;

public partial class ShaftChunksActivator : Node3D
{

	[ExportGroup("Mandatory Node References")]
	[Export] Godot.Collections.Array<ShaftChunkController> _chunksArray;
	[Export] Camera3D _mainCamera;

	[ExportGroup("Chunk Activation")]
	[Export] public float ActivationDistance { get; set; } = 50f;
	[Export] public float DeactivationDistance { get; set; } = 50f;

	[Export] Vector2 ActivationRange { get; set; } = new(75.0f, 250.0f);
	[Export] Vector2 DeactivationRange { get; set; } = new(10.0f, 75.0f);

	// [Export] public float HysteresisBuffer { get; set; } = 10f;
	private Godot.Collections.Dictionary<ShaftChunkController, bool> _chunkState = new();

	public override void _Ready()
	{
		if (_mainCamera == null || _chunksArray.Count == 0)
		{
			Log.Error($"ShaftChunksActivator error: Missing references for {nameof(_mainCamera)} or {nameof(_chunksArray)}");
			return;
		}

		//Start with all chunks inactive
		foreach (var chunk in _chunksArray)
		{
			_chunkState[(ShaftChunkController)chunk] = false; // assume all start inactive
			chunk.DeactivateChunk();
		}
	}

	private void ManageChunksActivation()
	{
		Vector3 cameraPos = _mainCamera.GlobalTransform.Origin;

		foreach (ShaftChunkController chunkController in _chunksArray)
		{
			float cameraDistance = cameraPos.DistanceTo(chunkController.GlobalTransform.Origin);
			bool isActive = _chunkState[chunkController];

			if (!isActive && cameraDistance <= ActivationDistance && cameraDistance > DeactivationDistance)
			{
				chunkController.ActivateChunk();
				_chunkState[chunkController] = true;
			}
			else if (isActive && cameraDistance < DeactivationDistance)
			{
				chunkController.DeactivateChunk();
				_chunkState[chunkController] = false;
			}

		}

	}
	public override void _Process(double delta)
	{
		ManageChunksActivation();
	}
}