using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;

// [Tool]
public partial class LightShaftMultiMeshController : MultiMeshInstance3D
{

	// [ExportToolButton("CreateMultiMeshes")]
	// public Callable CreateMultiMeshesBtb => Callable.From(() => SetupMultiMesh());
	// [Export] private bool _runInEditor { get; set; } = false;

	[ExportGroup("Shaft Generation")]
	[Export] Vector2 _gridSize = new Vector2(10, 10);
	[Export] int _instanceCount = 1;
	[Export] Vector3 _initialPosition { get; set; } = new();
	[Export] Vector3 _intialScale { get; set; } = Vector3.One;
	[Export] float _rotationZ { get; set; } = 0.0f;
	[Export] private float _worldBoundMaxSize { get; set; } = 500.0f;

	[ExportGroup("Raycast")]
	[Export] bool _raycastEnabled { get; set; } = true;
	[Export] bool _resizeShaftOnCollision { get; set; } = true;
	[Export] private float _rayLenght { get; set; } = 80.0f;
	[Export(PropertyHint.Layers3DRender)] public uint RaycastCollisionLayers { get; set; } = 1;
	[Export] private bool _showDebugSpheres { get; set; } = false;

	private List<InstanceCollider> _instanceList { get; set; } = new(); //int=IntanceID /--/ InstanceCollider=InstanaceInfo
	private bool _hasCollidersMissing = true;

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
		SetupMultiMeshInstances();
	}

	public override void _Process(double delta)
	{
		// if (!_runInEditor) return;
		if (!_hasCollidersMissing || _multiMesh == null) return;
		SetInstancesCollision();
	}

	private void SetupMultiMeshInstances()
	{

		MultiMesh Multimesh = this.Multimesh;
		//Reset the MultiMesh
		Multimesh.InstanceCount = 0;
		Multimesh.VisibleInstanceCount = -1;

		//Setup the MultiMesh
		Multimesh.UseCustomData = true;
		Multimesh.InstanceCount = _instanceCount;
		Multimesh.VisibleInstanceCount = _instanceCount;

		_instanceList.Clear();

		CleanAllDebugSpheres(); //DEBUG - TEST ONLY

		for (int i = 0; i < Multimesh.InstanceCount; i++)
		{
			Vector3 newLocalPos = new Vector3((i * _initialPosition.X), _initialPosition.Y, _initialPosition.Z); //LocalPos
			Vector3 centerGlobalWorldPos = this.GlobalTransform * newLocalPos; //Convert to World Position (Global Position)

			//Update Instance List for raycast logic
			// _instanceList[i] = new InstanceCollider(centerGlobalWorldPos, newLocalPos, false);
			_instanceList.Add(new InstanceCollider(centerGlobalWorldPos, newLocalPos, false));

			CreateDebugSphere(centerGlobalWorldPos, Colors.Green);// World position center 	//DEBUG - TEST ONLY


			//Setup transform and pass it to the MultiMesh for each instance
			float newRotation = Mathf.DegToRad(_rotationZ);
			Basis newBasis = new Basis(Vector3.One, newRotation); //Apply Rotation
			newBasis.Column0 *= _intialScale.X; //Scale just the X axis 
			newBasis.Column1 *= _intialScale.Y; //Scale just the Y axis
			newBasis.Column2 *= _intialScale.Z; //Scale just the Z axis

			Multimesh.SetInstanceTransform(i, new Transform3D(newBasis, newLocalPos));
			Log.Debug($"Instance {i} set to GlobalPos {centerGlobalWorldPos}, LocalPos {newLocalPos}");
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

				CreateDebugSphere(colliderPos, Colors.Red);     //DEBUG - TEST ONLY

				_instanceList[i].PassedCustomData = true;

				// Get instance dimensions and Resize the mesh/instance to realign with collision point
				// float meshOrigHeight = ((CylinderMesh)this.Multimesh.Mesh).Height;
				float? meshOrigHeight = (this.Multimesh.Mesh as CylinderMesh)?.Height;
				if (meshOrigHeight == null)
					Log.Error("Failed to get CylinderMesh Height");


				Vector3 basisYScale = _multiMesh.GetInstanceTransform(i).Basis.Column1; //Get  Y axis scale to multiple by original mesh height
				float meshCurrentHeight = basisYScale.Length() * (float)meshOrigHeight;
				Vector3 startPoint = _instanceList[i].GlobalPosition - (-this.Transform.Basis.Y) * meshCurrentHeight / 2.0f;

				CreateDebugSphere(startPoint, Colors.Blue); //DEBUG - TEST ONLY

				if (_resizeShaftOnCollision) ResizeInstance(i, colliderPos, _instanceList[i].GlobalPosition, startPoint, meshCurrentHeight);

			}
			else //Has not collided yet. Need to send a RayCast
			{
				//Get instance Global Position and send a RayCast to find collider
				Vector3 centerGlobalWorldPos = _instanceList[i].GlobalPosition;
				Vector3 centerLocalPos = _instanceList[i].LocalPosition;



				if (_raycastEnabled) SendRaycast(i, centerGlobalWorldPos, -this.Transform.Basis.Y);
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
		var raycastEndPoint = raycastStart + _raycastDirection * _rayLenght;
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

				Log.Debug($"Collider Found Pos: {colliderGlobalPos}");
			}

		}
		else
		{
			Log.Debug($"No Collision. Collider:{colliderGlobalPos}, RayStart:{raycastStart}, RayEnd:{raycastEndPoint}");
		}
	}

	private void ResizeInstance(int instanceIndex, Vector3 colliderGlobalPos, Vector3 instanceGlobalPos, Vector3 instanceStartPoint, float instanceHeight)
	{
		Log.Debug($"Resizing => ID: {instanceIndex}, ColliderPos: {colliderGlobalPos}, GlobalPos: {instanceGlobalPos}, InitHeight: {instanceHeight}");

		float newHeight = instanceStartPoint.DistanceTo(colliderGlobalPos);
		Vector3 newGlobalPos = (instanceStartPoint + colliderGlobalPos) / 2.0f;
		//Vector3 midPoint /this.GlobalTransform  = this.GlobalTransform * newLocalPos; //Convert to World Position (Global Position)

		//Set this as new Instance Transform
		Transform3D currentInstaTrans = _multiMesh.GetInstanceTransform(instanceIndex);
		Vector3 currentLocalPos = currentInstaTrans.Origin;

		Vector3 newLocalPos = this.ToLocal(newGlobalPos); //Gets the LocalPos representation of the newGlobalPos

		// Retrieve the current basis and current rotation from the instance and adjust the scale
		float newRotation = Mathf.DegToRad(_rotationZ);
		Basis newBasis = new Basis(Vector3.One, newRotation);
		newBasis.Column1 *= newHeight;

		Log.Debug($"ID {instanceIndex} => New_H: {newHeight} Prev_H: {instanceHeight}");

		Multimesh.SetInstanceTransform(instanceIndex, new Transform3D(newBasis, newLocalPos));
		CreateDebugSphere(newGlobalPos, Colors.Black); //DEBUG - TEST ONLY

		_instanceList[instanceIndex].GlobalPosition = newGlobalPos;
		_instanceList[instanceIndex].LocalPosition = newLocalPos;
	}

	private void CreateDebugSphere(Vector3 position, Color color)
	{
		if (!_showDebugSpheres) return;
		var mesh = new SphereMesh();
		mesh.Radius = 0.5f;
		var material = new StandardMaterial3D();
		material.AlbedoColor = color;
		var sphere = new DebugSphere();
		sphere.Mesh = mesh;
		sphere.MaterialOverride = material;
		AddChild(sphere);
		mesh.Radius = 0.25f;
		mesh.Height = 0.5f;
		sphere.CastShadow = 0; //SHADOW_CASTING_SETTING_OFF = 0
		sphere.GlobalPosition = position;
		Log.Debug($"DebugSphere: {sphere.GlobalPosition}, Color {color.ToString()}");

	}
	private void CleanAllDebugSpheres()
	{
		foreach (DebugSphere sphere in GetChildren())
		{
			sphere.QueueFree();
		}
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


// 	for (int i = 0; i<Multimesh.InstanceCount; i++)
// 	{
// 		Vector3 newLocalPos = new Vector3((i * _position.X), _position.Y, _position.Z); //Seems an offset from parent
// Vector3 centerGlobalWorldPos = this.GlobalTransform * newLocalPos; //Actual World Position (Global Position)

// _instanceList[i] = new InstanceCollider(centerGlobalWorldPos, false);

// //SET COLLIDER POSITION
// Vector3 colliderPos = await GetColliderPosition(centerGlobalWorldPos, new Vector3(0, -1, 0));
// Vector3 normalizedColliderPos = new Vector3(
// 	Mathf.InverseLerp(minWorld.X, maxWorld.X, colliderPos.X),
// 	Mathf.InverseLerp(minWorld.Y, maxWorld.Y, colliderPos.Y),
// 	Mathf.InverseLerp(minWorld.Z, maxWorld.Z, colliderPos.Z)
// );


// Multimesh.SetInstanceCustomData(i, new Color(normalizedColliderPos.X, normalizedColliderPos.Y, normalizedColliderPos.Z, 1));
// 		// Multimesh.SetInstanceCustomData(i, new Color(normalizedOffsetPos.X, normalizedOffsetPos.Y, normalizedOffsetPos.Z, 1));

// 		CreateDebugCircle(centerGlobalWorldPos, Colors.Green);// World position center
// CreateDebugCircle(colliderPos, Colors.Red);// Fake collider position (this will be replaced by the RayCast collider data)
// 										   // CreateDebugCircle(offset, Colors.Yellow);

// Multimesh.SetInstanceCustomData(i, new Color(normalizedColliderPos.X, normalizedColliderPos.Y, normalizedColliderPos.Z, 1));
