using System.Threading.Tasks;
using Godot;

public partial class FoxIdleState : PlayerBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.FOX_IDLE_STATE;

    [Export(PropertyHint.Range, "0.0,5.0,0.5")] private float _switchAnimTime = 1.5f; // Time to switch animations
    private float _idleElapsedTime = 0.0f;
    private bool _isSitted = false;


    public async override Task Enter()
    {
        _isSitted = false;
        _idleElapsedTime = 0.0f;

        if (_charMainNode.IsOnFloor())//landed
        {
            //_charMainNode.Velocity = Vector3.Zero; WORKING VELOCITY CODE
            _charMainNode.SetCharacterVelocity(_charMainNode, Vector3.Zero, "PlayerIdleState Enter");
        }
    }

    public async override Task Exit()
    {

    }

    public async override Task ProcessUpdate(double delta)
    {

    }

    public async override Task PhysicsUpdate(double delta)
    {
        await ManageIdleState(delta);
    }

    private async Task ManageIdleState(double delta)
    {
        _idleElapsedTime += (float)delta;

        if (_idleElapsedTime <= _switchAnimTime && !_isSitted)
        {
            PlayIdleAnimation("fox_idle");
        }
        else
        {
            if (!_isSitted)
            {
                PlayIdleAnimation("fox_sit");

                // Log.Info("Fox:  Sit Started");
                float animationTime = _animPlayer.GetAnimation("fox_sit").Length;
                await ToSignal(GetTree().CreateTimer(animationTime), Timer.SignalName.Timeout);
                // Log.Info("Fox: Sitting for 4 seconds completed");
                _isSitted = true;
            }
            else if (_isSitted)
            {
                // _isSitting = false;
                PlayIdleAnimation("fox_idle_sitting");
            }
        }


        if (_charMainNode != null)
        {
            //Move to Fall State if not on Floor
            if (!_charMainNode.IsOnFloor())
            {
                EmitStateTransition(this, Const.CharactersEnums.States.FOX_FALL_STATE, _charMainNode);
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
                EmitStateTransition(this, Const.CharactersEnums.States.FOX_WALK_STATE, _charMainNode);
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
            EmitStateTransition(this, Const.CharactersEnums.States.FOX_JUMP_STATE, _charMainNode);
            //direction = Vector2.Zero;
        }
    }

    private void PlayIdleAnimation(string idleAnimation)
    {

        if (_charMainNode.IsModel3D == true) //TODO: Refacot all of This. ADD IsModel3D CHECK AND ADD 3D ANIMATIONS CALLS.
        {

            _animPlayer.Play(idleAnimation);
            Log.Info($"Fox: Playing Animation: {idleAnimation}");
        }
    }



    public override void _ExitTree()
    {

    }

}
