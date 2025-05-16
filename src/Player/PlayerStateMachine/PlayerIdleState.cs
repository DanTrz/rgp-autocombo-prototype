using Godot;

public partial class PlayerIdleState : PlayerState, IState
{

    public override void Enter()
    {
        Log.Info("CS Idle State Entered");

        if (characterNode.IsOnFloor())//landed
        {
            characterNode.Velocity = Vector3.Zero;
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

        if (characterNode != null)
        {
            // if (!characterNode.IsOnFloor())
            // {
            // 	characterNode.Velocity += characterNode.GetGravity() * (float)delta;
            // 	characterNode.MoveAndSlide();
            // 	//GD.PrintT("Applying gravity - falling");
            // }

            if (characterNode.IsOnFloor())
            {
                characterNode.Velocity = Vector3.Zero;
            }

            Vector2 direction = Input.GetVector("left", "right", "up", "down");
            if (direction != Vector2.Zero && characterNode.IsOnFloor())
            {
                EmitStateTransition(this, Const.PLAYER_WALK_STATE, characterNode);
            }
            else if (Input.IsActionJustPressed("jump") && characterNode.IsOnFloor())
            {
                Log.Info("Jump Pressed from idle state");
                TransitionToJump();
            }
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

    private void PlayIdleAnimation()
    {

        //string cardinalDirection = GDNodeGlobals.Get("player_look_cardinal_direction").ToString();
        string cardinalDirection = GlobalEvents.Instance.GetLookDirectionCardinal(direction);


        switch (cardinalDirection)
        {
            case "east":
                GDPlayerAnimPlayerWorld.Play("idle_east");
                break;
            case "south_east":
                GDPlayerAnimPlayerWorld.Play("idle_south_east");
                break;
            case "south":
                GDPlayerAnimPlayerWorld.Play("idle_south");
                break;
            case "south_west":
                GDPlayerAnimPlayerWorld.Play("idle_south_west");
                break;
            case "west":
                GDPlayerAnimPlayerWorld.Play("idle_west");
                break;
            case "north_west":
                GDPlayerAnimPlayerWorld.Play("idle_north_west");
                break;
            case "north":
                GDPlayerAnimPlayerWorld.Play("idle_north");
                break;
            case "north_east":
                GDPlayerAnimPlayerWorld.Play("idle_north_east");
                break;
        }

    }



    public override void _ExitTree()
    {

    }

}
