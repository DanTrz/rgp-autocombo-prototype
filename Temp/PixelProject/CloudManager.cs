using Godot;

[Tool]
public partial class CloudManager : MeshInstance3D
{
	[ExportToolButton("UpdateCloudShadows")]
	public Callable UpdateBtn => Callable.From(UpdateCloudShadows);

	[Export] public float _shadowStrength = 0.8f;

	[Export(PropertyHint.Range, "0.0,1.0,0.01")]
	public float _alphaScissor
	{
		get
		{
			return field;
		}
		set
		{
			field = value;
			UpdateCloudShadows();
		}
	} = 0.55f;
	[Export] float _cloudAlphaOffset = 0.05f; //Apply an offect to our mesh, to make it smaller than the Shader one
	[Export(PropertyHint.Range, "0.1,5.0,0.1")] public float cloudTextureScale = 1.0f;
	[Export] public DirectionalLight3D sunLight;
	[Export] public bool enableDirectionalShadows = false;

	private double lastUpdateTime = 0.0;
	StandardMaterial3D _cloudStdMaterial;

	public override void _Ready()
	{
		_cloudStdMaterial = GetActiveMaterial(0) as StandardMaterial3D;
		UpdateCloudShadows();
	}

	private void UpdateCloudShadows()
	{
		try
		{
			Texture2D cloudTexture = GetCloudTexture();

			if (cloudTexture == null)
			{
				Log.Error("❌ No cloud texture found!");
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
				Log.Error("Cloud mesh should be a PlaneMesh!");
				return;
			}

			// Use the mesh size directly as cloud area size
			float autoAreaSize = Mathf.Max(meshSize.X, meshSize.Y);
			float scaledAreaSize = autoAreaSize / cloudTextureScale;

			//Update Mesh AlphaScissorThreshold on all Meshes 
			_cloudStdMaterial.AlphaScissorThreshold = _alphaScissor + _cloudAlphaOffset;
			_cloudStdMaterial.Uv1Scale = new Vector3(cloudTextureScale, cloudTextureScale, 1.0f);

			RenderingServer.GlobalShaderParameterSet("cloud_shadow_texture", cloudTexture);
			RenderingServer.GlobalShaderParameterSet("cloud_alpha_scissor", _alphaScissor);
			RenderingServer.GlobalShaderParameterSet("cloud_shadow_strength", _shadowStrength);
			RenderingServer.GlobalShaderParameterSet("cloud_movement_offset", Vector2.Zero);

			RenderingServer.GlobalShaderParameterSet("cloud_area_center", meshWorldPosition);
			// RenderingServer.GlobalShaderParameterSet("cloud_area_size", autoAreaSize);
			RenderingServer.GlobalShaderParameterSet("cloud_area_size", scaledAreaSize);

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

			Log.Debug("Cloud shadows updated!");
			Log.Debug($"Mesh World Position: {meshWorldPosition}");
			Log.Debug($"Plane Size: {meshSize}");
			Log.Debug($"Auto Area Size: {autoAreaSize}");
			Log.Debug($"Light Direction: {lightDirection}");
			Log.Debug($"Directional Shadows: {enableDirectionalShadows}");
		}
		catch (System.Exception e)
		{
			Log.Error($"UpdateCloudShadows Failed: {e.Message}");
		}
	}

	public override void _Process(double delta)
	{
		// Update cloud position in real-time as mesh moves
		// lastUpdateTime += delta;
		// if (lastUpdateTime >= 0.1) // Update every 0.1 seconds to avoid spam
		// {
		// 	Vector3 currentPosition = GlobalTransform.Origin;
		// 	RenderingServer.GlobalShaderParameterSet("cloud_area_center", currentPosition);
		// 	lastUpdateTime = 0.0;
		// }
	}

	private Texture2D GetCloudTexture()
	{
		if (_cloudStdMaterial == null)
			_cloudStdMaterial = GetActiveMaterial(0) as StandardMaterial3D;

		if (_cloudStdMaterial is StandardMaterial3D stdMat && stdMat.AlbedoTexture != null)
		{
			return stdMat.AlbedoTexture;
		}

		Log.Error("No texture found! Assign a StandardMaterial3D with AlbedoTexture");
		return null;
	}
}