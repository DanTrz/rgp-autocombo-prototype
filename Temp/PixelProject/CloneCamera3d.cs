using System;
using Godot;

public partial class CloneCamera3d : Camera3D
{
	[Export] Camera3D _mainCamera;
	[Export] bool _followMainCamera = true;
	public override void _Ready()
	{
		_followMainCamera = _mainCamera != null ? true : false;
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		if (_followMainCamera)
		{
			if (GlobalTransform != _mainCamera.GlobalTransform)
			{
				// GlobalPosition = _mainCamera.GlobalPosition;
				GlobalTransform = _mainCamera.GlobalTransform;
				GlobalRotation = _mainCamera.GlobalRotation;
				// Log.Info($"CloneCamera3d Position: {GlobalPosition} / MainCam Position: {_mainCamera.GlobalPosition}");
			}

		}
	}
}
