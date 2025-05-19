using Godot;

public partial class PlayerFallState : PlayerBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.PLAYER_FALL_STATE;


    [Export] public float fallSpeed = 10.0f;
    public override void Enter()
    {

        Log.Info($" {_characterNode.Name} - Fall State Entered");
    }

    public override void Exit()
    {

    }

    public override void ProcessUpdate(double delta)
    {

    }

    public override void PhysicsUpdate(double delta)
    {
        ManageFallState(delta);

    }

    private void ManageFallState(double delta)
    {
        if (_characterNode == null) return;

        if (!_characterNode.IsOnFloor())//FALLing - Apply Gravity
        {
            _characterNode.Velocity += _characterNode.GetGravity() * fallSpeed * (float)delta;
            // characterNode.Velocity = new Vector3((characterNode.Velocity.X / 2), (characterNode.Velocity.Y / 2), (characterNode.Velocity.Z / 2));

            _characterNode.MoveAndSlide();
        }

        if (_characterNode.IsOnFloor())//landed
        {
            TransitionToIdle(delta);

        }

    }


    private void PlayFallAnimation()
    {

    }

    private void TransitionToIdle(double delta)
    {

        if (_characterNode.IsOnFloor())//HAS LANDED
        {
            EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_IDLE_STATE, _characterNode);
        }

    }

    public override void _ExitTree()
    {

    }
}
