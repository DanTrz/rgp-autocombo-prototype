using System;
using Godot;

public partial class ShaftChunksSpawner : Node3D
{

	[ExportGroup("Mandatory Node References")]
	[Export] Camera3D _mainCamera;
	[Export] public DirectionalLight3D sunLight;

	[ExportGroup("Chunk Setup")]
	[Export] Vector2 _activationRange { get; set; } = new Vector2(40.0f, 150.0f);
	[Export] bool _useRandomSpread { get; set; } = true;
	[Export] bool _useFixedCount { get; set; } = false;
	[Export] int _fixeCountValue { get; set; } = 10;
	[Export] float _chunkDensity { get; set; } = 20.0f;
	[Export] float _minSpacing { get; set; } = 1.5f; // 


	[ExportGroup("Shaft Generation")]
	[Export] private float _worldBoundMaxSize { get; set; } = 500.0f;
	[Export] private bool _raycastEnabled { get; set; } = true;
	[Export] private bool _resizeShaftOnCollision { get; set; } = true;
	[Export] private float _rayLenght { get; set; } = 200.0f;

	[ExportGroup("Shaft Size and Rotation")]
	[Export] private Const.WeatherEnums.ShaftRotationTypes _rotationType { get; set; } = Const.WeatherEnums.ShaftRotationTypes.INSTANCE_ROTATION;
	[Export] private float _instancesRotationZ { get; set; } = 0.0f;
	[Export] private bool _useRandomWidth { get; set; } = true;
	[Export] private float _randWidthMax { get; set; } = 1.5f;
	[Export] private float _randWidthMin { get; set; } = 0.5f;


	[ExportGroup("Debug")]
	[Export] private bool _showDebugSpheres { get; set; } = false;
	[Export] private bool _showOnlyColliders { get; set; } = true;

	Godot.Collections.Array<ShaftChunkMMController> _chunksArray = new();
	private Godot.Collections.Dictionary<ShaftChunkMMController, bool> _chunkState = new();

	public override void _Ready()
	{
		if (_mainCamera == null)
		{
			Log.Error($"ShaftChunksActivator error: Missing references for {nameof(_mainCamera)}");
			return;
		}

		GetChunksArray();

		if (_chunksArray.Count == 0)
		{
			Log.Error($"ShaftChunksActivator error: Missing references for {nameof(_chunksArray)}");
			return;
		}

		Callable.From(ChunkInitialization).CallDeferred();
		// ChunkInitialization();
	}
	private void GetChunksArray()
	{
		foreach (ShaftChunkMMController item in GetChildren())
		{
			if (item is ShaftChunkMMController)
				_chunksArray.Add(item);
		}
	}

	private void ChunkInitialization()
	{
		foreach (ShaftChunkMMController chunkController in _chunksArray)
		{
			_chunkState[(ShaftChunkMMController)chunkController] = false; // assume all start inactive
																		  // chunkController.DeactivateChunk();
			chunkController.ActivationRangeMax = _activationRange.Y;
			chunkController.ActivationRangeMin = _activationRange.X;
			chunkController.UseRandomSpread = _useRandomSpread;
			chunkController.UseFixedCount = _useFixedCount;
			chunkController.FixeCountValue = _fixeCountValue;
			chunkController.ChunkDensity = _chunkDensity;
			chunkController.MinSpacing = _minSpacing;

			chunkController.WorldBoundMaxSize = _worldBoundMaxSize;
			chunkController.RotationType = _rotationType;
			chunkController.InstancesRotationZ = _instancesRotationZ;
			chunkController.RaycastEnabled = _raycastEnabled;
			chunkController.ResizeShaftOnCollision = _resizeShaftOnCollision;
			chunkController.RayLenght = _rayLenght;
			chunkController.UseRandomWidth = _useRandomWidth;
			chunkController.RandWidthMax = _randWidthMax;
			chunkController.RandWidthMin = _randWidthMin;
			chunkController.LightRotation = GetLight3DRotation();

			chunkController.ShowDebugSpheres = _showDebugSpheres;
			chunkController.ShowOnlyColliders = _showOnlyColliders;

			chunkController.IntialChunkSetup();

		}
	}

	private void ManageChunks()
	{
		Vector3 cameraPos = _mainCamera.GlobalTransform.Origin;
		foreach (ShaftChunkMMController chunkController in _chunksArray)
		{
			//Check and pass the camera distance to the chunk collisionShape and manage chunk alpha (fade-in and fade-out)
			float currentCamDistance = cameraPos.DistanceTo(chunkController._collisionShape.GlobalTransform.Origin);
			if (chunkController.DistanceToCamera != currentCamDistance)//Camera moved, then update chunk parameters
			{
				chunkController.DistanceToCamera = currentCamDistance;
				chunkController.UpdateInstanceColors(currentCamDistance);
				chunkController.ActivationRangeMax = _activationRange.Y;
				chunkController.ActivationRangeMin = _activationRange.X;
				chunkController.LightRotation = GetLight3DRotation();
			}

			bool isActive = _chunkState[chunkController];
			//Apply the activation based on the camera distance ranges (x=activationMin, y=ActivationMax)
			//ActivateChunk if cameraDistance > minRange and cameraDistance <= maxRange
			if (currentCamDistance > _activationRange.X && currentCamDistance <= _activationRange.Y)
			{
				if (!isActive)
				{
					chunkController.ActivateChunk();
					_chunkState[chunkController] = true;
				}
			}
			else if (isActive) //Deactivate Chunk if cameraDistance > ActivationRange.Y
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

	private Basis GetLight3DRotation()
	{
		if (sunLight == null) return Basis.Identity;

		Vector3 lightRotationEuler = sunLight.GlobalRotation; // Already in radians
		return Basis.FromEuler(lightRotationEuler); // Create rotation basis from Euler

	}
}