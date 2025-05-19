using Godot;

public partial class PlayerJumpState : PlayerBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.PLAYER_JUMP_STATE;

    [Export] public float JumpVelocity = 6.0f;

    // public Vector2 direction = Vector2.Zero;
    // public float currentVelocity = 0;
    // public bool isCharacterMoving = false;

    [Export] private float jumpForwardSlowRate = 0.7f;

    public override void Enter()
    {
        Log.Info("CS Jump State Entered");
    }

    public override void Exit()
    {

    }

    public override void ProcessUpdate(double delta)
    {

    }

    public override void PhysicsUpdate(double delta)
    {
        ManageJumpState(delta);

    }

    private void ManageJumpState(double delta)
    {
        if (_characterNode == null) return;

        if (_characterNode.IsOnFloor())//JUMP
        {
            //characterNode.Velocity += characterNode.GetGravity() * JumpVelocity * (float)delta;
            //velocity.Y = JumpVelocity;

            // velocity.X = Mathf.MoveToward(characterNode.Velocity.X, (characterNode.Velocity.X) / 2, characterSpeed);
            // velocity.Z = Mathf.MoveToward(characterNode.Velocity.X, (characterNode.Velocity.Z) / 2, characterSpeed);
            // velocity.Y = JumpVelocity;
            // characterNode.Velocity = velocity;

            _characterNode.Velocity = new Vector3(
                _characterNode.Velocity.X * jumpForwardSlowRate,
                JumpVelocity,
                _characterNode.Velocity.Z * jumpForwardSlowRate);

            _characterNode.MoveAndSlide();
        }

        if (!_characterNode.IsOnFloor())//FALL
        {
            TransitionToFall(delta);
        }

    }

    private void PlayJumpAnimation()
    {

        //string cardinalDirection = GDNodeGlobals.Get("player_look_cardinal_direction").ToString();
        // string cardinalDirection = GlobalEvents.Instance.GetLookDirectionCardinal(direction);
        // GD.PrintT("Cardingal Direction: " + cardinalDirection);

        // switch (cardinalDirection)
        // {
        // 	// case "east":
        // 	// 	GDPlayerAnimPlayerWorld.Play("run_east");
        // 	// 	break;
        // 	// case "south_east":
        // 	// 	GDPlayerAnimPlayerWorld.Play("run_south_east");
        // 	// 	break;
        // 	// case "south":
        // 	// 	GDPlayerAnimPlayerWorld.Play("run_south");
        // 	// 	break;
        // 	// case "south_west":
        // 	// 	GDPlayerAnimPlayerWorld.Play("run_south_west");
        // 	// 	break;
        // 	// case "west":
        // 	// 	GDPlayerAnimPlayerWorld.Play("run_west");
        // 	// 	break;
        // 	// case "north_west":
        // 	// 	GDPlayerAnimPlayerWorld.Play("run_north_west");
        // 	// 	break;
        // 	// case "north":
        // 	// 	GDPlayerAnimPlayerWorld.Play("run_north");
        // 	// 	break;
        // 	// case "north_east":
        // 	// 	GDPlayerAnimPlayerWorld.Play("run_north_east");
        // 	// 	break;
        // }
    }

    private void TransitionToFall(double delta)
    {

        EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_FALL_STATE, _characterNode);//Const.CharacterStates.States.PLAYER_FALL_STATE, _characterNode);

    }

    public override void _ExitTree()
    {

    }
}
