using Godot;

public partial class PlayerWalkState : PlayerState, IState
{

    public override void Enter()
    {
        Log.Info("CS Walk State Entered");
    }

    public override void Exit()
    {

    }

    public override void ProcessUpdate(double delta)
    {

    }

    public override void PhysicsUpdate(double delta)
    {
        ManageWalkState(delta);

    }

    private void ManageWalkState(double delta)
    {

        if (characterNode != null)
        {
            velocity = characterNode.Velocity;

            if (Input.IsActionJustPressed("jump") && characterNode.IsOnFloor())
            {
                Log.Info("Jump Pressed from walk state");
                TransitionToJump();
            }

            if (Input.IsActionPressed("left") || Input.IsActionPressed("right") || Input.IsActionPressed("up") || Input.IsActionPressed("down") && characterNode.IsOnFloor())
            {
                ManageWalkState();

            }
            else if (characterNode.IsOnFloor())
            {
                isCharacterMoving = false;
                TransitionToIdle();
            }
        }

    }

    private void ManageWalkState()
    {
        direction.X = Input.GetActionStrength("right") - Input.GetActionStrength("left");
        direction.Y = Input.GetActionStrength("down") - Input.GetActionStrength("up");
        direction = direction.Normalized();
        Vector3 direction3d = (characterNode.Transform.Basis * new Vector3(direction.X, 0, direction.Y)).Normalized();

        // Globals.current_player_direction = direction

        if (direction3d != Vector3.Zero)
        {
            velocity.X = direction3d.X * characterSpeed;
            velocity.Z = direction3d.Z * characterSpeed;

            characterNode.Velocity = velocity;

            //characterNode.MoveAndSlide(characterNode.Velocity * (float)delta);
            characterNode.MoveAndSlide();

            isCharacterMoving = true;

            // GDNodeGlobals.Call("set_player_look_cardinal_direction", direction, delta);
            // GDNodeGlobals.Set("current_player_direction", direction);

            PlayWalkAnimation();
        }




    }

    private void PlayWalkAnimation()
    {

        //string cardinalDirection = GDNodeGlobals.Get("player_look_cardinal_direction").ToString();
        string cardinalDirection = GlobalEvents.Instance.GetLookDirectionCardinal(direction);
        //GD.PrintT("Cardingal Direction: " + cardinalDirection);

        switch (cardinalDirection)
        {
            case "east":
                GDPlayerAnimPlayerWorld.Play("run_east");
                break;
            case "south_east":
                GDPlayerAnimPlayerWorld.Play("run_south_east");
                break;
            case "south":
                GDPlayerAnimPlayerWorld.Play("run_south");
                break;
            case "south_west":
                GDPlayerAnimPlayerWorld.Play("run_south_west");
                break;
            case "west":
                GDPlayerAnimPlayerWorld.Play("run_west");
                break;
            case "north_west":
                GDPlayerAnimPlayerWorld.Play("run_north_west");
                break;
            case "north":
                GDPlayerAnimPlayerWorld.Play("run_north");
                break;
            case "north_east":
                GDPlayerAnimPlayerWorld.Play("run_north_east");
                break;
        }
    }

    private void TransitionToIdle()
    {

        if (!isCharacterMoving || characterNode != null)
        {
            EmitStateTransition(this, Const.PLAYER_IDLE_STATE, characterNode);
            direction = Vector2.Zero;
        }

    }


    private void TransitionToJump()
    {
        if (characterNode != null)
        {
            EmitStateTransition(this, Const.PLAYER_JUMP_STATE, characterNode);
            //direction = Vector2.Zero;
        }
    }

    public override void _ExitTree()
    {

    }

}
