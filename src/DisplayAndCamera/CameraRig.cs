using System;
using Godot;

public partial class CameraRig : Node3D
{
	[Export] public float MoveSpeed = 4.0f;

	[Export(PropertyHint.Range, "0,50")]
	public float OrbitSpeed = 4.0f;

	private float _targetOrbit;

	[Export] public float CircularRadius = 0.0f;
	[Export] public float CircularSpeed = 0.2f;

	private float _circAngle = 0.0f;

	private Camera3D _cam;

	public override void _Ready()
	{
		_cam = GetNode<Camera3D>("Camera3D");
		_targetOrbit = Rotation.Y;
	}

	public override void _Process(double delta)
	{
		float d = (float)delta;

		// Movement
		Vector2 inputVec = Input.GetVector("cam_left", "cam_right", "cam_back", "cam_forward");
		Basis yaw = new Basis(Basis.X, Vector3.Up, Basis.Z).Orthonormalized();
		float pitchSin = Mathf.Sin(Rotation.X);
		if (Mathf.IsZeroApprox(pitchSin)) pitchSin = 0.01f; // prevent div by 0

		Vector3 moveVec = yaw * new Vector3(inputVec.X, 0, inputVec.Y / pitchSin);
		Position += moveVec * MoveSpeed * d;

		// Orbit control
		if (Input.IsActionJustPressed("cam_orbit_right"))
			_targetOrbit += Mathf.Tau / 8f;
		if (Input.IsActionJustPressed("cam_orbit_left"))
			_targetOrbit -= Mathf.Tau / 8f;

		Rotation = new Vector3(Rotation.X, Mathf.Lerp(Rotation.Y, _targetOrbit, 1f - Mathf.Pow(2f, -4f * d * OrbitSpeed)), Rotation.Z);
		if (Mathf.Abs(Rotation.Y - _targetOrbit) < 0.02f)
			Rotation = new Vector3(Rotation.X, _targetOrbit, Rotation.Z);

		// Circular motion of camera
		_circAngle -= Mathf.Tau * CircularSpeed * d;
		_cam.Position = new Vector3(Mathf.Cos(_circAngle) * CircularRadius, Mathf.Sin(_circAngle) * CircularRadius, _cam.Position.Z);
	}
}