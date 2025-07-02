using System;
using Godot;

public partial class DebugPanel : Control
{

	// [Export] private Label _fpsCountLabel;
	private Label _fpsCountLabel => field ?? GetNode<Label>("%FpsCountLbl");

	// Called every frame. 'delta' is the elapsed time since the previous frame.

	public override void _Process(double delta)
	{
		if (_fpsCountLabel != null)
		{
			_fpsCountLabel.Text = Engine.GetFramesPerSecond().ToString();
		}
	}
}
