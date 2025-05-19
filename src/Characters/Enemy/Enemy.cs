public partial class Enemy : BaseCharacter
{
    public override string CharacterName { get; set; } = "Enemy";
    public override int Health //{ get => field; set => field = value; } = 20; //TODO: Check if we should push this logic to the BaseCharacter
    {
        get
        {
            return field;
        }
        set
        {
            field = value;
        }

    } = 20;

    public override int MaxHealth { get; set; } = 20;
    public override int BaseDamage { get; set; } = 5;

}

