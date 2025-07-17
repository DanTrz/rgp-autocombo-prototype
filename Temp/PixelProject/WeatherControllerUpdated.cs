using System;
using System.Linq;
using Godot;

[Tool]
public partial class WeatherControllerUpdated : Node3D
{

	[Export] private bool _isWeatherCycleActive { get; set; } = false;
	[Export(PropertyHint.Range, "0.0,1.0,0.05")]
	public float WeatherMasterValue
	{
		get
		{
			return field;
		}
		set
		{
			field = value;
			if ((Engine.IsEditorHint() && !IsInsideTree())) return;
			// Callable.From(UpdateWeatherCycle).CallDeferred();
			UpdateWeatherCycle();
		}
	} = 0.65f;

	private bool _isReady = false;

	[ExportGroup("Shafts")]
	// [Export] private ShaftChunksSpawner _shaftChunksSpawner { get; set; }
	// private ShaftChunksSpawner _shaftChunksSpawner => field ?? GetNodeOrNull<ShaftChunksSpawner>("%ShaftChunksSpawner");
	private ShaftChunksSpawner _shaftChunksSpawner { get; set; }

	// private ShaftChunksSpawner _shaftChunksSpawner => field ?? GlobalUtil.GetAllChildNodesByType<ShaftChunksSpawner>(this).FirstOrDefault();

	[Export] private float _shaftAlphaMax { get; set; } = 0.8f;
	[Export] private float _shaftAlphaMin { get; set; } = 0.0f;

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




	public override void _Ready()
	{
		if (_shaftChunksSpawner == null) _shaftChunksSpawner = GetNodeOrNull<ShaftChunksSpawner>("%ShaftChunksSpawner");
		if (_cloudManager == null) _cloudManager = GetNodeOrNull<CloudManager>("%CloudManager");
		if (_directionalLight == null) _directionalLight = GetNodeOrNull<DirectionalLight3D>("%DayLight");
		if (_worldEnvironment == null) _worldEnvironment = GetNodeOrNull<WorldEnvironment>("%WorldEnvironment");

		if (_shaftChunksSpawner == null || _cloudManager == null || _directionalLight == null || _worldEnvironment == null)
		{
			Log.Error("ShaftChunksSpawner reference nodes are not assigned or found in the scene.");
			return;
		}

		_isReady = true;
		Callable.From(UpdateWeatherCycle).CallDeferred();
	}


	public override void _Process(double delta)
	{

	}

	private void UpdateWeatherCycle()
	{
		if (!_isReady || !IsInsideTree()) return;

		//TODO: Implement weather states, so we can blend values based on active state and others as part of "Base State"

		if (_isWeatherCycleActive)
		{
			//Set and update clouds
			float alphaScissor = LerpRemap(0.0f, 1.0f, _cloudAlphaScissorMin, _cloudAlphaScissorMax, WeatherMasterValue);
			_cloudManager._alphaScissor = alphaScissor;
			_cloudManager.UpdateCloudShadows();

			//Set and update lights
			float lightEnergy = LerpRemap(0.8f, 1.0f, _lightEnergyMin, _lightEnergyMax, WeatherMasterValue);
			_directionalLight.LightEnergy = lightEnergy; //Blend only at certain WeatherMasterValue...

			//Set and update envinronment
			Color fogAlbedo = _fogAlbedoNight.Lerp(_fogAlbedoDay, WeatherMasterValue); //Night ONLY
			float fogDensity = LerpRemap(0.0f, 1.0f, _fogDensityMin, _fogDensityMax, WeatherMasterValue); //Night - DAY ONLY (no blend)
			float glowIntensity = LerpRemap(0.0f, 1.0f, _glowIntensityMin, _glowIntensityMax, WeatherMasterValue); //Night - DAY ONLY (no blend)
			float glowStrength = LerpRemap(0.0f, 1.0f, _glowStrengthMin, _glowStrengthMax, WeatherMasterValue); //Night - DAY ONLY (no blend)
			_worldEnvironment.Environment.VolumetricFogAlbedo = fogAlbedo; //Night - DAY ONLY (no blend)
			_worldEnvironment.Environment.VolumetricFogDensity = fogDensity; //Night - DAY ONLY (no blend)
			_worldEnvironment.Environment.GlowIntensity = glowIntensity; //Night - DAY ONLY (no blend)
			_worldEnvironment.Environment.GlowStrength = glowStrength; //Night - DAY ONLY (no blend)


			//Shafts I need  custom Triangular distribution 
			// When WeatherMasterValue is from 0.8 to 1.0, we want to start reducing the shafts alpha from whatever it is to _shaftAlphaMin
			//When the WeatherMasterValue is <0.8, we want to start increasing the shafts alpha from _shaftAlphaMin to _shaftAlphaMax>

			// float shaftAlpha = LerpTriangularRemap(WeatherMasterValue, 0f, 0.8f, 1f, _shaftAlphaMin, _shaftAlphaMax);
			// UpdateMMShaftMaterials(_shaftAlphaMin);

			if (WeatherMasterValue >= 0.9f) // If the weather is close to max, we want to update shafts
			{
				FadeOutShaftMaterialAlpha();
			}
			// else if (WeatherMasterValue <= 0.1f) // If the weather is close to min, we want to update shafts
			// {
			// 	UpdateMMShaftMaterials(_shaftAlphaMax);
			// }

			// Log.Info($"""
			// 				Weather Updated:
			// 				Alpha Scissor: {alphaScissor}
			// 				Fog Density: {fogDensity}
			// 				Fog Albedo: {fogAlbedo}
			// 				Light Energy: {lightEnergy}
			// 				Glow Intensity: {glowIntensity}
			// 				Glow Strength: {glowStrength}
			// 				""");
			_cloudAlphaLbl.Text = $"Cloud Alpha: {alphaScissor}";
			_directLightLbl.Text = $"Light Energy: {lightEnergy}";
			_fogDensityLbl.Text = $"Fog Density: {fogDensity}";
			_glowStrenghtLbl.Text = $"Glow Strength: {glowStrength}";
			_glowIntensityLbl.Text = $"Glow Intensity: {glowIntensity:F2}";

		}
	}

	private void FadeOutShaftMaterialAlpha()
	{
		foreach (ShaftChunkMMController chunkController in _shaftChunksSpawner.GetChildren())
		{

			if (chunkController is not ShaftChunkMMController) continue;

			chunkController._autoAlphaControls = false; //Take over the alpha controls
														//Check what is the Alpha at the moment. 
			ShaderMaterial chunkMMMaterial = chunkController.Multimesh.Mesh.SurfaceGetMaterial(0) as ShaderMaterial;

			if (chunkMMMaterial != null)
			{
				float currentAlpha = chunkMMMaterial.GetShaderParameter("alpha").As<float>();
				//Calculate the new alpha based on the WeatherMasterValue
				float shaftAlpha = LerpRemap(0.0f, 1.0f, currentAlpha, _shaftAlphaMin, WeatherMasterValue);

				// float shaftAlpha = LerpRemap(0.0f, 1.0f, _shaftAlphaMin, _shaftAlphaMax, WeatherMasterValue);
				chunkMMMaterial.SetShaderParameter("alpha", shaftAlpha);
			}
		}

	}


	// TODO: REFACTOR THESE UTLIL FUNCTIONS TO A SEPARATE CLASS or extend MATHF classes

	/// <summary>
	/// Returns an output value by Linear interpolation between two input ranges.
	/// </summary>
	/// <param name="iMin">The minimum value of the input range.</param>
	/// <param name="iMax">The maximum value of the input range.</param>
	/// <param name="oMin">The minimum value of the output range.</param>
	/// <param name="oMax">The maximum value of the output range.</param>
	/// <param name="valueWeight">The value used as weight to be interpolated.</param>
	public float LerpRemap(float iMin, float iMax, float oMin, float oMax, float valueWeight)
	{
		var result = Mathf.InverseLerp(iMin, iMax, valueWeight);
		return Mathf.Lerp(oMin, oMax, result);
	}

	/// <summary>
	/// Performs a Triangle distribution ( 0 → 1 → 0) with Custom peak (outputMin → outputMax → outputMin) 
	/// Linear triangle interpolation over a given input range, where the output value increases from outputMin to outputMax as the input rises from 
	/// inputMin to peak. Then it decreases back to outputMin as the input moves from peak to inputMax.
	/// </summary>
	/// <param name="input">The input value to be remapped.</param>
	/// <param name="inputMin">The minimum value of the input range.</param>
	/// <param name="peak">The input value at which the output reaches its maximum (forming the peak of the triangle).</param>
	/// <param name="inputMax">The maximum value of the input range.</param>
	/// <param name="outputMin">The minimum output value (used at the base of the triangle).</param>
	/// <param name="outputMax">The maximum output value (used at the peak of the triangle).</param>
	/// <returns>Value from the Triangle distribution: (outputMin → outputMax → outputMin) </returns>
	public float LerpTriangularRemap(float input, float inputMin, float peak, float inputMax, float outputMin, float outputMax)
	{
		if (input <= peak)
		{
			float result = Mathf.InverseLerp(inputMin, peak, input);
			return Mathf.Lerp(outputMin, outputMax, result);
		}
		else
		{
			float result = Mathf.InverseLerp(peak, inputMax, input);
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


