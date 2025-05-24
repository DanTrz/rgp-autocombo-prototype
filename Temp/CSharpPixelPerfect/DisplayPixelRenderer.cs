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
		Vector2 screenSize = new Vector2(GetWindow().Size.X, GetWindow().Size.Y);
		// viewport size minus padding
		Vector2 gameSize = new Vector2(_viewPort.Size.X - 2, _viewPort.Size.Y - 2);

		Vector2 displayScale = screenSize / gameSize;
		// maintain aspect ratio
		float displayScaleMin = Math.Min(displayScale.X, displayScale.Y);
		_mainRendereSprite.Scale = new Vector2(displayScaleMin, displayScaleMin);

		// scale and center control node
		Size = (_mainRendereSprite.Scale * gameSize).Round();
		Position = ((screenSize - Size) / 2).Round();
		// smooth!
		if (_hasPixelMovement)
		{
			var cam = _viewPort.GetCamera3D() as CameraPixelSnap;
			var pixelError = cam.TextelError * _mainRendereSprite.Scale;
			_mainRendereSprite.Position = -_mainRendereSprite.Scale + pixelError;
			var isIntegerScale = displayScale == displayScale.Floor();
			if (isIntegerScale && !_hasSubPixelMovementAtIntegerScale)
				_mainRendereSprite.Position = _mainRendereSprite.Position.Round();
		}
	}
}
