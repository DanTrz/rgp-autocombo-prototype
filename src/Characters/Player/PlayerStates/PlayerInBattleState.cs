using System.Threading.Tasks;

public partial class PlayerInBattleState : PlayerBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.IN_BATTLE_STATE;


    public async override Task Enter()
    {
        Log.Info("CS InBattle State Entered");

    }

    public async override Task Exit()
    {

    }

    public async override Task ProcessUpdate(double delta)
    {

    }

    public async override Task PhysicsUpdate(double delta)
    {

    }

    public override void _ExitTree()
    {

    }



}