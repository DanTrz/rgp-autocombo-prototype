using System;
using System.Collections.Generic;
using Godot;

public partial class CameraPixelSnap : Camera3D
{

	[Export] bool _snapWorld = true;
	[Export] public bool _snapObjects = true;
	public Vector2 TextelError = Vector2.Zero;

	private Vector3 _prevRotation
	{
		get => field = this.GlobalRotation;
		set => field = value;
	}
	private Transform3D _snapSpace
	{
		get => field = this.GlobalTransform;
		set => field = value;
	}

	float _texelSize = 0.0f;

	Godot.Collections.Array<Node> _snapNodes = new();
	Godot.Collections.Array<Vector3> _preSnappedPositions = new();


	public override void _Ready()
	{
		RenderingServer.FramePostDraw += SnapObjectsRevert;
	}

	public override void _Process(double delta)
	{
		//rotation changes the snap space
		if (this.GlobalRotation != _prevRotation)
		{
			_prevRotation = this.GlobalRotation;
			_snapSpace = this.GlobalTransform;
		}
		//camera position in snap space
		_texelSize = this.Size / (float)((SubViewport)GetViewport()).Size.Y;

		//camera position in snap space
		Vector3 snapSpacePosition = this.GlobalPosition * _snapSpace;
		//Snap Position
		Vector3 snappedSnapSpacePosition = snapSpacePosition.Snapped(Vector3.One * _texelSize);
		//how much we snapped (in snap space)
		Vector3 snapError = snappedSnapSpacePosition - snapSpacePosition;

		if (_snapWorld)
		{
			//apply camera offset as to not affect the actual transform
			this.HOffset = snapError.X;
			this.VOffset = snapError.Y;
			//error in screen texels (will be used later)
			TextelError = new Vector2(snapError.X, -snapError.Y) / _texelSize;

			if (_snapObjects)
			{
				CallDeferred(nameof(SnapObjects));
			}
		}
		else
		{
			TextelError = Vector2.Zero;
		}

	}

	private void SnapObjects()
	{
		_snapNodes = GetTree().GetNodesInGroup("snap");
		_preSnappedPositions.Resize(_snapNodes.Count);

		for (int i = 0; i < _snapNodes.Count; i++)
		{
			Node3D node = _snapNodes[i] as Node3D;
			Vector3 pos = node.GlobalPosition;
			_preSnappedPositions[i] = pos;
			Vector3 snapSpacePos = pos * _snapSpace;
			Vector3 snappedSnapSpacePos = snapSpacePos.Snapped(new Vector3(_texelSize, _texelSize, 0.0f));
			node.GlobalPosition = _snapSpace * snappedSnapSpacePos;
		}
	}

	private void SnapObjectsRevert()
	{
		for (int i = 0; i < _snapNodes.Count; i++)
		{
			if (_snapNodes[i] is Node3D snapNode3D) snapNode3D.GlobalPosition = _preSnappedPositions[i];
		}
		_snapNodes.Clear();
	}

}
