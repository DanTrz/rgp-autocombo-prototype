using System;
using System.Threading.Tasks;
using Godot;
[Tool]
public partial class WeatherController : Node3D
{

	[ExportToolButton("Start Cycle")]
	public Callable StartWeatherCycleBtn => Callable.From(StartWeatherCycle);

	[ExportToolButton("Reset Cycle")]
	public Callable ResetWeatherCycleBtn => Callable.From(ResetWeatherCycle);

	[Export] private Node3D _lightDirectionNode { get; set; }
	[Export] private DirectionalLight3D _dayLight { get; set; }
	[Export] private DirectionalLight3D _nightLight { get; set; }
	[Export] private MeshInstance3D _cloudsMesh { get; set; }
	[Export] private Node3D _lightShafts { get; set; }
	[Export] private Timer _dayNightCycleTimer { get; set; }

	private bool _isDay = true;
	public bool _isWetherCycleActive;


	//TODO:Steps to work on
	//

	public override async void _Ready()
	{
		if (Engine.IsEditorHint()) return;
		await StartWeatherCycle();
	}

	public async Task StartWeatherCycle()
	{
		await ToSignal(GetTree().CreateTimer(1.0f), SceneTreeTimer.SignalName.Timeout);
		StartAllShafts();

		// _isWetherCycleActive = true;
		// _dayNightCycleTimer.Timeout += DayNightCycleTimerTimeout;
		// _dayNightCycleTimer.Start();
	}

	private void StartAllShafts()
	{
		foreach (LightShaft shaft in _lightShafts.GetChildren())
		{
			shaft.StartExpandRadius = true;
		}
	}

	public void ResetWeatherCycle()
	{
		_dayLight.Position = new Vector3(0, 0, 0);
		_nightLight.Position = new Vector3(0, 0, 0);
		_lightShafts.Position = new Vector3(0, 0, 0);
		_cloudsMesh.Position = new Vector3(0, 0, 0);

		_dayLight.Rotation = new Vector3(Mathf.DegToRad(-90), 0, 0);
		_nightLight.Rotation = new Vector3(Mathf.DegToRad(-90), 0, 0);
		_lightShafts.Rotation = new Vector3(0, 0, 0);
		_cloudsMesh.Rotation = new Vector3(Mathf.DegToRad(-90), 0, 0);
	}

	private void DayNightCycleTimerTimeout()
	{
		if (!_isWetherCycleActive) return;
		if (_isDay)
		{
			StartNightCycle();
			_isDay = false;
		}
		else
		{
			StartDayCycle();
			_isDay = true;
		}
	}

	private void StartNightCycle() { }
	private void StartDayCycle() { }



	public override void _Process(double delta)
	{
	}
}
