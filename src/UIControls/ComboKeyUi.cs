using System;
using Godot;

public partial class ComboKeyUi : PanelContainer
{
	public Label ComboKeyLabel => field ?? GetNode<Label>("%Label");


}
