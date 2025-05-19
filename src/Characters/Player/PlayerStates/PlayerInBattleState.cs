public partial class PlayerInBattleState : PlayerBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.IN_BATTLE_STATE;


    public override void Enter()
    {
        Log.Info("CS InBattle State Entered");

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