using System;
using Godot;

public partial class MeshInstanceGodRay : MeshInstance3D
{
	[Export]
	public NodePath OccluderSubViewportPath { get; set; }

	[Export]
	public NodePath MainLightPath { get; set; }

	[Export]
	public NodePath MainCameraPath { get; set; }

	private SubViewport _occluderSubViewport;
	private Node3D _mainLight;
	private Camera3D _mainCamera;
	private ShaderMaterial _shaderMaterial;
	private Vector2I _lastViewportSize = Vector2I.Zero;


	public override void _Ready()
	{
		_shaderMaterial = GetActiveMaterial(0) as ShaderMaterial;
		if (_shaderMaterial == null)
		{
			GD.PrintErr("GodRayUniformUpdater: ShaderMaterial not found on this MeshInstance3D.");
			SetProcess(false);
			return;
		}

		if (OccluderSubViewportPath != null)
			_occluderSubViewport = GetNode<SubViewport>(OccluderSubViewportPath);
		if (_occluderSubViewport == null)
			GD.PrintErr($"GodRayUniformUpdater: OccluderSubViewport not found at path: {OccluderSubViewportPath}.");

		if (MainLightPath != null)
			_mainLight = GetNode<Node3D>(MainLightPath);
		if (_mainLight == null)
			GD.PrintErr($"GodRayUniformUpdater: Main Light Node3D not found at path: {MainLightPath}.");

		if (MainCameraPath != null)
			_mainCamera = GetNode<Camera3D>(MainCameraPath);
		if (_mainCamera == null)
			GD.PrintErr($"GodRayUniformUpdater: Main Camera3D not found at path: {MainCameraPath}.");

		UpdateShaderParameters();
	}

	public override void _Process(double delta)
	{
		UpdateShaderParameters();
	}

	private void UpdateShaderParameters()
	{
		if (_shaderMaterial == null) return;

		if (_occluderSubViewport != null && IsInstanceValid(_occluderSubViewport))
		{
			Vector2I currentViewportSize = _occluderSubViewport.Size;
			if (currentViewportSize != _lastViewportSize)
			{
				_shaderMaterial.SetShaderParameter("screen_resolution", (Vector2)currentViewportSize);
				_lastViewportSize = currentViewportSize;
			}
		}

		if (_mainLight != null && IsInstanceValid(_mainLight) &&
			_mainCamera != null && IsInstanceValid(_mainCamera) &&
			_mainCamera.IsInsideTree())
		{
			Viewport mainCameraViewport = _mainCamera.GetViewport();
			if (mainCameraViewport == null) return;

			Vector2 normalizedLightPos;
			Rect2 mainCameraViewportRect = mainCameraViewport.GetVisibleRect();

			if (mainCameraViewportRect.Size.X <= 0 || mainCameraViewportRect.Size.Y <= 0) return;

			if (_mainLight is DirectionalLight3D directionalLight)
			{
				// For DirectionalLight3D:
				// The light shines *along* its local -Z axis.
				// So, the direction vector *from which the light is coming* is its local +Z axis, transformed to world space.
				Vector3 lightSourceDirectionWorld = directionalLight.GlobalTransform.Basis.Z.Normalized();

				// Create a representative 3D point for this light source, very far away from the camera
				// along this source direction. Using the camera's 'Far' plane distance is a good heuristic.
				Vector3 representativeWorldPosOfLightSource = _mainCamera.GlobalTransform.Origin + lightSourceDirectionWorld * _mainCamera.Far;

				Vector2 lightPixelPos = _mainCamera.UnprojectPosition(representativeWorldPosOfLightSource);
				normalizedLightPos = lightPixelPos / mainCameraViewportRect.Size;
			}
			else // For OmniLight3D, SpotLight3D, or other Node3D, use their origin
			{
				Vector2 lightPixelPos = _mainCamera.UnprojectPosition(_mainLight.GlobalTransform.Origin);
				normalizedLightPos = lightPixelPos / mainCameraViewportRect.Size;
			}

			// Ensure Y-coordinate matches SCREEN_UV (Y=0 at top)
			// UnprojectPosition generally gives Y=0 at top for viewports.
			// If your shader interprets light_screen_pos with Y=0 at bottom, you might need:
			// normalizedLightPos.Y = 1.0f - normalizedLightPos.Y;

			_shaderMaterial.SetShaderParameter("light_screen_pos", normalizedLightPos);
			// For debugging:
			GD.Print($"Light Screen Pos ({_mainLight.GetType().Name}): {normalizedLightPos}");
		}
	}
}
