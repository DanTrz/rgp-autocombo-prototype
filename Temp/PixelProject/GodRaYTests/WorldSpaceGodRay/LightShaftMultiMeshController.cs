using System;
using System.Collections.Generic;
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
	[Export] MultiMeshInstance3D _multiMesh;
	[Export] int _instanceCount = 1;

	[Export] Vector3 _position { get; set; } = new();
	[Export] Vector3 _scale { get; set; } = Vector3.One;
	[Export] float _rotationZ { get; set; } = 0.0f;

	[ExportGroup("Raycast Settings")]
	[Export] private float _rayLenght { get; set; } = 45.0f;
	[Export(PropertyHint.Layers3DRender)] public uint CollisionLayers { get; set; }

	private Dictionary<int, InstanceCollider> _instanceList { get; set; } = new();
	private bool _hasCollided = false;
	// private PhysicsRayQueryParameters3D _raycast;




	public override async void _Ready()
	{
		if (Engine.IsEditorHint()) return;
		//PopulateGrid(_gridSize, GetGridCellSize(_gridSize));
		await SetupMultiMesh();
	}


	private async Task SetupMultiMesh()
	{

		MultiMesh Multimesh = _multiMesh.Multimesh;
		//Reset the MultiMesh
		Multimesh.InstanceCount = 0;
		Multimesh.VisibleInstanceCount = -1;

		//Setup the MultiMesh
		Multimesh.UseCustomData = true;
		Multimesh.InstanceCount = _instanceCount;
		Multimesh.VisibleInstanceCount = _instanceCount;

		//DEBUG - TEST ONLY
		//Define Vector3 Offset for shadow control. 
		Vector3 minWorld = new Vector3(-500, -500, -500);
		Vector3 maxWorld = new Vector3(500, 500, 500);
		CleanAllDebugSpheres();
		//DEBUG - TEST ONLY

		for (int i = 0; i < Multimesh.InstanceCount; i++)
		{
			Vector3 newLocalPos = new Vector3((i * _position.X), _position.Y, _position.Z); //Seems an offset from parent
			Vector3 centerGlobalWorldPos = this.GlobalTransform * newLocalPos; //Actual World Position (Global Position)

			_instanceList[i] = new InstanceCollider(centerGlobalWorldPos, false);

			//DEBUG - TEST ONLY //
			// Vector3 colliderPos = new Vector3(centerGlobalWorldPos.X + 2, centerGlobalWorldPos.Y + 2, centerGlobalWorldPos.Z);
			// await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
			// await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
			Vector3 colliderPos = await GetColliderPosition(centerGlobalWorldPos, new Vector3(0, -1, 0));
			Vector3 normalizedColliderPos = new Vector3(
				Mathf.InverseLerp(minWorld.X, maxWorld.X, colliderPos.X),
				Mathf.InverseLerp(minWorld.Y, maxWorld.Y, colliderPos.Y),
				Mathf.InverseLerp(minWorld.Z, maxWorld.Z, colliderPos.Z)
			);

			// Vector3 offset = colliderPos - centerWorldPos;
			// Vector3 normalizedOffsetPos = new Vector3(
			// 	Mathf.InverseLerp(minWorld.X, maxWorld.X, offset.X),
			// 	Mathf.InverseLerp(minWorld.Y, maxWorld.Y, offset.Y),
			// 	Mathf.InverseLerp(minWorld.Z, maxWorld.Z, offset.Z)
			// );

			Multimesh.SetInstanceCustomData(i, new Color(normalizedColliderPos.X, normalizedColliderPos.Y, normalizedColliderPos.Z, 1));
			// Multimesh.SetInstanceCustomData(i, new Color(normalizedOffsetPos.X, normalizedOffsetPos.Y, normalizedOffsetPos.Z, 1));

			CreateDebugCircle(centerGlobalWorldPos, Colors.Green);// World position center
			CreateDebugCircle(colliderPos, Colors.Red);// Fake collider position (this will be replaced by the RayCast collider data)
													   // CreateDebugCircle(offset, Colors.Yellow);

			//	_offsetFromObjCenter = _colliderPos - _originalObjCenter;

			//DEBUG - TEST ONLY

			float newRotation = Mathf.DegToRad(_rotationZ);
			Basis newBasis = new Basis(Vector3.One, newRotation); //Apply Rotation
			newBasis.Column1 *= _scale.Y; //Scale just the Y axis
			newBasis.Column2 *= _scale.Z; //Scale just the Z axis
			newBasis.Column0 *= _scale.X; //Scale just the X axis //If you want apply Rotation indiviaully use basis.Column0 * RotationValue;

			Multimesh.SetInstanceTransform(i, new Transform3D(newBasis, newLocalPos));
			GD.Print($"Instance {i} set to {newLocalPos}");
		}


		// Set the transform of the instances.
		// for (int i = 0; i < Multimesh.InstanceCount; i++)
		// {
		// 	Vector3 adjustedPosition = new Vector3(i * position.X, position.Y, position.Z);
		// 	Vector3 adjustedScale = new Vector3(scale.X, scale.Y, scale.Z);
		// 	float adjustedRotation = Mathf.DegToRad(rotationZ);

		// 	// Vector3 adjustedPosition = new Vector3(i * position.X, position.Y, position.Z);
		// 	// rotation = Mathf.DegToRad(rotation);

		// 	//CREATING A TRANSFORM MANUALLY AND APPLYING SCALE
		// 	Transform3D transform = new Transform3D(Basis.Identity, adjustedPosition);

		// 	Basis newBasis = new Basis(Vector3.One.Normalized(), Mathf.DegToRad(-20f));
		// 	transform.Basis = newBasis;
		// 	// transform.Basis = new Basis(Vector3.Forward.Normalized(), adjustedRotation);


		// 	transform = transform.Scaled(adjustedScale);

		// 	Multimesh.SetInstanceTransform(i, transform);

		// 	GD.Print($"Instance {i} set to {adjustedPosition}");
		// }

		// for (int i = 0; i < Multimesh.InstanceCount; i++)
		// {
		// 	Vector3 newPosition = new Vector3(i * position.X, position.Y, position.Z);
		// 	Vector3 newScale = new Vector3(scale.X, scale.Y, scale.Z);
		// 	float newRotation = Mathf.DegToRad(rotationZ);

		// 	// Create rotation basis (around Y for example)
		// 	Basis basis = new Basis(Vector3.Up, newRotation);

		// 	// Apply scale manually to the basis
		// 	basis = new Basis(
		// 		basis.Column0 * scale.X,
		// 		basis.Column1 * scale.Y,
		// 		basis.Column2 * scale.Z
		// 	);

		// 	// Apply transform
		// 	Multimesh.SetInstanceTransform(i, new Transform3D(basis, newPosition));

		// 	GD.Print($"Instance {i} set to {newPosition}");
		// }

	}

	private void SetInstancesCollision()
	{


	}

	private async Task<Vector3> GetColliderPosition(Vector3 raycastStart, Vector3 _raycastDirection)
	{

		// _raycastDirection = _markerDownDirection;
		//_markerDownDirection = -_originMarker.GlobalTransform.Basis.Y;
		_hasCollided = false;
		Vector3 colliderGlobalPos = Vector3.Zero;
		_raycastDirection = -this.GlobalTransform.Basis.Y;

		var spaceState = GetWorld3D().DirectSpaceState;
		var raycastEndPoint = raycastStart + _raycastDirection * _rayLenght;

		var query = PhysicsRayQueryParameters3D.Create(raycastStart, raycastEndPoint);
		query.CollideWithAreas = false;
		query.CollideWithBodies = true;
		query.CollisionMask = CollisionLayers;

		Godot.Collections.Dictionary result = spaceState.IntersectRay(query);

		// await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
		// await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame);
		// await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
		// await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
		// await ToSignal(GetTree().CreateTimer(0.2), Timer.SignalName.Timeout);



		if (result.Count > 0) //while (result.Count < 0)
		{
			_hasCollided = true;
			if (result.TryGetValue("collider", out var collider))
			{
				Node3D colliderNode = (Node3D)collider; // Cast the Variant to a Node
														// Log.Debug($"Collider is: {colliderNode.Name}");

				Vector3 colliderLocalPos = result["position"].AsVector3();
				colliderGlobalPos = this.GlobalTransform * colliderLocalPos; //Actual World Position (Global Position)
				Log.Debug($"Collider Found Pos: {colliderGlobalPos}");


				// _offsetFromObjCenter = _colliderPos - _originalObjCenter;
				// UpdateShaderParameters(_offsetFromObjCenter, noiseMovement);

				// ResizeMesh();
				// PositionMarkers(_raycastMesh.Mesh as CylinderMesh, _colliderPos);


			}
			return colliderGlobalPos;


			// if (DebugActive)
			// {
			// 	_debugCollisionSphere.Visible = true;
			// 	_originMarker.Visible = true;
			// 	// //_debugSphere.GlobalPosition = raycastEndPoint;
			// }


		}
		else
		{
			Log.Debug($"No Collision Found - Return default {colliderGlobalPos}");
			return colliderGlobalPos;
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




	//OLDER CODE

	private Vector2 GetGridCellSize(Vector2 gridSize)
	{
		//1. Get the camera size
		//For an Orthogonal camera, 'size' is its height in world units.
		float camViewHeight = _mainCam.Size;
		float camViewWidth = camViewHeight * _mainCam.GetViewport().GetVisibleRect().Size.X / _mainCam.GetViewport().GetVisibleRect().Size.Aspect();

		//2. Find the Top-Left Corner of the View
		Vector3 topLeftCorner = _mainCam.GlobalTransform.Origin - _mainCam.GlobalTransform.Basis.Z * camViewHeight * 0.5f;
		Log.Debug($"Top Left Corner: {topLeftCorner}");
		//var top_left = cam_transform.origin - (cam_transform.basis.x * view_width / 2.0) + (cam_transform.basis.y * view_height / 2.0)

		//3. Calculate Cell Size in World Units 
		float gridCellWidth = camViewWidth / gridSize.X;
		float gridCellHeight = camViewHeight / gridSize.Y;

		Log.Debug($"GridSize - Width: {gridCellWidth} - Height: {gridCellHeight}");
		return new Vector2(gridCellWidth, gridCellHeight);

	}

	private void PopulateGrid(Vector2 gridSize, Vector2 cellSize)
	{
		for (int y = 0; y < gridSize.Y; y++)
		{
			for (int x = 0; x < gridSize.X; x++)
			{
				//# Calculate the center of the current cell in 2D screen coordinates.
				//var screen_point = Vector2(x * cell_size.x, y * cell_size.y) + (cell_size * 0.5)
				Vector2 gridCenter = new Vector2(x, y) * cellSize;

				// #Convert 2D Point to 3D Position ---
				// # This is the core logic.
				// 	var ray_origin = camera.project_ray_origin(screen_point)
				// 	var ray_direction = camera.project_ray_normal(screen_point)
				// 	var world_position = ray_origin + ray_direction * spawn_distance_from_camera

				// SpawnLightShaft(new Vector3(gridCenter.X, 0, gridCenter.Y));
				// Log.Debug($"Spawned LightShaft at: {gridCenter}");
			}
		}

	}

	private void SpawnLightShaft(Vector3 position)
	{
		LightShaftRaycast lightShaftNode = _lightShaftScene.Instantiate<LightShaftRaycast>();
		lightShaftNode.GlobalPosition = position;
		AddChild(lightShaftNode);
	}
}

public class InstanceCollider
{
	public Vector3 Position { get; set; }
	public bool HasCollided { get; set; }

	public InstanceCollider(Vector3 position, bool hasCollided)
	{
		Position = position;
		HasCollided = hasCollided;
	}
}

public partial class DebugSphere : MeshInstance3D
{

}

