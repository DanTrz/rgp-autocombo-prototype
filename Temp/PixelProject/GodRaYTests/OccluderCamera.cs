using System;
using Godot;

public partial class OccluderCamera : Camera3D
{
	[Export]
	public NodePath MainCameraPath { get; set; }

	private Camera3D _mainCamera;

	public override void _Ready()
	{
		if (MainCameraPath != null)
		{
			_mainCamera = GetNode<Camera3D>(MainCameraPath);
		}

		if (_mainCamera == null)
		{
			GD.PrintErr($"OccluderCameraSync: MainCamera3D not found at path: {MainCameraPath}. Please assign it in the Inspector.");
		}
	}

	public override void _Process(double delta)
	{
		if (_mainCamera != null && IsInstanceValid(_mainCamera))
		{
			// Sync global transform (position and rotation)

			GlobalTransform = _mainCamera.GlobalTransform;

			// Sync projection type and relevant properties

			if (_mainCamera.Projection == ProjectionType.Perspective)
			{
				Projection = ProjectionType.Perspective;
				Fov = _mainCamera.Fov;
				// Near and Far are important for depth consistency if your shader uses depth

				Near = _mainCamera.Near;
				Far = _mainCamera.Far;
				// KeepAspect can also be synced if necessary

				KeepAspect = _mainCamera.KeepAspect;

			}
			else if (_mainCamera.Projection == ProjectionType.Orthogonal)
			{
				Projection = ProjectionType.Orthogonal;
				Size = _mainCamera.Size;
				Near = _mainCamera.Near;
				Far = _mainCamera.Far;
			}
			// Add other properties to sync if needed (e.g., FrustumOffset)

		}
	}
}
