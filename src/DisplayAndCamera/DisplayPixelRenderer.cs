using System;
using Godot;

/// <summary>
/// A control that renders a SubViewport in a pixel perfect manner.
/// </summary>
public partial class DisplayPixelRenderer : Control
{
	[Export] SubViewport _viewport;
	// Whether to apply the basic smooth "stabilization" logic
	[Export] bool _pixelMovement = true;
	// Whether to use sub-pixel movement at integer scale for the smooth "stabilization" logic
	[Export] bool _subPixelMovementAtIntegerScale = true;
	//rendered game resolution is always scaled up in whole pixels (Not always helpful or needed)
	[Export] bool _forceIntegerScale = false;
	// The main sprite to render the screen
	[Export] Sprite2D _mainRendereSprite;

	[Export] int _screenPadding = 2;

	public override void _Process(double delta)
	{
		// Get the size of the screen
		Vector2 screenSize = GetWindow().Size;
		// Get the size of the viewport, minus any padding
		Vector2 gameSize = new Vector2(_viewport.Size.X - _screenPadding, _viewport.Size.Y - _screenPadding);
		// Calculate the display scale
		Vector2 displayScale = screenSize / gameSize;

		// Maintain aspect ratio by using the minimum display scale
		//float displayScaleMin = Math.Min(displayScale.X, displayScale.Y); //Original
		float scaleRaw = Math.Min(displayScale.X, displayScale.Y);
		float displayScaleMin = _forceIntegerScale ? Mathf.Floor(scaleRaw) : scaleRaw;

		// Set the scale of the main sprite
		_mainRendereSprite.Scale = new Vector2(displayScaleMin, displayScaleMin);
		// Scale and center the control node
		this.Size = (_mainRendereSprite.Scale * gameSize).Round();
		this.Position = ((screenSize - Size) / 2).Round();
		// Check if we want to apply pixel Smooth and sub-pixel movement smooth and apply it
		if (_pixelMovement)
		{
			// Get the camera
			var cam = _viewport.GetCamera3D() as CameraPixelSnap;
			if (cam != null)
			{
				// Get the texel error
				Vector2 pixelError = cam.TexelError * _mainRendereSprite.Scale;
				// Set the position of the main sprite to the negated scale plus the pixel error
				_mainRendereSprite.Position = -_mainRendereSprite.Scale + pixelError;
				// Check if the display scale is an integer
				bool isIntegerScale = displayScale == displayScale.Floor();
				// If it is and we don't want sub-pixel movement at integer scale, round the position
				if (isIntegerScale && !_subPixelMovementAtIntegerScale)
					_mainRendereSprite.Position = _mainRendereSprite.Position.Round();
			}
		}
	}



}

