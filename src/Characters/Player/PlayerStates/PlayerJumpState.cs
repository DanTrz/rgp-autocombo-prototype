using System.Threading.Tasks;
using Godot;

public partial class PlayerJumpState : PlayerBaseState, ICharacterState
{
    public override Const.CharactersEnums.States StateName { get; set; } = Const.CharactersEnums.States.PLAYER_JUMP_STATE;

    [Export] public float JumpVelocity = 7.0f;
    [Export] private float airControlFactor = 0.2f;
    [Export] private float jumpDuration = 0.1f;

    private Vector3 _initialHorizontalVelocity = Vector3.Zero;

    public override void Enter()
    {

        _initialHorizontalVelocity = new Vector3(_charMainNode.Velocity.X, 0, _charMainNode.Velocity.Z);

        // Apply the jump impulse:

        //         _charMainNode.Velocity = new Vector3( // WRONG VELOCITY CODE
        //     _initialHorizontalVelocity.X * airControlFactor,
        //     JumpVelocity,
        //     _initialHorizontalVelocity.Z * airControlFactor
        // );
        _velocity = new Vector3(
            _initialHorizontalVelocity.X * airControlFactor,
            JumpVelocity,
            _initialHorizontalVelocity.Z * airControlFactor
        );

        _charMainNode.SetCharacterVelocity(_charMainNode, _velocity, "PlayerJumpState Enter");
        //_charMainNode.Velocity = _velocity; //WORKING VELOCIY CODE

        GD.Print($"1 -Velocity AT VERY END of Enter: {_charMainNode.Velocity}");
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

        if (_charMainNode == null) return;

        GD.Print($"2 -Velocity AT ManageJumpState Enter: {_charMainNode.Velocity}");
        // if (_charMainNode.IsOnFloor())//JUMP
        // {
        //     //WORKING VELOCITY CODE
        //     // _charMainNode.Velocity = new Vector3(
        //     //     _charMainNode.Velocity.X * airControlFactor,
        //     //     JumpVelocity,
        //     //     _charMainNode.Velocity.Z * airControlFactor);


        //     _velocity = new Vector3(
        //         _charMainNode.Velocity.X * airControlFactor,
        //         JumpVelocity,
        //         _charMainNode.Velocity.Z * airControlFactor);

        //     _charMainNode.SetCharacterVelocity(_charMainNode, _velocity, "PlayerJumpState ManageJumpState - JUMP");
        //     GD.Print($"3 - Velocity AT JUMP: {_charMainNode.Velocity}");
        // }

        //Apply Gravity
        //_charMainNode.Velocity += _charMainNode.GetGravity() * (float)delta; //WORKING VELOCITY CODE

        _velocity += _charMainNode.GetGravity() * (float)delta;
        _charMainNode.SetCharacterVelocity(_charMainNode, _velocity, "PlayerJumpState ManageJumpState 2 - Apply Gravity");

        _charMainNode.MoveAndSlide();

        GD.Print($"4 -Velocity AFTER  _charMainNode.MoveAndSlide();: {_charMainNode.Velocity}");


        if (_charMainNode.Velocity.Y < 0) //Means the player is starting to fall from the jump
        {
            EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_FALL_STATE, _charMainNode);
        }





        // if (_charMainNode == null) return;


        // //If not on floor - Transitio to fall
        // if (_charMainNode.Velocity.Y < 0) //Means the player is starting to fall from the jump
        // {
        //     await ToSignal(_charMainNode.GetTree().CreateTimer(jumpDuration), Godot.Timer.SignalName.Timeout);
        //     EmitStateTransition(this, Const.CharactersEnums.States.PLAYER_FALL_STATE, _charMainNode);
        // }

        // GD.Print($" 3-Velocity just before gravity in ManageJumpState: {_charMainNode.Velocity}");
        // //Apply Gravity
        // _charMainNode.Velocity += _charMainNode.GetGravity() * (float)delta; //Deduct the gravity to the jump velocity
        // // Move the character
        // _charMainNode.MoveAndSlide();

        // GD.Print($"4 - Velocity after gravity in ManageJumpState: {_charMainNode.Velocity}");

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

    public override void _ExitTree()
    {

    }
}
