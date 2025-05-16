using Godot;

public partial class PlayerState : State
{

    //protected Node GDNodeGlobals { get; set; }
    protected AnimationPlayer GDPlayerAnimPlayerWorld { get; set; }
    protected Vector3 velocity = Vector3.Zero;
    public float characterSpeed = 10.0f;

    //protected AnimationPlayer GDPlayerAnimPlayerBattle { get; set; }

    public override void _Ready()
    {
        base._Ready();

        //GDNodeGlobals = GetNode<Node>("/root/Globals");

        var parentNodePath = GetOwner().GetPath();

        GDPlayerAnimPlayerWorld = GetNode<AnimationPlayer>(parentNodePath + "/AnimationPlayerWorld");

        //GDPlayerAnimPlayerBattle = GetNode<AnimationPlayer>(parentNodePath + "/AnimationPlayerBattle");

    }

    public override void _PhysicsProcess(double delta)
    {

        if (characterNode == null) return;

        if (!characterNode.IsOnFloor() && characterNode.stateMachineManager.CurrentState is not PlayerFallState)
        {
            EmitStateTransition(this, Const.PLAYER_FALL_STATE, characterNode);
        }




    }


}
