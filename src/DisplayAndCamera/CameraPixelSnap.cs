using System;
using System.Collections.Generic;
using Godot;

/// <summary>
/// CameraPixelSnap is a specialized Camera3D that ensures both the camera and objects
/// in the scene align to pixel boundaries to achieve a pixel-perfect rendering effect.
/// </summary>
public partial class CameraPixelSnap : Camera3D
{

	// Determines if the camera's view should be snapped to pixel boundaries.
	[Export] public bool SnapWorld = true;
	// Determines if objects in the scene should also be snapped to pixel boundaries ( objects must have the "snap" group.)
	[Export] public bool SnapObjects = true;
	[Export] string snapGroup = "snap_objects";

	// Stores the error in texel snapping, useful for adjusting sprite positions.
	public Vector2 TexelError = Vector2.Zero;
	// Previous rotation of the camera to detect changes.
	private Vector3 _prevRotation { get; set; }
	// Transformation matrix used for snapping calculations.
	private Transform3D _snapSpace { get; set; }
	// Size of a single texel in world units.
	float _texelSize = 0.0f;
	// Collection of nodes that need to be snapped to pixel boundaries.
	Godot.Collections.Array<Node> _snapNodes = new();
	// Original positions of nodes before snapping.
	Godot.Collections.Array<Vector3> _preSnappedPositions = new();

	public override void _Ready()
	{
		// Cache the initial rotation and transformation of the camera.
		_prevRotation = this.GlobalRotation;
		_snapSpace = this.GlobalTransform;
		// Connects to the RenderingServer's post-draw event to revert snapped objects.
		RenderingServer.FramePostDraw += SnapObjectsRevert;
	}

	public override void _Process(double delta)
	{
		if (!SnapWorld && !SnapObjects) return;
		// Check if the camera's rotation has changed.
		if (this.GlobalRotation != _prevRotation)
		{
			// Update previous rotation and snap space transform.
			_prevRotation = this.GlobalRotation;
			_snapSpace = this.GlobalTransform;
		}
		// Calculate texel size based on the viewport size.
		_texelSize = this.Size / (float)((SubViewport)GetViewport()).Size.Y;
		// Calculate the camera's position in the snapping space.
		Vector3 snapSpacePosition = this.GlobalPosition * _snapSpace;

		// Snap the position to the nearest texel.//CHANGES HERE
		//Vector3 snappedSnapSpacePosition = snapSpacePosition.Snapped(Vector3.One * _texelSize); //Original (X and Y)
		Vector3 snappedSnapSpacePosition = snapSpacePosition.Snapped(new Vector3(_texelSize, _texelSize, _texelSize)); //Added DT:try and snap Z also

		// Calculate the error introduced by snapping.
		Vector3 snapError = snappedSnapSpacePosition - snapSpacePosition;
		if (SnapWorld)
		{
			// Apply the snapping offset to the camera without altering the actual transform.
			this.HOffset = snapError.X;
			this.VOffset = snapError.Y;
			// Calculate the snapping error in screen space texels.
			TexelError = new Vector2(snapError.X, -snapError.Y) / _texelSize;
			if (SnapObjects)
			{
				// Defer the snapping of objects to pixel boundaries.
				CallDeferred(nameof(SnapObjectsToPixel));
			}
		}
		else
		{
			// Reset texel error if snapping is disabled.
			TexelError = Vector2.Zero;
		}
	}

	/// <summary>
	/// Snaps objects in the "snap" group to pixel boundaries.
	/// </summary>
	private void SnapObjectsToPixel()
	{
		// Retrieve nodes in the "snap" group.
		_snapNodes = GetTree().GetNodesInGroup(snapGroup);

		//if (_snapNodes.Count == 0 && _prevRotation == this.GlobalRotation) return; //Added DT: Tries to avoid snaping when no changes

		_preSnappedPositions.Resize(_snapNodes.Count);
		for (int i = 0; i < _snapNodes.Count; i++)
		{
			// Cast node to Node3D and store its original position.
			Node3D node = _snapNodes[i] as Node3D;
			Vector3 pos = node.GlobalPosition;
			_preSnappedPositions[i] = pos;

			// Calculate and apply the snapped position.
			Vector3 snapSpacePos = pos * _snapSpace;
			Vector3 snappedSnapSpacePos = snapSpacePos.Snapped(new Vector3(_texelSize, _texelSize, 0.0f));
			node.GlobalPosition = _snapSpace * snappedSnapSpacePos;
		}
	}

	/// <summary>
	/// Reverts objects snapped to pixel boundaries back to their original positions.
	/// </summary>
	private void SnapObjectsRevert()
	{
		for (int i = 0; i < _snapNodes.Count; i++)
		{
			// Restore the original position of each node.
			if (_snapNodes[i] is Node3D snapNode3D) snapNode3D.GlobalPosition = _preSnappedPositions[i];
		}
		// Clear the list of snapped nodes.
		_snapNodes.Clear();
	}
}
