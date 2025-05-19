public partial class Player : BaseCharacter
{
    public override string CharacterName { get; set; } = "Player";
    public override int Health { get; set; } = 100;
    public override int MaxHealth { get; set; } = 100;
    public override int BaseDamage { get; set; } = 5;


    public override void _Ready()
    {
        base._Ready();
    }

}
