using Godot;

public partial class EnemyIdleState : EnemyBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.ENEMY_IDLE_STATE;

    public override void Enter()
    {
        Log.Info($" {_charMainNode.Name} - Idle State Entered");

        if (_charMainNode.IsOnFloor())//landed
        {
            _charMainNode.Velocity = Vector3.Zero;
        }
    }

    public override void Exit()
    {

    }

    public override void ProcessUpdate(double delta)
    {

    }

    public override void PhysicsUpdate(double delta)
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