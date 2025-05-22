using Godot;

public partial class PlayerWalkState : PlayerBaseState, ICharacterState
{

    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.PLAYER_WALK_STATE;
    [Export] public float WalkSpeed = 10;
    [Export] public float WalkRotationSpeed = 10;
    [Export] public float WalkAcceleration = 10;


    public override void Enter()
    {
        _charSpeed = WalkSpeed;
        _charRotationSpeed = WalkRotationSpeed;
        _charAcceleration = WalkAcceleration;
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
        // Log.Info($" {_characterNode.Name} - Walk velocity: {_velocity}, direction: {_direction2D}");

    }

    private void ManageWalkState(double delta)
    {

        if (_charMainNode != null)
        {
            _velocity = _charMainNode.Velocity;

            if (Input.IsActionJustPressed("jump") && _charMainNode.IsOnFloor())
            {
                // Log.Info("Jump Pressed from walk state");
                TransitionToJump();
            }

            if (Input.IsActionPressed("left") || Input.IsActionPressed("right") || Input.IsActionPressed("up") || Input.IsActionPressed("down") && _charMainNode.IsOnFloor())
            {
                MakeCharacterWalk(delta);
            }
            else if (_charMainNode.IsOnFloor())
            {
                _isCharMoving = false;
                TransitionToIdle();
            }
        }
    }

    private void MakeCharacterWalk(double delta)
    {
        _direction2D.X = Input.GetActionStrength("right") - Input.GetActionStrength("left");
        _direction2D.Y = Input.GetActionStrength("down") - Input.GetActionStrength("up");
        //direction2D = _direction2D.Normalized();
        _direction3D = (_charMainNode.Transform.Basis * new Vector3(_direction2D.X, 0, _direction2D.Y)).Normalized();

        if (_direction3D != Vector3.Zero) //TODO: Refacot all of This. ADD IsModel3D CHECK AND ADD 3D ANIMATIONS CALLS.
        {
            //IF THE CAMERA ROTATES, CHANGE THE DIRECTIONS 
            // Camera3D _camera = GetViewport().GetCamera3D();
            // var forwardDirection = _camera.GlobalBasis.Z;
            // var rightDirection = _camera.GlobalBasis.X;

            //VELOCITY CALC 01 => Utilize a Function with Acceleration and "smooth" start/stop and feeling of slide/acceleration
            //_charMainNode.Velocity = _charMainNode.Velocity.MoveToward(_direction3D * _charSpeed, _charAcceleration * (float)delta);

            //VELOCITY CALC 02 => Precise start and stop, responsive and more "2d" feeling of old topdown game
            _velocity.X = _direction3D.X * _charSpeed;
            _velocity.Z = _direction3D.Z * _charSpeed;
            _charMainNode.Velocity = _velocity;

            _charMainNode.MoveAndSlide();
            _isCharMoving = true;

            float lookAngle = Vector3.Back.SignedAngleTo(_direction3D, Vector3.Up);
            //Node3D skin = _characterNode.GetNode<Node3D>("%Skin");
            _charSkin?.GlobalRotation = new Vector3(0, Godot.Mathf.LerpAngle(_charSkin.Rotation.Y, lookAngle, 50f * (float)delta), 0);


            // _charSkin?.SetGlobalTransform(new Transform3D(
            //     Basis.FromEuler(
            //         new Vector3(0, Godot.Mathf.LerpAngle(_charSkin.Transform.Basis.GetEuler().Y,
            //         lookAngle, 50f * (float)delta), 0)),
            //    _charSkin.GlobalTransform.Origin
            // ));
            PlayWalkAnimation();

        }

    }


    private void PlayWalkAnimation()
    {
        Log.Debug($"{_charMainNode.Name} _charSpeed:{_charSpeed}");

        if (_charMainNode.IsModel3D == true) //TODO: Refacot all of This. ADD IsModel3D CHECK AND ADD 3D ANIMATIONS CALLS.
        {
            _animPlayer.Play("AnimPack_1/RunForward");
            // float lookAngle2 = GlobalEvents.Instance.DirectionVector2DToAngle(_direction2D);



            // _characterNode.LookAt(_characterNode.GlobalTransform.Origin + _direction3D, Vector3.Up);
            // float rotationAngle = GlobalEvents.Instance.DirectionVector2DToAngle(_direction2D);
            // _characterNode.RotationDegrees = new Vector3(0, rotationAngle - 90, 0);
            // Log.Info($"rotationAngle: {rotationAngle}");

        }
        else
        {
            string cardinalDirection = GlobalEvents.Instance.GetLookDirection2DCardinal(_direction2D);

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




    }

    private void TransitionToIdle()
    {
        if (!_isCharMoving || _charMainNode != null)
        {
            EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_IDLE_STATE, _charMainNode);//Const.CharacterStates.States.PLAYER_IDLE_STATE, _characterNode);
            _direction2D = Vector2.Zero;
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

    public override void _ExitTree()
    {

    }

}
