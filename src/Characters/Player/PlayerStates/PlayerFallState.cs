using System;
using Godot;

public partial class PlayerFallState : PlayerBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.PLAYER_FALL_STATE;


    [Export] public float fallSpeed = 5.0f;
    public override void Enter()
    {


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
        if (_charMainNode == null) return;

        ApplyGravity(fallSpeed, delta);

        if (_charMainNode.IsOnFloor())//landed
        {
            TransitionToIdle(delta);
        }

    }

    private void ApplyGravity(float fallSpeed, double delta)
    {

        //NEW VELOCITY CODE
        var _newVelocity = _charMainNode.Velocity;
        _newVelocity += _charMainNode.GetGravity() * fallSpeed * (float)delta;
        _charMainNode.SetCharacterVelocity(_charMainNode, _newVelocity, "PlayerFallState ApplyGravity");
        //NEW VELOCITY CODE


        // _charMainNode.Velocity += _charMainNode.GetGravity() * fallSpeed * (float)delta; //ORIGINAL WORKING

        _charMainNode.MoveAndSlide();
    }

    private void PlayFallAnimation()
    {

    }

    private void TransitionToIdle(double delta)
    {

        if (_charMainNode.IsOnFloor())//HAS LANDED
        {
            EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_IDLE_STATE, _charMainNode);
        }

    }

    public override void _ExitTree()
    {

    }
}
