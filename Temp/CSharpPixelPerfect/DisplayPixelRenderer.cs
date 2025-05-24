using System;
using Godot;

public partial class DisplayPixelRenderer : Control
{
	[Export] SubViewport _viewPort;
	[Export] bool _hasPixelMovement = true;
	[Export] bool _hasSubPixelMovementAtIntegerScale = true;
	[Export] Sprite2D _mainRendereSprite;

	public override void _Process(double delta)
	{
		Vector2 screenSize = GetWindow().Size;
		// viewport size minus padding
		Vector2 gameSize = new Vector2(_viewPort.Size.X - 2, _viewPort.Size.Y - 2);
		Vector2 displayScale = screenSize / gameSize;
		// maintain aspect ratio
		float displayScaleMin = Math.Min(displayScale.X, displayScale.Y);
		_mainRendereSprite.Scale = new Vector2(displayScaleMin, displayScaleMin);

		// scale and center control node
		this.Size = (_mainRendereSprite.Scale * gameSize).Round();
		this.Position = ((screenSize - Size) / 2).Round();
		// smooth!
		if (_hasPixelMovement)
		{
			var cam = _viewPort.GetCamera3D() as CameraPixelSnap;

			if (cam != null)
			{
				Vector2 pixelError = cam.TexelError * _mainRendereSprite.Scale;
				_mainRendereSprite.Position = -_mainRendereSprite.Scale + pixelError;

				bool isIntegerScale = displayScale == displayScale.Floor();
				if (isIntegerScale && !_hasSubPixelMovementAtIntegerScale)
					_mainRendereSprite.Position = _mainRendereSprite.Position.Round();
			}
		}
	}
}
