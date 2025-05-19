public abstract partial class PlayerBaseState : CharacterBaseState, ICharacterState
{

    //protected AnimationPlayer AnimPlayerWorld { get; set; }
    //protected AnimationPlayer AnimPlayerWorld => field ?? GetOwner().GetNode<AnimationPlayer>(GetOwner().GetPath() + "/AnimationPlayer"); //TODO: Fix this hard coded string

    public override void _Ready()
    {
        base._Ready();
    }


}
