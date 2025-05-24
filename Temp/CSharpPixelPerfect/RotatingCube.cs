using System;
using Godot;

public partial class RotatingCube : Node3D
{
	[Export] public float Speed = 45.0f;

	public override void _Process(double delta)
	{
		float d = (float)delta;

		var cube = GetChild<Node3D>(0);
		var originalRotation = cube.GlobalRotation;

		RotateY(Mathf.DegToRad(Speed) * d);

		cube.GlobalRotation = originalRotation;
	}
}
