using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using Godot;

public partial class ComboManager : Node
{

	private bool _isComboActive = false;
	private int _comboKeyCounter = 0; //Used to determine how many keys have been pressed in a row
	private List<string> _activeComboSequence = new();
	private Godot.Timer _comboTotalTimer => field ?? GetNode<Godot.Timer>("%ComboTotalTimer");
	private Godot.Timer _comboStepTimer => field ?? GetNode<Godot.Timer>("%ComboStepTimer");

	private Godot.Timer _choiceSelectorTimer => field ?? GetNode<Godot.Timer>("%ChoiceSelectorTimer");

	private ProgressBar _choiceSelectorProgressBar => field ?? GetNode<ProgressBar>("%ChoiceSelectorProgressBar");  //TODO: Temp/pROTOTYPE
	private ProgressBar _comboTotalTimerProgressBar => field ?? GetNode<ProgressBar>("%ComboTotalTimerProgressBar");  //TODO: Temp/pROTOTYPE
	private ProgressBar _comboStepTimerProgressBar => field ?? GetNode<ProgressBar>("%ComboStepTimerProgressBar");  //TODO: Temp/pROTOTYPE

	private BoxContainer _buttonsContainer => field ?? GetNode<BoxContainer>("%Buttons");  //TODO: Temp/pROTOTYPE

	private BaseCharacter _character => field ?? GetOwner<BaseCharacter>(); //TODO: Temp/pROTOTYPE
	private CanvasLayer _debugUIComboSystem => field ?? GetNode<CanvasLayer>("%DebugUIComboSystem");  //TODO: Temp/pROTOTYPE
	private ComboKeysContainer _comboKeyContaier => field ?? GetNode<ComboKeysContainer>("%ComboKeysContainer");  //TODO: Temp/pROTOTYPE


	private Button _attack1Button => field ?? GetNode<Button>("%Attack1"); //TODO: Temp/pROTOTYPE
	private Button _attack2Button => field ?? GetNode<Button>("%Attack2");  //TODO: Temp/pROTOTYPE

	private Button _startTurnButton => field ?? GetNode<Button>("%StartTurn"); //TODO: Temp/pROTOTYPE


	//Using a TEMP tuple //TODO: THis will come from a COllection Stored Somewhere else in the future. 
	List<(string skillName, bool hasCombo, List<string> comboSequence)> _skillsComboMap = new()  //TODO: Temp/pROTOTYPE
	{
		("Attack1", true, new List<string> { "R", "T" }),
		("Attack2", false, new List<string> { ""}),
	};

	public override void _Ready()
	{
		Log.Debug($"ComboManager Ready - from {_character.Name}");
		_attack1Button.Pressed += () => OnAttackButtonPressed("Attack1"); //TODO: Temp //TEST only - Replace with Context List and UI Manager in the future
		_attack2Button.Pressed += () => OnAttackButtonPressed("Attack2");
		_startTurnButton.Pressed += () => StartChoiceTimer(3.0f);
		_comboTotalTimer.Timeout += () => ComboSequenceFailed("ComboTotalTimer Timeout", 0);
		_comboStepTimer.Timeout += () => ComboSequenceFailed("ComboKeyPressTimer Timeout", 0);
		_choiceSelectorTimer.Timeout += ChoiceSelectionTimeOut;

	}

	public override void _Process(double delta)
	{
		UpdateProgressBars();
	}

	private void ChoiceSelectionTimeOut()
	{
		_buttonsContainer.Visible = false;
		Log.Debug("Turn Cancelled: Choice Selection TimeOut");

		//TODO: Add logic here that would cancel the turn / skip the turn and reset turn timer. 
	}

	private void StartChoiceTimer(float timerDuration)
	{
		_buttonsContainer.Visible = true;
		_choiceSelectorTimer.Start(timerDuration);
		_choiceSelectorProgressBar.MaxValue = timerDuration;
		_choiceSelectorProgressBar.Value = timerDuration;
	}

	private void UpdateProgressBars()
	{
		if (_choiceSelectorTimer.TimeLeft > 0)
		{
			_choiceSelectorProgressBar.Value = _choiceSelectorTimer.TimeLeft;
		}
		if (_isComboActive)
		{
			_comboTotalTimerProgressBar.Value = _comboTotalTimer.TimeLeft;
			_comboStepTimerProgressBar.Value = _comboStepTimer.TimeLeft;
		}
	}

	#region TEMP CODE - PROTOTYPE ONLY   //TODO: Temp/pROTOTYPE
	private void OnAttackButtonPressed(string skillSelected)
	{
		_choiceSelectorTimer.Stop();//TODO - THis shouuld Puase the Turn Counter
									// if (_skillsWithComboMap.TryGetValue(skillSelected, out bool hasCombo))
		var selectedSkill = _skillsComboMap.Find(x => x.skillName == skillSelected);
		if (selectedSkill.hasCombo && !_isComboActive)
		{
			Log.Debug($"Skill {skillSelected} has Combo - Starting Monitoring Combo");
			GetViewport().SetInputAsHandled();

			// ComboSequenceStart(_skillsComboSequence[skillSelected]);
			ComboSequenceStart(selectedSkill.comboSequence);
			foreach (string key in selectedSkill.comboSequence)
			{
				_comboKeyContaier.AddComboKey(key);
			}
		}
	}

	#endregion TEMP CODE - PROTOTYPE ONLY

	//Monitor Combo Key presses
	public override void _UnhandledInput(InputEvent @event)
	{
		if (_isComboActive)
		{
			ManageComboKeyPresses(@event);
		}
	}

	//Used to Start a Combo Sequence - First Step in the Combo
	private void ComboSequenceStart(List<string> comboSequence)
	{
		//Prepare the ComboManager (or reset it) to track a new combo
		_isComboActive = true;
		_activeComboSequence = new List<string>(comboSequence); //Passes a Copy of the Combo Sequence
		_comboTotalTimer.Start(10.0f);
		_comboStepTimer.Start(2f);

		_comboTotalTimerProgressBar.MaxValue = _comboTotalTimer.TimeLeft;
		_comboTotalTimerProgressBar.Value = _comboTotalTimer.TimeLeft;

		_comboStepTimerProgressBar.MaxValue = _comboStepTimer.TimeLeft;
		_comboStepTimerProgressBar.Value = _comboStepTimer.TimeLeft;


	}

	//This is triggered as a Result of a Specific Combo Step (One Key) being pressed at the right time
	private void ComboStepSuccessful(string lastKeyPressed, int comboCounterStep)
	{
		_comboStepTimer.Start(2.0f); //Reset ComboKeyPressTimer - In preparation for next KeyPress //In the future this time needs to be set based on the Combo Step Duration (Combo Step duration needs to consider the animation time of the previous step + Time for player to execute the Key press - We should store all that information in a Collection)
		Log.Debug($"COMBO KEY CORRECT - keyPressed: {lastKeyPressed}, comboCounter: {comboCounterStep}");

		_comboKeyContaier.UpdateComboKeyColor(comboCounterStep, Colors.Green);  //TEMP CODE //TODO Remove in the future - Just for Testing


		//TODO: Here we would have logic to execute the Combo Step Animation + Apply Damage
	}

	//Used to End Combos as a result of a failure
	private void ComboSequenceFailed(string failCode, int comboCounterStep)
	{
		Log.Debug($"COMBO FAILED: Reason: {failCode}");
		Log.Debug($"COMBO FAILED: ComboTimer = {_comboTotalTimer.TimeLeft}, ComboKeyPressTimer = {_comboStepTimer.TimeLeft}");

		_comboKeyContaier.UpdateComboKeyColor(comboCounterStep, Colors.Red); //TEMP CODE //TODO Remove in the future - Just for Testing

		ResetComboManager();
	}

	//Used to End Combos as a result of a full COMBO being SUCESS
	private void ComboSequenceSuccessful()
	{
		//Log.Debug($"COMBO COMPLETE full Sequence: {_activeComboSequence.ToString()}");
		Log.Debug($"FULL COMBO COMPLETED => Combo Sequence: {string.Join(", ", _activeComboSequence)}");

		ResetComboManager();

		//TODO: OPTIONAL - Here we would have Code to execute as a result of a successful Full Combo (But to be begin with this is not needed)
		//We should start small and add the Damage/Animation as a result of a Combo Step being successful (See ComboStepSuccessful())
	}

	private async void ResetComboManager()
	{
		await ToSignal(GetTree().CreateTimer(0.5f), SceneTreeTimer.SignalName.Timeout);  //TEMP CODE //TODO Remove in the future - Just for Testing// Used just to allow the DebugUI to show the "Green/Red" Colors changes before the ComboManager is reset and disaperar from the screen

		_isComboActive = false;
		_comboTotalTimer.Stop();
		_comboStepTimer.Stop();
		_comboKeyContaier.ClearComboKeys();
		_comboKeyCounter = 0;
		_activeComboSequence.Clear();

		_buttonsContainer.Visible = false;
	}

	private void ManageComboKeyPresses(InputEvent @event)
	{
		string keyPressed = "";
		if (@event is InputEventKey keyEvent && keyEvent.Pressed) // keyEvent.Pressed is true when the key is pressed //Avoid double registering key presses
		{
			keyPressed = keyEvent.Keycode.ToString();
			Log.Debug($"keyPressed: {keyPressed}, keyPressedCount: {_comboKeyCounter}");

			GetViewport().SetInputAsHandled();

			if (_comboStepTimer.TimeLeft <= 0.0f || _comboKeyCounter >= _activeComboSequence.Count)
			{
				ComboSequenceFailed("_comboKeyPressTimer Timeout", _comboKeyCounter);
				return;
			}

			if (keyPressed == _activeComboSequence[_comboKeyCounter])
			{
				ComboStepSuccessful(keyPressed, _comboKeyCounter);

				if (_comboKeyCounter == _activeComboSequence.Count - 1)
				{
					_isComboActive = false;
					ComboSequenceSuccessful();
				}
			}
			else
			{
				ComboSequenceFailed($"Wrong Key Pressed: {keyPressed}, Expected: {_activeComboSequence[_comboKeyCounter]}, KeyPressedCount: {_comboKeyCounter}", _comboKeyCounter);
			}

			_comboKeyCounter++;
		}

	}
}
