using Godot;

public partial class PlayerWalkState : PlayerBaseState, ICharacterState
{

    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.PLAYER_WALK_STATE;
    [Export] public float WalkSpeed = 20f;

    public override void Enter()
    {
        _characterSpeed = WalkSpeed;

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
        Log.Info($" {_characterNode.Name} - Walk velocity: {_velocity}, direction: {_direction}");

    }

    private void ManageWalkState(double delta)
    {

        if (_characterNode != null)
        {
            _velocity = _characterNode.Velocity;

            if (Input.IsActionJustPressed("jump") && _characterNode.IsOnFloor())
            {
                Log.Info("Jump Pressed from walk state");
                TransitionToJump();
            }

            if (Input.IsActionPressed("left") || Input.IsActionPressed("right") || Input.IsActionPressed("up") || Input.IsActionPressed("down") && _characterNode.IsOnFloor())
            {
                ManageWalkState();

            }
            else if (_characterNode.IsOnFloor())
            {
                _isCharacterMoving = false;
                TransitionToIdle();
            }
        }

    }

    private void ManageWalkState()
    {
        _direction.X = Input.GetActionStrength("right") - Input.GetActionStrength("left");
        _direction.Y = Input.GetActionStrength("down") - Input.GetActionStrength("up");
        _direction = _direction.Normalized();
        Vector3 direction3d = (_characterNode.Transform.Basis * new Vector3(_direction.X, 0, _direction.Y)).Normalized();

        if (direction3d != Vector3.Zero)
        {
            _velocity.X = direction3d.X * _characterSpeed;
            _velocity.Z = direction3d.Z * _characterSpeed;

            _characterNode.Velocity = _velocity;
            _characterNode.MoveAndSlide();
            _isCharacterMoving = true;

            PlayWalkAnimation();
        }
    }

    private void PlayWalkAnimation()
    {

        string cardinalDirection = GlobalEvents.Instance.GetLookDirectionCardinal(_direction);

        switch (cardinalDirection)
        {
            case "east":
                _animPlayer.Play("run_east");
                break;
            case "south_east":
                _animPlayer.Play("run_south_east");
                break;
            case "south":
                _animPlayer.Play("run_south");
                break;
            case "south_west":
                _animPlayer.Play("run_south_west");
                break;
            case "west":
                _animPlayer.Play("run_west");
                break;
            case "north_west":
                _animPlayer.Play("run_north_west");
                break;
            case "north":
                _animPlayer.Play("run_north");
                break;
            case "north_east":
                _animPlayer.Play("run_north_east");
                break;
        }
    }

    private void TransitionToIdle()
    {
        if (!_isCharacterMoving || _characterNode != null)
        {
            EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_IDLE_STATE, _characterNode);//Const.CharacterStates.States.PLAYER_IDLE_STATE, _characterNode);
            _direction = Vector2.Zero;
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

    public override void _ExitTree()
    {

    }

}
