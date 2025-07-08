using Godot;

[Tool]
public partial class CloudManager : MeshInstance3D
{
	[ExportToolButton("UpdateCloudShadows")]
	public Callable UpdateBtn => Callable.From(UpdateCloudShadows);

	[Export] public float _shadowStrength = 0.8f;
	[Export] public float _alphaScissor = 0.55f;

	// Only the essential controls we actually need
	[Export] public DirectionalLight3D sunLight;
	[Export] public bool enableDirectionalShadows = false;

	private double lastUpdateTime = 0.0;

	public override void _Ready()
	{
		UpdateCloudShadows();
	}

	private void UpdateCloudShadows()
	{
		try
		{
			Texture2D cloudTexture = GetCloudTexture();

			if (cloudTexture == null)
			{
				GD.PrintErr("❌ No cloud texture found!");
				return;
			}

			// AUTO-CALCULATE everything from our own mesh
			Vector3 meshWorldPosition = GlobalTransform.Origin;

			// Get the actual plane size directly
			Vector2 meshSize = Vector2.Zero;
			if (GetMesh() is PlaneMesh planeMesh)
			{
				meshSize = planeMesh.Size;
			}
			else
			{
				GD.PrintErr("❌ Cloud mesh should be a PlaneMesh!");
				return;
			}

			// Use the mesh size directly as cloud area size
			float autoAreaSize = Mathf.Max(meshSize.X, meshSize.Y);

			RenderingServer.GlobalShaderParameterSet("cloud_shadow_texture", cloudTexture);
			RenderingServer.GlobalShaderParameterSet("cloud_alpha_scissor", _alphaScissor);
			RenderingServer.GlobalShaderParameterSet("cloud_shadow_strength", _shadowStrength);
			RenderingServer.GlobalShaderParameterSet("cloud_movement_offset", Vector2.Zero);

			RenderingServer.GlobalShaderParameterSet("cloud_area_center", meshWorldPosition);
			RenderingServer.GlobalShaderParameterSet("cloud_area_size", autoAreaSize);

			// Light direction support
			Vector3 lightDirection = Vector3.Down; // Default fallback
			if (enableDirectionalShadows && sunLight != null)
			{
				lightDirection = -sunLight.GlobalTransform.Basis.Z; // Light forward direction
																	// lightDirection = sunLight.GlobalTransform.Basis.Z; // Light back direction

			}

			RenderingServer.GlobalShaderParameterSet("sun_light_direction", lightDirection);
			RenderingServer.GlobalShaderParameterSet("enable_directional_shadows", enableDirectionalShadows);
			RenderingServer.GlobalShaderParameterSet("cloud_mesh_y", meshWorldPosition.Y);

			GD.Print("✅ Cloud shadows updated!");
			GD.Print($"🌍 Mesh World Position: {meshWorldPosition}");
			GD.Print($"📏 Plane Size: {meshSize}");
			GD.Print($"📐 Auto Area Size: {autoAreaSize}");
			GD.Print($"☀️ Light Direction: {lightDirection}");
			GD.Print($"🔆 Directional Shadows: {enableDirectionalShadows}");
		}
		catch (System.Exception e)
		{
			GD.PrintErr($"❌ Failed: {e.Message}");
		}
	}

	public override void _Process(double delta)
	{
		// Update cloud position in real-time as mesh moves
		lastUpdateTime += delta;
		if (lastUpdateTime >= 0.1) // Update every 0.1 seconds to avoid spam
		{
			Vector3 currentPosition = GlobalTransform.Origin;
			RenderingServer.GlobalShaderParameterSet("cloud_area_center", currentPosition);
			lastUpdateTime = 0.0;
		}
	}

	private Texture2D GetCloudTexture()
	{
		Material material = GetActiveMaterial(0);

		if (material is StandardMaterial3D stdMat && stdMat.AlbedoTexture != null)
		{
			return stdMat.AlbedoTexture;
		}

		GD.PrintErr("❌ No texture found! Assign a StandardMaterial3D with AlbedoTexture");
		return null;
	}
}