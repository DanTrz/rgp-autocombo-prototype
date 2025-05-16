using Godot;
using System.Collections.Generic;
using System.Linq;

public partial class StateMachineManager : Node
{

    public State CurrentState { get; set; }
    protected Dictionary<string, State> StatesList = new();
    [Export] public State _initialState { get; set; }

    // [OnReady("/root/Globals")]
    private Player3D _currentPlayer { get; set; }

    GDScript MyGDScript { get; set; }


    public StateMachineManager()
    {
        Log.Info("State Machine Manager Created");
    }

    public override void _Ready()
    {
        Log.Info("State Machine Manager READY");

        // GDNodeGlobals = GetNode<Node>("/root/Globals");

        foreach (var node in GetChildren()) //foreach (State states in GetChildren())
        {
            State state = GetNodeOrNull<State>(node.Name.ToString());

            if (state is State)
            {
                StatesList.Add(node.Name.ToString().ToLower(), state);
                state.OnStateTransition += OnStateTransition;
            }
        }

        if (_initialState != null)
        {
            CurrentState = _initialState;
            _initialState.Enter();
        }

        //GlobalEvents.OnBattleEnded += OnBattleEnded;
        //GlobalEvents.OnBattleStarted += OnBattleStarted;
        //GlobalEvents.OnBattleLoading += OnBattleLoading;

    }

    public override void _Process(double delta)
    {
        if (CurrentState != null)
        {
            CurrentState.ProcessUpdate(delta);
        }

        if (_currentPlayer != null)
        {
            UpdatePlayerGlobals(_currentPlayer, delta);
        }
    }


    public override void _PhysicsProcess(double delta)
    {
        if (CurrentState != null)
        {
            CurrentState.PhysicsUpdate(delta);

            // update__player_globals(current_player, delta)

        }
    }


    private void OnStateTransition(State currentState, string NewStateName, Player3D character)
    {
        if (currentState != CurrentState) { return; } //No need to switch states

        State NextState = StatesList.Where((state) => state.Key == NewStateName.ToLower()).FirstOrDefault().Value;

        if (CurrentState != null)
        {
            CurrentState.Exit();
            CurrentState = NextState;
            CurrentState.Enter();
        }

        if (character != null)
        {
            _currentPlayer = character;
        }

    }

    private void UpdatePlayerGlobals(Player3D currentPlayer, double delta)
    {
        if (currentPlayer != null)
        {
            if (CurrentState != null)
            {
                if (currentPlayer.IsInGroup("Player")) //TODO Replace with Is Player (once Player Class Created)
                {
                    //GDNodeGlobals.Set("current_player_state", CurrentState.Name.ToString().ToLower());
                    //GDNodeGlobals.Set("player_global_world_position", currentPlayer.GlobalPosition);
                    // GDNodeGlobals.Set("current_player_direction", CurrentState.direction);
                    // GDNodeGlobals.Call("set_player_look_cardinal_direction", CurrentState.direction, delta);

                }

            }
        }

    }

    public override void _ExitTree()
    {
        Log.Info("State Machine Manager EXITED_TREE");
        // GlobalEvents.OnBattleEnded -= OnBattleEnded;
        // GlobalEvents.OnBattleStarted -= OnBattleStarted;
        // GlobalEvents.OnBattleLoading -= OnBattleLoading;

        // foreach (var node in GetChildren()) //foreach (State states in GetChildren())
        // {
        // 	State state = GetNodeOrNull<State>(node.Name.ToString());

        // 	if (state is State)
        // 	{
        // 		state.OnStateTransition -= OnStateTransition;
        // 	}
        // }
    }




    private void OnBattleLoading(Node areaNode, Node[] playersNodes, Node[] enemiesNodes)
    {

    }


    private void OnBattleStarted(Node areaNode, Node[] playersNodes, Node[] enemiesNodes)
    {

    }


    private void OnBattleEnded(Node areaNode, Node[] playersNodes, Node[] enemiesNodes)
    {

    }


    // func update__player_globals(character, delta) -> void:
    // if current_player != null:
    // 	if current_state:
    // 		if character.is_in_group("Player"):
    // 			Globals.current_player_state = current_state.name.to_lower()
    // 			Globals.player_global_world_position = current_player.global_position
    // 			Globals.set_player_look_cardinal_direction(Globals.current_player_direction, delta)

    // func OnBattleLoading(_area, _players_list, _enemies) -> void: #Manually forces to go to Battle Transition / Signal Emit is sent from BattleZoneArea
    // 	_on_state_transition(current_state, "inbattletransition", current_player)

    // func OnBattleStarted(_area, _players_list, _enemies) -> void: #Manually forces to go to Battle State / Signal Emit is sent from BattleZoneArea
    // 	_on_state_transition(current_state, "inbattle", current_player)

    // func OnBattleEnded(_area, _players_list, _enemies) -> void:
    // 	_on_state_transition(current_state, "idle", current_player)
}
