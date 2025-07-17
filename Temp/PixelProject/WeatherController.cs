using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

[Tool]
public partial class WeatherController : Node3D
{
	[Export] private Camera3D _mainCamera { get; set; }

	[ExportGroup("Weather Cycle")]
	[Export] private bool _isAutoWeatherCycle { get; set; } = true;
	[Export(PropertyHint.Range, "0.0,1.0,0.01")] public float MasterWeatherCycle { get; set; } = 0.65f;
	[Export] private Timer _cycleDurationTimer { get; set; }
	[Export] private float _sunriseDuration { get; set; } = 1.0f;
	[Export] private float _dayDuration { get; set; } = 1.0f;
	[Export] private float _sunsetDuration { get; set; } = 1.0f;
	[Export] private float _nightDuration { get; set; } = 1.0f;


	[ExportGroup("Shafts")]
	[Export] private ShaftSpawner _shaftChunksSpawner { get; set; }
	[Export] private float _shaftAlphaMax { get; set; } = 0.8f;
	[Export] private float _shaftAlphaMin { get; set; } = 0.0f;
	//If WeatherMasterValue is Above this value we disable autoAlpha on shafts and set it manually on this script
	[Export] private float _disableShaftAutoalphaThreshold { get; set; } = 0.8f;
	[ExportGroup("Clouds")]
	[Export] private CloudManager _cloudManager { get; set; }
	[Export] private float _cloudAlphaScissorMax { get; set; } = 0.66f; //day
	[Export] private float _cloudAlphaScissorMin { get; set; } = 0.4f; //nigh
	[ExportGroup("Light")]
	[Export] private DirectionalLight3D _directionalLight { get; set; }
	[Export] private float _lightEnergyMax { get; set; } = 1.1f; //mid-day 
	[Export] private float _lightEnergyMin { get; set; } = 0.9f; //night
	[ExportGroup("Environment")]
	[Export] private WorldEnvironment _worldEnvironment { get; set; }
	[Export] private Color _fogAlbedoDay { get; set; } = new Color(1.0f, 1.0f, 0.6f); //day
	[Export] private Color _fogAlbedoNight { get; set; } = new Color(0.34f, 0.41f, 0.43f); //night
	[Export] private float _fogDensityMax { get; set; } = 0.005f; //day
	[Export] private float _fogDensityMin { get; set; } = 0.01f; //night
	[Export] private float _glowIntensityMax { get; set; } = 1.3f; //night
	[Export] private float _glowIntensityMin { get; set; } = 1.0f; //day
	[Export] private float _glowStrengthMax { get; set; } = 1.3f; //night
	[Export] private float _glowStrengthMin { get; set; } = 0.8f; //day

	private Label _cloudAlphaLbl => field ?? GetNodeOrNull<Label>("%AlphaScissorLbl");
	private Label _directLightLbl => field ?? GetNodeOrNull<Label>("%SunLightLbl");
	private Label _fogDensityLbl => field ?? GetNodeOrNull<Label>("%FogDensity");
	private Label _glowIntensityLbl => field ?? GetNodeOrNull<Label>("%GlowIntensity");
	private Label _glowStrenghtLbl => field ?? GetNodeOrNull<Label>("%GlowStrenght");

	//Weather Cycle state variables
	public Dictionary<int, WeatherState> WeatherStates = new();



	private WeatherState _currentWeatherState;

	private float _currentCycleProgress = 0.0f;
	private float _currentCycleDuration = 0.0f;
	private bool _isProgressing = false;
	private float _previousMaterValue = -0.1f; // To track changes in MasterWeatherCycle	



	public override void _Ready()
	{
		if (_shaftChunksSpawner == null) _shaftChunksSpawner = GetNodeOrNull<ShaftSpawner>("%ShaftChunksSpawner");
		if (_cloudManager == null) _cloudManager = GetNodeOrNull<CloudManager>("%CloudManager");
		if (_directionalLight == null) _directionalLight = GetNodeOrNull<DirectionalLight3D>("%DayLight");
		if (_worldEnvironment == null) _worldEnvironment = GetNodeOrNull<WorldEnvironment>("%WorldEnvironment");
		if (_mainCamera == null) _mainCamera = GetNodeOrNull<Camera3D>("%MainCamera3D");


		if (IsAnyReferenceNull().IsNull)
		{
			Log.Error($"ShaftChunksSpawner null reference {IsAnyReferenceNull().NullNodeName}");
			return;
		}

		//Prepare Weather Cycle
		CreateWeatherStates();
		_cycleDurationTimer.Timeout += CycleDurationTimerTimeout;
		_currentWeatherState = WeatherStates[0]; // Start with Sunrise state

		if (_isAutoWeatherCycle)
			StartCycle(_currentWeatherState);

	}
	private void CreateWeatherStates()
	{
		// Create and add weather states to the dictionary
		WeatherStates.Add(0, new SunriseState(_sunriseDuration, this));
		WeatherStates.Add(1, new DayState(_dayDuration, this));
		WeatherStates.Add(2, new SunsetState(_sunsetDuration, this));
		WeatherStates.Add(3, new NightState(_nightDuration, this));
	}

	public override void _Process(double delta)
	{

		if (IsAnyReferenceNull().IsNull) return;

		if (!_isAutoWeatherCycle)
		{
			//Log.Info($"Manual Weather Cycle started update: {MasterWeatherCycle}");
			if (MasterWeatherCycle != _previousMaterValue)
			{
				_previousMaterValue = MasterWeatherCycle;
				UpdateWeatherParameters(MasterWeatherCycle);
			}
		}
		else if (_isAutoWeatherCycle && _isProgressing)
		{
			ManageWeatherState(_currentWeatherState, (float)delta);
		}
	}


	private void StartCycle(WeatherState state)
	{
		_cycleDurationTimer.WaitTime = state.StateDuration;
		_currentCycleProgress = 0;
		_currentCycleDuration = state.StateDuration;
		_isProgressing = true;

		_cycleDurationTimer.Start();
		state.EnterState();
	}


	private void StateTransition(WeatherState nextState)
	{
		if (_currentWeatherState != nextState)
		{

			_currentWeatherState.ExitState();
			_currentWeatherState = nextState;
			StartCycle(nextState);
		}
	}

	private void ManageWeatherState(WeatherState state, float delta)
	{
		//Check how time passed and add to this weather state progress
		_currentCycleProgress += (float)delta;

		//Calculate a normalized 0 to 1 weight based on progress and duration
		// float normalizedProgress = Mathf.Min(_currentCycleProgress / _currentCycleDuration, 1.0f);
		float progressNormalized = (_currentCycleDuration > 0f) ? Mathf.Min(_currentCycleProgress / _currentCycleDuration, 1.0f) : 1.0f;

		//Update the MasterWeatherCycle based on the current state and weight
		//Blend from state to end cycle time based on the normalizedProgress
		MasterWeatherCycle = Mathf.Lerp(state.StartTime, state.EndCycleTime, progressNormalized);
		UpdateWeatherParameters(MasterWeatherCycle);
	}


	private void CycleDurationTimerTimeout()
	{
		_cycleDurationTimer.Stop();
		int currentStateKey = WeatherStates.FirstOrDefault(x => x.Value == _currentWeatherState).Key;

		//Find the next state key
		int nextStateKey = currentStateKey + 1;

		if (nextStateKey > WeatherStates.Count - 1)
		{
			nextStateKey = 0;
		}

		WeatherState nextState = WeatherStates[nextStateKey];
		StateTransition(nextState);
	}


	private void UpdateWeatherParameters(float masterWeatherCycle)
	{
		//TODO: Implement weather states, so we can blend values based on active state and others as part of "Base State"


		//Set and update clouds
		float alphaScissor = LerpRemap(masterWeatherCycle, 0.0f, 1.0f, _cloudAlphaScissorMin, _cloudAlphaScissorMax);
		_cloudManager._alphaScissor = alphaScissor;
		_cloudManager.UpdateCloudShadows();

		//Set and update lights
		float lightEnergy = LerpRemap(masterWeatherCycle, 0.8f, 1.0f, _lightEnergyMin, _lightEnergyMax);
		_directionalLight.LightEnergy = lightEnergy; //Blend only at certain WeatherMasterValue...

		//Set and update envinronment
		Color fogAlbedo = _fogAlbedoNight.Lerp(_fogAlbedoDay, masterWeatherCycle); //Night ONLY
		float fogDensity = LerpRemap(masterWeatherCycle, 0.0f, 1.0f, _fogDensityMin, _fogDensityMax); //Night - DAY ONLY (no blend)
		float glowIntensity = LerpRemap(masterWeatherCycle, 0.0f, 1.0f, _glowIntensityMin, _glowIntensityMax); //Night - DAY ONLY (no blend)
		float glowStrength = LerpRemap(masterWeatherCycle, 0.0f, 1.0f, _glowStrengthMin, _glowStrengthMax); //Night - DAY ONLY (no blend)
		_worldEnvironment.Environment.VolumetricFogAlbedo = fogAlbedo; //Night - DAY ONLY (no blend)
		_worldEnvironment.Environment.VolumetricFogDensity = fogDensity; //Night - DAY ONLY (no blend)
		_worldEnvironment.Environment.GlowIntensity = glowIntensity; //Night - DAY ONLY (no blend)
		_worldEnvironment.Environment.GlowStrength = glowStrength; //Night - DAY ONLY (no blend)


		if (masterWeatherCycle >= _disableShaftAutoalphaThreshold) // If the weather is close to max, we want to update shafts
		{
			FadeOutShaftMaterialAlpha();
		}
		else
		{
			EnableShaftMaterialAutoAlpha();
		}

		_cloudAlphaLbl.Text = $"Cloud Alpha: {alphaScissor}";
		_directLightLbl.Text = $"Light Energy: {lightEnergy}";
		_fogDensityLbl.Text = $"Fog Density: {fogDensity}";
		_glowStrenghtLbl.Text = $"Glow Strength: {glowStrength}";
		_glowIntensityLbl.Text = $"Glow Intensity: {glowIntensity:F2}";
	}

	private void FadeOutShaftMaterialAlpha()
	{
		foreach (var node in _shaftChunksSpawner.GetChildren())
		{
			if (node is ShaftChunkMMController chunkController)
			{
				//get current alpha value from chunkController
				ShaderMaterial chunkMMMaterial = chunkController.Multimesh.Mesh.SurfaceGetMaterial(0) as ShaderMaterial;
				float currentAlpha = chunkController.GetMMShaftAlpha();       // chunkMMMaterial.GetShaderParameter("alpha").As<float>();

				//Set chunk to stop "AutoAlphaControls"
				chunkController._autoAlphaControls = false; //Take over the alpha controls

				//Calculate the new Alpha value as a Lerp from current alpha to zero (_shaftAlphaMin)
				float shaftAlpha = LerpRemap(MasterWeatherCycle, _disableShaftAutoalphaThreshold, 1.0f, currentAlpha, _shaftAlphaMin);

				//Set the new alpha value to the chunkController shader
				chunkController.SetMMShaftAlpha(shaftAlpha);
			}
		}
	}

	private void EnableShaftMaterialAutoAlpha()
	{
		Vector3 cameraPos = _mainCamera.GlobalTransform.Origin;
		foreach (var node in _shaftChunksSpawner.GetChildren())
		{
			if (node is ShaftChunkMMController chunkController)
			{
				if (chunkController._autoAlphaControls == true) continue;

				chunkController._autoAlphaControls = true; //Enable the auto alpha controls

				float currentCamDistance = cameraPos.DistanceTo(chunkController._collisionShape.GlobalTransform.Origin);
				chunkController.AutoUpdateInstanceAlpha(currentCamDistance); //Set the alpha to previous state before auto alpha controls were disabled
			}

		}
	}


	/// <summary>
	/// Returns a tuple with "isNull" and "nullNodeName" . Returns true if any reference is null, and the name of the null node
	/// </summary>
	private (bool IsNull, string NullNodeName) IsAnyReferenceNull()
	{
		var nullChecks = new (object nodeReference, string nodeName)[]
		{
			(_shaftChunksSpawner, nameof(_shaftChunksSpawner)),
			(_cloudManager, nameof(_cloudManager)),
			(_directionalLight, nameof(_directionalLight)),
			(_worldEnvironment, nameof(_worldEnvironment)),
			(_mainCamera, nameof(_mainCamera))
		};

		foreach (var (nodeReference, nodeName) in nullChecks)
		{
			if (nodeReference == null)
				return (true, $"Reference '{nodeName}' is null.");
		}

		return (false, "All reference nodes are valid.");
	}


	// TODO: REFACTOR THESE UTLIL FUNCTIONS TO A SEPARATE CLASS or extend MATHF classes

	/// <summary>
	/// Returns an output value by Linear interpolation between two input ranges.
	/// </summary>
	/// <param name="inputValue">The value to be monitored and checked against the input range (inputMin → inputMax).</param>
	/// <param name="inputMin">The minimum value of the input range to affect the output.</param>
	/// <param name="inputMin">The minimum value of the input range to affect the output.</param>
	/// <param name="outputMin">The min value of the output range when inputValue = inputMin.</param>
	/// <param name="outputMax">The max value of the output range when inputValue = inputMax.</param>
	public float LerpRemap(float inputValue, float inputMin, float inputMax, float outputMin, float outputMax)
	{
		var result = Mathf.InverseLerp(inputMin, inputMax, inputValue);
		return Mathf.Lerp(outputMin, outputMax, result);
	}

	/// <summary>
	/// Performs a Triangle distribution ( 0 → 1 → 0) with Custom peak (outputMin → outputMax → outputMin).
	/// Linear triangle interpolation over a given input range, where the output value increases from outputMin to outputMax as the input rises from 
	/// inputMin to peak. Then it decreases back to outputMin as the input moves from peak to inputMax.
	/// </summary>
	/// <param name="inputValue">The value to be monitored and checked against the input range.</param>
	/// <param name="inputMin">The minimum value of the input range to affect the output.</param>
	/// <param name="peak">The input value at which the output reaches its maximum (forming the peak of the triangle).</param>
	/// <param name="inputMin">The minimum value of the input range to affect the output.</param>
	/// <param name="outputMin">The min output value on "either sides" of the peak (used at the base of the triangle).</param>
	/// <param name="outputMax">The max output value when inputValue = peak (used at the Top of the triangle).</param>
	/// <returns>Value from the Triangle distribution: (outputMin → outputMax → outputMin) </returns>
	public float LerpTriangularRemap(float inputValue, float inputMin, float peak, float inputMax, float outputMin, float outputMax)
	{
		if (inputValue <= peak)
		{
			float result = Mathf.InverseLerp(inputMin, peak, inputValue);
			return Mathf.Lerp(outputMin, outputMax, result);
		}
		else
		{
			float result = Mathf.InverseLerp(peak, inputMax, inputValue);
			return Mathf.Lerp(outputMax, outputMin, result);
		}
	}


	/// <summary>
	/// Calculates a weight using a triangular distribution with a custom peak. 
	/// The output is 0 at the min/max bounds and linearly interpolates to 1 at the peak.
	/// </summary>
	/// <param name="value">The input value to check.</param>
	/// <param name="min">The lower bound of the range, where the weight is 0.</param>
	/// <param name="max">The upper bound of the range, where the weight is 0.</param>
	/// <param name="peak">The point between min and max where the weight is 1.</param>
	/// <returns>A weight from 0.0 to 1.0.</returns>
	public static float GetTriangularWeight(float value, float min, float max, float peak)
	{
		// Ensure the value is within the [min, max] range and parameters are valid.
		if (value < min || value > max || min >= max || peak < min || peak > max)
		{
			return 0f;
		}

		// Calculate weight on the ascending slope (from min to peak)
		if (value <= peak)
		{
			float denominator = peak - min;
			// Avoid division by zero if the range has no width
			if (Mathf.IsZeroApprox(denominator))
			{
				return 1f; // At the peak, so weight is 1
			}
			return (value - min) / denominator;
		}
		// Calculate weight on the descending slope (from peak to max)
		else
		{
			float denominator = max - peak;
			// Avoid division by zero if the range has no width
			if (Mathf.IsZeroApprox(denominator))
			{
				return 1f; // At the peak, so weight is 1
			}
			return (max - value) / denominator;
		}
	}

	/// <summary>
	/// Calculates a weight using a symmetrical triangular distribution.
	/// The output is 0 at the min/max bounds and 1 at the exact center.
	/// </summary>
	/// <param name="value">The input value to check.</param>
	/// <param name="min">The lower bound of the range.</param>
	/// <param name="max">The upper bound of the range.</param>
	/// <returns>A weight from 0.0 to 1.0.</returns>
	public static float GetTriangularWeight(float value, float min, float max)
	{
		if (min >= max) return 0f;

		float mid = min + (max - min) * 0.5f;
		float halfWidth = mid - min;

		// Calculate weight, where 1 is at the mid-point and 0 is at the edges
		float weight = 1.0f - Mathf.Abs((value - mid) / halfWidth);

		// Clamp the result to ensure it's always within the [0, 1] range
		return Mathf.Clamp(weight, 0f, 1f);
	}
}

////
#region WeatherRecordsAndSupportingClasses

public abstract record WeatherState()
{
	public abstract float StateDuration { get; set; }
	public abstract float StartTime { get; set; }
	public abstract float EndCycleTime { get; set; }
	protected virtual WeatherController weatherControllerNode { get; set; }


	public virtual void EnterState() { }// Make this abstract or virtual later.
	public virtual void ExitState() { }
}

public record DayState : WeatherState
{
	public override float StateDuration { get; set; } = 1.0f;
	public override float StartTime { get; set; } = 0.51f;
	public override float EndCycleTime { get; set; } = 1.0f;

	public DayState(float stateDuration, WeatherController weatherController)
	{
		StateDuration = stateDuration;
		weatherControllerNode = weatherController;
	}
	public override void EnterState()
	{
		// // Custom logic for entering the Day state
		// weatherControllerNode.IsPrintEnabled = true; // Enable printing for debugging
		// weatherControllerNode.PrintMessage = "Entering Day State";
	}
	public override void ExitState()
	{
		// // Custom logic for exiting the Day state
		// weatherControllerNode.IsPrintEnabled = false; // Disable printing for debugging
		// weatherControllerNode.PrintMessage = "";
	}
}
public record SunsetState : WeatherState
{
	public override float StateDuration { get; set; } = 1.0f;
	public override float StartTime { get; set; } = 1.0f;
	public override float EndCycleTime { get; set; } = 0.51f;

	public SunsetState(float stateDuration, WeatherController weatherController)
	{
		StateDuration = stateDuration;
		weatherControllerNode = weatherController;
	}
}

public record NightState : WeatherState
{
	public override float StateDuration { get; set; } = 1.0f;
	public override float StartTime { get; set; } = 0.5f;
	public override float EndCycleTime { get; set; } = 0.0f;

	public NightState(float stateDuration, WeatherController weatherController)
	{
		StateDuration = stateDuration;
		weatherControllerNode = weatherController;
	}
}

public record SunriseState : WeatherState
{
	public override float StateDuration { get; set; } = 1.0f;
	public override float StartTime { get; set; } = 0.0f;
	public override float EndCycleTime { get; set; } = 0.5f;

	public SunriseState(float stateDuration, WeatherController weatherController)
	{
		StateDuration = stateDuration;
		weatherControllerNode = weatherController;
	}
}

































#endregion WeatherRecordsAndSupportingClasses


