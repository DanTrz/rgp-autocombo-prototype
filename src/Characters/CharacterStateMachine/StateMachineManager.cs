using System.Collections.Generic;
using System.Linq;
using Godot;

public partial class StateMachineManager : Node
{
    public CharacterBaseState CurrentState { get; set; }
    protected Dictionary<Const.CharactersEnums.States, CharacterBaseState> _statesList = [];
    [Export] private CharacterBaseState _initialState { get; set; }

    // [OnReady("/root/Globals")]
    private BaseCharacter _currentCharacter { get; set; }

    public StateMachineManager()
    {
        Log.Info("State Machine Manager Created");
    }

    public override void _Ready()
    {
        Log.Info($"{GetOwner().Name} : State Machine Manager READY");

        foreach (Node node in GetChildren())
        {
            if (node is CharacterBaseState _characterState)
            {
                _statesList.Add(_characterState.StateName, _characterState);
                _characterState.OnStateTransition += OnCharacterStateTransition;
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
        CurrentState?.ProcessUpdate(delta);

        if (_currentCharacter != null)
        {
            UpdatePlayerGlobals(_currentCharacter, delta);
        }
    }


    public override void _PhysicsProcess(double delta)
    {
        CurrentState?.PhysicsUpdate(delta);
    }

    private void OnCharacterStateTransition(CharacterBaseState currentState, Const.CharactersEnums.States NewStateName, BaseCharacter character)
    {
        if (currentState != CurrentState) { return; } //No need to switch states

        // CharacterState _nextState = StatesList.Where((state) => state.Key == NewStateName.ToLower()).FirstOrDefault().Value;
        //CharacterBaseState _nextState = _statesList.Where((state) => state.Value.StateName == NewStateName).FirstOrDefault().Value;
        CharacterBaseState _nextState = _statesList.FirstOrDefault((state) => state.Value.StateName == NewStateName).Value;

        if (CurrentState != null)
        {
            CurrentState.Exit();
            CurrentState = _nextState;
            CurrentState.Enter();
        }

        if (character != null)
        {
            _currentCharacter = character;
        }

    }

    private void UpdatePlayerGlobals(BaseCharacter currentPlayer, double delta)
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
        //Log.Info("State Machine Manager EXITED_TREE");
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




    private static void OnBattleLoading(Node areaNode, Node[] playersNodes, Node[] enemiesNodes)
    {

    }


    private static void OnBattleStarted(Node areaNode, Node[] playersNodes, Node[] enemiesNodes)
    {

    }


    private static void OnBattleEnded(Node areaNode, Node[] playersNodes, Node[] enemiesNodes)
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
