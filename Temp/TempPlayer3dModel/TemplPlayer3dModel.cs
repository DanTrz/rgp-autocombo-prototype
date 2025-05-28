using System;
using Godot;

public partial class TemplPlayer3dModel : BaseCharacter
{
	public override string CharacterName { get; set; } = "Player3DModel";
	public override int Health { get; set; } = 100;
	public override int MaxHealth { get; set; } = 100;
	public override int BaseDamage { get; set; } = 5;
	public override bool IsModel3D { get; set; } = true;



	public override void _Ready()
	{
		base._Ready();
	}






}
