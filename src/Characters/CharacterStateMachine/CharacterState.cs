using System;
using System.Linq;
using Godot;

public abstract partial class CharacterBaseState : Node, ICharacterState //TODO : Check if there is a better way to use this INterface, doe snothing at the moment. 
{
    //Export] public Const.CharactersEnums.States StateName { get; set; }
    public abstract Const.CharactersEnums.States StateName { get; set; }

    protected BaseCharacter _charMainNode => field ?? GetOwner<BaseCharacter>();
    protected virtual AnimationPlayer _animPlayer => field ?? GlobalUtil.GetAllChildNodesByType<AnimationPlayer>(GetOwner()).FirstOrDefault(); //TODO: Fix this - Not scalable way to find AnimationPlayer (too expensive to search AllChildNodes
    protected Node3D _charSkin => field ?? _charMainNode.GetNodeOrNull<Node3D>("%Skin");
    protected Vector2 _direction2D = Vector2.Zero;
    protected Vector3 _direction3D = Vector3.Zero;
    protected Vector3 _velocity = Vector3.Zero;
    protected float _charSpeed = 20.0f;
    protected float _charRotationSpeed = 100.0f;
    protected float _charAcceleration = 100.0f;
    protected bool _isCharMoving = false;
    public event Action<CharacterBaseState, Const.CharactersEnums.States, BaseCharacter> OnStateTransition; //#used to transition to another state / called by State Machine Manager
    //public float currentVelocity = 0;

    public void EmitStateTransition(CharacterBaseState currentState, Const.CharactersEnums.States nextStateName, BaseCharacter character) => OnStateTransition?.Invoke(currentState, nextStateName, character);


    public virtual void Enter()
    {
    }

    public virtual void Exit()
    {
    }

    public virtual void ProcessUpdate(double delta)
    {

    }

    public virtual void PhysicsUpdate(double delta)
    {
    }

    public override void _ExitTree()
    {

    }


}
