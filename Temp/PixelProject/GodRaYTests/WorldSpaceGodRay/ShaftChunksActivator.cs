using System;
using Godot;

public partial class ShaftChunksActivator : Node3D
{

	[ExportGroup("Mandatory Node References")]
	[Export] Godot.Collections.Array<ShaftChunkController> _chunksArray;
	[Export] Camera3D _mainCamera;

	[ExportGroup("Chunk Activation")]
	[Export] Vector2 ActivationRange { get; set; } = new Vector2(75.0f, 250.0f);


	private Godot.Collections.Dictionary<ShaftChunkController, bool> _chunkState = new();

	public override void _Ready()
	{
		if (_mainCamera == null || _chunksArray.Count == 0)
		{
			Log.Error($"ShaftChunksActivator error: Missing references for {nameof(_mainCamera)} or {nameof(_chunksArray)}");
			return;
		}
		ChunkInitialization();
	}

	private void ChunkInitialization()
	{
		foreach (ShaftChunkController chunkController in _chunksArray)
		{
			_chunkState[(ShaftChunkController)chunkController] = false; // assume all start inactive
																		// chunkController.DeactivateChunk();
			chunkController._shaftMultiMesh.ActivationRangeMax = ActivationRange.Y;
			chunkController._shaftMultiMesh.ActivationRangeMin = ActivationRange.X;
		}
	}

	private void ManageChunks()
	{
		Vector3 cameraPos = _mainCamera.GlobalTransform.Origin;
		foreach (ShaftChunkController chunkController in _chunksArray)
		{
			//Check and pass the camera distance to the chunk collisionShape and manage chunk alpha (fade-in and fade-out)
			float currentCamDistance = cameraPos.DistanceTo(chunkController._collisionShape.GlobalTransform.Origin);
			if (chunkController.DistanceToCamera != currentCamDistance)
			{
				chunkController.DistanceToCamera = currentCamDistance;
				chunkController._shaftMultiMesh.UpdateInstanceColors(currentCamDistance);
				chunkController._shaftMultiMesh.ActivationRangeMax = ActivationRange.Y;
				chunkController._shaftMultiMesh.ActivationRangeMin = ActivationRange.X;
			}

			bool isActive = _chunkState[chunkController];
			//Apply the activation based on the camera distance ranges
			if (currentCamDistance > ActivationRange.X && currentCamDistance <= ActivationRange.Y)
			{
				if (!isActive)
				{
					chunkController.ActivateChunk();
					_chunkState[chunkController] = true;
				}
			}
			else if (isActive)
			{
				chunkController.DeactivateChunk();
				_chunkState[chunkController] = false;
			}
		}
	}
	public override void _Process(double delta)
	{
		ManageChunks();
	}
}