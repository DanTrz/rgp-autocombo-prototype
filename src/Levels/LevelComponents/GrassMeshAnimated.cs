using System;
using Godot;

public partial class GrassMeshAnimated : Node3D
{
	[Export] MeshInstance3D meshInstance3D;

	public override void _Ready()
	{
		//ApplyShaderOffset();
	}

	private void ApplyShaderOffset()
	{
		if (meshInstance3D.Mesh.SurfaceGetMaterial(0) is ShaderMaterial shaderMaterial)
		{
			shaderMaterial.SetShaderParameter("wind_time_offset", (float)GD.Randf());
			Log.Info("wind_time_offset: " + shaderMaterial.GetShaderParameter("wind_time_offset"));
		}
	}
}