using System;
using System.Collections.Generic;
using Godot;

public partial class ComboKeysContainer : FlowContainer
{

	[Export] private PackedScene _comboKeyUiPackedScene;
	List<ComboKeyUi> _loadedComoboKeys = new();

	public void ClearComboKeys()
	{
		_loadedComoboKeys.Clear();

		foreach (ComboKeyUi comboKeyUi in GetChildren())
		{
			RemoveChild(comboKeyUi);
			comboKeyUi.QueueFree();
		}
	}

	public void AddComboKey(string keyText)
	{
		ComboKeyUi comboKeyUi = _comboKeyUiPackedScene.Instantiate<ComboKeyUi>();
		comboKeyUi.ComboKeyLabel.Text = keyText;
		comboKeyUi.Modulate = Colors.White;
		AddChild(comboKeyUi);
		_loadedComoboKeys.Add(comboKeyUi);
	}

	public void UpdateComboKeyColor(int indexPosition, Color color)
	{
		_loadedComoboKeys[indexPosition].Modulate = color;
	}

}

