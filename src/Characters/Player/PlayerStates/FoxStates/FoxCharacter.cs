using System;
using Godot;

public partial class FoxCharacter : Player
{
	public override string CharacterName { get; set; } = "Fox3DModel";
	public override int Health { get; set; } = 100;
	public override int MaxHealth { get; set; } = 100;
	public override int BaseDamage { get; set; } = 5;
	public override bool IsModel3D { get; set; } = true;

	public override void _Ready()
	{
		base._Ready();
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
	}
}
