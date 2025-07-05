using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Intrinsics.X86;
using System.Threading.Tasks;
using Godot;

// [Tool]
public partial class ShaftMultiMeshController : MultiMeshInstance3D
{
	public bool IsShaftMMActive { get; set; } = false;
	public Vector3 InitialScale { get; set; } = Vector3.One;
	public float WorldBoundMaxSize { get; set; } = 500.0f;
	public int RotationType { get; set; } = 0;
	public float InstancesRotationZ { get; set; } = 0.0f;
	public bool RaycastEnabled { get; set; } = true;
	public bool ResizeShaftOnCollision { get; set; } = true;
	public float RayLenght { get; set; } = 80.0f;
	public uint RaycastCollisionLayers { get; set; } = 1;
	public bool ShowDebugSpheres { get; set; } = false;
	public SphereDebugVisualizer DebuggerSphere { get; set; }
	public bool ShowOnlyColliders { get; set; } = true;
	private List<InstanceCollider> _instanceList { get; set; } = new(); //int=IntanceID /--/ InstanceCollider=InstanaceInfo
	private bool _hasCollidersMissing = true;
	public float ActivationRangeMax { get; set; } = 100.0f;
	public float ActivationRangeMin { get; set; } = 50.0f;


	public float RandWidthMax { get; set; } = 50.0f;
	public float RandWidthMin { get; set; } = 50.0f;
	public bool UseRandomWith { get; set; } = true;


	MultiMesh _multiMesh;

	public override void _Ready()
	{
		_multiMesh = this.Multimesh;
		if (_multiMesh == null)
		{
			Log.Error($"Error: MultiMesh is null: {_multiMesh}");
			return;
		}



		// if (!_runInEditor) return;
		//PopulateGrid(_gridSize, GetGridCellSize(_gridSize));
		CleanAllDebugSpheres();
		//SpawnInstances();
	}

	public override void _Process(double delta)
	{
		// if (!_runInEditor) return;
		if (!_hasCollidersMissing || _multiMesh == null || !IsShaftMMActive) return;
		SetInstancesCollision();
	}

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
			float newRotation = Mathf.DegToRad(InstancesRotationZ);
			Basis newBasis = new Basis(new Vector3(0, 0, 1), newRotation); //Rotation on Z only
			newBasis.Column0 *= InitialScale.X; //Scale just the X axis 
			newBasis.Column1 *= InitialScale.Y; //Scale just the Y axis
			newBasis.Column2 *= InitialScale.Z; //Scale just the Z axis

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
					if (RotationType == 0) //  "0=InstanceBased,1=NodeBased")]
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
		var raycastEndPoint = raycastStart + _raycastDirection * RayLenght;
		var query = PhysicsRayQueryParameters3D.Create(raycastStart, raycastEndPoint);
		query.CollideWithAreas = false;
		query.CollideWithBodies = true;
		query.CollisionMask = RaycastCollisionLayers;
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
		float newHeightMultiplier = instanceStartPoint.DistanceTo(colliderGlobalPos);
		float newWithMultiplier = (float)GD.RandRange(RandWidthMin, RandWidthMax);

		Vector3 newGlobalPos = (instanceStartPoint + colliderGlobalPos) / 2.0f;

		//Set this as new Instance Transform
		Transform3D currentInstaTrans = _multiMesh.GetInstanceTransform(instanceIndex);
		Vector3 currentLocalPos = currentInstaTrans.Origin;

		Vector3 newLocalPos = this.ToLocal(newGlobalPos); //Gets the LocalPos representation of the newGlobalPos

		// Retrieve the current basis and current rotation from the instance and adjust the scale
		float newRotation = Mathf.DegToRad(InstancesRotationZ);
		Basis newBasis = new Basis(new Vector3(0, 0, 1), newRotation); //Rotation on Z only
		newBasis.Column1 *= newHeightMultiplier; //Scale Y axis
		newBasis.Column0 *= newWithMultiplier; //Scale X axis


		Multimesh.SetInstanceTransform(instanceIndex, new Transform3D(newBasis, newLocalPos));
		CreateDebugSphere(newGlobalPos, Colors.Black, DebugType.MID_POINT_SPHERE); //DEBUG - TEST ONLY

		_instanceList[instanceIndex].GlobalPosition = newGlobalPos;
		_instanceList[instanceIndex].LocalPosition = newLocalPos;
	}

	private void CreateDebugSphere(Vector3 position, Color color, DebugType type)
	{
		if (!ShowDebugSpheres || DebuggerSphere == null) return;
		if (ShowOnlyColliders && type != DebugType.COLLIDER_SPHERE) return;
		DebuggerSphere.AddPoint(position, color);

	}

	private void CleanAllDebugSpheres()
	{
		if (!ShowDebugSpheres || DebuggerSphere == null) return;
		DebuggerSphere.ClearAll();

		// foreach (DebugSphere sphere in GetChildren())
		// {
		// 	sphere.QueueFree();
		// }

		// foreach (DebugSphere sphere in GetChildren())
		// {
		// 	sphere.QueueFree();
		// }
	}

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
}