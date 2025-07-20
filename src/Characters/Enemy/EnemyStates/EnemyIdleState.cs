using System.Threading.Tasks;
using Godot;

public partial class EnemyIdleState : EnemyBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.ENEMY_IDLE_STATE;

    public async override Task Enter()
    {
        Log.Info($" {_charMainNode.Name} - Idle State Entered");

        if (_charMainNode.IsOnFloor())//landed
        {
            _charMainNode.Velocity = Vector3.Zero;
        }
    }

    public async override Task Exit()
    {

    }

    public async override Task ProcessUpdate(double delta)
    {

    }

    public async override Task PhysicsUpdate(double delta)
    {
        ManageIdleState(delta);
    }

    private void ManageIdleState(double delta)
    {

        PlayIdleAnimation();

        if (_charMainNode != null)
        {
            //Move to Fall State if not on Floor
            if (!_charMainNode.IsOnFloor())
            {
                EmitStateTransition(this, Const.CharactersEnums.States.ENEMY_FALL_STATE, _charMainNode);
            }

            if (_charMainNode.IsOnFloor())
            {
                _charMainNode.Velocity = Vector3.Zero;
            }
        }

    }


    private void PlayIdleAnimation()
    {
    }

    public override void _ExitTree()
    {

    }

}