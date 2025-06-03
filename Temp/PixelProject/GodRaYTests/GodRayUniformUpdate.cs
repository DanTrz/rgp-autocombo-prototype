using Godot;

public partial class GodRayUniformUpdater : MeshInstance3D
{
	[Export]
	public NodePath OccluderViewportPath { get; set; }

	[Export]
	public NodePath MainLightPath { get; set; }

	[Export]
	public NodePath MainCameraPath { get; set; }

	private SubViewport _occluderViewport;
	private Node3D _mainLight;
	private Camera3D _mainCamera;
	private ShaderMaterial _shaderMaterial;
	private Vector2 _lastViewportSize = Vector2.Zero;


	public override void _Ready()
	{
		// Get the ShaderMaterial from this MeshInstance3D
		_shaderMaterial = GetActiveMaterial(0) as ShaderMaterial;
		if (_shaderMaterial == null)
		{
			GD.PrintErr("GodRayUniformUpdater: ShaderMaterial not found on this MeshInstance3D. Please assign one.");
			SetProcess(false); // Disable processing if no material
			return;
		}

		// Get OccluderViewport
		if (OccluderViewportPath != null)
		{
			_occluderViewport = GetNode<SubViewport>(OccluderViewportPath);
		}
		if (_occluderViewport == null)
		{
			GD.PrintErr($"GodRayUniformUpdater: OccluderViewport not found at path: {OccluderViewportPath}. Please assign it.");
		}

		// Get MainLight
		if (MainLightPath != null)
		{
			_mainLight = GetNode<Node3D>(MainLightPath);
		}
		if (_mainLight == null)
		{
			GD.PrintErr($"GodRayUniformUpdater: Main Light Node3D not found at path: {MainLightPath}. Please assign it.");
		}

		// Get MainCamera
		if (MainCameraPath != null)
		{
			_mainCamera = GetNode<Camera3D>(MainCameraPath);
		}
		if (_mainCamera == null)
		{
			GD.PrintErr($"GodRayUniformUpdater: Main Camera3D not found at path: {MainCameraPath}. Please assign it.");
		}

		// Initial update of uniforms
		UpdateShaderParameters();
	}

	public override void _Process(double delta)
	{
		// Continuously update parameters, or you could optimize this
		// to only update when necessary (e.g., on viewport resize signals, camera/light movement).
		UpdateShaderParameters();
	}

	private void UpdateShaderParameters()
	{
		if (_shaderMaterial == null) return;

		// Update screen_resolution from OccluderViewport size
		if (_occluderViewport != null && IsInstanceValid(_occluderViewport))
		{
			Vector2 currentViewportSize = _occluderViewport.Size;
			if (currentViewportSize != _lastViewportSize) // Only update if size changed
			{
				_shaderMaterial.SetShaderParameter("screen_resolution", currentViewportSize);
				_lastViewportSize = currentViewportSize;
			}
		}
		else
		{
			// Fallback if viewport not assigned, use main window size or a default
			// This might not be what you want if OccluderViewport has a fixed different size.
			// Vector2 mainWinSize = DisplayServer.WindowGetSize();
			// _shaderMaterial.SetShaderParameter("screen_resolution", mainWinSize);
		}


		// Update light_screen_pos from MainLight and MainCamera
		if (_mainLight != null && IsInstanceValid(_mainLight) &&
			_mainCamera != null && IsInstanceValid(_mainCamera) &&
			_mainCamera.IsInsideTree() && _mainCamera.GetViewport() != null)
		{
			// Get the viewport the main camera is rendering to
			Viewport mainCameraViewport = _mainCamera.GetViewport();
			if (mainCameraViewport == null) return;

			Vector2 lightPixelPos = _mainCamera.UnprojectPosition(_mainLight.GlobalTransform.Origin);
			Rect2 mainCameraViewportRect = mainCameraViewport.GetVisibleRect(); // This gives the size of the viewport the camera renders to

			if (mainCameraViewportRect.Size.X > 0 && mainCameraViewportRect.Size.Y > 0)
			{
				// Normalize based on the actual viewport size the main camera is using
				Vector2 normalizedLightPos = lightPixelPos / mainCameraViewportRect.Size;

				// SCREEN_UV in Godot 4 has Y=0 at the top.
				// Camera3D.unproject_position also typically has Y=0 at the top of the viewport.
				// If your shader's light_screen_pos uniform expects Y=0 at the bottom, you might need:
				// normalizedLightPos.Y = 1.0f - normalizedLightPos.Y;
				// However, for consistency with SCREEN_UV, it's often best to keep Y=0 at the top.

				_shaderMaterial.SetShaderParameter("light_screen_pos", normalizedLightPos);
			}
		}
	}
}
