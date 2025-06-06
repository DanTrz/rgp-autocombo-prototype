using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
public partial class WeatherController : Node3D
{

	// [ExportToolButton("Start Cycle")]
	// public Callable StartWeatherCycleBtn => Callable.From(StartWeatherStateCycle);

	// [ExportToolButton("Reset Cycle")]
	// public Callable ResetWeatherCycleBtn => Callable.From(ResetWeatherCycle);

	[Export] private Node3D _lightDirectionNode { get; set; }
	[Export] private DirectionalLight3D _dayLight { get; set; }
	[Export] private DirectionalLight3D _nightLight { get; set; }
	[Export] private MeshInstance3D _cloudsMesh { get; set; }
	[Export] private Node3D _lightShafts { get; set; }
	[Export] private string _initialState { get; set; }
	[Export] private Timer _cycleDurationTimer { get; set; }

	[Export] private Label _cycleState { get; set; }
	[Export] private ProgressBar _cycleProgress { get; set; }

	private bool _isDay = true;
	public bool _isWetherCycleActive;

	public bool _isLerping = false;
	public float _lerpProgress = 0;
	public float _lerpDuration = 0;

	private ShaderMaterial _cloudsMaterial { get; set; }



	public BaseWeatherState CurrentWeatherState { get; set; }
	// public Dictionary<int, BaseWeatherState> WeatherStates = new()
	// {
	// 	{ 0, new SunriseState() },
	// 	{ 1, new DayState() },
	// 	{ 2, new SunsetState() },
	// 	{ 3, new NightState() }
	// };

	public Dictionary<int, BaseWeatherState> WeatherStates = new()
	{
		{ 0, new DayState() },
		{ 1, new NightState() },
	};

	//TODO:Steps to work on
	//1. Create a logic to calculate % of time spent in each cycle (SunRise, Day, SunSet, Night)
	//2. Future improvement, consider implementing a full state machine for the weather? ?//TODO 
	//3. Implement Weather States as Resources???? (Not sure makes sense.)

	public override void _Ready()
	{
		if (Engine.IsEditorHint()) return;
		_cycleDurationTimer.Timeout += CycleDurationTimerTimeout;

		CurrentWeatherState = WeatherStates[0];
		StartCycle(CurrentWeatherState);

		if (_cloudsMesh.Mesh.SurfaceGetMaterial(0) is ShaderMaterial cloudsMaterial)
		{
			_cloudsMaterial = cloudsMaterial;
		}
		// StartWeatherStateCycle();
	}

	#region  oldcode
	// public void StartWeatherStateCycle()
	// {
	// 	StartAllShafts();

	// 	// _isWetherCycleActive = true;
	// 	// _dayNightCycleTimer.Timeout += DayNightCycleTimerTimeout;
	// 	// _dayNightCycleTimer.Start();
	// }

	// private void StartAllShafts()
	// {
	// 	foreach (LightShaft shaft in _lightShafts.GetChildren())
	// 	{
	// 		shaft.StartExpandRadius = true;
	// 	}
	// }

	// public void ResetWeatherCycle()
	// {
	// 	_dayLight.Position = new Vector3(0, 0, 0);
	// 	_nightLight.Position = new Vector3(0, 0, 0);
	// 	_lightShafts.Position = new Vector3(0, 0, 0);
	// 	_cloudsMesh.Position = new Vector3(0, 0, 0);

	// 	_dayLight.Rotation = new Vector3(Mathf.DegToRad(-90), 0, 0);
	// 	_nightLight.Rotation = new Vector3(Mathf.DegToRad(-90), 0, 0);
	// 	_lightShafts.Rotation = new Vector3(0, 0, 0);
	// 	_cloudsMesh.Rotation = new Vector3(Mathf.DegToRad(-90), 0, 0);
	// }

	// private void DayNightCycleTimerTimeout()
	// {

	// }
	#endregion oldcode

	private void StartCycle(BaseWeatherState state)
	{
		_cycleDurationTimer.WaitTime = state.StateDuration;
		_lerpProgress = 0;
		_lerpDuration = state.StateDuration;
		_isLerping = true;
		_cycleDurationTimer.Start();
		state.EnterState();
	}

	private void StateTransition(BaseWeatherState nextState)
	{
		if (CurrentWeatherState != nextState)
		{

			CurrentWeatherState.ExitState();
			CurrentWeatherState = nextState;
			StartCycle(nextState);
		}
	}

	private void CycleDurationTimerTimeout()
	{
		_cycleDurationTimer.Stop();
		int currentStateKey = WeatherStates.FirstOrDefault(x => x.Value == CurrentWeatherState).Key;

		int nextStateKey = currentStateKey + 1;

		if (nextStateKey > WeatherStates.Count - 1)
		{
			nextStateKey = 0;
		}

		BaseWeatherState nextState = WeatherStates[nextStateKey]; ;
		StateTransition(nextState);
	}

	public override void _Process(double delta)
	{
		if (CurrentWeatherState == null) return;
		ManageState(CurrentWeatherState, (float)delta);

		//DEBUG CODE ONLY
		_cycleState.Text = CurrentWeatherState.ToString();
		_cycleProgress.Value = _cycleDurationTimer.TimeLeft / _cycleDurationTimer.WaitTime * 100;
	}

	private void ManageState(BaseWeatherState state, float delta)
	{
		if (_isLerping)
		{
			_lerpProgress += (float)delta;
			float learpWeight = Mathf.Min(_lerpProgress / _lerpDuration, 1.0f);
			//TODO: lerp the values// position.x = lerp(start_value, end_value, t)

			var rotationX = Mathf.DegToRad(Mathf.Lerp(state.DirXRotationStart, state.DirXRotationEnd, learpWeight));
			var rotationZ = Mathf.DegToRad(Mathf.Lerp(state.DirZRotationStart, state.DirZRotationEnd, learpWeight));
			_lightDirectionNode.Rotation = new Vector3(rotationX, 0, rotationZ);


			var shaftAlphaValue = Mathf.Lerp(state.ShaftsAlphaValueStart, state.ShaftsAlphaValueEnd, learpWeight);
			var shaftRadiusValue = Mathf.Lerp(state.ShaftsRadiusValueStart, state.ShaftsRadiusValueEnd, learpWeight);
			GlobalEvents.WeatherEvents?.ShaftValueChanged?.Invoke(shaftAlphaValue, shaftRadiusValue);
			Log.Debug($" Shaft Value: {shaftAlphaValue} // {shaftRadiusValue}");

			var cloudsValue = Mathf.Lerp(state.CloudsValueStart, state.CloudsValueEnd, learpWeight);
			_cloudsMaterial.SetShaderParameter("dissolveSlider", cloudsValue);

		}

		if (_lerpProgress >= _lerpDuration) _isLerping = false;

		//LERP BETERRN THE VALUES FOR EACH USING THE STATEDURATION AS REFERENCE. 
	}
}


public abstract class BaseWeatherState
{
	public abstract float StateDuration { get; set; }
	public abstract float DirXRotationStart { get; set; }
	public abstract float DirXRotationEnd { get; set; }
	public abstract float DirZRotationStart { get; set; }
	public abstract float DirZRotationEnd { get; set; }
	public abstract float ShaftsAlphaValueStart { get; set; }
	public abstract float ShaftsAlphaValueEnd { get; set; }

	public abstract float ShaftsRadiusValueStart { get; set; }
	public abstract float ShaftsRadiusValueEnd { get; set; }
	public abstract float CloudsValueStart { get; set; }
	public abstract float CloudsValueEnd { get; set; }


	public virtual void EnterState() { }// Make this abstract or virtual later.
	public virtual void ExitState() { }
}


public class DayState : BaseWeatherState
{
	public override float StateDuration { get; set; } = 10.0f;
	public override float DirXRotationStart { get; set; } = 30.0f;
	public override float DirXRotationEnd { get; set; } = 0.0f;
	public override float DirZRotationStart { get; set; } = 40.0f;
	public override float DirZRotationEnd { get; set; } = 0.0f;
	public override float ShaftsAlphaValueStart { get; set; } = 0.2f;
	public override float ShaftsAlphaValueEnd { get; set; } = 0.6f;
	public override float ShaftsRadiusValueStart { get; set; } = 1.5f;
	public override float ShaftsRadiusValueEnd { get; set; } = 5.0f;
	public override float CloudsValueStart { get; set; } = 0.25f;
	public override float CloudsValueEnd { get; set; } = 1.0f;
}

public class NightState : BaseWeatherState
{
	public override float StateDuration { get; set; } = 2.0f;
	public override float DirXRotationStart { get; set; } = 0.0f;
	public override float DirXRotationEnd { get; set; } = -30.0f;
	public override float DirZRotationStart { get; set; } = 0.0f;
	public override float DirZRotationEnd { get; set; } = -40.0f;
	public override float ShaftsAlphaValueStart { get; set; } = 0.2f;
	public override float ShaftsAlphaValueEnd { get; set; } = 0.0f;
	public override float ShaftsRadiusValueStart { get; set; } = 3.0f;
	public override float ShaftsRadiusValueEnd { get; set; } = 1.5f;
	public override float CloudsValueStart { get; set; } = 0.0f;
	public override float CloudsValueEnd { get; set; } = 0.0f;
}


// public class SunsetState : BaseWeatherState
// {
// 	public override float StateDuration { get; set; } = 2.0f;
// }

// public class SunriseState : BaseWeatherState
// {
// 	public override float StateDuration { get; set; } = 2.0f;
// }