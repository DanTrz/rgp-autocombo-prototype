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
			Callable.From(UpdateCloudShadows).CallDeferred();
			// UpdateCloudShadows();
		}
	} = 0.55f;

	[Export] float _cloudAlphaOffset = 0.05f; //Apply an offset to our mesh, to make it smaller than the Shader one

	// Cloud texture scaling control
	[Export(PropertyHint.Range, "0.1,5.0,0.1")] public float cloudTextureScale = 1.0f;

	// NEW: Cloud movement controls
	[ExportGroup("Cloud Movement")]
	[Export] public bool isMoving = false;
	[Export] public bool followSunDirection = false;

	[Export] public Vector2 moveDirection = new Vector2(0.1f, 0.1f); // Speed in X and Z directions
	[Export(PropertyHint.Range, "0.0,5.0,0.01")] public float moveSpeedMultiplier = 1.0f; // Overall speed control

	// Cloud texture assignment (for custom shader)
	[Export] public Texture2D cloudTexture;

	// Only the essential controls we actually need
	[Export] public DirectionalLight3D sunLight;
	[Export] public bool enableDirectionalShadows = false;

	private double lastUpdateTime = 0.0;
	private Vector2 currentMovementOffset = Vector2.Zero; // Track current offset
	ShaderMaterial _cloudShaderMaterial; // Changed from StandardMaterial3D

	public override void _Ready()
	{
		_cloudShaderMaterial = GetActiveMaterial(0) as ShaderMaterial;
		Callable.From(UpdateCloudShadows).CallDeferred();
	}

	public override void _Process(double delta)
	{
		// Update cloud movement if enabled
		if (isMoving)
		{
			// Calculate animated offset based on time
			double currentTime = Time.GetTicksMsec() / 1000.0; // Convert to seconds
			Vector2 effectiveSpeed = moveDirection.Normalized() * (moveSpeedMultiplier / 100.0f);

			currentMovementOffset = new Vector2(
				(float)(currentTime * effectiveSpeed.X),
				(float)(currentTime * effectiveSpeed.Y)
			);

			// Update global uniform for both shaders
			RenderingServer.GlobalShaderParameterSet("cloud_movement_offset", currentMovementOffset);
		}
		else
		{
			// Reset offset when not moving
			if (currentMovementOffset != Vector2.Zero)
			{
				currentMovementOffset = Vector2.Zero;
				RenderingServer.GlobalShaderParameterSet("cloud_movement_offset", currentMovementOffset);
			}
		}

		// Original position update logic (commented out as before)
		// lastUpdateTime += delta;
		// if (lastUpdateTime >= 0.1) // Update every 0.1 seconds to avoid spam
		// {
		// 	Vector3 currentPosition = GlobalTransform.Origin;
		// 	RenderingServer.GlobalShaderParameterSet("cloud_area_center", currentPosition);
		// 	lastUpdateTime = 0.0;
		// }
	}

	public void UpdateCloudShadows()
	{
		try
		{
			Texture2D textureToUse = GetCloudTexture();

			if (textureToUse == null)
			{
				Log.Error("No cloud texture found!");
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

			// Use the mesh size directly as cloud area size (NO SCALING HERE)
			float autoAreaSize = Mathf.Max(meshSize.X, meshSize.Y);

			// Update cloud shader material parameters
			if (_cloudShaderMaterial != null)
			{
				_cloudShaderMaterial.SetShaderParameter("cloud_texture", textureToUse);
				_cloudShaderMaterial.SetShaderParameter("cloud_texture_scale", cloudTextureScale);
				_cloudShaderMaterial.SetShaderParameter("cloud_alpha_scissor_threshold", _alphaScissor + _cloudAlphaOffset);
			}

			// Set global shader parameters for grass/foliage shaders
			RenderingServer.GlobalShaderParameterSet("cloud_shadow_texture", textureToUse);
			RenderingServer.GlobalShaderParameterSet("cloud_alpha_scissor", _alphaScissor);
			RenderingServer.GlobalShaderParameterSet("cloud_shadow_strength", _shadowStrength);
			RenderingServer.GlobalShaderParameterSet("cloud_texture_scale", cloudTextureScale);

			// Set initial movement offset (will be overridden by _Process if moving)
			RenderingServer.GlobalShaderParameterSet("cloud_movement_offset", currentMovementOffset);

			// Keep original area size - no scaling here
			RenderingServer.GlobalShaderParameterSet("cloud_area_center", meshWorldPosition);
			RenderingServer.GlobalShaderParameterSet("cloud_area_size", autoAreaSize);

			// Light direction support
			Vector3 lightDirection = Vector3.Down; // Default fallback
			if (enableDirectionalShadows && sunLight != null)
			{
				lightDirection = -sunLight.GlobalTransform.Basis.Z; // Light forward direction

				if (followSunDirection)
					moveDirection = new Vector2(lightDirection.X, -lightDirection.Z).Normalized();
			}

			RenderingServer.GlobalShaderParameterSet("sun_light_direction", lightDirection);
			RenderingServer.GlobalShaderParameterSet("enable_directional_shadows", enableDirectionalShadows);
			RenderingServer.GlobalShaderParameterSet("cloud_mesh_y", meshWorldPosition.Y);

			// Log.Debug("Cloud shadows updated!");
			// Log.Info($"Mesh World Position: {meshWorldPosition}");
			// Log.Debug($"Plane Size: {meshSize}");
			// Log.Debug($"Area Size: {autoAreaSize}");
			// Log.Debug($"Texture Scale: {cloudTextureScale}");
			// Log.Debug($"Is Moving: {isMoving}");
			// Log.Debug($"Move Speed: {moveDirection}");
			// Log.Debug($"Speed Multiplier: {moveSpeedMultiplier}");
			// Log.Debug($"Light Direction: {lightDirection}");
			// Log.Debug($"Directional Shadows: {enableDirectionalShadows}");
		}
		catch (System.Exception e)
		{
			Log.Error($"UpdateCloudShadows Failed: {e.Message}");
		}
	}

	private Texture2D GetCloudTexture()
	{
		// First try the explicitly assigned texture
		if (cloudTexture != null)
		{
			return cloudTexture;
		}

		// Fallback: Try to get from shader material
		if (_cloudShaderMaterial == null)
			_cloudShaderMaterial = GetActiveMaterial(0) as ShaderMaterial;

		if (_cloudShaderMaterial != null)
		{
			var shaderTexture = _cloudShaderMaterial.GetShaderParameter("cloud_texture");
			if (shaderTexture.VariantType == Variant.Type.Object)
			{
				return shaderTexture.AsGodotObject() as Texture2D;
			}
		}

		Log.Error("No texture found! Assign cloudTexture property or set cloud_texture shader parameter");
		return null;
	}
}