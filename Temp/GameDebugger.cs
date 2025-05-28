using System;
using Godot;

public partial class GameDebugger : Node
{
	public Label VelocityLabel => field ?? GetNode<Label>("%VelocityLabel");
	public Label CurrentStateLabel => field ?? GetNode<Label>("%CurrentStateLabel");
	[Export] BaseCharacter character;
	public static GameDebugger Instance { get; private set; }

	public override void _Ready()
	{
		Instance = this;
	}

	public override void _Process(double delta)
	{
		Instance.VelocityLabel.Text = character?.Velocity.ToString();
		Instance.CurrentStateLabel.Text = character?.StateMachine.CurrentState.StateName.ToString();
	}

}
