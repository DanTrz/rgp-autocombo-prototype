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

	[ExportGroup("Controller Settings")]
	[Export] PackedScene _lightShaftScene = GD.Load<PackedScene>("uid://b3vej5yd5cpjo");
	[Export] Camera3D _mainCam;
	[Export] Vector2 _gridSize = new Vector2(10, 10);
	// [Export] MultiMeshInstance3D _multiMesh;
	[Export] int _instanceCount = 1;

	[Export] Vector3 _position { get; set; } = new();
	[Export] Vector3 _scale { get; set; } = Vector3.One;
	[Export] float _rotationZ { get; set; } = 0.0f;

	[ExportGroup("Raycast Settings")]
	[Export] private float _rayLenght { get; set; } = 45.0f;
	[Export(PropertyHint.Layers3DRender)] public uint CollisionLayers { get; set; }

	private Dictionary<int, InstanceCollider> _instanceList { get; set; } = new(); //int=IntanceID /--/ InstanceCollider=InstanaceInfo
	private bool _hasCollidersMissing = true;
	// private PhysicsRayQueryParameters3D _raycast;




	public override void _Ready()
	{
		if (Engine.IsEditorHint()) return;
		//PopulateGrid(_gridSize, GetGridCellSize(_gridSize));
		SetupMultiMeshInstances();
	}

	public override void _Process(double delta)
	{
		if (!_hasCollidersMissing) return;
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

		//DEBUG - TEST ONLY
		CleanAllDebugSpheres();
		//DEBUG - TEST ONLY

		for (int i = 0; i < Multimesh.InstanceCount; i++)
		{
			Vector3 newLocalPos = new Vector3((i * _position.X), _position.Y, _position.Z); //Seems an offset from parent (Local Pos)
			Vector3 centerGlobalWorldPos = this.GlobalTransform * newLocalPos; //Convert to World Position (Global Position)

			_instanceList[i] = new InstanceCollider(centerGlobalWorldPos, newLocalPos, false);

			//DEBUG - TEST ONLY
			CreateDebugCircle(centerGlobalWorldPos, Colors.Green);// World position center

			float newRotation = Mathf.DegToRad(_rotationZ);
			Basis newBasis = new Basis(Vector3.One, newRotation); //Apply Rotation
			newBasis.Column1 *= _scale.Y; //Scale just the Y axis
			newBasis.Column2 *= _scale.Z; //Scale just the Z axis
			newBasis.Column0 *= _scale.X; //Scale just the X axis //use basis.Column0 * RotationValue;

			//Set position. SetInstanceTransform is relative to parent
			Multimesh.SetInstanceTransform(i, new Transform3D(newBasis, newLocalPos));
			Log.Debug($"Instance {i} set to GlobalPos {centerGlobalWorldPos}, LocalPos {newLocalPos}");
		}

	}

	private void SetInstancesCollision()
	{
		if (_instanceList.Count == 0) return; //TODO: In the future we can find a way to check if the "entire list" is already set customdata. 

		MultiMesh Multimesh = this.Multimesh;
		//DEBUG - TEST ONLY
		//Define Vector3 Offset for shadow control. 
		Vector3 minWorld = new Vector3(-500, -500, -500);
		Vector3 maxWorld = new Vector3(500, 500, 500);
		//DEBUG - TEST ONLY

		//Loop our InstanceList and Send the RayCast for Collision from their World Position Center
		for (int i = 0; i < _instanceList.Count; i++)
		{
			if (_instanceList[i].HasCustomData) continue; //Skipt if we already passed CustomData to the Shader

			if (_instanceList[i].HasCollided)
			{
				Vector3 colliderPos = _instanceList[i].ColliderPosition;
				Vector3 normalizedColliderPos = new Vector3(
					Mathf.InverseLerp(minWorld.X, maxWorld.X, colliderPos.X),
					Mathf.InverseLerp(minWorld.Y, maxWorld.Y, colliderPos.Y),
					Mathf.InverseLerp(minWorld.Z, maxWorld.Z, colliderPos.Z)
				);

				Multimesh.SetInstanceCustomData(i, new Color(normalizedColliderPos.X, normalizedColliderPos.Y, normalizedColliderPos.Z, 1));
				CreateDebugCircle(colliderPos, Colors.Red);
				_instanceList[i].HasCustomData = true;
			}
			else //Has not collided yet. Need to send a RayCast
			{
				//Get instance Global Position and send a RayCast to find collider
				Vector3 centerGlobalWorldPos = _instanceList[i].GlobalPosition;
				Vector3 centerLocalPos = _instanceList[i].LocalPosition;

				//TODO - Wich one is more correct? Should we fire the Raycast from GlobalPos or is it influence by parent and local pos?
				SendRaycast(i, centerGlobalWorldPos, new Vector3(0, -1, 0));
				//SendRaycast(i, centerLocalPos, new Vector3(0, -1, 0));

			}
		}

		//Check if all instances have collided and update class level
		_hasCollidersMissing = _instanceList.Values.Any(instance => !instance.HasCustomData);
	}

	private void SendRaycast(int instanceIndex, Vector3 raycastStart, Vector3 _raycastDirection)
	{
		if (_instanceList[instanceIndex].HasCollided) return;

		Vector3 colliderGlobalPos = Vector3.Zero;
		//_raycastDirection = -this.GlobalTransform.Basis.Y;

		var spaceState = GetWorld3D().DirectSpaceState;
		var raycastEndPoint = raycastStart + _raycastDirection * _rayLenght;

		var query = PhysicsRayQueryParameters3D.Create(raycastStart, raycastEndPoint);
		query.CollideWithAreas = false;
		query.CollideWithBodies = true;
		query.CollisionMask = CollisionLayers;

		Godot.Collections.Dictionary result = spaceState.IntersectRay(query);

		if (result.Count > 0) //while (result.Count < 0)
		{
			if (result.TryGetValue("collider", out var collider))
			{

				Node3D colliderNode = (Node3D)collider; // Cast the Variant to a Node
														// Log.Debug($"Collider is: {colliderNode.Name}");

				// Vector3 colliderLocalPos = result["position"].AsVector3();
				// colliderGlobalPos = this.GlobalTransform * colliderLocalPos; //Actual World Position (Global Position)

				colliderGlobalPos = result["position"].AsVector3(); // already global??

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

	private void CreateDebugCircle(Vector3 position, Color color)
	{
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

		public bool HasCustomData { get; set; } = false;

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
