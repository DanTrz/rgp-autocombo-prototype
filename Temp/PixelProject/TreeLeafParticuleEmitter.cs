using System;
using Godot;

[Tool]
public partial class TreeLeafParticuleEmitter : Node3D
{
	[ExportToolButton("Stop Particles")]
	public Callable StopEmission => Callable.From(ResetParticles);

	[ExportToolButton("Start Particles")]
	public Callable StartEmission => Callable.From(StartEmittingParticles);

	[Export] GpuParticles3D _particleEmitter;
	[Export] MeshInstance3D _treeMesh;

	[Export] int _totalParticulesCount = 700;
	[Export] Color _mainParticuleColor = Colors.White; // Main particule color
	[Export] Color _internalMeshColorAdjust = Colors.White; // Adjust for the mesh color(internal mesh color)
	[Export] GradientTexture1D _colorShadingRamp; // Color shading and darken ramp for particle colors
	[Export] Vector3 _colorShadingDirection = new Vector3(0, 1, 0); // Direction for darkest color (default: Y-up)
	[Export(PropertyHint.Range, "0,1,0.01")] float _colorSpread = 0.5f; // How spread out colors are (0.0 = tight, 1.0 = full sphere)
	[Export(PropertyHint.Range, "0,1,0.01")] float _colorNoise = 0.01f; // Random noise for color variation
	[Export(PropertyHint.Range, "0,2,0.1")] float _particuleSphereRadius = 1.0f; // Radius of the emission sphere (fixed)
	[Export] Timer _restartParticulesTime;

	public override void _Ready()
	{
		_restartParticulesTime.Timeout += StartEmittingParticles;
		StartEmittingParticles();
		StartTimer();
	}

	private void StartTimer()
	{
		_restartParticulesTime.Start(_restartParticulesTime.WaitTime);

	}

	private void ResetParticles()
	{
		_particleEmitter.Lifetime = 0.001f;
		_particleEmitter.OneShot = false;
		_particleEmitter.Emitting = false;
		_particleEmitter.Amount = _totalParticulesCount;
	}

	private void StartEmittingParticles()
	{
		ResetParticles();

		_particleEmitter.Lifetime = 10000000.0f;
		_particleEmitter.OneShot = true;
		_particleEmitter.Emitting = true;

		ApplyColorToMesh();
	}

	private void ApplyColorToMesh()
	{

		if (_treeMesh.Mesh.SurfaceGetMaterial(0) is ShaderMaterial meshShaderMaterial)
		{
			meshShaderMaterial.SetShaderParameter("albedo_color", _mainParticuleColor * _internalMeshColorAdjust);
		}

		if (_particleEmitter.DrawPass1.SurfaceGetMaterial(0) is ShaderMaterial particuleShaderMaterial)
		{
			particuleShaderMaterial.SetShaderParameter("albedo_color", _mainParticuleColor);
		}
		// _particleEmitter.DrawPass1.Material.SetShaderParameter("albedo_color", _particuleColor);

		if (_particleEmitter.ProcessMaterial is ShaderMaterial processShaderMaterial)
		{

			if (_colorShadingRamp != null)
				processShaderMaterial.SetShaderParameter("color_ramp_texture", _colorShadingRamp);

			processShaderMaterial.SetShaderParameter("target_color_direction", _colorShadingDirection);
			processShaderMaterial.SetShaderParameter("color_spread", _colorSpread);
			processShaderMaterial.SetShaderParameter("emission_sphere_radius", _particuleSphereRadius);
			processShaderMaterial.SetShaderParameter("color_noise", _colorNoise);
		}

	}

}
