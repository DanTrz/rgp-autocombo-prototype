using System;
using System.Threading.Tasks;
using Godot;

public partial class EnemyFallState : EnemyBaseState, ICharacterState
{

    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.ENEMY_FALL_STATE;
    [Export] public float fallSpeed = 10.0f;
    public async override Task Enter()
    {
        Log.Info($" {_charMainNode.Name} - Fall State Entered");
    }

    public async override Task Exit()
    {
    }

    public async override Task ProcessUpdate(double delta)
    {
    }

    public async override Task PhysicsUpdate(double delta)
    {
        ManageFallState(delta);
    }

    private void ManageFallState(double delta)
    {
        if (_charMainNode == null) return;

        if (!_charMainNode.IsOnFloor())//FALLing - Apply Gravity
        {
            _charMainNode.Velocity += _charMainNode.GetGravity() * fallSpeed * (float)delta;
            // characterNode.Velocity = new Vector3((characterNode.Velocity.X / 2), (characterNode.Velocity.Y / 2), (characterNode.Velocity.Z / 2));

            _charMainNode.MoveAndSlide();
        }

        if (_charMainNode.IsOnFloor())//landed
        {
            TransitionToIdle(delta);
        }
    }
    private void PlayFallAnimation()
    {
    }

    private void TransitionToIdle(double delta)
    {
        if (_charMainNode.IsOnFloor())//HAS LANDED
        {
            EmitStateTransition(this, Const.CharactersEnums.States.ENEMY_IDLE_STATE, _charMainNode);
        }
    }

    public override void _ExitTree()
    {
    }
}
