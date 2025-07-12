using System;
using Godot;

/// <summary>
/// A control that renders a SubViewport in a pixel perfect manner.
/// </summary>
public partial class DisplayPixelRenderer : Control
{
	[Export] SubViewport _mainSubViewport;
	// The main sprite to render the screen
	[Export] Sprite2D _mainRendereSprite;
	// Whether to apply the basic smooth "stabilization" logic
	[Export] bool _pixelMovement = true;
	// Whether to use sub-pixel movement at integer scale for the smooth "stabilization" logic
	[Export] bool _subPixelMovementAtIntegerScale = true;
	//rendered game resolution is always scaled up in whole pixels (Not always helpful or needed)
	[Export] bool _forceIntegerScale = false;
	//Controls to implemente a second rendered (for weather or Godrays, Rain etc)
	[Export] bool _userDualRender = true;
	[Export] SubViewport _secondSubViewport;
	[Export] Sprite2D _secondRenderSprite;

	int _screenPaddingBase = 2;

	public override void _Process(double delta)
	{
		if (_mainSubViewport == null || _mainRendereSprite == null) return;
		AutoScaleRenderer(_mainSubViewport, _mainRendereSprite, _screenPaddingBase);

		if (!_userDualRender) return;
		if (_secondRenderSprite == null || _secondSubViewport == null) return;
		AutoScaleRenderer(_secondSubViewport, _secondRenderSprite, 0);

	}

	private void AutoScaleRenderer(SubViewport subViewport, Sprite2D renderSprite, int screenPadding)
	{
		// Get the size of the screen
		Vector2 screenSize = GetWindow().Size;
		// Get the size of the viewport, minus any padding
		Vector2 mainGameSize = new Vector2(subViewport.Size.X - screenPadding, subViewport.Size.Y - screenPadding);
		// Calculate the display scale
		Vector2 displayScale = screenSize / mainGameSize;

		// Maintain aspect ratio by using the minimum display scale
		//float displayScaleMin = Math.Min(displayScale.X, displayScale.Y); //Original
		float mainScaleRaw = Math.Min(displayScale.X, displayScale.Y);
		float mainDisplayScaleMin = _forceIntegerScale ? Mathf.Floor(mainScaleRaw) : mainScaleRaw;

		// Set the scale of the main sprite
		renderSprite.Scale = new Vector2(mainDisplayScaleMin, mainDisplayScaleMin);
		// _secondRenderSprite?.Scale = _userDualRender ? new Vector2(mainDisplayScaleMin, mainDisplayScaleMin) : Vector2.One;
		// Scale and center the control node
		this.Size = (renderSprite.Scale * mainGameSize).Round();
		this.Position = ((screenSize - Size) / 2).Round();
		// Check if we want to apply pixel Smooth and sub-pixel movement smooth and apply it
		if (_pixelMovement)
		{
			// Get the camera
			var cam = subViewport.GetCamera3D() as CameraPixelSnap;
			if (cam != null)
			{
				// Get the texel error
				Vector2 pixelError = cam.TexelError * renderSprite.Scale;
				// Set the position of the main sprite to the negated scale plus the pixel error
				renderSprite.Position = -renderSprite.Scale + pixelError;
				// _secondRenderSprite?.Position = _userDualRender ? _mainRendereSprite.Position : Vector2.One;
				// Check if the display scale is an integer
				bool isIntegerScale = displayScale == displayScale.Floor();
				// If it is and we don't want sub-pixel movement at integer scale, round the position
				if (isIntegerScale && !_subPixelMovementAtIntegerScale)
				{
					renderSprite.Position = renderSprite.Position.Round();
					// _secondRenderSprite?.Position = _userDualRender ? _mainRendereSprite.Position : Vector2.One;
				}

			}
		}
	}



}

