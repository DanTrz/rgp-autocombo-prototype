using Godot;

public partial class PlayerIdleState : PlayerBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.PLAYER_IDLE_STATE;

    public override void Enter()
    {


        if (_charMainNode.IsOnFloor())//landed
        {
            //_charMainNode.Velocity = Vector3.Zero; WORKING VELOCITY CODE
            _charMainNode.SetCharacterVelocity(_charMainNode, Vector3.Zero, "PlayerIdleState Enter");
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
                EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_FALL_STATE, _charMainNode);
            }

            if (_charMainNode.IsOnFloor())
            {
                //_charMainNode.Velocity = Vector3.Zero; //WORKING VELOCITY CODE
                _charMainNode.SetCharacterVelocity(_charMainNode, Vector3.Zero, "PlayerIdleState ManageIdleState");
            }

            Vector2 _inputDirection = Input.GetVector("left", "right", "up", "down");
            //Log.Info($"inputDirection: {_inputDirection.ToString()} isOnFloor: {_characterNode.IsOnFloor()}");

            if (_inputDirection != Vector2.Zero && _charMainNode.IsOnFloor())
            {
                EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_WALK_STATE, _charMainNode);
            }
            else if (Input.IsActionJustPressed("jump") && _charMainNode.IsOnFloor())
            {
                //Log.Info("Jump Pressed from idle state");
                TransitionToJump();
            }
        }

    }

    private void TransitionToJump()
    {
        if (_charMainNode != null)
        {
            EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_JUMP_STATE, _charMainNode);
            //direction = Vector2.Zero;
        }
    }

    private void PlayIdleAnimation()
    {

        if (_charMainNode.IsModel3D == true) //TODO: Refacot all of This. ADD IsModel3D CHECK AND ADD 3D ANIMATIONS CALLS.
        {

            _animPlayer.Play("AnimPack_1/StandardIdle");
        }
        else
        {

            //string cardinalDirection = GDNodeGlobals.Get("player_look_cardinal_direction").ToString();
            string cardinalDirection = GlobalEvents.Instance.GetLookDirection2DCardinal(_direction2D);
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

    }



    public override void _ExitTree()
    {

    }

}
