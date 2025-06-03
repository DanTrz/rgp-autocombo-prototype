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

	[Export] int _totalParticulesCount = 300;
	[Export] Color _particuleColor = Colors.White;

	[Export] Color _internalMeshColorAdjust = Colors.White;

	[Export] Timer _restartParticulesTime;


	public override void _Ready()
	{
		_restartParticulesTime.Timeout += StartEmittingParticles;
		StartEmittingParticles();
		StartTimer();
	}

	private void StartTimer()
	{
		_restartParticulesTime.Start(100.0f);

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

		_particleEmitter.Lifetime = 100000.0f;
		_particleEmitter.OneShot = true;
		_particleEmitter.Emitting = true;

		ApplyColorToMesh();
	}

	private void ApplyColorToMesh()
	{

		if (_treeMesh.Mesh.SurfaceGetMaterial(0) is ShaderMaterial meshShaderMaterial)
		{
			meshShaderMaterial.SetShaderParameter("albedo_color", _particuleColor * _internalMeshColorAdjust);
		}

		if (_particleEmitter.DrawPass1.SurfaceGetMaterial(0) is ShaderMaterial particuleShaderMaterial)
		{
			particuleShaderMaterial.SetShaderParameter("albedo_color", _particuleColor);
		}
		// _particleEmitter.DrawPass1.Material.SetShaderParameter("albedo_color", _particuleColor);

	}

}
