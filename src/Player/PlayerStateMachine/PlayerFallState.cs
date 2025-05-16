using Godot;

public partial class PlayerFallState : PlayerState, IState
{
    [Export] public float fallSpeed = 10.0f;
    public override void Enter()
    {

        Log.Info("CS Fall State Entered");
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
        if (characterNode == null) return;

        if (!characterNode.IsOnFloor())//FALLing - Apply Gravity
        {
            characterNode.Velocity += characterNode.GetGravity() * fallSpeed * (float)delta;
            // characterNode.Velocity = new Vector3((characterNode.Velocity.X / 2), (characterNode.Velocity.Y / 2), (characterNode.Velocity.Z / 2));

            characterNode.MoveAndSlide();
        }

        if (characterNode.IsOnFloor())//landed
        {
            TransitionToIdle(delta);

        }

    }

    private void PlayFallAnimation()
    {

    }

    private void TransitionToIdle(double delta)
    {

        if (characterNode.IsOnFloor())//HAS LANDED
        {
            EmitStateTransition(this, Const.PLAYER_IDLE_STATE, characterNode);
        }

    }

    public override void _ExitTree()
    {

    }
}
