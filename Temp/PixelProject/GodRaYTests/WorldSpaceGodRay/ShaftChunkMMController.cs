using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Intrinsics.X86;
using System.Threading.Tasks;
using Godot;

// [Tool]
public partial class ShaftChunkMMController : MultiMeshInstance3D
{
	[ExportGroup("Mandatory Node References")]
	[Export] public CollisionShape3D _collisionShape { get; set; }

	[ExportGroup("Chunk Settings")]
	[Export] bool _isChunkActive { get; set; } = true;
	[Export] bool _useRandomSpread { get; set; } = true;
	[Export] bool _useFixedCount { get; set; } = false;
	[Export] int _fixCountPerChunk { get; set; } = 10;
	[Export] float _chunkDensity { get; set; } = 50.0f;
	[Export] float _minimumSpacing { get; set; } = 1.5f; // Minimum distance between instances

	[ExportGroup("Shaft Generation")]
	[Export] private bool _isShaftMMActive { get; set; } = false;
	[Export] private Vector3 _initialScale { get; set; } = Vector3.One;
	[Export] private float _worldBoundMaxSize { get; set; } = 500.0f;

	[Export(PropertyHint.Enum, "InstanceBased,NodeBased")] public int _rotationType { get; set; } = 0;
	[Export] private float _instancesRotationZ { get; set; } = 0.0f;
	[Export] private bool _raycastEnabled { get; set; } = true;
	[Export] private bool _resizeShaftOnCollision { get; set; } = true;
	[Export] private float _rayLenght { get; set; } = 200.0f;
	[Export] private bool _useRandomWidth { get; set; } = true;
	[Export] private float _randWidthMax { get; set; } = 1.5f;
	[Export] private float _randWidthMin { get; set; } = 0.5f;

	[Export] public float _activationRangeMax { get; set; } = 100.0f;
	[Export] public float _activationRangeMin { get; set; } = 50.0f;
	[Export(PropertyHint.Layers3DRender)] public uint _raycastCollisionLayers { get; set; } = 1;

	[ExportGroup("Debug")]
	[Export] private bool _showDebugSpheres { get; set; } = false;
	[Export] private SphereDebugVisualizer _debuggerSphere { get; set; }
	[Export] private bool _showOnlyColliders { get; set; } = true;
	private List<InstanceCollider> _instanceList { get; set; } = new(); //int=IntanceID /--/ InstanceCollider=InstanaceInfo
	private bool _hasCollidersMissing = true;
	public float DistanceToCamera { get; set; }
	MultiMesh _multiMesh;

	public override void _Ready()
	{
		_multiMesh = this.Multimesh;
		if (_multiMesh == null)
		{
			Log.Error($"Error: MultiMesh is null: {_multiMesh}");
			return;
		}
		CleanAllDebugSpheres();
		IntialChunkSetup();
	}

	private void IntialChunkSetup()
	{
		if (_collisionShape == null)
		{
			try
			{
				_collisionShape = GetNode<CollisionShape3D>("CollisionShape3D");
			}
			catch (System.Exception ex)
			{
				Log.Error($"ShaftChunkController error: Missing references for CollisionShape3D {ex.Message}");
				return;
			}
		}

		var bounds = ((BoxShape3D)_collisionShape.Shape).Size;

		List<Vector3> spawnPositions = _useRandomSpread
			? GenerateRandomPositions(bounds)
			: GenerateGridPositions(bounds);

		SpawnInstances(spawnPositions);
	}

	public override void _Process(double delta)
	{
		// if (!_runInEditor) return;
		if (!_hasCollidersMissing || _multiMesh == null || !_isShaftMMActive) return;
		SetInstancesCollision();
	}

	#region ChunkCreation

	public void ActivateChunk()
	{
		Visible = true;
		_isChunkActive = true;
		SetProcess(true);

		SetProcess(true);
		_isShaftMMActive = true;

		Log.Debug($"Activated chunk: {Name}");
		// Future: trigger shader fade-in
	}

	public void DeactivateChunk()
	{
		Visible = false;
		_isChunkActive = false;
		SetProcess(false);

		SetProcess(false);
		_isShaftMMActive = false;

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
	#endregion ChunkCreation

	#region MultiMeshSpwaning Controls
	public void SpawnInstances(List<Vector3> positions) //List<Vector3>
	{
		Log.Debug($"{this.Name} SpawnInstances called: {positions.Count}");
		MultiMesh Multimesh = this.Multimesh;
		//Reset the MultiMesh
		Multimesh.InstanceCount = 0;
		Multimesh.VisibleInstanceCount = -1;

		//Setup the MultiMesh
		Multimesh.UseCustomData = true;
		Multimesh.UseColors = true;
		Multimesh.InstanceCount = positions.Count;
		Multimesh.VisibleInstanceCount = positions.Count;

		_instanceList.Clear();
		CleanAllDebugSpheres();

		for (int i = 0; i < positions.Count; i++)
		{
			Multimesh.SetInstanceColor(i, Colors.White);

			Vector3 newLocalPos = positions[i]; //Instance LocalPos
			Vector3 centerGlobalWorldPos = this.GlobalTransform * newLocalPos; //Get World Position (Global Position)

			//Update Instance List for raycast logic
			_instanceList.Add(new InstanceCollider(centerGlobalWorldPos, newLocalPos, false));
			CreateDebugSphere(centerGlobalWorldPos, Colors.Green, DebugType.MID_POINT_SPHERE);// World position center 

			//Setup transform and pass it to the MultiMesh for each instance
			float newRotation = Mathf.DegToRad(_instancesRotationZ);
			Basis newBasis = new Basis(new Vector3(0, 0, 1), newRotation); //Rotation on Z only
			newBasis.Column0 *= _initialScale.X; //Scale just the X axis 
			newBasis.Column1 *= _initialScale.Y; //Scale just the Y axis
			newBasis.Column2 *= _initialScale.Z; //Scale just the Z axis

			Multimesh.SetInstanceTransform(i, new Transform3D(newBasis, newLocalPos));
			// Log.Debug($"Instance {i} set to GlobalPos {centerGlobalWorldPos}, LocalPos {newLocalPos}");
		}
	}

	public void UpdateInstanceColors(float cameraDistance)
	{
		//Lerp between Colors.White and Colors.Black based on cameraDistance and ActivationRangeMax and ActivationRangeMin.
		//THis creates a fade-in and fade-out effect
		float min = _activationRangeMin;
		float max = _activationRangeMax;
		float mid = (min + max) * 0.5f;

		// Triangle distribution: 0 → 1 → 0
		float weight = 1.0f - Mathf.Abs((cameraDistance - mid) / (mid - min));
		weight = Mathf.Clamp(weight, 0f, 1f);
		Color fadeColor = Colors.Black.Lerp(Colors.White, weight);
		for (int i = 0; i < _multiMesh.InstanceCount; i++)
		{
			_multiMesh.SetInstanceColor(i, fadeColor);
		}
	}

	private void SetInstancesCollision()
	{
		if (_instanceList.Count == 0) return; //TODO: In the future we can find a way to check if the "entire list" is already set customdata. 



		//Define world bounds (used for packing/unpacking vectors to be sent to shader)
		Vector3 minWorld = new Vector3(-_worldBoundMaxSize, -_worldBoundMaxSize, -_worldBoundMaxSize);
		Vector3 maxWorld = new Vector3(_worldBoundMaxSize, _worldBoundMaxSize, _worldBoundMaxSize);


		//Loop our InstanceList and Send the RayCast for Collision from their World Position Center
		for (int i = 0; i < _instanceList.Count; i++)
		{
			if (_instanceList[i].PassedCustomData) continue; //Skipt if we already passed CustomData to the Shader

			if (_instanceList[i].HasCollided) //Have collision (we got collider pos) but have not yet passed it to Shader CustomData
			{
				//Normalize collider (required for the Shader to receive this as CustomData)
				Vector3 colliderPos = _instanceList[i].ColliderPosition;
				Vector3 normalizedColliderPos = new Vector3(
					Mathf.InverseLerp(minWorld.X, maxWorld.X, colliderPos.X),
					Mathf.InverseLerp(minWorld.Y, maxWorld.Y, colliderPos.Y),
					Mathf.InverseLerp(minWorld.Z, maxWorld.Z, colliderPos.Z)
				);

				_multiMesh.SetInstanceCustomData(i, new Color(normalizedColliderPos.X, normalizedColliderPos.Y, normalizedColliderPos.Z, 1));

				CreateDebugSphere(colliderPos, Colors.Red, DebugType.COLLIDER_SPHERE);     //DEBUG - TEST ONLY

				_instanceList[i].PassedCustomData = true;

				// Get instance dimensions and Resize the mesh/instance to realign with collision point
				// float meshOrigHeight = ((CylinderMesh)this.Multimesh.Mesh).Height;
				float? meshOrigHeight = (this.Multimesh.Mesh as CylinderMesh)?.Height;
				if (meshOrigHeight == null)
					Log.Error("Failed to get CylinderMesh Height");


				Vector3 basisYScale = _multiMesh.GetInstanceTransform(i).Basis.Column1; //Get  Y axis scale to multiple by original mesh height
				float meshCurrentHeight = basisYScale.Length() * (float)meshOrigHeight;
				Vector3 startPoint = _instanceList[i].GlobalPosition - (-this.Transform.Basis.Y) * meshCurrentHeight / 2.0f;

				CreateDebugSphere(startPoint, Colors.Blue, DebugType.START_POINT_SPHERE); //DEBUG - TEST ONLY

				if (_resizeShaftOnCollision) ResizeInstance(i, colliderPos, _instanceList[i].GlobalPosition, startPoint, meshCurrentHeight);

			}
			else //Has not collided yet. Need to send a RayCast
			{
				//Get instance Global Position and send a RayCast to find collider
				Vector3 centerGlobalWorldPos = _instanceList[i].GlobalPosition;
				Vector3 centerLocalPos = _instanceList[i].LocalPosition;

				if (_raycastEnabled)
				{
					var rayDirection = -this.Transform.Basis.Y.Normalized();
					if (_rotationType == 0) //  "0=InstanceBased,1=NodeBased")]
					{
						//If rotation is based on "Instance Rotation" we apply the instance rotation to the raycast direction
						Transform3D instTransform = _multiMesh.GetInstanceTransform(i);
						Transform3D globalInst = this.GlobalTransform * instTransform;
						rayDirection = -globalInst.Basis.Y.Normalized();
					}
					SendRaycast(i, centerGlobalWorldPos, rayDirection);
				}
			}
		}

		//Check if all instances have collided and update class level variable
		_hasCollidersMissing = _instanceList.Any(instance => !instance.PassedCustomData);
	}

	//TODO: We are using this Nodes GlobalTransform to get the Raycast direction. This will break if we change the logic to InstanceBased rotations
	//BUG: Raycast and collision not going in riht direction when rotation is "per instance"
	private void SendRaycast(int instanceIndex, Vector3 raycastStart, Vector3 _raycastDirection)
	{
		if (_instanceList[instanceIndex].HasCollided) return;

		Vector3 colliderGlobalPos = Vector3.Zero;

		//Create a Raycast and check if it hits anything
		var spaceState = GetWorld3D().DirectSpaceState;
		var raycastEndPoint = raycastStart + _raycastDirection * _rayLenght;
		var query = PhysicsRayQueryParameters3D.Create(raycastStart, raycastEndPoint);
		query.CollideWithAreas = false;
		query.CollideWithBodies = true;
		query.CollisionMask = _raycastCollisionLayers;
		Godot.Collections.Dictionary result = spaceState.IntersectRay(query);

		if (result.Count > 0) //If the Raycast hit something we get the collider and updated _instanceList
		{
			if (result.TryGetValue("collider", out var collider))
			{
				// Node3D colliderNode = (Node3D)collider; // Cast the Variant to a Node (Optional)
				colliderGlobalPos = result["position"].AsVector3(); // This returns a GlobalPosition

				_instanceList[instanceIndex].HasCollided = true;
				_instanceList[instanceIndex].ColliderPosition = colliderGlobalPos;

				// Log.Debug($"Collider Found Pos: {colliderGlobalPos}");
			}

		}
		else
		{
			// Log.Debug($"No Collision. Collider:{colliderGlobalPos}, RayStart:{raycastStart}, RayEnd:{raycastEndPoint}");

			//TODO: Log a number of attempts, then stop trying to send rays for that instance
			//BUG: We will get a bug when no collsion is found and a "continues loop"
		}
	}

	private void ResizeInstance(int instanceIndex, Vector3 colliderGlobalPos, Vector3 instanceGlobalPos, Vector3 instanceStartPoint, float instanceHeight)
	{
		float heighMultiplier = instanceStartPoint.DistanceTo(colliderGlobalPos);
		float widthMultiplier = 1.0f;
		if (_useRandomWidth)
		{
			widthMultiplier = (float)GD.RandRange(_randWidthMin, _randWidthMax);
		}

		Vector3 newGlobalPos = (instanceStartPoint + colliderGlobalPos) / 2.0f;

		//Set this as new Instance Transform
		Transform3D currentInstaTrans = _multiMesh.GetInstanceTransform(instanceIndex);
		Vector3 currentLocalPos = currentInstaTrans.Origin;

		Vector3 newLocalPos = this.ToLocal(newGlobalPos); //Gets the LocalPos representation of the newGlobalPos

		// Retrieve the current basis and current rotation from the instance and adjust the scale
		float newRotation = Mathf.DegToRad(_instancesRotationZ);
		Basis newBasis = new Basis(new Vector3(0, 0, 1), newRotation); //Rotation on Z only
		newBasis.Column1 *= heighMultiplier; //Scale Y axis
		newBasis.Column0 *= widthMultiplier; //Scale X axis


		Multimesh.SetInstanceTransform(instanceIndex, new Transform3D(newBasis, newLocalPos));
		CreateDebugSphere(newGlobalPos, Colors.Black, DebugType.MID_POINT_SPHERE); //DEBUG - TEST ONLY

		_instanceList[instanceIndex].GlobalPosition = newGlobalPos;
		_instanceList[instanceIndex].LocalPosition = newLocalPos;
	}

	private void CreateDebugSphere(Vector3 position, Color color, DebugType type)
	{
		if (!_showDebugSpheres || _debuggerSphere == null) return;
		if (_showOnlyColliders && type != DebugType.COLLIDER_SPHERE) return;
		_debuggerSphere.AddPoint(position, color);

	}

	private void CleanAllDebugSpheres()
	{
		if (!_showDebugSpheres || _debuggerSphere == null) return;
		_debuggerSphere.ClearAll();

		// foreach (DebugSphere sphere in GetChildren())
		// {
		// 	sphere.QueueFree();
		// }

		// foreach (DebugSphere sphere in GetChildren())
		// {
		// 	sphere.QueueFree();
		// }
	}

	#endregion MultiMeshSpwaning Controls

	#region Helper Classes
	private enum DebugType
	{
		COLLIDER_SPHERE,
		START_POINT_SPHERE,
		END_POINT_SPHERE,
		MID_POINT_SPHERE

	}

	public class InstanceCollider
	{
		public Vector3 GlobalPosition { get; set; }
		public Vector3 LocalPosition { get; set; }


		public bool HasCollided { get; set; } = false;

		public Vector3 ColliderPosition { get; set; }

		public bool PassedCustomData { get; set; } = false;

		public bool HasResized { get; set; } = false;


		public InstanceCollider(Vector3 globalPos, Vector3 localPos, bool hasCollided)
		{
			GlobalPosition = globalPos;
			LocalPosition = localPos;
			HasCollided = hasCollided;
		}
	}

	public partial class DebugSphere : MeshInstance3D
	{

	}

	#endregion Helper Classes
}