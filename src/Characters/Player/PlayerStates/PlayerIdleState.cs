using Godot;

public partial class PlayerIdleState : PlayerBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.PLAYER_IDLE_STATE;

    public override void Enter()
    {
        Log.Info($" {_characterNode.Name} - Idle State Entered");

        if (_characterNode.IsOnFloor())//landed
        {
            _characterNode.Velocity = Vector3.Zero;
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

        if (_characterNode != null)
        {
            //Move to Fall State if not on Floor
            if (!_characterNode.IsOnFloor())
            {
                EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_FALL_STATE, _characterNode);
            }

            if (_characterNode.IsOnFloor())
            {
                _characterNode.Velocity = Vector3.Zero;
            }

            Vector2 _inputDirection = Input.GetVector("left", "right", "up", "down");
            //Log.Info($"inputDirection: {_inputDirection.ToString()} isOnFloor: {_characterNode.IsOnFloor()}");

            if (_inputDirection != Vector2.Zero && _characterNode.IsOnFloor())
            {
                EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_WALK_STATE, _characterNode);
            }
            else if (Input.IsActionJustPressed("jump") && _characterNode.IsOnFloor())
            {
                Log.Info("Jump Pressed from idle state");
                TransitionToJump();
            }
        }

    }

    private void TransitionToJump()
    {
        if (_characterNode != null)
        {
            EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_JUMP_STATE, _characterNode);
            //direction = Vector2.Zero;
        }
    }

    private void PlayIdleAnimation()
    {

        //string cardinalDirection = GDNodeGlobals.Get("player_look_cardinal_direction").ToString();
        string cardinalDirection = GlobalEvents.Instance.GetLookDirectionCardinal(_direction);


        switch (cardinalDirection)
        {
            case "east":
                _animPlayer.Play("idle_east");
                break;
            case "south_east":
                _animPlayer.Play("idle_south_east");
                break;
            case "south":
                _animPlayer.Play("idle_south");
                break;
            case "south_west":
                _animPlayer.Play("idle_south_west");
                break;
            case "west":
                _animPlayer.Play("idle_west");
                break;
            case "north_west":
                _animPlayer.Play("idle_north_west");
                break;
            case "north":
                _animPlayer.Play("idle_north");
                break;
            case "north_east":
                _animPlayer.Play("idle_north_east");
                break;
        }

    }



    public override void _ExitTree()
    {

    }

}
