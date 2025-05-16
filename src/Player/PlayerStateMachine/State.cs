using Godot;
using System;
using static State;

public abstract partial class State : Node, IState
{

	public Player3D characterNode; //TODO: Replace with BattleCharacter Classes after converted from GDScript 
	public Vector2 direction;
	public float currentVelocity = 0;
	public bool isCharacterMoving = false;



	// public event Action<State, T, CharacterBody2D> OnStateTransition;


	public event Action<State, string, Player3D> OnStateTransition; //#used to transition to another state / called by State Machine Manager

	// [Signal]
	// public delegate void OnStateTransitio2nEventHandler();

	public void EmitStateTransition(State currentState, string nextStateName, Player3D character) => OnStateTransition?.Invoke(currentState, nextStateName, character);

	public override void _Ready()
	{
		characterNode = GetOwner<Player3D>();//TODO: Replace with BattleCharacter Classes after converted from GDScript
	}

	public virtual void Enter()
	{
	}

	public virtual void Exit()
	{
		// OnStateTransition -= OnStateTransition;
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
