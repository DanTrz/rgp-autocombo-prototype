using System;
using Godot;

public partial class CameraRig : Node3D
{
	[Export] public float MoveSpeed = 10.0f;

	[Export(PropertyHint.Range, "0,50")]
	public float OrbitSpeed = 1.0f;

	private float _targetOrbit;

	[Export] public float CircularRadius = 0.01f;
	[Export] public float CircularSpeed = 0.01f;

	private float _circAngle = 0.0f;

	private Camera3D _cam;

	public override void _Ready()
	{
		_cam = GetNode<Camera3D>("%Camera3D");
		_targetOrbit = Rotation.Y;
	}

	public override void _Process(double delta)
	{
		MoveCameraRig((float)delta);
	}

	private void MoveCameraRig(float delta)
	{

		Vector2 inputVec = Vector2.Zero;
		inputVec.X = Input.GetActionStrength("cam_right") - Input.GetActionStrength("cam_left");
		inputVec.Y = Input.GetActionStrength("cam_back") - Input.GetActionStrength("cam_forward");

		if (inputVec.Length() > 0)
		{
			inputVec = inputVec.Normalized();

			// Get directions from camera
			Vector3 camForward = new Vector3(_cam.GlobalTransform.Basis.Z.X, 0, _cam.GlobalTransform.Basis.Z.Z).Normalized(); ;
			Vector3 camRight = new Vector3(_cam.GlobalTransform.Basis.X.X, 0, _cam.GlobalTransform.Basis.X.Z).Normalized();

			// Construct movement direction
			Vector3 moveDir = (camRight * inputVec.X) + (-camForward * inputVec.Y);
			//moveDir = moveDir.Normalized();

			// Apply movement
			GlobalPosition += moveDir * MoveSpeed * delta;
		}

		// Orbit control
		if (Input.IsActionPressed("cam_orbit_right"))
			this.RotateY(-CircularSpeed * delta);

		if (Input.IsActionPressed("cam_orbit_left"))
			this.RotateY(CircularSpeed * delta);
	}
}