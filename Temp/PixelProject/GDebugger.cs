using System;
using Godot;

public partial class GDebugger : Control
{
	[Export] Label FPSCount;

	public override void _Ready()
	{
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		FPSCount.Text = "FPS: " + Engine.GetFramesPerSecond().ToString();
	}
}
