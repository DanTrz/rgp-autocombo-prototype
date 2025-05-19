using System;
using Godot;

public partial class BatteArea : Area3D
{
	public override void _Ready()
	{
		BodyEntered += OnBodyEntered;
	}

	private void OnBodyEntered(Node3D body)
	{
		Log.Debug($"Area: {this.Name} entered by body: {body.Name}");
	}
}
