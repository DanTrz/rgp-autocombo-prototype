using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.Intrinsics.X86;
using System.Threading.Tasks;
using Godot;

// [Tool]
public partial class ShaftChunkMMController : MultiMeshInstance3D
{
	[ExportGroup("Mandatory Node References")]
	[Export] public CollisionShape3D _collisionShape { get; set; }

	[ExportGroup("Chunk Setup")]
	[Export] bool _isChunkActive { get; set; } = true;
	[Export] public bool UseRandomSpread { get; set; } = true;
	[Export] public bool UseFixedCount { get; set; } = false;
	[Export] public int FixeCountValue { get; set; } = 10;
	[Export] public float ChunkDensity { get; set; } = 50.0f;
	[Export] public float MinSpacing { get; set; } = 1.5f; // Minimum distance between instances

	[ExportGroup("Shaft Generation")]
	[Export] private bool _isShaftMMActive { get; set; } = false;
	[Export] private Vector3 _initialScale { get; set; } = Vector3.One;
	[Export] public float WorldBoundMaxSize { get; set; } = 500.0f;
	[Export] public Basis LightRotation { get; set; } = new();

	[Export] public Const.WeatherEnums.ShaftRotationTypes RotationType { get; set; } = Const.WeatherEnums.ShaftRotationTypes.INSTANCE_ROTATION;
	[Export] public float InstancesRotationZ { get; set; } = 0.0f;
	[Export] public bool RaycastEnabled { get; set; } = true;
	[Export] public bool ResizeShaftOnCollision { get; set; } = true;
	[Export] public float RayLenght { get; set; } = 200.0f;
	[Export] public bool UseRandomWidth { get; set; } = true;
	[Export] public float RandWidthMax { get; set; } = 1.5f;
	[Export] public float RandWidthMin { get; set; } = 0.5f;

	[Export] public float ActivationRangeMax { get; set; } = 100.0f;
	[Export] public float ActivationRangeMin { get; set; } = 50.0f;
	[Export(PropertyHint.Layers3DRender)] public uint _raycastCollisionLayers { get; set; } = 1;

	[ExportGroup("Debug")]
	[Export] public bool ShowDebugSpheres { get; set; } = false;
	[Export] private SphereDebugVisualizer _debuggerSphere { get; set; }
	[Export] public bool ShowOnlyColliders { get; set; } = true;
	private List<InstanceCollider> _instanceList { get; set; } = new(); //int=IntanceID /--/ InstanceCollider=InstanaceInfo
	private bool _hasCollidersMissing = true;
	public float DistanceToCamera { get; set; }
	MultiMesh _multiMesh;

	public override void _Ready()
	{
		_isShaftMMActive = false;
		_multiMesh = this.Multimesh;
		if (_multiMesh == null)
		{
			Log.Error($"Error: MultiMesh is null: {_multiMesh}");
			return;
		}
		CleanAllDebugSpheres();
	}

	public void IntialChunkSetup()
	{
		_isShaftMMActive = true;

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

		List<Vector3> spawnPositions = UseRandomSpread
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
		float area = bounds.X * bounds.Z;
		int count = UseFixedCount
			? FixeCountValue
			: Mathf.RoundToInt(area * (ChunkDensity / 100f));
		count = Mathf.Max(count, 1);

		// Adjust grid layout based on minimum spacing
		int columns = Mathf.Max(1, Mathf.FloorToInt(bounds.X / MinSpacing));
		int rows = Mathf.Max(1, Mathf.FloorToInt(bounds.Z / MinSpacing));
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
		// Calculate the maximum number of positions that can fit in the bounds
		// taking into account the minimum spacing between positions.
		// The area of a single position is the minimum spacing squared.
		// The maximum count is the area of the bounds divided by the area of a single position.
		// The actual count is the minimum of the maximum count and the specified count (if using fixed count).
		// The actual count is also capped at 1 to ensure we always have at least one position.

		// The formula for the maximum count is:
		// maxCount = floor(area / (minSpacing^2))
		float area = bounds.X * bounds.Z;
		float effectiveCellArea = MinSpacing * MinSpacing;
		int maxCountBySpacing = Mathf.FloorToInt(area / effectiveCellArea);

		int count = UseFixedCount
			? FixeCountValue
			: Mathf.Min(Mathf.RoundToInt(area * (ChunkDensity / 100f)), maxCountBySpacing);
		count = Mathf.Max(count, 1);

		// Log.Info($"ChunkDensity: {ChunkDensity}");

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
				if (candidate.DistanceTo(pos) < MinSpacing)
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
			// Multimesh.SetInstanceColor(i, Colors.White);
			Vector3 newLocalPos = positions[i]; //Instance LocalPos
			Vector3 centerGlobalWorldPos = this.GlobalTransform * newLocalPos; //Get World Position (Global Position)

			//Update Instance List for raycast logic
			_instanceList.Add(new InstanceCollider(centerGlobalWorldPos, newLocalPos, false));
			CreateDebugSphere(centerGlobalWorldPos, Colors.Green, DebugType.MID_POINT_SPHERE);// World position center 

			//Setup transform and pass it to the MultiMesh for each instance


			// PREVIOUS WORKING CODE
			// float simpleRotation = Mathf.DegToRad(InstancesRotationZ);
			// Basis finalBasis = new Basis(new Vector3(0, 0, 1), simpleRotation); //Rotation on Z only
			// finalBasis.Column0 *= _initialScale.X; //Scale just the X axis 
			// finalBasis.Column1 *= _initialScale.Y; //Scale just the Y axis
			// finalBasis.Column2 *= _initialScale.Z; //Scale just the Z axis

			//NEW CODE NOT WORKING
			// 1. Determine Rotation
			Basis newBasis;
			if (RotationType == Const.WeatherEnums.ShaftRotationTypes.LIGHT_ROTATION)
			{
				// Rotate light forward (-Z) into +Y for godray mesh alignment
				Basis adjustedLightBasis = LightRotation * new Basis(Vector3.Right, Mathf.DegToRad(90));
				newBasis = adjustedLightBasis;
			}
			else
			{
				float simpleRotation = Mathf.DegToRad(InstancesRotationZ);
				newBasis = new Basis(Vector3.Back, simpleRotation); // simple Z rotation
			}

			// 2. Apply scale
			// Basis finalBasis = newBasis.Scaled(_initialScale);
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
		float min = ActivationRangeMin;
		float max = ActivationRangeMax;
		float mid = (min + max) * 0.5f;

		//Max "brightness color" value is halfpoint within _activationRangeMin and _activationRangeMax
		//Triangle distribution: 0 → 1 → 0
		float weight = 1.0f - Mathf.Abs((cameraDistance - mid) / (mid - min));
		weight = Mathf.Clamp(weight, 0f, 1f);

		//Set new color (Use this when updating individual instances)
		// Color fadeColor = Colors.Black.Lerp(Colors.White, weight);
		// for (int i = 0; i < _multiMesh.InstanceCount; i++)
		// {
		// 	_multiMesh.SetInstanceColor(i, fadeColor);
		// }

		//Set new alpha (Use this when updating all instances- directly using the Shader inside the MultiMesh mesh)
		float alpha = Mathf.Lerp(0.0f, 1.0f, weight); // LLerp(Colors.White, weight);
		UpdateMMMeshShaderAlpha(alpha);

		// if (this.Name == "ShaftChunkMMController")
		// 	Log.Info($"UpdateAlpha {alpha}");
	}

	public void UpdateMMMeshShaderAlpha(float value)
	{
		var material = _multiMesh.Mesh.SurfaceGetMaterial(0);
		if (material is ShaderMaterial shaderMaterial)
		{
			shaderMaterial.SetShaderParameter("alpha", value);
		}
	}

	private void SetInstancesCollision()
	{
		if (_instanceList.Count == 0) return; //TODO: In the future we can find a way to check if the "entire list" is already set customdata. 



		//Define world bounds (used for packing/unpacking vectors to be sent to shader)
		Vector3 minWorld = new Vector3(-WorldBoundMaxSize, -WorldBoundMaxSize, -WorldBoundMaxSize);
		Vector3 maxWorld = new Vector3(WorldBoundMaxSize, WorldBoundMaxSize, WorldBoundMaxSize);


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

				if (ResizeShaftOnCollision) ResizeInstance(i, colliderPos, _instanceList[i].GlobalPosition, startPoint, meshCurrentHeight);

			}
			else //Has not collided yet. Need to send a RayCast
			{
				//Get instance Global Position and send a RayCast to find collider
				Vector3 centerGlobalWorldPos = _instanceList[i].GlobalPosition;
				Vector3 centerLocalPos = _instanceList[i].LocalPosition;

				if (RaycastEnabled)
				{
					var rayDirection = -this.Transform.Basis.Y.Normalized();
					if (RotationType == Const.WeatherEnums.ShaftRotationTypes.INSTANCE_ROTATION)
					{
						//If rotation is based on "Instance Rotation" we apply the instance rotation to the raycast direction
						Transform3D instTransform = _multiMesh.GetInstanceTransform(i);
						Transform3D globalInst = this.GlobalTransform * instTransform;
						rayDirection = -globalInst.Basis.Y.Normalized();
					}
					else if (RotationType == Const.WeatherEnums.ShaftRotationTypes.LIGHT_ROTATION)
					{
						Basis adjustedLightBasis = LightRotation * new Basis(Vector3.Right, Mathf.DegToRad(90));
						rayDirection = -adjustedLightBasis.Y.Normalized(); // Shaft "down" from light direction

					}
					SendRaycast(i, centerGlobalWorldPos, rayDirection);
				}
			}
		}

		//Check if all instances have collided and update class level variable
		_hasCollidersMissing = _instanceList.Any(instance => !instance.PassedCustomData);
	}

	private void SendRaycast(int instanceIndex, Vector3 raycastStart, Vector3 _raycastDirection)
	{
		if (_instanceList[instanceIndex].HasCollided) return;

		Vector3 colliderGlobalPos = Vector3.Zero;

		//Create a Raycast and check if it hits anything
		var spaceState = GetWorld3D().DirectSpaceState;
		var raycastEndPoint = raycastStart + _raycastDirection * RayLenght;
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
		if (UseRandomWidth)
		{
			widthMultiplier = (float)GD.RandRange(RandWidthMin, RandWidthMax);
		}

		Vector3 newGlobalPos = (instanceStartPoint + colliderGlobalPos) / 2.0f;

		//Set this as new Instance Transform
		Transform3D currentInstaTrans = _multiMesh.GetInstanceTransform(instanceIndex);
		Vector3 currentLocalPos = currentInstaTrans.Origin;

		Vector3 newLocalPos = this.ToLocal(newGlobalPos); //Gets the LocalPos representation of the newGlobalPos

		// PREVIOUS WORKING CODE
		// float simpleRotation = Mathf.DegToRad(InstancesRotationZ);
		// Basis finalBasis = new Basis(new Vector3(0, 0, 1), simpleRotation); //Rotation on Z only
		// finalBasis.Column1 *= heighMultiplier; //Scale Y axis
		// finalBasis.Column0 *= widthMultiplier; //Scale X axis


		//NEW CODE NOT WORKING
		// 1. Determine Rotation
		Basis newBasis;
		if (RotationType == Const.WeatherEnums.ShaftRotationTypes.LIGHT_ROTATION)
		{
			// Rotate light forward (-Z) into +Y for godray mesh alignment
			Basis adjustedLightBasis = LightRotation * new Basis(Vector3.Right, Mathf.DegToRad(90));
			newBasis = adjustedLightBasis;
		}
		else
		{
			float simpleRotation = Mathf.DegToRad(InstancesRotationZ);
			newBasis = new Basis(Vector3.Back, simpleRotation); // simple Z rotation
		}

		// 2. Apply scale
		// Basis finalBasis = newBasis.Scaled(new Vector3(widthMultiplier, heighMultiplier, 1.0f));
		newBasis.Column1 *= heighMultiplier; //Scale Y axis
		newBasis.Column0 *= widthMultiplier; //Scale X axis

		// 3. APPLY THE TRANSFORM
		Multimesh.SetInstanceTransform(instanceIndex, new Transform3D(newBasis, newLocalPos));

		CreateDebugSphere(newGlobalPos, Colors.Black, DebugType.MID_POINT_SPHERE);
		_instanceList[instanceIndex].GlobalPosition = newGlobalPos;
		_instanceList[instanceIndex].LocalPosition = newLocalPos;
	}

	private void CreateDebugSphere(Vector3 position, Color color, DebugType type)
	{
		if (!ShowDebugSpheres || _debuggerSphere == null) return;
		if (ShowOnlyColliders && type != DebugType.COLLIDER_SPHERE) return;
		_debuggerSphere.AddPoint(position, color);

	}

	private void CleanAllDebugSpheres()
	{
		if (!ShowDebugSpheres || _debuggerSphere == null) return;
		_debuggerSphere.ClearAll();

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