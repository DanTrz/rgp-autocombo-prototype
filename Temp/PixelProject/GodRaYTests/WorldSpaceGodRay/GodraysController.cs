using System.Runtime.InteropServices.Swift;
using Godot;
using Microsoft.VisualBasic.FileIO;

// [Tool]
public partial class GodraysController : Node3D
{

	// [ExportToolButton("CreateMultiMeshes")]
	// public Callable CreateMultiMeshesBtb => Callable.From(() => SetupMultiMesh());
	[Export] PackedScene _lightShaftScene = GD.Load<PackedScene>("uid://b3vej5yd5cpjo");
	[Export] Camera3D _mainCam;
	[Export] Vector2 _gridSize = new Vector2(10, 10);
	[Export] MultiMeshInstance3D _multiMesh;
	[Export] int _instanceCount = 1;

	[Export] Vector3 _position { get; set; } = new();
	[Export] Vector3 _scale { get; set; } = Vector3.One;
	[Export] float _rotationZ { get; set; } = 0.0f;



	public override void _Ready()
	{
		if (Engine.IsEditorHint()) return;
		//PopulateGrid(_gridSize, GetGridCellSize(_gridSize));
		SetupMultiMesh();
	}


	private void SetupMultiMesh()
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
		Vector3 normalizedPosition = new();
		//DEBUG - TEST ONLY

		for (int i = 0; i < Multimesh.InstanceCount; i++)
		{
			Vector3 newPosition = new Vector3((i * _position.X), _position.Y, _position.Z);

			//DEBUG - TEST ONLY //
			normalizedPosition = new Vector3(
				Mathf.InverseLerp(minWorld.X, maxWorld.X, newPosition.X),
				Mathf.InverseLerp(minWorld.Y, maxWorld.Y, newPosition.Y),
				Mathf.InverseLerp(minWorld.Z, maxWorld.Z, newPosition.Z)
			);
			// Multimesh.SetInstanceCustomData(i, new Color(normalizedPosition.X, normalizedPosition.Y, normalizedPosition.Z, 1));
			Multimesh.SetInstanceCustomData(i, new Color(normalizedPosition.X, normalizedPosition.Y, normalizedPosition.Z, 1));
			CreateDebugCircle(newPosition);

			//DEBUG - TEST ONLY

			float newRotation = Mathf.DegToRad(_rotationZ);
			Basis newBasis = new Basis(Vector3.One, newRotation); //Apply Rotation
			newBasis.Column1 *= _scale.Y; //Scale just the Y axis
			newBasis.Column2 *= _scale.Z; //Scale just the Z axis
			newBasis.Column0 *= _scale.X; //Scale just the X axis //If you want apply Rotation indiviaully use basis.Column0 * RotationValue;

			Multimesh.SetInstanceTransform(i, new Transform3D(newBasis, newPosition));
			GD.Print($"Instance {i} set to {newPosition}");
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

	private void CreateDebugCircle(Vector3 position)
	{
		var mesh = new SphereMesh();
		mesh.Radius = 0.5f;
		var material = new StandardMaterial3D();
		material.AlbedoColor = Colors.Red;
		var sphere = new MeshInstance3D();
		sphere.Mesh = mesh;
		sphere.MaterialOverride = material;
		AddChild(sphere);
		sphere.CastShadow = 0; //SHADOW_CASTING_SETTING_OFF = 0
		sphere.GlobalPosition = position;

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
