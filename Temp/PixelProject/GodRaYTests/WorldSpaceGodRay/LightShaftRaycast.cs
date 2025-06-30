using System;
using Godot;
using Godot.Collections;

[Tool]
public partial class LightShaftRaycast : Node3D
{
	[ExportToolButton("Reset Raycast Shaft")]
	public Callable ResetMeshBtn => Callable.From(() => SetMeshParameters());


	[Export] MeshInstance3D _raycastMesh { get; set; }
	[Export] MeshInstance3D _debugCollisionSphere { get; set; }
	[Export] Marker3D _originMarker { get; set; }
	[Export] private float _rayLenght { get; set; } = 45.0f;
	[Export] private float _rayWidth { get; set; } = 1.0f;
	[Export] private bool _randomize { get; set; } = true;
	[Export] private float _widthMaxRand { get; set; } = 1.4f;
	[Export] private float _widthMinRand { get; set; } = 0.5f;

	[Export(PropertyHint.Range, "0.0,1.0")] private float _rayLenghtFactor { get; set; } = 0.9f;
	[Export(PropertyHint.Layers3DRender)] public uint CollisionLayers { get; set; }
	[Export] public Godot.Collections.Array<GradientTexture2D> _gradientTextures { get; set; }

	[Export] bool DebugActive = false;

	private Vector3 _originalObjCenter = new Vector3(0, 0, 0);
	private Vector3 _markerDownDirection = new Vector3(0, 0, 0);
	private Vector3 _raycastStart = new Vector3(0, 0, 0);
	private Vector3 _raycastDirection = new Vector3(0, 0, 0);
	private Vector3 _colliderPos = new Vector3(0, 0, 0);
	private Vector3 _offsetFromObjCenter = new Vector3(0, 0, 0);
	float noiseMovement = 0.5f;

	private bool _hasCollided = false;
	private PhysicsRayQueryParameters3D _raycast;


	public override void _Ready()
	{
		if (Engine.IsEditorHint()) return;
		_debugCollisionSphere.Visible = false;
		_originMarker.Visible = false;

		SetMeshParameters(_randomize);
		Log.Debug($"Light Shaft Ready Called: {this.Name}");


	}

	public override void _Process(double delta)
	{
		if (Engine.IsEditorHint()) return;

		if (_hasCollided) return; //We just want to track the first collision
		SendRayCast();
	}

	private void SendRayCast()
	{
		_raycastStart = _originalObjCenter;
		//_raycastDirection = -this.GlobalTransform.Basis.Y;
		_raycastDirection = _markerDownDirection;

		var spaceState = GetWorld3D().DirectSpaceState;
		var raycastEndPoint = _raycastStart + _raycastDirection * _rayLenght;

		var query = PhysicsRayQueryParameters3D.Create(_raycastStart, raycastEndPoint);
		query.CollideWithAreas = false;
		query.CollideWithBodies = true;
		query.CollisionMask = CollisionLayers;

		Dictionary result = spaceState.IntersectRay(query);
		if (result.Count > 0)
		{
			_hasCollided = true;
			if (result.TryGetValue("collider", out var collider))
			{
				Node3D colliderNode = (Node3D)collider; // Cast the Variant to a Node
														// Log.Debug($"Collider is: {colliderNode.Name}");

				_colliderPos = result["position"].AsVector3();
				_offsetFromObjCenter = _colliderPos - _originalObjCenter;
				UpdateShaderParameters(_offsetFromObjCenter, noiseMovement);

				// Log.Debug($"Collider LocalPos is: {result["position"].AsVector3().ToString()}");
				// Log.Debug($"Offset from Center: {_offsetFromObjCenter.ToString()}");

				ResizeMesh();
				PositionMarkers(_raycastMesh.Mesh as CylinderMesh, _colliderPos);
				// _debugCollisionSphere.GlobalPosition = _colliderPos;

			}

			if (DebugActive)
			{
				_debugCollisionSphere.Visible = true;
				_originMarker.Visible = true;
				// //_debugSphere.GlobalPosition = raycastEndPoint;
			}


		}
	}

	private void UpdateShaderParameters(Vector3 samplingOffset, float noiseMovement)
	{

		if (_raycastMesh.GetActiveMaterial(0) is ShaderMaterial shaderMaterial)
		{
			// Log.Debug("Offset before: " + shaderMaterial.GetShaderParameter("sampling_offset").ToString());
			shaderMaterial.SetShaderParameter("sampling_offset", samplingOffset);
			shaderMaterial.SetShaderParameter("noise_movement", noiseMovement);

			if (_randomize)
			{
				shaderMaterial.SetShaderParameter("gradient", _gradientTextures.PickRandom());
			}
			else
			{
				shaderMaterial.SetShaderParameter("gradient", _gradientTextures[0]);
			}


			// Log.Debug("Offset after: " + shaderMaterial.GetShaderParameter("sampling_offset").ToString());
		}

	}

	private void ResizeMesh()
	{
		//_raycastMesh
		// float height = _originMarker.GlobalPosition.DistanceTo(_colliderPos) * _rayLenghtFactor;

		float height = _originMarker.GlobalPosition.DistanceTo(_colliderPos);
		// Vector3 midPoint = (_originMarker.GlobalPosition + _colliderPos) / 2.0f;
		// Vector3 distance = (_originMarker.GlobalPosition + _colliderPos);
		// Vector3 scaledDistance = new Vector3(distance.X * _rayLenghtFactor, distance.Y * _rayLenghtFactor, distance.Z);
		// Vector3 midPoint = scaledDistance / 2.0f;

		Vector3 midPoint = (_originMarker.GlobalPosition + _colliderPos) / 2.0f;

		if (_raycastMesh.Mesh is CylinderMesh cylinderMesh)
			cylinderMesh.Height = height;



		this.GlobalPosition = midPoint;
		_raycastMesh.GlobalPosition = midPoint;

	}

	private void SetMeshParameters(bool randomize = false)
	{

		if (_raycastMesh.Mesh is CylinderMesh cylinderMesh)
		{
			if (randomize)
			{
				_rayWidth = (float)GD.RandRange(_rayWidth * _widthMinRand, _rayWidth * _widthMaxRand);
				noiseMovement = (float)GD.RandRange(0.1f, noiseMovement);
			}

			cylinderMesh.Height = _rayLenght;
			cylinderMesh.TopRadius = _rayWidth;
			cylinderMesh.BottomRadius = _rayWidth;

			_debugCollisionSphere.Transform = Transform3D.Identity;
			_hasCollided = false;

			PositionMarkers(cylinderMesh, this.GlobalPosition);

		}
		UpdateShaderParameters(Vector3.Zero, noiseMovement);
		Log.Debug($"{this.Name} - Noise:{noiseMovement} - Width:{_rayWidth} ");
	}

	private void PositionMarkers(CylinderMesh cylinder, Vector3 collisionPoint)
	{
		_originMarker.GlobalPosition = this.GlobalPosition + (cylinder.Height / 2.0f) * _originMarker.GlobalTransform.Basis.Y;
		_debugCollisionSphere.GlobalPosition = collisionPoint;

		_originalObjCenter = this.GlobalTransform.Origin; //Same as GlobalPosition
														  //You want to move "up" and "down" along the parent's line. In Godot's 3D coordinate system, 
														  // the "up" direction is typically along the Y-axis. We will use the parent's local Y-axis.
		_markerDownDirection = -_originMarker.GlobalTransform.Basis.Y;
		// 	Log.Debug($"Original Origin: {_originalObjCenter}");
		// 	Log.Debug($"DebugCollisionSphere Global Position: {_debugSphere.GlobalPosition}");
	}

	//Method used to force a new raycast entire loop. Used mostly in Editor
	private void ForceSendRayCast()
	{
		SetMeshParameters();
		SendRayCast();

	}
}
