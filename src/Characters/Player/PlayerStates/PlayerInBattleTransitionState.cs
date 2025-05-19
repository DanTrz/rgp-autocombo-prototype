public partial class PlayerInBattleTransitionState : PlayerBaseState, ICharacterState
{

    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.IN_PREBATTLE_STATE;

    public override void Enter()
    {
        Log.Info("CS BatteTransition State Entered");

    }

    public override void Exit()
    {

    }

    public override void ProcessUpdate(double delta)
    {

    }

    public override void PhysicsUpdate(double delta)
    {

    }

    public override void _ExitTree()
    {

    }


}
