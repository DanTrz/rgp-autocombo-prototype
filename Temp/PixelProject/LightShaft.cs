using System;
using Godot;

[Tool]
public partial class LightShaft : Node3D
{
	[Export] float _growthFactor = 50.0f;
	[Export] float _maxHeight = 45.0f;
	[Export] float _maxRadius = 10.0f;

	[Export] float _posYAdjustFactor = 2.0f;

	bool _isShaftActive = false;
	bool _isGrowthComplete = false;

	[Export] Area3D _detectionArea { get; set; }
	[Export] MeshInstance3D _lightShaftSkin { get; set; }

	// [ExportToolButton("Start Shaft")]
	// public Callable StartShaftBtn => Callable.From(StartShaftGrowth);

	[ExportToolButton("Start/Stop Radius")]
	public Callable ExpandRadiusBtn => Callable.From(() => StartExpandRadius = !StartExpandRadius);

	[ExportToolButton("Reset Radius size")]
	public Callable ResetRadiusBtn => Callable.From(ResetRadius);

	// [ExportToolButton("Reset Shaft")]
	// public Callable ResetShaftBtn => Callable.From(ResetShaftGrowth);

	[Export] bool _runOnReady = false;

	private Transform3D _skinOriginalTrans;
	private Transform3D area2DOriginalTrans;

	public bool StartExpandRadius = false;

	public override void _Ready()
	{
		if (Engine.IsEditorHint()) return;

		// _detectionArea.BodyEntered += OnBodyEntered;
		// if (_runOnReady) StartShaftGrowth();
	}

	// private void OnBodyEntered(Node3D body)
	// {
	// 	Log.Debug($"Body: {this.Name} entered by body: {body.Name}");
	// 	_startExpandRadius = true;
	// }

	// public void StartShaftGrowth()
	// {
	// 	if (_detectionArea == null || _lightShaftSkin == null) return;
	// 	_skinOriginalTrans = _lightShaftSkin.GlobalTransform;
	// 	area2DOriginalTrans = _detectionArea.GlobalTransform;
	// 	_isShaftActive = true;
	// }

	// public void ResetShaftGrowth()
	// {
	// 	if (_detectionArea == null || _lightShaftSkin == null || !_isShaftActive) return;
	// 	_lightShaftSkin.GlobalTransform = _skinOriginalTrans;
	// 	_detectionArea.GlobalTransform = area2DOriginalTrans;

	// 	if (_lightShaftSkin.Mesh is CylinderMesh cylinderMesh)
	// 	{
	// 		cylinderMesh.Height = 1.0f;
	// 	}
	// 	_startExpandRadius = false;
	// 	_isShaftActive = false;

	// }

	public override void _Process(double delta)
	{
		if (StartExpandRadius && !_isGrowthComplete)
		{
			ExpandRadius((float)delta);
		}




		// if (!_isShaftActive || _detectionArea == null || _lightShaftSkin == null) return;
		// if (_lightShaftSkin.Mesh is CylinderMesh cylinderMesh)
		// {
		// 	if (cylinderMesh.Height <= _maxHeight)
		// 	{
		// 		cylinderMesh.Height += (float)delta * _growthFactor;
		// 		_lightShaftSkin.Position -= new Vector3(0, (_growthFactor * (float)delta) / _posYAdjustFactor, 0);
		// 		_detectionArea.Position -= new Vector3(0, (_growthFactor * (float)delta) / _posYAdjustFactor, 0);
		// 	}
		// }

		// if (_startExpandRadius && !_isGrowthComplete)
		// {
		// 	ExpandRadius((float)delta);
		// }

	}


	public void ExpandRadius(float delta)
	{
		if (_lightShaftSkin.Mesh is CylinderMesh cylinderMesh)
		{
			if (cylinderMesh.TopRadius >= _maxRadius)
			{
				_isGrowthComplete = false;
				return;
			}
			cylinderMesh.BottomRadius += 1.0f * delta;
			cylinderMesh.TopRadius += 1.0f * delta;
		}
	}

	private void ResetRadius()
	{
		if (_lightShaftSkin.Mesh is CylinderMesh cylinderMesh)
		{
			cylinderMesh.BottomRadius = 1.0f;
			cylinderMesh.TopRadius = 1.5f;
		}
	}


	public override void _ExitTree()
	{
		// if (_detectionArea.HasConnections(Area3D.SignalName.BodyEntered))
		// 	_detectionArea.BodyEntered -= OnBodyEntered;
	}
}
